extends SceneTree
const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Arena := preload("res://src/skills_builder/arena_preview.gd")
var arena: Node3D
var viewport: SubViewport
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond: falhas += 1

func avancar(segundos: float) -> void:
	for i in int(ceil(segundos * 120)): arena._process(1.0 / 120.0)

func evento(tipo: String, inicio: float = 0.0, duracao: float = 1.0) -> Dictionary:
	return {"id":tipo, "tipo":tipo, "inicio":inicio, "duracao":duracao, "habilitado":true, "parametros":{}}

func amostrar_pose() -> Array[Transform3D]:
	var amostras: Array[Transform3D] = []
	for esqueleto: Skeleton3D in arena.modelo.find_children("*", "Skeleton3D", true, false):
		for i in esqueleto.get_bone_count(): amostras.append(esqueleto.get_bone_pose(i))
	# Base v2 usa rig por nós, enquanto Harpia usa Skeleton3D.
	if amostras.is_empty():
		for papel in ["Torso", "UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Thigh_L", "Thigh_R"]:
			var no: Node3D = arena.modelo.find_child(papel, true, false)
			if no: amostras.append(no.transform)
	return amostras

func animacao_move() -> bool:
	arena.buscar(.1)
	var antes := amostrar_pose()
	arena.buscar(.35)
	var depois := amostrar_pose()
	for i in mini(antes.size(), depois.size()):
		if not antes[i].is_equal_approx(depois[i]): return true
	return false

func rodar() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	arena = Arena.new()
	viewport.add_child(arena)
	arena.set_process(false)
	var d := Dados.novo()
	arena.configurar(d)
	ok(arena.rodar().is_empty() and arena.energia == 90, "Rodar debita custo e inicia")
	avancar(.7)
	ok(arena.vida_alvo == 975 and arena.estado().acertos == 1, "hitbox aplica um único dano real")
	var tempo: float = arena.tempo
	arena.pausar()
	avancar(.2)
	ok(arena.tempo == tempo, "pausa congela o executor")
	arena.pausar()
	avancar(.9)
	ok(not arena.rodando and not arena.rodar().is_empty(), "fim encerra e cooldown bloqueia nova ativação")
	arena.reiniciar()
	ok(arena.energia == 100 and arena.vida_alvo == 1000 and arena._transitorios.get_child_count() == 0, "reiniciar limpa efeitos e restaura arena")
	arena.buscar(.6)
	var pos: Vector3 = arena.ator.position
	var hp: float = arena.vida_alvo
	arena.buscar(.2)
	arena.buscar(.6)
	ok(arena.vida_alvo == hp and arena.ator.position.is_equal_approx(pos), "scrub para trás/à frente é reproduzível")
	ok(arena._transitorios.find_children("*", "AudioStreamPlayer", true, false).is_empty(), "scrub não dispara áudio")
	arena.buscar(.4)
	arena.definir_hitboxes(false)
	ok(not arena._eventos.hitbox_1.node.visible, "ocultar hitboxes funciona com prévia pausada")
	arena.definir_hitboxes(true)
	ok(arena._eventos.hitbox_1.node.visible, "exibir hitboxes funciona com prévia pausada")
	ok(arena._ap != null and arena._ap.has_animation("punching"), "prévia base possui clipe real de ataque")
	ok(animacao_move(), "amostras do rig comprovam movimento no clipe Base")
	arena.buscar(.6)
	ok(is_equal_approx(arena.ator.position.z, -1.2), "movimento chega à distância exata no fim do evento")
	for forma in ["Esfera", "Caixa", "Cápsula"]:
		d = Dados.novo()
		d.eventos = [evento("hitbox")]
		d.hitboxes.forma = forma
		d.hitboxes.z = -4.0
		arena.configurar(d)
		arena.buscar(.4)
		ok(arena.vida_alvo == 975, "colisão da forma " + forma)
		d.hitboxes.x = 8.0
		arena.configurar(d)
		arena.buscar(.4)
		ok(arena.vida_alvo == 1000, "offset da forma " + forma + " evita acerto")
	d = Dados.novo()
	d.eventos = [evento("hitbox")]
	d.hitboxes.z = -4.0
	d.hitboxes.unicos = false
	d.dano.empurrao = 0
	arena.configurar(d)
	arena.buscar(.65)
	ok(arena.estado().acertos == 4, "multihit usa intervalo e não causa dano a cada frame")
	d.hitboxes.unicos = true
	d.dano.critico = 100
	d.dano.multiplicador = 3
	arena.configurar(d)
	arena.buscar(.4)
	ok(arena.vida_alvo == 925, "crítico usa multiplicador configurado")
	d.dano.critico = 0
	d.dano.atordoamento = 1
	arena.configurar(d)
	arena.alvo_movel = true
	arena.buscar(.5)
	ok(is_zero_approx(arena.alvo.position.x) and arena.estado().efeito == "Atordoado", "atordoamento imobiliza alvo móvel")
	d.dano.atordoamento = 0
	d.dano.lentidao = 100
	d.dano.duracao_efeito = 1
	arena.configurar(d)
	arena.buscar(.5)
	ok(is_zero_approx(arena.alvo.position.x), "lentidão de 100% impede deslocamento")
	d.dano.lentidao = 0
	arena.configurar(d)
	arena.buscar(.5)
	ok(arena.alvo.position.x > .1, "alvo móvel se desloca sem impedimentos")
	arena.alvo_movel = false
	d = Dados.novo()
	d.eventos = [evento("projetil")]
	d.projeteis.velocidade = 100
	d.projeteis.raio = .05
	arena.configurar(d)
	arena.buscar(.12)
	ok(arena.vida_alvo == 975 and arena._projeteis[0].morto, "projétil rápido usa colisão varrida e termina no impacto")
	d.projeteis.perfurar = true
	arena.configurar(d)
	arena.buscar(.12)
	ok(arena.vida_alvo == 975 and not arena._projeteis[0].morto, "projétil perfurante continua após impacto")
	d = Dados.novo()
	arena.configurar(d)
	arena.nivel = 0
	ok(not arena.rodar().is_empty() and arena.energia == 100, "nível bloqueia sem consumir energia")
	arena.nivel = 1
	d.condicoes.exige_chao = true
	d.condicoes.vida_minima = 50
	arena.configurar(d)
	arena.no_chao = false
	ok(not arena.rodar().is_empty(), "condição de chão bloqueia")
	arena.no_chao = true
	arena.vida = 40
	ok(not arena.rodar().is_empty(), "condição de vida bloqueia")
	arena.vida = 100
	arena.distancia_alvo = 20
	arena.reiniciar()
	ok(not arena.rodar().is_empty(), "alcance bloqueia alvo distante")
	arena.distancia_alvo = 4
	arena.reiniciar()
	arena.energia = 0
	ok(not arena.rodar().is_empty(), "custo bloqueia energia insuficiente")
	d.ativacao.modo = "Segurar"
	d.ativacao.carga = .5
	d.eventos = [evento("hitbox")]
	d.hitboxes.z = -4.0
	arena.configurar(d)
	arena.rodar(true)
	avancar(.2)
	ok(arena.tempo == 0 and arena.vida_alvo == 1000, "carga aguarda antes de iniciar eventos no tempo zero")
	arena.soltar()
	ok(not arena.rodando and arena.energia == 100 and arena.estado().recarga == 0, "soltar cedo cancela carga e restitui custo")
	arena.rodar(true)
	avancar(.6)
	ok(arena.vida_alvo == 975, "segurar até carregar executa habilidade")
	d.ativacao.modo = "Automática"
	d.configuracoes.recarga = 0
	d.configuracoes.duracao = .2
	d.eventos = []
	arena.configurar(d)
	arena.rodar()
	avancar(.5)
	ok(arena.energia <= 70, "modo automático repete após conclusão")
	arena.parar()
	var energia: float = arena.energia
	avancar(.5)
	ok(arena.energia == energia and not arena.rodando, "Parar interrompe repetição")
	d = Dados.novo()
	d.eventos = [evento("audio", 0, .1), evento("camera", 0, .2), evento("vfx", 0, .4)]
	d.audio.volume = -15
	d.audio.tom = 1.5
	d.camera.zoom = 35
	d.vfx.escala = 2
	arena.configurar(d)
	arena.rodar()
	var som: AudioStreamPlayer = arena._eventos.audio.audio
	ok(som.playing and som.volume_db == -15 and som.pitch_scale == 1.5, "evento de áudio usa som, volume e tom")
	arena.pausar()
	ok(som.stream_paused, "pausar suspende áudio junto da timeline")
	arena.pausar()
	avancar(.15)
	ok(not som.playing, "fim do bloco de áudio encerra reprodução")
	ok(arena.camera.fov == 35 and arena._eventos.vfx.node.scale.x > .8, "câmera e escala VFX respondem aos parâmetros")
	d = Dados.novo()
	d.identificacao.modelo = "Harpia"
	arena.configurar(d)
	arena.buscar(.45)
	ok(arena._pose != null and arena._ap != null and not arena._clip.is_empty(), "Harpia usa esqueleto, pose e animação importada")
	ok(animacao_move(), "amostras de ossos comprovam movimento no clipe Harpia")
	arena.parar()
	ok(arena._transitorios.get_child_count() == 0 and arena.camera.fov == 48, "Parar limpa VFX/projéteis e restaura câmera")
	viewport.queue_free()
	await process_frame
	print("SKILLS_BUILDER_PREVIEW_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)
