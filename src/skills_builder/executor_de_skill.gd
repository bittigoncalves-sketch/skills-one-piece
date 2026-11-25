class_name ExecutorDeSkill
extends Node3D
## Roda uma skill do Skills Builder num corpo DO JOGO (06/10/2026).
##
## A prévia do Builder (`arena_preview.gd`) simula a skill contra um alvo de treino,
## de forma analítica, para poder voltar no tempo pela régua. Aqui a MESMA timeline
## vira golpe de verdade: hitboxes e projéteis são `DamageZone` (dano só no servidor,
## via `CombatResolver`), o movimento passa pela física do corpo e o visual é o da
## prévia (`visual_de_skill.gd`). A semântica segue a prévia:
##   • hitbox: metros relativos ao PÉ do ator, na frente do lançamento (X lado,
##     Y altura, Z negativo = frente); acompanha o ator enquanto o bloco dura;
##     "um acerto por alvo" = uma vez por bloco; senão de novo a cada 0,2 s;
##   • projétil: nasce 1 m acima do pé e 0,6 m à frente; abertura horizontal;
##     gravidade; vida; atravessa ou para no primeiro acerto;
##   • movimento: frente/trás/acima, até min(distância, velocidade × duração);
##   • dano por acerto, com crítico, impulso (para longe do ator), atordoamento
##     e lentidão; `escala_de_dano` faz a ponte arena → história.
## O campo de visão do bloco de câmera vale só na prévia: no jogo o dono desligou
## o soco de FOV ("distorção", `camera_rig.gd`); o tremor vale.

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Transformacao := preload("res://src/skills_builder/transformacao_de_skill.gd")
const Visual := preload("res://src/skills_builder/visual_de_skill.gd")
const Catalogo := preload("res://src/skills_builder/catalogo_de_projeteis.gd")
const Viagem := preload("res://src/skills_builder/viagem_de_skill.gd")
const Chuva := preload("res://src/skills_builder/chuva_de_projeteis.gd")
## Explosões em sequência (a chuva do C): um som a cada tanto, não um por bolinha.
const INTERVALO_DE_SOM_MS := 90
## Reacerto do mesmo bloco no mesmo alvo (o `_acertar` da prévia usa 0,2 s).
const INTERVALO_REACERTO := 0.2
const DURACAO_DA_EXPLOSAO := 0.6
## De onde o projétil e o VFX nascem, relativos ao pé e à frente (os da prévia).
const DISPARO := Vector3(0, 1.0, -0.6)
const LUGAR_DO_VFX := Vector3(0, 1.0, -1.0)
## Meta de lentidão no alvo: {"fator": 0..1, "ate": msec}. Quem anda lê
## `ExecutorDeSkill.fator_de_lentidao(corpo)`.
const META_LENTIDAO := "lentidao_de_skill"
## Vida do jogador da arena: o número do Builder é escrito nessa escala.
const VIDA_DA_ARENA := 2048.0

signal terminou

var skill: Dictionary = {}
var ator: Node3D = null
var escala_de_dano := 1.0
## Ponto que o retículo marca (Vector3.INF = sem mira: projéteis vão para a frente).
var ponto_mirado := Vector3.INF
## Skill de INIMIGO (decisão do dono, 06/10/2026): tira do alvo a mesma FRAÇÃO de vida
## que tiraria de um jogador da arena — dano × vida máxima do alvo / 2048. Calculado no
## acerto, porque depende de quem levou.
var escala_pela_vida_do_alvo := false
var cast_id := 0

var _base := Basis()          # a frente do lançamento (só giro em Y)
var _rumo3d := Vector3.FORWARD # a mira COM a inclinação (feixe e hitbox que seguem a mira)
var _explosoes: Array[Dictionary] = []   # VFX de explosão vivos ({no, idade, p})
var _flutuando := false
var _corpo_oculto := false
## Quanto o projétil que bateu no cenário (chão, parede) fica visível antes de sumir.
const PERMANENCIA_NO_CENARIO := 1.0
const META_CRAVADA := "cravada_no_cenario"

## Projéteis da esfera/explosão e os só de efeito (06/10/2026): andam aqui, sem
## DamageZone; o raio de cada passo acha o impacto.
var _manuais: Array[Dictionary] = []
var _t := 0.0
var _duracao := 0.0
var _estado := {}             # id do bloco → estado do bloco
var _projeteis: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
## Pose do Builder em curso (papel → radianos), com a transição de `PosesDeSkill`. Vai
## para o corpo pelo meta `pose_de_skill`, que o `ProceduralAnimator` soma.
var _pose_atual := {}
const META_POSE := "pose_de_skill"
## "Carregar e soltar" (06/10/2026): com `segurando`, a timeline PÁRA no ponto de
## segurar; `soltar()` continua; soltar antes do ponto é `cancelar()`. `_segurado`
## conta o tempo parado (limite `segurar_max`, depois solta sozinho).
var segurando := false
var _segurado := 0.0
## Quem não tem tecla (IA de inimigo) solta sozinho depois disto (s; −1 = não).
var segurar_auto := -1.0
## A mão direita do ator (`Hand_R` do rig): de onde nasce o que tem "Nasce na mão".
var _no_da_mao: Node3D = null
## Viagem que acabou antes (X da Pika, 07/10/2026): em cima de um inimigo (`_ponto_do_fim`
## = onde ele estava; a esfera "Abaixo" sai de cima dele) ou na beira do vazio.
var _viagem_acabou := false
var _ponto_do_fim := Vector3.INF
var _ultimo_som_ms := -100000
## Âncora do VFX (07/10/2026): o bloco de projétil que está disparando agora (cada
## projétil leva o id para um VFX "Projétil" poder segui-lo) e os ossos já achados.
var _bloco_disparando := ""
var _ossos := {}


## Cria e põe para rodar. `rumo` = para onde o ator lança (a mira; só o giro em Y
## vale para hitbox, movimento e VFX). `pai` = onde os nós moram (o contêiner de
## golpes do jogador, que a troca de fruta limpa).
## `semente` (07/10/2026): a mesma em todos os peers (vem da mira e da origem do
## lançamento, que viajam iguais na rede): o sorteio da chuva cai no mesmo lugar em todos.
static func lancar(pai: Node, quem: Node3D, dados: Dictionary, rumo: Vector3,
		escala: float = 1.0, mira: Vector3 = Vector3.INF, semente: int = 0) -> ExecutorDeSkill:
	var e: ExecutorDeSkill = ExecutorDeSkill.new()
	e.name = "SkillBuilder_" + str(dados.get("identificacao", {}).get("id", "skill"))
	e.skill = dados
	e.ator = quem
	e.escala_de_dano = escala
	e.ponto_mirado = mira
	var conf: Dictionary = dados.get("configuracoes", {})
	if bool(conf.get("mirar_no_alvo", false)):
		# Rumo travado no alvo vivo mais perto (o C da Pika): a skill sai PARA ELE, e não
		# para a câmera (era o que gerava a barragem atrás do jogador).
		var alvo := KitDoBuilder.alvo_mais_perto(quem, float(conf.get("alcance", 30.0)))
		if alvo != null:
			mira = AlvosDeGolpe.centro(alvo)
			e.ponto_mirado = mira
			rumo = mira - (quem.global_position + Vector3.UP * 0.6)
	e._rumo3d = rumo.normalized() if rumo.length_squared() > 0.0001 else -quem.global_transform.basis.z
	var plano := Vector3(rumo.x, 0, rumo.z)
	if plano.length_squared() < 0.0001:
		plano = -quem.global_transform.basis.z
		plano.y = 0
	e._base = Basis.looking_at(plano.normalized(), Vector3.UP)
	e.cast_id = CombatResolver.novo_cast()
	e._rng.seed = semente if semente != 0 else e.cast_id * 7919 + 17
	e._duracao = float(dados.get("configuracoes", {}).get("duracao", 0.0))
	e.segurando = str(dados.get("ativacao", {}).get("modo", "")) == "Carregar e soltar"
	pai.add_child(e)
	if bool(conf.get("flutuar", false)) and quem.has_method("definir_flutuar"):
		e._flutuando = true
		quem.definir_flutuar(true)
	return e


## Ponto da timeline onde "Carregar e soltar" espera (−1 = não espera).
func ponto_de_segurar() -> float:
	if str(skill.get("ativacao", {}).get("modo", "")) != "Carregar e soltar":
		return -1.0
	return float(skill.ativacao.get("ponto_segurar", 0.5))


## Tecla solta. Antes do ponto de segurar = cancelar (devolve "cancelou"); depois,
## a timeline continua (golpe sai).
func soltar() -> String:
	if str(skill.get("ativacao", {}).get("modo", "")) == "Sustentar":
		# "Sustentar": soltar a tecla encerra a skill ali (o que faltava não sai). O que
		# já saiu termina o voo (a chuva do C cai; 07/10/2026): a timeline vai ao fim,
		# os blocos fecham no próximo quadro e o ator volta a cair.
		_t = maxf(_t, _duracao)
		if _flutuando and is_instance_valid(ator) and ator.has_method("definir_flutuar"):
			ator.definir_flutuar(false)
		_flutuando = false
		return "soltou"
	if not segurando:
		return ""
	segurando = false
	if _t < ponto_de_segurar() - 0.0001:
		cancelar()
		return "cancelou"
	return "soltou"


## "Carregar e soltar" (07/10/2026): a câmera anda enquanto carrega — o golpe sai para a
## mira do SOLTAR. `rumo` = a mira nova; `ponto` = o que o retículo marca agora.
func mirar_de_novo(rumo: Vector3, ponto: Vector3) -> void:
	if rumo.length_squared() < 0.0001:
		return
	ponto_mirado = ponto
	_rumo3d = rumo.normalized()
	var plano := Vector3(rumo.x, 0, rumo.z)
	if plano.length_squared() > 0.0001:
		_base = Basis.looking_at(plano.normalized(), Vector3.UP)


## Quanto da carga encheu (0..1): o tempo segurado sobre o Tempo de carga. Skill que não
## carrega conta como cheia.
func fator_de_carga() -> float:
	var a: Dictionary = skill.get("ativacao", {})
	var carga := float(a.get("carga", 0.0))
	if str(a.get("modo", "")) != "Carregar e soltar" or carga <= 0.0:
		return 1.0
	return clampf(_segurado / carga, 0.0, 1.0)


## O empurrão cresce com a carga até "Empurrão com carga cheia" (Z da Pika: 1,5×).
func multiplicador_de_empurrao() -> float:
	var maximo := float(skill.get("ativacao", {}).get("empurrao_carga_max", 1.0))
	if str(skill.get("ativacao", {}).get("modo", "")) != "Carregar e soltar":
		return 1.0
	return lerpf(1.0, maximo, fator_de_carga())


## Encerra já, sem o resto da timeline (carga cancelada, troca de fruta...).
func cancelar() -> void:
	for st: Dictionary in _estado.values():
		for chave in ["zona", "no", "som"]:
			if is_instance_valid(st.get(chave)):
				(st[chave] as Node).queue_free()
	_projeteis.clear()
	_encerrar()


## Quanto a lentidão de uma skill deixa o corpo andar (1 = livre).
static func fator_de_lentidao(corpo: Node) -> float:
	return Lentidao.fator(corpo)


## O pé do ator: hitbox e disparo são medidos daqui, como na prévia (ator no chão).
## Bicho tem origem no pé (`centro_do_corpo` existe); o jogador e o boneco têm a
## origem no meio da cápsula.
func pe() -> Vector3:
	if not is_instance_valid(ator):
		return global_position
	if ator.has_method("centro_do_corpo"):
		return ator.global_position
	# A primeira forma SIMPLES: o inimigo do mapa tem antes a malha de triângulos (sem
	# altura legível) e depois o núcleo sólido em caixa.
	for filho in ator.get_children():
		if not (filho is CollisionShape3D) or (filho as CollisionShape3D).shape == null:
			continue
		var cs := filho as CollisionShape3D
		var meia := -1.0
		if cs.shape is CapsuleShape3D:
			meia = (cs.shape as CapsuleShape3D).height * 0.5
		elif cs.shape is BoxShape3D:
			meia = (cs.shape as BoxShape3D).size.y * 0.5
		elif cs.shape is CylinderShape3D:
			meia = (cs.shape as CylinderShape3D).height * 0.5
		elif cs.shape is SphereShape3D:
			meia = (cs.shape as SphereShape3D).radius
		if meia >= 0.0:
			return cs.global_position - Vector3.UP * meia * cs.global_basis.get_scale().y
	return ator.global_position


func terminado() -> bool:
	return _t >= _duracao and _projeteis.is_empty() and _manuais.is_empty() and _explosoes.is_empty()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(ator):
		_encerrar()
		return
	delta *= Lentidao.fator(ator)          # ator lento: a skill dele também anda devagar
	var ponto := ponto_de_segurar()
	if segurando and ponto >= 0.0 and _t + delta >= ponto:
		# Parado no ponto de segurar: a timeline não anda; pose e VFX seguem vivos.
		_t = ponto
		_segurado += delta
		if _segurado >= float(skill.ativacao.get("segurar_max", 5.0)) \
				or (segurar_auto >= 0.0 and _segurado >= segurar_auto):
			segurando = false               # segurou o máximo (ou a IA soltou): sai o golpe
	else:
		_t += delta
	for e: Dictionary in skill.get("eventos", []):
		_bloco(e, delta)
	_passo_de_pose(delta)
	_avancar_projeteis(delta)
	_avancar_manuais(delta)
	_avancar_explosoes(delta)
	_seguir_projeteis()
	if terminado():
		_encerrar()


func _bloco(e: Dictionary, delta: float) -> void:
	if not bool(e.get("habilitado", true)):
		return
	var inicio := float(e.inicio)
	var fim := inicio + float(e.duracao)
	var id: String = e.id
	if _t < inicio:
		return
	if _t >= fim:
		if _estado.has(id) and not _estado[id].get("fechado", false):
			_fechar(e)
		return
	var p: Dictionary = Dados.parametros(skill, e)
	var local := _t - inicio
	var u := clampf(local / maxf(float(e.duracao), 0.001), 0.0, 1.0)
	var novo := not _estado.has(id)
	if novo:
		_estado[id] = {"origem": ator.global_position}
	var st: Dictionary = _estado[id]
	match str(e.tipo):
		"transformacao":
			if novo: st.transformacao = Transformacao.iniciar(self, ator, p)
			st.transformacao.atualizar(local)
		"movimento":
			_mover(st, p, float(e.duracao), u, delta)
		"hitbox":
			if novo:
				st.zona = _zona(Visual.forma_da_hitbox(p), Vector3.ZERO, float(e.duracao) + 0.1)
				st.unico = bool(p.unicos)
				st.proximo = INTERVALO_REACERTO
			if is_instance_valid(st.zona):
				var zona: DamageZone = st.zona
				if bool(p.get("mirar", false)) and str(p.forma) == "Caixa":
					# Feixe: da altura X/Y do ator (ou da mão), ao longo da MIRA, até a parede.
					var de := pe() + _base * Vector3(p.x, p.y, 0.0)
					if bool(p.get("na_mao", false)) and _mao().is_finite():
						de = _mao()
					var dir := _rumo_da_mira(de)
					var comp := _livre(de, dir, float(p.profundidade))
					var caixa := zona.get_child(0) as CollisionShape3D
					if caixa != null and caixa.shape is BoxShape3D:
						(caixa.shape as BoxShape3D).size = Vector3(float(p.largura), float(p.altura), maxf(comp, 0.1))
					zona.global_transform = Transform3D(Basis.looking_at(dir, _cima(dir)), de + dir * comp * 0.5)
				else:
					zona.global_transform = Transform3D(_base, pe() + _base * Vector3(p.x, p.y, p.z))
				if not st.unico and local >= float(st.proximo):
					st.proximo = float(st.proximo) + INTERVALO_REACERTO
					_reacertar(zona)
		"projetil":
			if novo:
				_bloco_disparando = id
				_disparar(p)
		"vfx":
			if novo:
				st.no = Visual.vfx(self, p)
				if str(p.estilo) == "Cometa":
					_ocultar_corpo(true)       # o corpo vira luz enquanto o bloco dura
			var fx: Node3D = st.no
			var onde := _lugar_do_vfx(st, p)
			fx.visible = onde.is_finite()          # âncora que ainda não existe (projétil por sair)
			if onde.is_finite():
				fx.global_position = onde
			var pv := p.duplicate()
			pv.carga = fator_de_carga()
			if bool(p.get("mirar", false)):
				var dir := _rumo_da_mira(fx.global_position)
				fx.global_basis = Basis.looking_at(dir, _cima(dir))
				pv.comprimento = _livre(fx.global_position, dir, float(p.get("comprimento", 8.0)))
			else:
				fx.global_basis = _base
			Visual.animar_vfx(fx, pv, local + _segurado, u)
		"audio":
			if novo:
				st.som = Visual.som_3d(self, p, pe() + Vector3.UP)
		"camera":
			if ator.has_method("add_camera_shake"):
				ator.add_camera_shake(float(p.tremor) * sin(u * PI))
		"animacao":
			# Bloco com Pose: a transição mora em `_passo_de_pose`; sem pose, o clipe.
			if str(p.get("pose", "")).is_empty() and ator.has_method("tocar_animacao_de_skill"):
				# O TEMPO do clipe (07/10/2026): o mesmo que a prévia mostra no bloco.
				ator.tocar_animacao_de_skill(str(p.clipe), local * float(p.velocidade), float(p.velocidade), float(p.intensidade))


## Fim de um bloco: o movimento chega ao destino, a hitbox sai, o som para.
func _fechar(e: Dictionary) -> void:
	var st: Dictionary = _estado[e.id]
	st.fechado = true
	match str(e.tipo):
		"transformacao":
			if is_instance_valid(st.get("transformacao")): st.transformacao.encerrar()
		"movimento":
			_parar_movimento()
		"hitbox":
			if is_instance_valid(st.get("zona")):
				(st.zona as Node).queue_free()
		"vfx":
			if is_instance_valid(st.get("no")):
				(st.no as Node).queue_free()
			if str(Dados.parametros(skill, e).get("estilo", "")) == "Cometa":
				_ocultar_corpo(false)
		"audio":
			if is_instance_valid(st.get("som")):
				(st.som as AudioStreamPlayer3D).stop()
				(st.som as Node).queue_free()
		"animacao":
			if ator.has_method("parar_animacao_de_skill"):
				ator.parar_animacao_de_skill()


# ------------------------------------------------------------------ movimento

func _mover(st: Dictionary, p: Dictionary, duracao: float, u: float, delta: float) -> void:
	if str(p.direcao) == "Mira":
		_voar(p, delta)
		return
	var dir := _direcao_do_movimento(p)
	var total := minf(float(p.distancia), float(p.velocidade) * duracao)
	var vertical: bool = str(p.direcao) == "Acima" or absf(float(p.get("inclinacao", 0.0))) > 0.01
	if bool(p.get("so_do_chao", false)) and not st.has("chao"):
		st.chao = not (ator is CharacterBody3D) or (ator as CharacterBody3D).is_on_floor()
	if st.has("chao") and not bool(st.chao):
		return                       # começou no ar: este movimento não acontece
	if bool(p.get("teleporte", false)):
		# Teleporte: chega ao fim no primeiro quadro (varrendo: pára na parede) e fica.
		if not st.has("teleportou"):
			st.teleportou = true
			if _e_autoridade():
				ator.global_position = _destino_varrido(ator.global_position, dir * total)
			_parar_movimento()
		return
	var u2 := clampf(u + delta / maxf(duracao, 0.001), 0.0, 1.0)
	var fracao := smoothstep(0.0, 1.0, u2) if p.curva == "Suave" else u2
	var destino: Vector3 = st.origem + dir * total * fracao
	if not vertical and _viagem_interrompida(destino):
		return
	var falta := destino - ator.global_position
	if not vertical:
		falta.y = 0.0               # andando no chão, a gravidade do corpo continua
	# O Player move o próprio corpo (a cadeia de velocidade dele, com colisão). Outro
	# corpo que anda é varrido aqui; corpo estático não se move.
	if ator.has_method("definir_movimento_de_skill"):
		ator.definir_movimento_de_skill(falta / maxf(delta, 0.0001), vertical)
	elif ator is CharacterBody3D and _e_autoridade():
		(ator as CharacterBody3D).move_and_collide(falta)


## "Seguir a mira" (F da Pika, 07/10/2026): o corpo voa para onde a câmera aponta AGORA,
## na Velocidade, sem destino fixo. A mira viva é a do dono do corpo (quem move o corpo
## é ele; nos outros peers a posição chega pela rede).
func _voar(p: Dictionary, delta: float) -> void:
	var rumo := _rumo3d
	if _e_autoridade() and ator.has_method("mira_do_cast"):
		rumo = (ator.mira_do_cast()["aim"] as Vector3).normalized()
		_rumo3d = rumo
	var vel := rumo * float(p.velocidade)
	if ator.has_method("definir_movimento_de_skill"):
		ator.definir_movimento_de_skill(vel, true)
	elif ator is CharacterBody3D and _e_autoridade():
		(ator as CharacterBody3D).move_and_collide(vel * delta)


## A viagem no plano acaba antes? "Terminar sobre o inimigo" (raio): o ator vai para cima
## do inimigo que passou perto/embaixo; "Parar antes do vazio": o passo que deixaria o
## ator sem chão embaixo não acontece. Nos dois, a timeline pula para "Início do fim".
func _viagem_interrompida(destino: Vector3) -> bool:
	if _viagem_acabou:
		return true
	var conf: Dictionary = skill.get("configuracoes", {})
	var raio := float(conf.get("fim_sobre_alvo", 0.0))
	if raio > 0.0:
		var alvo := Viagem.inimigo_embaixo(ator, pe(), raio)
		if alvo != null:
			_ponto_do_fim = alvo.global_position
			if _e_autoridade():
				var sobre := Vector3(alvo.global_position.x, ator.global_position.y, alvo.global_position.z)
				ator.global_position = _destino_varrido(ator.global_position, sobre - ator.global_position)
			_fim_antecipado()
			return true
	if bool(conf.get("parar_no_vazio", false)) \
			and not Viagem.tem_chao(get_world_3d(), destino, _corpos_vivos()):
		_fim_antecipado()
		return true
	return false


func _fim_antecipado() -> void:
	_viagem_acabou = true
	_parar_movimento()
	var salto := float(skill.get("configuracoes", {}).get("inicio_do_fim", -1.0))
	if salto > _t:
		_t = salto          # os blocos que ficaram no meio fecham no próximo quadro


## Direção do bloco de Movimento: Frente/Trás/Acima girada pelo Ângulo (lateral, + =
## direita) e pela Inclinação (+ = para cima) — o zigue-zague e a subida da Pika.
func _direcao_do_movimento(p: Dictionary) -> Vector3:
	if p.direcao == "Acima":
		return Vector3.UP
	var frente := _base * Vector3.FORWARD
	if p.direcao == "Trás":
		frente = -frente
	var dir := frente.rotated(Vector3.UP, -deg_to_rad(float(p.get("angulo", 0.0))))
	var inc := deg_to_rad(float(p.get("inclinacao", 0.0)))
	if absf(inc) > 0.0001:
		var lado := dir.cross(Vector3.UP).normalized()
		dir = dir.rotated(lado, inc)
	return dir.normalized()


## Até onde o corpo chega andando `deslocamento` sem atravessar parede (teleporte).
func _destino_varrido(de: Vector3, deslocamento: Vector3) -> Vector3:
	if ator is PhysicsBody3D:
		var choque := KinematicCollision3D.new()
		if (ator as PhysicsBody3D).test_move(ator.global_transform, deslocamento, choque):
			return de + choque.get_travel()
	return de + deslocamento


func _parar_movimento() -> void:
	if is_instance_valid(ator) and ator.has_method("definir_movimento_de_skill"):
		ator.definir_movimento_de_skill(Vector3.ZERO, false, true)


func _e_autoridade() -> bool:
	return not multiplayer.has_multiplayer_peer() or ator.is_multiplayer_authority()


# ---------------------------------------------------------------- dano

func _zona(forma: Shape3D, vel: Vector3, vida: float, imunidade_gelo := true) -> DamageZone:
	var d: Dictionary = skill.get("dano", {})
	var zona := DamageZone.new()
	add_child(zona)
	zona.setup(float(d.get("valor", 0.0)) * escala_de_dano, float(d.get("empurrao", 0.0)), vel,
		vida, ator, 0.0, forma, float(d.get("atordoamento", 0.0)))
	zona.cast_id = cast_id
	zona.antes_do_acerto.connect(_antes_do_acerto.bind(zona))
	zona.hit_landed.connect(_depois_do_acerto.bind(imunidade_gelo, zona))
	return zona


## Crítico e direção do empurrão, decididos no instante do acerto (no servidor:
## `DamageZone._on_body` só roda lá).
func _antes_do_acerto(alvo: Node, zona: DamageZone) -> void:
	var d: Dictionary = skill.get("dano", {})
	var valor := float(d.get("valor", 0.0)) * escala_de_dano
	if escala_pela_vida_do_alvo:
		var vida_max: Variant = alvo.get("max_health")
		valor = float(d.get("valor", 0.0)) * (float(vida_max) if vida_max != null else VIDA_DA_ARENA) / VIDA_DA_ARENA
	if _rng.randf() * 100.0 < float(d.get("critico", 0.0)):
		valor *= float(d.get("multiplicador", 1.0))
	zona.damage = valor
	zona.knockback = float(d.get("empurrao", 0.0)) * multiplicador_de_empurrao()
	if alvo is Node3D and is_instance_valid(ator):
		var longe := (alvo as Node3D).global_position - ator.global_position
		longe.y = 0.0
		zona.override_kb_dir = longe.normalized() if longe.length_squared() > 0.0001 else _base * Vector3.FORWARD


func _depois_do_acerto(alvo: Node, imunidade_gelo := true, zona: DamageZone = null) -> void:
	var d: Dictionary = skill.get("dano", {})
	# Cura pelo dano (`hit_landed` só dispara no servidor, que é quem manda na vida).
	var cura := float(d.get("cura_do_dano", 0.0))
	if cura > 0.0 and zona != null and is_instance_valid(ator) and ator.get("max_health") != null:
		ator.health = minf(float(ator.get("max_health")), float(ator.get("health")) + zona.damage * cura / 100.0)
	if float(d.get("congelar", 0.0)) > 0.0:
		# O bloco de gelo do jogo (+ 0,5 s imune). No Modo História (10/10/2026, Z da Hie):
		# projétil com "Dá imunidade ao gelo" desligado congela SEM deixar imunidade, e o
		# acerto em quem já está congelado estica o gelo — a 3ª salva fecha com a imunidade.
		var historia := _no_modo_historia()
		IceFX.congelar(alvo, float(d.congelar), true,
			IceFX.IMUNIDADE if (imunidade_gelo or not historia) else 0.0, historia)
	var lento := float(d.get("lentidao", 0.0))
	if lento > 0.0 and is_instance_valid(alvo):
		# Movimento E ações (decisão do dono, 06/10/2026), replicado ao dono do corpo.
		Lentidao.aplicar(alvo, 1.0 - lento / 100.0, float(d.get("duracao_efeito", 1.0)))


## Rodando no Modo História? (a cena da campanha se põe no grupo "modo_historia")
func _no_modo_historia() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group("modo_historia") != null


## "Dá imunidade ao gelo ao acertar" do bloco de projétil (padrão: dá).
static func _da_imunidade(p: Dictionary) -> bool:
	return bool(p.get("imunidade_gelo", true))


## Hitbox de vários acertos: libera quem já levou e acerta de novo quem ainda está
## dentro (a `Area3D` só avisa quem ENTRA).
func _reacertar(zona: DamageZone) -> void:
	zona._hit.clear()
	for corpo in zona.get_overlapping_bodies():
		zona._on_body(corpo)


# ---------------------------------------------------------------- projéteis

func _disparar(p: Dictionary) -> void:
	var origem := pe() + _base * DISPARO
	var da_mao := _origem_nas_maos(str(p.get("sai_de", "Corpo")))
	if da_mao.is_finite():
		origem = da_mao
	var frente := _base * Vector3.FORWARD
	var sai := str(p.get("direcao_disparo", "Mira"))
	if sai == "Abaixo":
		var de := pe()
		if _ponto_do_fim.is_finite():
			de = Vector3(_ponto_do_fim.x, de.y, _ponto_do_fim.z)   # em cima do inimigo achado
		origem = de + Vector3.UP * 0.2
		frente = Vector3.DOWN
	elif sai == "Chuva":
		_disparar_chuva(p, origem)
		return
	elif (sai == "Mira" or sai == "Anel") and ponto_mirado.is_finite() and (ponto_mirado - origem).length_squared() > 1.0:
		frente = (ponto_mirado - origem).normalized()
	if float(p.get("explosao", 0.0)) > 0.0 or bool(p.get("sem_dano", false)):
		_disparar_manuais(p, origem, frente)
		return
	var n := int(p.quantidade)
	var cor := Color(skill.get("vfx", {}).get("cor", "#ffffff"))
	var anel := sai == "Anel"
	for i in n:
		var a := lerpf(-float(p.abertura) * 0.5, float(p.abertura) * 0.5, float(i) / maxf(1.0, n - 1.0)) if n > 1 else 0.0
		var rumo := frente.rotated(Vector3.UP, deg_to_rad(a))
		var onde := origem
		if anel:
			# Em volta do jogador, em alturas variadas; todos saem para a mira (com um
			# leque pequeno da Abertura sorteado pela semente do lançamento).
			var ang := TAU * (float(i) + _rng.randf() * 0.6) / float(n)
			onde = pe() + Vector3(cos(ang), 0.0, sin(ang)) * float(p.get("raio_do_anel", 2.5)) \
				+ Vector3.UP * _rng.randf_range(0.5, 2.6)
			rumo = frente.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-float(p.abertura), float(p.abertura)) * 0.5))
		var esfera := SphereShape3D.new()
		esfera.radius = float(p.get("raio_de_acerto", 0.0)) if float(p.get("raio_de_acerto", 0.0)) > 0.0 else float(p.raio)
		var zona := _zona(esfera, rumo * float(p.velocidade), float(p.vida), _da_imunidade(p))
		zona.is_projectile = true
		zona.global_position = onde
		# A forma vem da loja de projéteis (mesmo desenho da prévia); o acerto é a esfera.
		var desenho := Catalogo.criar(p, cor)
		zona.add_child(desenho)
		if not bool(p.perfurar):
			zona.hit_landed.connect(func(_alvo: Node) -> void:
				if is_instance_valid(zona): zona.queue_free())
		# Cenário (chão, parede) sempre para o projétil; "atravessar" vale para ALVOS.
		# A prévia, sem paredes, o mata ao passar abaixo do chão. Ele não some na hora:
		# fica cravado e inofensivo por `PERMANENCIA_NO_CENARIO` (1 s) — pedido do dono,
		# 15/10/2026.
		zona.collided_with_any.connect(func(corpo: Node) -> void:
			if is_instance_valid(zona) and not corpo.has_method("take_damage"): _cravar(zona))
		_projeteis.append({"zona": zona, "gravidade": float(p.gravidade), "desenho": desenho, "bloco": _bloco_disparando})


## O projétil bateu no cenário: para onde está, deixa de acertar e some depois de
## `PERMANENCIA_NO_CENARIO`. Quem o mantém vivo até lá é a lista `_projeteis` (a skill só
## termina com ela vazia), e a gravidade não o puxa mais (`_avancar_projeteis`).
func _cravar(zona: DamageZone) -> void:
	if zona.has_meta(META_CRAVADA):
		return
	zona.set_meta(META_CRAVADA, true)
	zona.vel = Vector3.ZERO
	zona.set_deferred("monitoring", false)
	zona.set_deferred("monitorable", false)
	get_tree().create_timer(PERMANENCIA_NO_CENARIO).timeout.connect(func() -> void:
		if is_instance_valid(zona): zona.queue_free())


func _avancar_projeteis(delta: float) -> void:
	var vivos: Array[Dictionary] = []
	for pr in _projeteis:
		# Checar ANTES de tipar: atribuir nó já liberado a variável tipada é erro.
		if not is_instance_valid(pr.zona) or (pr.zona as Node).is_queued_for_deletion():
			continue
		var zona: DamageZone = pr.zona
		if zona.has_meta(META_CRAVADA):
			vivos.append(pr)
			continue
		zona.vel.y -= float(pr.gravidade) * delta
		Catalogo.animar(pr.desenho, zona.vel, delta)
		vivos.append(pr)
	_projeteis = vivos


func _passo_de_pose(delta: float) -> void:
	var alvo := PosesDeSkill.alvo_no_tempo(skill, _t, Callable(Dados, "parametros"))
	if alvo.is_empty() and _pose_atual.is_empty():
		return
	_pose_atual = PosesDeSkill.aproximar(_pose_atual, alvo.get("pose", {}), float(alvo.get("transicao", 0.15)), delta)
	if _pose_atual.is_empty():
		ator.remove_meta(META_POSE)
	else:
		ator.set_meta(META_POSE, PosesDeSkill.com_pulso(_pose_atual, float(alvo.get("pulso", 0.0)), _t + _segurado))


func _encerrar() -> void:
	set_physics_process(false)
	for st in _estado.values():
		if is_instance_valid(st.get("transformacao")): st.transformacao.encerrar()
	if _flutuando and is_instance_valid(ator) and ator.has_method("definir_flutuar"):
		ator.definir_flutuar(false)
	_flutuando = false
	_ocultar_corpo(false)
	for m in _manuais:
		if is_instance_valid(m.get("no")):
			(m.no as Node).queue_free()
	_manuais.clear()
	if is_instance_valid(ator) and ator.has_meta(META_POSE):
		ator.remove_meta(META_POSE)      # o animador do corpo volta suave sozinho
	_parar_movimento()
	if is_instance_valid(ator) and ator.has_method("parar_animacao_de_skill"):
		ator.parar_animacao_de_skill()
	terminou.emit()
	queue_free()


# ------------------------------------------------------------ mira e paredes

## Rumo da mira a partir de `de`: ao ponto mirado (o retículo, ou o alvo travado) ou,
## sem ponto, a mira com que a skill saiu.
func _rumo_da_mira(de: Vector3) -> Vector3:
	if ponto_mirado.is_finite() and (ponto_mirado - de).length_squared() > 1.0:
		return (ponto_mirado - de).normalized()
	return _rumo3d


## Onde o VFX está agora, pela Âncora do bloco (07/10/2026). INF = a âncora ainda não
## existe (o projétil do bloco não saiu, ou já acabou): o efeito fica escondido.
func _lugar_do_vfx(st: Dictionary, p: Dictionary) -> Vector3:
	var padrao := pe() + _base * Visual.lugar(p)
	match str(p.get("ancora", "Jogador")):
		"Osso do jogador":
			var o := _osso(str(p.get("osso", "Mão direita")))
			return o if o.is_finite() else padrao
		"Alvo":
			if not st.has("alvo"):
				st.alvo = KitDoBuilder.alvo_mais_perto(ator, maxf(float(skill.get("configuracoes", {}).get("alcance", 30.0)), 1.0))
			return AlvosDeGolpe.centro(st.alvo) if is_instance_valid(st.alvo) else padrao
		"Projétil":
			return _projetil_do_bloco(str(p.get("projetil_de", "")))
		"Ponto mirado":
			return ponto_mirado if ponto_mirado.is_finite() else padrao
		"Mundo":
			if not st.has("fixo"):
				st.fixo = padrao
			return st.fixo
	if bool(p.get("na_mao", false)) and _mao().is_finite():
		return _mao()
	return padrao


## VFX com âncora "Projétil": de novo DEPOIS de os projéteis andarem no quadro (senão
## fica um quadro atrás da bola).
func _seguir_projeteis() -> void:
	for e: Dictionary in skill.get("eventos", []):
		if str(e.get("tipo", "")) != "vfx" or str(e.get("parametros", {}).get("ancora", "")) != "Projétil":
			continue
		var st: Dictionary = _estado.get(e.id, {})
		if st.has("no") and is_instance_valid(st.no) and not st.get("fechado", false):
			var onde := _projetil_do_bloco(str(e.parametros.get("projetil_de", "")))
			(st.no as Node3D).visible = onde.is_finite()
			if onde.is_finite():
				(st.no as Node3D).global_position = onde


## "Sai de" do projétil (07/10/2026): a mão direita, a esquerda ou o meio das duas. INF =
## do corpo (o lugar de sempre) — ou o ator não tem mãos.
func _origem_nas_maos(sai_de: String) -> Vector3:
	match sai_de:
		"Mão direita", "Mão esquerda":
			return _osso(sai_de)
		"Entre as mãos":
			var d := _osso("Mão direita")
			var e := _osso("Mão esquerda")
			return (d + e) * 0.5 if d.is_finite() and e.is_finite() else Vector3.INF
	return Vector3.INF


## Um osso do ator agora (a mão direita é o `Hand_R`; a esquerda, a ponta do antebraço,
## como o `Hand_R` na direita). INF se o ator não tem esse osso.
func _osso(nome: String) -> Vector3:
	if nome == "Mão direita":
		return _mao()
	var papel: String = {"Mão esquerda": "ForeArm_L", "Cabeça": "Head", "Tronco": "Torso",
		"Pé direito": "Foot_R", "Pé esquerdo": "Foot_L"}.get(nome, "")
	if papel.is_empty() or not is_instance_valid(ator):
		return Vector3.INF
	if not is_instance_valid(_ossos.get(papel)):
		_ossos[papel] = ator.find_child(papel, true, false)
	var no := _ossos.get(papel) as Node3D
	if no == null:
		return Vector3.INF
	return no.global_transform * Vector3(0, -0.36, 0.02) if papel == "ForeArm_L" else no.global_position


## Onde está o primeiro projétil vivo do bloco `id` (INF se nenhum).
func _projetil_do_bloco(id: String) -> Vector3:
	for m in _manuais:
		if str(m.get("bloco", "")) == id and is_instance_valid(m.no):
			return (m.no as Node3D).global_position
	for pr in _projeteis:
		if str(pr.get("bloco", "")) == id and is_instance_valid(pr.zona) and not (pr.zona as Node).is_queued_for_deletion():
			return (pr.zona as Node3D).global_position
	return Vector3.INF


## Onde está a mão direita do ator agora (INF = o ator não tem mão: usa o lugar do bloco).
func _mao() -> Vector3:
	if not is_instance_valid(_no_da_mao) and is_instance_valid(ator):
		_no_da_mao = ator.find_child("Hand_R", true, false) as Node3D
	return _no_da_mao.global_position if is_instance_valid(_no_da_mao) else Vector3.INF


static func _cima(dir: Vector3) -> Vector3:
	return Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK


## Quanto de `maximo` a luz anda de `de` em `dir` até a primeira PAREDE (personagem não
## é parede: o feixe passa e fere).
func _livre(de: Vector3, dir: Vector3, maximo: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(de, de + dir * maximo, 1)
	q.exclude = _corpos_vivos()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return de.distance_to(hit.position) if not hit.is_empty() else maximo


func _corpos_vivos() -> Array[RID]:
	var fora: Array[RID] = []
	if ator is CollisionObject3D:
		fora.append((ator as CollisionObject3D).get_rid())
	for grupo in ["player", "enemy", AlvosDeGolpe.GRUPO]:
		for n in get_tree().get_nodes_in_group(grupo):
			if n is CollisionObject3D and is_instance_valid(n):
				fora.append((n as CollisionObject3D).get_rid())
	return fora


func _ocultar_corpo(sim: bool) -> void:
	if sim == _corpo_oculto or not is_instance_valid(ator):
		return
	_corpo_oculto = sim
	if ator.has_method("ocultar_corpo_por_skill"):
		ator.ocultar_corpo_por_skill(sim)


# ------------------------------------------- esfera que explode / só efeito

func _disparar_manuais(p: Dictionary, origem: Vector3, frente: Vector3) -> void:
	var n := int(p.quantidade)
	var cor := Color(skill.get("vfx", {}).get("cor", "#ffffff"))
	for i in n:
		var a := lerpf(-float(p.abertura) * 0.5, float(p.abertura) * 0.5, float(i) / maxf(1.0, n - 1.0)) if n > 1 else 0.0
		var rumo := frente.rotated(Vector3.UP, deg_to_rad(a)) if absf(frente.y) < 0.98 else frente
		var desenho := Catalogo.criar(p, cor)
		add_child(desenho)
		desenho.global_position = origem
		_manuais.append({"no": desenho, "vel": rumo * float(p.velocidade), "vida": float(p.vida),
			"gravidade": float(p.gravidade), "explosao": float(p.get("explosao", 0.0)), "p": p, "bloco": _bloco_disparando})


## "Chuva" (C da Pika, 07/10/2026): cada bolinha sai da mão em arco e cai num ponto do
## círculo ("Área da chuva") em volta do chão mirado; explode ao tocar (quem fere é a
## explosão). Sorteio pela semente do lançamento: o mesmo em todos os peers.
func _disparar_chuva(p: Dictionary, origem: Vector3) -> void:
	var conf: Dictionary = skill.get("configuracoes", {})
	var mirado := ponto_mirado if ponto_mirado.is_finite() else pe() + _base * Vector3.FORWARD * 12.0
	var meio := Chuva.centro(get_world_3d(), pe(), mirado, float(conf.get("alcance", 30.0)), _corpos_vivos())
	var g := float(p.gravidade) if float(p.gravidade) > 0.0 else Chuva.GRAVIDADE
	var cor := Color(skill.get("vfx", {}).get("cor", "#ffffff"))
	for queda in Chuva.quedas(_rng, meio, float(p.get("area_chuva", 8.0)), int(p.quantidade)):
		var t := lerpf(Chuva.VOO_MIN, Chuva.VOO_MAX, _rng.randf())
		var desenho := Catalogo.criar(p, cor)
		add_child(desenho)
		desenho.global_position = origem
		_manuais.append({"no": desenho, "vel": Chuva.arremesso(origem, queda, g, t), "vida": t + 1.0,
			"gravidade": g, "explosao": float(p.get("explosao", 0.0)), "p": p, "bloco": _bloco_disparando})


## Cada passo: anda, raio do passo acha o impacto (cenário OU alguém). Explosiva explode
## ali; só efeito some.
func _avancar_manuais(delta: float) -> void:
	var vivos: Array[Dictionary] = []
	var fora: Array[RID] = []
	if ator is CollisionObject3D:
		fora.append((ator as CollisionObject3D).get_rid())
	for m in _manuais:
		var no: Variant = m.no
		if not is_instance_valid(no):
			continue
		var desenho := no as Node3D
		m.vida = float(m.vida) - delta
		m.vel = (m.vel as Vector3) + Vector3.DOWN * float(m.gravidade) * delta
		var de := desenho.global_position
		var ate := de + (m.vel as Vector3) * delta
		var q := PhysicsRayQueryParameters3D.create(de, ate, 1)
		q.exclude = fora
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if m.has("espera"):                  # cravado no cenário, esperando para sumir
			m.espera = float(m.espera) - delta
			if float(m.espera) <= 0.0:
				desenho.queue_free()
				continue
			vivos.append(m)
			continue
		if not hit.is_empty():
			if float(m.explosao) > 0.0:
				_explodir(hit.position, float(m.explosao), str((m.p as Dictionary).get("som_explosao", "Impacto")),
					_da_imunidade(m.p))
			desenho.global_position = hit.position
			m.espera = PERMANENCIA_NO_CENARIO
			vivos.append(m)
			continue
		if float(m.vida) <= 0.0:
			desenho.queue_free()
			continue
		desenho.global_position = ate
		Catalogo.animar(desenho, m.vel, delta)
		vivos.append(m)
	_manuais = vivos


## A explosão: uma esfera de dano do raio (quem fere é o servidor, pela DamageZone) e
## o clarão que cresce e some, nos dois lados da rede.
func _explodir(ponto: Vector3, raio: float, som := "Impacto", imunidade_gelo := true) -> void:
	var esfera := SphereShape3D.new()
	esfera.radius = raio
	var zona := _zona(esfera, Vector3.ZERO, 0.15, imunidade_gelo)
	zona.global_position = ponto
	var pv := {"estilo": "Explosão", "cor": skill.get("vfx", {}).get("cor", "#ffe08a"), "escala": raio * 0.5}
	var fx := Visual.vfx(self, pv)
	fx.global_position = ponto
	_explosoes.append({"no": fx, "idade": 0.0, "p": pv})
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_som_ms >= INTERVALO_DE_SOM_MS:
		_ultimo_som_ms = agora
		Visual.som_3d(self, {"som": som, "volume": -4.0, "tom": 0.85 if som == "Impacto" else 1.0}, ponto)


func _avancar_explosoes(delta: float) -> void:
	var vivas: Array[Dictionary] = []
	for x in _explosoes:
		if not is_instance_valid(x.no):
			continue
		x.idade = float(x.idade) + delta
		if float(x.idade) >= DURACAO_DA_EXPLOSAO:
			(x.no as Node).queue_free()
			continue
		Visual.animar_vfx(x.no, x.p, float(x.idade), float(x.idade) / DURACAO_DA_EXPLOSAO)
		vivas.append(x)
	_explosoes = vivas
