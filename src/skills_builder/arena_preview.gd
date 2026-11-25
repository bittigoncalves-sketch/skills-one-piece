extends Node3D
## Ensaio isolado: tempo fixo e seed estável tornam a timeline reproduzível.
## Não instancia Player, DamageZone, progressão nem peers de rede.
signal mudou(snapshot: Dictionary)
const PASSO := 1.0 / 120.0
const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Transformacao := preload("res://src/skills_builder/transformacao_de_skill.gd")
const PoseHarpia := preload("res://src/historia/bosses/harpia/pose_harpia.gd")
## Malhas, VFX e som numa fonte só com o executor do jogo (06/10/2026).
const Visual := preload("res://src/skills_builder/visual_de_skill.gd")
const Catalogo := preload("res://src/skills_builder/catalogo_de_projeteis.gd")
const Chuva := preload("res://src/skills_builder/chuva_de_projeteis.gd")
const Clipes := preload("res://src/skills_builder/clipes_de_skill.gd")
var skill: Dictionary = {}
var tempo := 0.0
var rodando := false
var pausado := false
var vida_alvo := 1000.0
var energia := 100.0
var distancia_alvo := 4.0
var nivel := 1
var no_chao := true
var vida := 100.0
var mostrar_hitboxes := true
var alvo_movel := false
var camera: Camera3D
var ator: Node3D
var alvo: Node3D
var modelo: Node3D
var _ap: AnimationPlayer
var _pose: SkeletonModifier3D
var _alvo_label: Label3D
var _transitorios: Node3D
var _eventos := {}
var _projeteis: Array[Dictionary] = []
var _hits := {}
var _acertos := 0
var _recarga := 0.0
var _carga := 0.0
var _acumulado := 0.0
var _status := "Pronto"
var _efeito := ""
var _status_ate := 0.0
var _stun_ate := 0.0
var _gelo_ate := 0.0          # "Congelar" (07/10/2026): o alvo de treino no bloco de gelo
var _bloco_de_gelo: MeshInstance3D
var _slow_ate := 0.0
var _slow := 0.0
var _knockback := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _repetindo := false
var _yaw := 0.68
var _pitch := 0.43
var _dist := 7.0
var _tremor := 0.0
var _fov := 48.0
var _clip := ""
# Poses do Builder (06/10/2026): juntas do Base (BodyScanner), pose em curso e a pose
# fixa mostrada pelo editor de poses ("" = segue a timeline).
var _rig := {}
var _pose_atual := {}
var _pose_aplicada := false
var pose_em_edicao := ""
var _modelo_id := ""
var _ativacao_manual := false
# "Carregar e soltar": parado no ponto de segurar enquanto a tecla segue apertada.
# Rodar/F5 (sem tecla) segura `SEGURAR_NO_RODAR` s e solta sozinho.
const SEGURAR_NO_RODAR := 0.6
var _segurando := false
var _segurado := 0.0
var _viagem_acabou := false       # "Terminar sobre o inimigo" já levou o ator até o alvo
## Bloco Animação com clipe neste passo (07/10/2026): a pose do Builder não o cobre (no
## jogo o clipe de ação também passa por cima da pose).
var _clipe_ativo := false
var _torso_pos0 := Vector3.INF    # posição de repouso do tronco (o clipe sobe/desce o corpo)

func _ready() -> void:
	_montar_arena()
	if skill.is_empty():
		skill = Dados.novo()
	_montar_ator()
	reiniciar()

func configurar(d: Dictionary) -> void:
	skill = d.duplicate(true)
	if is_inside_tree():
		_montar_ator()
		reiniciar()
		if not pose_em_edicao.is_empty():
			mostrar_pose(pose_em_edicao)     # o editor de poses continua mostrando a pose

func rodar(manual: bool = false) -> String:
	pose_em_edicao = ""                      # rodar mostra a timeline, não a pose parada
	if rodando:
		return "A habilidade já está em execução."
	var validacao: Dictionary = Dados.validar(skill)
	if not validacao.ok:
		return "; ".join(validacao.erros)
	var c: Dictionary = skill.condicoes
	if nivel < int(c.nivel_minimo):
		return "Nível insuficiente."
	if vida < float(c.vida_minima):
		return "Vida do ator insuficiente."
	if c.exige_chao and not no_chao:
		return "O ator precisa estar no chão."
	if c.exige_alvo and vida_alvo <= 0.0:
		return "Reinicie o alvo para testar."
	var distancia := ator.position.distance_to(alvo.position)
	if c.exige_alvo and distancia > minf(float(c.distancia_maxima), float(skill.configuracoes.alcance)):
		return "Alvo fora do alcance configurado."
	if _recarga > 0.001:
		return "A habilidade está em recarga."
	if energia < float(skill.configuracoes.custo):
		return "Energia insuficiente; reinicie a arena."
	_limpar_execucao()
	energia -= float(skill.configuracoes.custo)
	_recarga = float(skill.configuracoes.recarga)
	_carga = float(skill.ativacao.carga) if skill.ativacao.modo == "Segurar" else 0.0
	rodando = true
	pausado = false
	_ativacao_manual = manual
	_segurando = skill.ativacao.modo == "Carregar e soltar"
	_segurado = 0.0
	_repetindo = skill.ativacao.repetir or skill.ativacao.modo == "Automática"
	_status = "Carregando" if _carga > 0.0 else "Executando"
	if _carga <= 0.0: _atualizar_eventos(false)
	mudou.emit(estado())
	return ""

func soltar() -> void:
	if not _ativacao_manual: return
	if str(skill.ativacao.modo) == "Sustentar" and rodando:
		# "Sustentar": soltar a tecla encerra a skill ali.
		parar()
		_status = "Soltou: encerrada"
		_ativacao_manual = false
		return
	if _segurando:
		_segurando = false
		if tempo < float(skill.ativacao.get("ponto_segurar", 0.5)) - 0.0001:
			# Soltou antes do ponto: cancela e devolve, como o Segurar.
			energia = minf(100.0, energia + float(skill.configuracoes.custo))
			_recarga = 0.0
			parar()
			_status = "Carga cancelada"
		_ativacao_manual = false
		return
	if _carga > 0.0:
		energia = minf(100.0, energia + float(skill.configuracoes.custo))
		_recarga = 0.0
		parar()
		_status = "Carga cancelada"
	else:
		_repetindo = false
	_ativacao_manual = false

func pausar() -> void:
	if rodando:
		pausado = not pausado
		for n in _transitorios.get_children():
			if n is AudioStreamPlayer:
				n.stream_paused = pausado
		mudou.emit(estado())

func parar() -> void:
	_segurando = false
	_pose_atual = {}
	_aplicar_pose_no_modelo({})
	rodando = false
	pausado = false
	_repetindo = false
	_limpar_nos()
	_restaurar_pose()
	_tremor = 0.0
	_fov = 48.0
	_status = "Parado"
	_camera()
	mudou.emit(estado())

func reiniciar() -> void:
	parar()
	_limpar_execucao()
	vida_alvo = 1000.0
	energia = 100.0
	_recarga = 0.0
	_stun_ate = 0.0
	_gelo_ate = 0.0
	_slow_ate = 0.0
	_slow = 0.0
	_status_ate = 0.0
	_knockback = Vector3.ZERO
	_efeito = ""
	if alvo:
		alvo.position = Vector3(0, 0, -distancia_alvo)
		alvo.rotation = Vector3.ZERO
	_status = "Pronto"
	_atualizar_alvo()
	mudou.emit(estado())

func buscar(t: float) -> void:
	reiniciar()
	t = clampf(t, 0.0, float(skill.configuracoes.duracao))
	energia = maxf(0, energia - float(skill.configuracoes.custo))
	_atualizar_eventos(true)
	while tempo + PASSO < t:
		_avancar(PASSO, true)
	if t > tempo:
		_avancar(t - tempo, true)
	rodando = true
	pausado = true
	_repetindo = false
	_status = "Prévia da timeline"
	_atualizar_alvo()
	_camera()
	mudou.emit(estado())

func orbitar(delta: Vector2) -> void:
	_yaw -= delta.x * 0.007
	_pitch = clampf(_pitch + delta.y * 0.005, 0.12, 1.25)
	_camera()

func zoom(delta: float) -> void:
	_dist = clampf(_dist + delta, 4.0, 32.0)
	_camera()

func definir_hitboxes(visiveis: bool) -> void:
	mostrar_hitboxes = visiveis
	for e: Dictionary in skill.eventos:
		if e.tipo == "hitbox" and _eventos.has(e.id) and _eventos[e.id].has("node"):
			_eventos[e.id].node.visible = visiveis and e.habilitado and tempo >= float(e.inicio) and tempo < float(e.inicio) + float(e.duracao)

func estado() -> Dictionary:
	return {"tempo": tempo, "status": "Pausado" if pausado else _status, "vida_alvo": vida_alvo,
		"energia": energia, "recarga": _recarga, "acertos": _acertos, "efeito": _efeito,
		"rodando": rodando, "pausado": pausado, "carga": _carga}

func _process(delta: float) -> void:
	if pausado or skill.is_empty():
		return
	if not rodando:
		_recarga = maxf(0, _recarga - delta)
		if _repetindo and _recarga <= 0.0:
			var erro := rodar(_ativacao_manual)
			if not erro.is_empty():
				_repetindo = false
				_status = erro
		mudou.emit(estado())
		return
	_acumulado += minf(delta, 0.25)
	while _acumulado >= PASSO and rodando:
		_acumulado -= PASSO
		_recarga = maxf(0, _recarga - PASSO)
		if _carga > 0:
			_carga = maxf(0, _carga - PASSO)
			continue
		if _segurando and tempo >= float(skill.ativacao.get("ponto_segurar", 0.5)) - 0.00001:
			# Parado no ponto de segurar: o tempo da timeline não anda; a pose pulsa.
			_segurado += PASSO
			_status = "Segurando"
			_passo_de_pose(PASSO)
			_atualizar_eventos(true)          # a estrela da carga cresce enquanto segura
			var limite := float(skill.ativacao.get("segurar_max", 5.0))
			if not _ativacao_manual:
				limite = minf(limite, SEGURAR_NO_RODAR)
			if _segurado >= limite:
				_segurando = false
			continue
		_status = "Executando"
		_avancar(PASSO, false)
		if tempo >= float(skill.configuracoes.duracao) - 0.00001:
			rodando = false
			_limpar_nos()
			_restaurar_pose()
			_tremor = 0.0
			_fov = 48.0
			_status = "Concluído"
	_atualizar_alvo()
	_camera()
	mudou.emit(estado())

func _avancar(dt: float, silencioso: bool) -> void:
	tempo += dt
	if alvo_movel and vida_alvo > 0.0 and _stun_ate <= tempo:
		var fator := 1.0 - _slow / 100.0 if _slow_ate > tempo else 1.0
		alvo.position.x += cos(tempo * 1.6) * 1.2 * fator * dt
	alvo.position += _knockback * dt
	_knockback = _knockback.move_toward(Vector3.ZERO, dt * 16.0)
	# Estado tem consequência mensurável na movimentação do alvo de treino.
	if _gelo_ate > tempo:
		_efeito = "Congelado"
	elif _stun_ate > tempo:
		_efeito = "Atordoado"
	elif _slow_ate > tempo:
		_efeito = "Lentidão %d%%" % _slow
	elif _status_ate < tempo:
		_efeito = ""
	_atualizar_eventos(silencioso)
	_passo_de_pose(dt)
	for p in _projeteis:
		if p.morto:
			continue
		var antes: Vector3 = p.node.position
		p.vel.y -= float(p.get("g", p.param.gravidade)) * dt
		p.node.position += p.vel * dt
		Catalogo.animar(p.node, p.vel, dt)
		p.idade += dt
		var centro := alvo.position + Vector3.UP
		var perto := Geometry3D.get_closest_point_to_segment(centro, antes, p.node.position)
		var explode := float(p.param.get("explosao", 0.0))
		var so_efeito := bool(p.param.get("sem_dano", false))
		if perto.distance_to(centro) <= float(p.param.raio) + 0.55 and not p.acertou and not so_efeito:
			if explode <= 0.0:
				_acertar(p.id, true)
			p.acertou = true
			if not p.param.perfurar or explode > 0.0:
				p.morto = true
		if p.node.position.y < 0.0 and explode > 0.0 and not p.morto:
			p.morto = true                       # tocou o chão da prévia
		if p.morto and explode > 0.0:
			_explodir_na_previa(p.id, p.node.position, explode)
		if p.idade >= float(p.param.vida) or p.node.position.y < -1:
			p.morto = true
		if p.morto:
			p.node.visible = false
	# VFX com âncora "Projétil": de novo depois de as bolinhas andarem (como no executor).
	for e: Dictionary in skill.eventos:
		if str(e.tipo) == "vfx" and str(e.get("parametros", {}).get("ancora", "")) == "Projétil" \
				and _eventos.has(e.id) and _eventos[e.id].has("node"):
			var onde := _lugar_do_vfx_na_previa(_eventos[e.id], Dados.parametros(skill, e))
			if onde.is_finite():
				(_eventos[e.id].node as Node3D).global_position = onde

func _atualizar_eventos(silencioso: bool) -> void:
	_clipe_ativo = false
	_tremor = 0.0
	_fov = 48.0
	var animou := false
	var cometa := false
	for e: Dictionary in skill.eventos:
		if not e.habilitado or tempo < float(e.inicio) or tempo >= float(e.inicio) + float(e.duracao):
			if _eventos.has(e.id) and is_instance_valid(_eventos[e.id].get("transformacao")):
				_eventos[e.id].transformacao.encerrar()
				_eventos[e.id].erase("transformacao")
			if e.habilitado and e.tipo == "movimento" and _eventos.has(e.id) and not _eventos[e.id].get("finalizado", false) and tempo >= float(e.inicio) + float(e.duracao):
				_mover(e, Dados.parametros(skill, e), 1.0)
				_eventos[e.id].finalizado = true
			if _eventos.has(e.id) and _eventos[e.id].has("node"):
				_eventos[e.id].node.visible = false
			if _eventos.has(e.id) and is_instance_valid(_eventos[e.id].get("audio")):
				_eventos[e.id].audio.stop()
			continue
		var p: Dictionary = Dados.parametros(skill, e)
		var local: float = tempo - float(e.inicio)
		var u := clampf(local / maxf(float(e.duracao), 0.001), 0, 1)
		var novo := not _eventos.has(e.id)
		if novo:
			_eventos[e.id] = {"origem": ator.position}
		match e.tipo:
			"transformacao":
				if novo:
					_eventos[e.id].transformacao = Transformacao.iniciar(_transitorios, ator, p)
				_eventos[e.id].transformacao.atualizar(local)
			"movimento":
				_mover(e, p, u)
			"hitbox":
				if novo:
					_eventos[e.id].node = _hitbox_visual(p)
				var hb: Node3D = _eventos[e.id].node
				hb.position = ator.position + Vector3(p.x, p.y, p.z)
				hb.visible = mostrar_hitboxes
				if _atinge(p, hb.position):
					_acertar(e.id, p.unicos)
			"projetil":
				if novo: _disparar(e.id, p)
			"vfx":
				if novo: _eventos[e.id].node = _criar_vfx(p)
				var fx: Node3D = _eventos[e.id].node
				var onde := _lugar_do_vfx_na_previa(_eventos[e.id], p)
				if onde.is_finite():
					fx.global_position = onde
				var pv := p.duplicate()
				pv.carga = _fator_de_carga()
				Visual.animar_vfx(fx, pv, local + _segurado, u)
				fx.visible = onde.is_finite()
				cometa = cometa or str(p.estilo) == "Cometa"   # o corpo vira luz
			"audio":
				if novo and not silencioso: _eventos[e.id].audio = _tocar(p)
			"camera":
				_tremor = float(p.tremor) * sin(u * PI)
				_fov = float(p.zoom)
			"animacao":
				# Bloco com Pose: quem move o corpo é `_passo_de_pose`, não o clipe.
				if str(p.get("pose", "")).is_empty():
					_animar(p, local, u)
					animou = true
	if not animou:
		_restaurar_pose()
	if is_instance_valid(ator):
		ator.visible = not cometa

func _mover(e: Dictionary, p: Dictionary, u: float) -> void:
	var dir := Vector3.FORWARD
	if p.direcao == "Trás": dir = Vector3.BACK
	if p.direcao == "Acima": dir = Vector3.UP
	else:
		# Ângulo lateral (+ direita) e inclinação (+ cima), como no executor do jogo.
		dir = dir.rotated(Vector3.UP, -deg_to_rad(float(p.get("angulo", 0.0))))
		var inc := deg_to_rad(float(p.get("inclinacao", 0.0)))
		if absf(inc) > 0.0001:
			dir = dir.rotated(dir.cross(Vector3.UP).normalized(), inc)
	var fracao := smoothstep(0, 1, u) if p.curva == "Suave" else u
	if bool(p.get("teleporte", false)):
		fracao = 1.0
	if p.direcao != "Acima" and _viagem_acabou_na_previa():
		return
	ator.position = _eventos[e.id].origem + dir * minf(float(p.distancia), float(p.velocidade) * float(e.duracao)) * fracao


## "Terminar sobre o inimigo" (07/10/2026), como no executor: o alvo de treino perto no
## plano leva o ator para cima dele e a timeline pula para "Início do fim". (A prévia não
## tem buracos: "Parar antes do vazio" só se vê no jogo.)
func _viagem_acabou_na_previa() -> bool:
	if _viagem_acabou:
		return true
	var conf: Dictionary = skill.get("configuracoes", {})
	var raio := float(conf.get("fim_sobre_alvo", 0.0))
	if raio <= 0.0 or vida_alvo <= 0.0:
		return false
	if Vector2(alvo.position.x - ator.position.x, alvo.position.z - ator.position.z).length() > raio:
		return false
	_viagem_acabou = true
	ator.position = Vector3(alvo.position.x, ator.position.y, alvo.position.z)
	var salto := float(conf.get("inicio_do_fim", -1.0))
	if salto > tempo:
		tempo = salto
	return true

func _atinge(p: Dictionary, centro: Vector3) -> bool:
	var pos := alvo.position + Vector3.UP - centro
	if p.forma == "Caixa":
		var half := Vector3(p.largura, p.altura, p.profundidade) * 0.5
		return pos.distance_to(pos.clamp(-half, half)) <= 0.55
	if p.forma == "Cápsula":
		var half := maxf(0, float(p.altura) * 0.5 - float(p.raio))
		return pos.distance_to(Vector3(0, clampf(pos.y, -half, half), 0)) <= float(p.raio) + 0.55
	return pos.length() <= float(p.raio) + 0.55

func _acertar(id: String, unico: bool) -> void:
	if vida_alvo <= 0 or (_hits.has(id) and (unico or tempo - float(_hits[id]) < 0.2)):
		return
	_hits[id] = tempo
	_acertos += 1
	var d: Dictionary = skill.dano
	var critico := _rng.randf() * 100 < float(d.critico)
	var valor := float(d.valor) * (float(d.multiplicador) if critico else 1.0)
	vida_alvo = maxf(0, vida_alvo - valor)
	_efeito = "%s −%d%s" % [d.tipo, valor, " CRÍTICO" if critico else ""]
	_status_ate = tempo + maxf(0.4, float(d.duracao_efeito))
	_stun_ate = tempo + float(d.atordoamento)
	if float(d.get("congelar", 0.0)) > 0.0 and _gelo_ate + 0.5 <= tempo:   # 0,5 s de imunidade, como no jogo
		_gelo_ate = tempo + float(d.congelar)
		_stun_ate = maxf(_stun_ate, _gelo_ate)
	_slow = float(d.lentidao)
	_slow_ate = tempo + float(d.duracao_efeito) if _slow > 0 else 0.0
	var direcao := (alvo.position - ator.position).normalized()
	var mult := _multiplicador_de_empurrao()
	_knockback += direcao * float(d.empurrao) * mult
	if mult > 1.001:
		_efeito += " · impulso ×%.2f" % mult

## "Carregar e soltar" (07/10/2026): quanto da carga encheu e o impulso dela — as mesmas
## contas do `ExecutorDeSkill`.
func _fator_de_carga() -> float:
	var a: Dictionary = skill.get("ativacao", {})
	if str(a.get("modo", "")) != "Carregar e soltar" or float(a.get("carga", 0.0)) <= 0.0:
		return 1.0
	return clampf(_segurado / float(a.carga), 0.0, 1.0)


func _multiplicador_de_empurrao() -> float:
	var a: Dictionary = skill.get("ativacao", {})
	if str(a.get("modo", "")) != "Carregar e soltar":
		return 1.0
	return lerpf(1.0, float(a.get("empurrao_carga_max", 1.0)), _fator_de_carga())


## A Âncora do VFX na prévia (07/10/2026), como no executor: o alvo de treino faz o papel
## do inimigo e do ponto mirado; "Projétil" segue a primeira bolinha viva do bloco.
func _lugar_do_vfx_na_previa(estado_bloco: Dictionary, p: Dictionary) -> Vector3:
	var padrao := ator.global_position + Visual.lugar(p)
	match str(p.get("ancora", "Jogador")):
		"Osso do jogador":
			var o := _osso_na_previa(str(p.get("osso", "Mão direita")))
			return o if o.is_finite() else padrao
		"Alvo", "Ponto mirado":
			return alvo.global_position + Vector3.UP
		"Projétil":
			var prefixo := str(p.get("projetil_de", "")) + ":"
			for pr in _projeteis:
				if str(pr.id).begins_with(prefixo) and not pr.morto:
					return (pr.node as Node3D).global_position
			return Vector3.INF
		"Mundo":
			if not estado_bloco.has("fixo"):
				estado_bloco.fixo = padrao
			return estado_bloco.fixo
	if bool(p.get("na_mao", false)) and _mao_na_previa().is_finite():
		return _mao_na_previa()
	return padrao


var _saida_do_disparo := Vector3.INF

## "Sai de" na prévia (07/10/2026): as mesmas mãos do executor.
func _origem_nas_maos_na_previa(sai_de: String) -> Vector3:
	match sai_de:
		"Mão direita", "Mão esquerda":
			return _osso_na_previa(sai_de)
		"Entre as mãos":
			var d := _osso_na_previa("Mão direita")
			var e := _osso_na_previa("Mão esquerda")
			return (d + e) * 0.5 if d.is_finite() and e.is_finite() else Vector3.INF
	return Vector3.INF


func _osso_na_previa(nome: String) -> Vector3:
	if nome == "Mão direita":
		return _mao_na_previa()
	var papel: String = {"Mão esquerda": "ForeArm_L", "Cabeça": "Head", "Tronco": "Torso",
		"Pé direito": "Foot_R", "Pé esquerdo": "Foot_L"}.get(nome, "")
	var no := modelo.find_child(papel, true, false) as Node3D if modelo and not papel.is_empty() else null
	if no == null:
		return Vector3.INF
	return no.global_transform * Vector3(0, -0.36, 0.02) if papel == "ForeArm_L" else no.global_position


## A mão direita do Base na prévia: a ponta do antebraço, a mesma medida do `Hand_R`
## do jogo (`player_rig.gd`).
func _mao_na_previa() -> Vector3:
	var braco := modelo.find_child("ForeArm_R", true, false) as Node3D if modelo else null
	return braco.global_transform * Vector3(0, -0.36, 0.02) if braco else Vector3.INF


func _disparar(id: String, p: Dictionary) -> void:
	_saida_do_disparo = _origem_nas_maos_na_previa(str(p.get("sai_de", "Corpo")))
	if str(p.get("direcao_disparo", "Mira")) == "Chuva":
		_chover_na_previa(id, p)
		return
	for i in int(p.quantidade):
		var a := lerpf(-float(p.abertura) * 0.5, float(p.abertura) * 0.5, float(i) / maxf(1, float(p.quantidade) - 1)) if int(p.quantidade) > 1 else 0.0
		var no := Catalogo.criar(p, Color(skill.vfx.cor))
		_transitorios.add_child(no)
		var rumo := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(a))
		no.position = ator.position + Vector3(0, 1, -0.6)
		if _saida_do_disparo.is_finite():
			no.global_position = _saida_do_disparo
		if str(p.get("direcao_disparo", "Mira")) == "Abaixo":
			rumo = Vector3.DOWN
			no.position = ator.position + Vector3(0, 0.2, 0)
		_projeteis.append({"id": "%s:%d" % [id, i], "node": no, "param": p,
			"vel": rumo * float(p.velocidade),
			"idade": 0.0, "morto": false, "acertou": false})

## "Chuva" (C da Pika, 07/10/2026): as mesmas contas do executor, em volta do alvo de
## treino (é ele o "ponto mirado" da prévia), no chão da prévia (y = 0).
func _chover_na_previa(id: String, p: Dictionary) -> void:
	var de := ator.position + Vector3(0, 1, -0.6)
	var nada: Array[RID] = []
	var meio := Chuva.centro(null, ator.position, Vector3(alvo.position.x, 0.0, alvo.position.z),
		float(skill.configuracoes.get("alcance", 30.0)), nada)
	meio.y = 0.0
	var g := float(p.gravidade) if float(p.gravidade) > 0.0 else Chuva.GRAVIDADE
	var i := 0
	for queda in Chuva.quedas(_rng, meio, float(p.get("area_chuva", 8.0)), int(p.quantidade)):
		var t := lerpf(Chuva.VOO_MIN, Chuva.VOO_MAX, _rng.randf())
		var no := Catalogo.criar(p, Color(skill.vfx.cor))
		_transitorios.add_child(no)
		no.position = de
		_projeteis.append({"id": "%s:%d" % [id, i], "node": no, "param": p, "g": g,
			"vel": Chuva.arremesso(de, queda, g, t), "idade": 0.0, "morto": false, "acertou": false})
		i += 1


## Esfera que explode (X da Pika): clarão no ponto e dano se o alvo estiver no raio.
func _explodir_na_previa(id: String, ponto: Vector3, raio: float) -> void:
	var pv := {"estilo": "Explosão", "cor": skill.vfx.cor, "escala": raio * 0.5}
	var fx := Visual.vfx(_transitorios, pv)
	fx.position = Vector3(ponto.x, maxf(ponto.y, 0.0), ponto.z)
	Visual.animar_vfx(fx, pv, 0.2, 0.3)
	if (alvo.position + Vector3.UP).distance_to(fx.position) <= raio + 0.55:
		_acertar(id + ":explosao", true)


func _limpar_execucao() -> void:
	_limpar_nos()
	tempo = 0.0
	_acumulado = 0.0
	_carga = 0.0
	_acertos = 0
	_hits.clear()
	_viagem_acabou = false
	_rng.seed = 57131
	if ator: ator.position = Vector3.ZERO
	_restaurar_pose()

func _limpar_nos() -> void:
	_eventos.clear()
	_projeteis.clear()
	if _transitorios:
		for n in _transitorios.get_children():
			n.free()

func _tocar(p: Dictionary) -> AudioStreamPlayer:
	var som := AudioStreamPlayer.new()
	som.stream = AudioFX._pool(Visual.SONS.get(p.som, "dash"))
	som.volume_db = float(p.volume)
	som.pitch_scale = float(p.tom)
	_transitorios.add_child(som)
	som.finished.connect(som.queue_free)
	som.play()
	return som

func _animar(p: Dictionary, local: float, u: float) -> void:
	if _modelo_id != "Harpia" and not _rig.is_empty():
		_aplicar_clipe(p, local)
		return
	if _pose:
		var fase: String = {"Preparar": "preparar_investida", "Ataque": "lancar_vendaval", "Investida": "investida", "Vendaval": "preparar_vendaval"}.get(p.clipe, "")
		_pose.influence = clampf(float(p.intensidade), 0, 1)
		_pose.atualizar(fase, clampf(u * float(p.velocidade), 0, 1), PASSO)
	var nome: String = {"Preparar": "idle", "Ataque": "punching", "Planar": "jump", "Investida": "run", "Vendaval": "groundsmash"}.get(p.clipe, "idle")
	if _modelo_id == "Harpia":
		for n in _ap.get_animation_list() if _ap else []:
			if String(n).to_lower().ends_with("gliding"):
				nome = n
				break
	if _ap and _ap.has_animation(nome):
		if _clip != nome:
			_ap.play(nome)
			_ap.pause()
			_clip = nome
		var duracao := _ap.get_animation(nome).length
		_ap.seek(fmod(local * float(p.velocidade), maxf(duracao, 0.001)), true)
	# Intensidade acrescenta inclinação corporal sem substituir o clipe real.
	modelo.rotation.x = -sin(u * PI) * 0.18 * float(p.intensidade)

## O clipe do bloco nos papéis do Base, como o "clipe de ação" do jogo
## (`ProceduralAnimator._aplicar_acao`, 07/10/2026): o mesmo arquivo lido pela mesma
## função, no mesmo tempo (local × velocidade, parado no último quadro) e com o mesmo
## peso (Intensidade, 0..1).
func _aplicar_clipe(p: Dictionary, local: float) -> void:
	var info := ProceduralAnimator._clipe(Clipes.caminho(str(p.clipe)))
	if not info.has("anim"):
		return
	var anim: Animation = info.anim
	var t := clampf(local * float(p.velocidade), 0.0, anim.length)
	var w := clampf(float(p.intensidade), 0.0, 1.0)
	var nos: Dictionary = _rig.get("nodes", {})
	var repouso: Dictionary = _rig.get("rest", {})
	for papel in info.faixas:
		if nos.has(papel):
			var de := Quaternion.from_euler(repouso.get(papel, Vector3.ZERO))
			var alvo := Quaternion.from_euler(anim.value_track_interpolate(info.faixas[papel], t))
			(nos[papel] as Node3D).quaternion = de.slerp(alvo, w)
	if nos.has("Torso") and _torso_pos0.is_finite():
		var tronco: Node3D = nos.Torso
		if info.has("giro"):
			tronco.basis = Basis(Vector3.UP, float(anim.value_track_interpolate(info.giro, t)) * w) * tronco.basis
		var altura := float(anim.value_track_interpolate(info.altura, t)) if info.has("altura") else 0.0
		var perna := maxf(float(_rig.get("metrics", {}).get("leg_len", 0.8)), 0.3)
		tronco.position = _torso_pos0 + Vector3(0, altura * perna * w, 0)
	modelo.rotation.x = 0.0
	_clipe_ativo = true
	_pose_aplicada = true

## Transição para a pose do bloco ativo (ou de volta ao repouso) e aplicação no Base.
## Com o editor de poses aberto numa pose, ela fica parada na tela.
func _passo_de_pose(dt: float) -> void:
	if _rig.is_empty():
		return
	if not pose_em_edicao.is_empty():
		_pose_atual = PosesDeSkill.pose(skill, pose_em_edicao)
		_aplicar_pose_no_modelo(_pose_atual)
		return
	var alvo := PosesDeSkill.alvo_no_tempo(skill, tempo, Callable(Dados, "parametros"))
	var destino: Dictionary = alvo.get("pose", {})
	_pose_atual = PosesDeSkill.aproximar(_pose_atual, destino, float(alvo.get("transicao", 0.15)), dt)
	if _clipe_ativo:
		return                       # o clipe do bloco Animação manda no corpo neste passo
	# A fase do pulso anda também enquanto a timeline está parada segurando.
	_aplicar_pose_no_modelo(PosesDeSkill.com_pulso(_pose_atual, float(alvo.get("pulso", 0.0)), tempo + _segurado))

func _aplicar_pose_no_modelo(pose: Dictionary) -> void:
	if pose.is_empty() and not _pose_aplicada:
		return
	var nos: Dictionary = _rig.get("nodes", {})
	var repouso: Dictionary = _rig.get("rest", {})
	for papel in nos:
		(nos[papel] as Node3D).rotation = (repouso.get(papel, Vector3.ZERO) as Vector3) + (pose.get(papel, Vector3.ZERO) as Vector3)
	if nos.has("Torso") and _torso_pos0.is_finite():
		(nos.Torso as Node3D).position = _torso_pos0
	_pose_aplicada = not pose.is_empty()

## Mostra uma pose parada (editor de poses) ou volta à timeline (id vazio).
func mostrar_pose(id: String) -> void:
	pose_em_edicao = id
	if id.is_empty():
		_pose_atual = {}
		_aplicar_pose_no_modelo({})
	else:
		_passo_de_pose(0.0)
	_camera()

func _restaurar_pose() -> void:
	if _pose: _pose.restaurar()
	if _ap and not _clip.is_empty():
		_ap.seek(0, true)
		_ap.stop(true)
		_clip = ""
	if modelo: modelo.rotation.x = 0

func _montar_ator() -> void:
	var id: String = skill.get("identificacao", {}).get("modelo", "Base")
	if id == _modelo_id and modelo:
		return
	_pose = null
	_ap = null
	if modelo: modelo.free()
	_modelo_id = id
	if id == "Harpia":
		modelo = BibliotecaDeModelos.carregar_glb("res://mapas/modelos/harpia_-_animated_low_poly.glb")
	else:
		modelo = CharacterBuilder.build_character("base").node
	if modelo == null:
		_modelo_id = "Base"
		modelo = CharacterBuilder.build_character("base").node
	ator.add_child(modelo)
	var caixa: AABB = BibliotecaDeModelos.medir(modelo).aabb
	var escala := 2.0 / maxf(caixa.size.y, 0.1)
	if id == "Harpia": escala = minf(escala, 4.5 / maxf(caixa.size.x, 0.1))
	modelo.scale = Vector3.ONE * escala
	modelo.position = Vector3(-caixa.get_center().x * escala, -caixa.position.y * escala, -caixa.get_center().z * escala)
	if id == "Harpia": modelo.rotation.y = PI
	var players := modelo.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_ap = players[0] as AnimationPlayer
		_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if id == "Harpia":
		_pose = PoseHarpia.new()
		_pose.montar(modelo)
	# As poses do Builder valem no rig A (o Base, o mesmo do jogador).
	_rig = BodyScanner.scan(modelo) if id != "Harpia" else {}
	_torso_pos0 = (_rig.nodes.Torso as Node3D).position if _rig.get("nodes", {}).has("Torso") else Vector3.INF
	_pose_atual = {}
	_pose_aplicada = false

func _montar_arena() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("111d2d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a9c8e2")
	env.environment.ambient_light_energy = 0.75
	add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48, -32, 0)
	sol.light_energy = 1.4
	add_child(sol)
	var piso := BoxMesh.new()
	piso.size = Vector3(26, 0.12, 26)
	_malha(self, piso, Color("25394b")).position.y = -0.1
	for i in range(-12, 13):
		for eixo in 2:
			var linha := BoxMesh.new()
			linha.size = Vector3(0.018, 0.006, 24) if eixo == 0 else Vector3(24, 0.006, 0.018)
			var n := _malha(self, linha, Color("375368"))
			n.position = Vector3(i, -0.032, 0) if eixo == 0 else Vector3(0, -0.032, i)
	ator = Node3D.new()
	ator.name = "Ator"
	add_child(ator)
	alvo = Node3D.new()
	alvo.name = "Alvo"
	alvo.add_to_group("alvo_previa_transformacao")
	add_child(alvo)
	var dummy: Node3D = CharacterBuilder.build_character("base").node
	alvo.add_child(dummy)
	var a: AABB = BibliotecaDeModelos.medir(dummy).aabb
	var s := 2.0 / maxf(0.1, a.size.y)
	dummy.scale = Vector3.ONE * s
	dummy.position.y = -a.position.y * s
	dummy.rotation.y = PI
	_alvo_label = Label3D.new()
	_alvo_label.position.y = 2.65
	_alvo_label.font_size = 42
	_alvo_label.pixel_size = 0.012
	_alvo_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alvo.add_child(_alvo_label)
	_transitorios = Node3D.new()
	add_child(_transitorios)
	# Objetos separados do piso: permitem ensaiar "assets ao redor" sem alterar o cenário.
	for i in 2:
		var objeto := Node3D.new()
		objeto.name = "AssetDeEnsaio%d" % i
		objeto.add_to_group(Transformacao.GRUPO_ASSETS)
		add_child(objeto)
		objeto.position = Vector3(-2.0 if i == 0 else 2.0, .5, -2.5)
		var caixa := BoxMesh.new()
		caixa.size = Vector3.ONE * .9
		_malha(objeto, caixa, Color("aa7951") if i == 0 else Color("527d8c"))
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_camera()

func _atualizar_alvo() -> void:
	if not _alvo_label: return
	_alvo_label.text = "ALVO  %d / 1000\n%s" % [vida_alvo, _efeito]
	_alvo_label.modulate = Color("ffcb77") if _status_ate > tempo else Color("e6f1fa")
	alvo.rotation.x = -0.12 * sin(tempo * 35) if _stun_ate > tempo and _gelo_ate <= tempo else 0.0
	if _gelo_ate > tempo and _bloco_de_gelo == null:
		_bloco_de_gelo = MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(1.6, 2.4, 1.6)
		_bloco_de_gelo.mesh = caixa
		_bloco_de_gelo.material_override = IceFX._crystal_mat()
		_bloco_de_gelo.position = Vector3(0, 1.2, 0)
		alvo.add_child(_bloco_de_gelo)
	if _bloco_de_gelo != null:
		_bloco_de_gelo.visible = _gelo_ate > tempo
	alvo.rotation.z = PI * 0.48 if vida_alvo <= 0 else 0.0

func _camera() -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return
	# Editando pose: a câmera enquadra o PERSONAGEM de perto (o giro continua do usuário).
	var editando := not pose_em_edicao.is_empty() and is_instance_valid(ator)
	var mira := ator.position + Vector3(0, 1.0, 0) if editando else Vector3(0, 0.9, -distancia_alvo * 0.5)
	var dist := minf(_dist, 3.8) if editando else _dist
	camera.position = mira + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * dist
	camera.position += Vector3(sin(tempo * 91), cos(tempo * 73), 0) * _tremor * 0.2
	camera.look_at(mira)
	camera.fov = _fov

func _malha(pai: Node3D, mesh: Mesh, cor: Color) -> MeshInstance3D:
	return Visual.malha(pai, mesh, cor)

func _hitbox_visual(p: Dictionary) -> MeshInstance3D:
	var mesh: Mesh
	if p.forma == "Caixa":
		var box := BoxMesh.new()
		box.size = Vector3(p.largura, p.altura, p.profundidade)
		mesh = box
	elif p.forma == "Cápsula":
		var cap := CapsuleMesh.new()
		cap.radius = float(p.raio)
		cap.height = maxf(float(p.altura), float(p.raio) * 2)
		mesh = cap
	else:
		var sphere := SphereMesh.new()
		sphere.radius = float(p.raio)
		sphere.height = float(p.raio) * 2
		mesh = sphere
	return _malha(_transitorios, mesh, Color(1, 0.3, 0.16, 0.23))

func _criar_vfx(p: Dictionary) -> Node3D:
	return Visual.vfx(_transitorios, p)
