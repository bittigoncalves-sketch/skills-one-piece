class_name TaticaDeMissao
extends Node
## POSICIONAMENTO DOS INIMIGOS EM MISSÃO (08/11/2026, pedido do dono). Filho de um `PersonagemMinePiece` que não é chefe nem aliado; vale só
## quando o personagem tem alvo E está em missão: raid (facção "raid:*") ou missão de combate aceita (`tem_missao_de_combate`).
##
##  • ATIRADOR (arma de fogo): procura um POSTO ALTO — o topo de qualquer coisa sólida (prédio, árvore, pedra, muro) a 2–9 m acima do chão,
##    a 6–20 m do jogador, com linha de tiro — e sobe até lá com PULO DUPLO (dois impulsos, o segundo no ápice do primeiro). Lá em cima
##    fica parado, encara o jogador e MIRA: toca o braço estendido (`right_arm_front`) em laço enquanto tem linha de tiro. O disparo em
##    si continua sendo a IA do mod (`IaDoMod`). Sem posto, ou sem linha de tiro por `PACIENCIA` s, procura outro.
##  • ESPADACHIM: aproxima DEFENDENDO (clipe `guard` em laço) e tenta CERCAR o jogador: cada um ocupa uma posição num anel em volta dele.
##    O mais bem posicionado à FRENTE do jogador fica lá; quem encontraria um na frente vai para TRÁS (arco de trás, repartido). Circulam
##    pelo anel em vez de atravessar o jogador.
## `dirige()` diz ao cérebro para NÃO andar sozinho neste quadro (ele só persegue em linha reta).

const PERIODO := 0.5
const RAIO_DO_CERCO := 2.2
const DEFESA_ATE := 6.0              # m: de longe até aqui o espadachim avança com a guarda erguida
const ARCO_DE_TRAS := Vector2(110.0, 250.0)
const ALTURA_DO_POSTO := Vector2(2.0, 9.0)
## Decisão do dono (15/11/2026): o atirador fica MAIS LONGE que o espadachim (antes 6–20 m; o fuzil agora alcança 48 m — ver
## `src/minecraft/ajustadas/LogicRifleProcedure.gd`).
const DISTANCIA_DO_POSTO := Vector2(16.0, 36.0)
## Decisão do dono (15/11/2026): o espadachim NÃO defende nem cerca — vai para cima do jogador e solta golpes assim que entra em alcance
## (o cérebro persegue em linha reta e ataca). `true` religa o cerco com a guarda erguida (código mantido abaixo, medido em
## `test_tatica_de_missao`). GATILHO: se o cerco não voltar até a próxima revisão de IA dos inimigos, apagar `_cercar`/`_guarda`.
static var cercar_o_jogador := false
const IMPULSO_DO_PULO := 15.0        # m/s; com a gravidade do corpo (32) sobe ~3,5 m por pulo, ~7 m nos dois
const PACIENCIA := 4.0
const PASSO_DA_BUSCA := 3.0
const ESPERA_DEPOIS_DE_FALHAR := 4.0

enum Papel { NENHUM, ATIRADOR, ESPADACHIM }
enum Estado { SEM_POSTO, INDO, NO_POSTO }

var corpo: PersonagemMinePiece
var papel := Papel.NENHUM
var estado := Estado.SEM_POSTO
var posto := Vector3.INF
var pulos_dados := 0
var _tempo := 0.0
var _contexto := false
var _ataque_total := false          # um chefe do bando está em campo: o espadachim para de cercar e vai para cima
var _relogio := 0.0
var _no_ar_desde := -1.0
var _sem_linha := 0.0
var _espera := 0.0
var _fase_aim := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	corpo = get_parent() as PersonagemMinePiece
	_rng.randomize()
	papel = papel_de(corpo.ficha, corpo.id_personagem)


static func papel_de(ficha: Dictionary, id: String) -> Papel:
	if bool(ficha.get("chefe", false)) or str(ficha.get("faccao", "")) == "aliado":
		return Papel.NENHUM
	if bool(ficha.get("arma_de_fogo", false)) or not EquipamentoPadrao.armas_de_fogo(id).is_empty():
		return Papel.ATIRADOR
	if bool(ficha.get("espada", false)):
		return Papel.ESPADACHIM
	return Papel.NENHUM


## O cérebro pergunta a cada quadro: true = a tática anda e encara por este quadro.
func dirige(alvo: Node3D) -> bool:
	if papel == Papel.ESPADACHIM and (_ataque_total or not cercar_o_jogador):
		return false
	return papel != Papel.NENHUM and _contexto and alvo != null and is_instance_valid(alvo)


## ATAQUE TOTAL (08/11/2026, pedido do dono): enquanto houver um CHEFE do mesmo bando vivo em campo (na raid ele nasce por último), os
## espadachins largam a defesa e o cerco e atacam direto, como os mobs comuns. Os atiradores seguem nos postos.
func _chefe_em_campo() -> bool:
	var faccao := str(corpo.ficha.get("faccao", ""))
	var zona := str(corpo.ficha.get("zona", ""))
	for n in get_tree().get_nodes_in_group("personagens_east_blue"):
		var p := n as PersonagemMinePiece
		if p == null or p == corpo or not p.vivo() or not bool(p.ficha.get("chefe", false)):
			continue
		if str(p.ficha.get("faccao", "")) == faccao or (not zona.is_empty() and str(p.ficha.get("zona", "")) == zona):
			return true
	return false


## O papel de AGORA: o que está na mão manda (o sorteio do mod pode dar fuzil a quem a ficha chama de espadachim, e `ArmaUnica` tira uma).
func _papel_vivo() -> Papel:
	if bool(corpo.ficha.get("chefe", false)) or str(corpo.ficha.get("faccao", "")) == "aliado":
		return Papel.NENHUM
	var maos := ArmaUnica.armas_nas_maos(corpo)
	if maos.values().has("fogo"):
		return Papel.ATIRADOR
	if maos.values().has("corte"):
		return Papel.ESPADACHIM
	return papel_de(corpo.ficha, corpo.id_personagem)


func _em_missao() -> bool:
	if str(corpo.ficha.get("faccao", "")).begins_with("raid:"):
		return true
	var cena := get_tree().current_scene
	var prog: Variant = cena.get("progressao") if cena != null else null
	return prog != null and prog.has_method("tem_missao_de_combate") and prog.tem_missao_de_combate()


func _physics_process(delta: float) -> void:
	if papel == Papel.NENHUM or corpo == null or not corpo.vivo():
		return
	_tempo += delta
	_relogio -= delta
	_espera = maxf(_espera - delta, 0.0)
	if _relogio <= 0.0:
		_relogio = PERIODO
		_contexto = _em_missao()
		_ataque_total = _contexto and _chefe_em_campo()
		var novo := _papel_vivo()
		if novo != papel:
			_largar_posto()
			papel = novo
	var alvo: Node3D = corpo.cerebro.alvo if corpo.cerebro != null else null
	if not dirige(alvo) or corpo.esta_caido():
		if estado != Estado.SEM_POSTO:
			_largar_posto()
		return
	if papel == Papel.ESPADACHIM:
		_cercar(alvo, delta)
	else:
		_atirar_do_alto(alvo, delta)


# ------------------------------------------------------------------ espadachim

static func frente_do_jogador(jogador: Node3D) -> Vector3:
	var modelo: Variant = jogador.get("_char_model")
	var f := -(modelo as Node3D).global_basis.z if modelo is Node3D else -jogador.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func _cercar(alvo: Node3D, _delta: float) -> void:
	var plano := Vector3(corpo.global_position.x - alvo.global_position.x, 0.0, corpo.global_position.z - alvo.global_position.z)
	var d := plano.length()
	var frente := frente_do_jogador(alvo)
	var meu_angulo := rad_to_deg(frente.signed_angle_to(plano, Vector3.UP)) if d > 0.01 else 0.0
	var alvo_angulo := angulo_do_posto(self, alvo)
	var vel := corpo.velocidade_de_andar()
	if d > DEFESA_ATE:
		_guarda()
		corpo.andar((alvo.global_position - corpo.global_position).normalized() * vel * 0.85)
	else:
		var erro := wrapf(alvo_angulo - meu_angulo, -180.0, 180.0)
		if absf(erro) > 18.0:
			# Circula pelo anel (nunca atravessa o jogador): tangente na direção do menor giro, com a pitada radial que o prende ao anel.
			var radial := plano.normalized() if d > 0.01 else Vector3.FORWARD
			var tangente := radial.cross(Vector3.UP) * (-signf(erro))
			var ajuste := clampf(RAIO_DO_CERCO - d, -1.0, 1.0)
			corpo.andar((tangente + radial * ajuste * 0.8).normalized() * vel * 0.9)
			if d > RAIO_DO_CERCO + 1.0:
				_guarda()
		else:
			var ponto := alvo.global_position + frente.rotated(Vector3.UP, deg_to_rad(alvo_angulo)) * RAIO_DO_CERCO
			var ate := ponto - corpo.global_position
			ate.y = 0.0
			corpo.andar(ate.normalized() * vel * 0.7 if ate.length() > 0.35 else Vector3.ZERO)
	corpo.encarar(alvo.global_position)


func _guarda() -> void:
	if _tempo - _fase_aim >= 0.5:
		_fase_aim = _tempo
		corpo.tocar_clipe("guard", 0.6)


## O ângulo (graus, 0 = bem à frente do jogador) do posto deste espadachim. Mais perto da frente fica com a frente; os outros se
## repartem no arco de trás, por ordem de posição no arco (sem cruzar caminho).
static func angulo_do_posto(eu: TaticaDeMissao, alvo: Node3D) -> float:
	var colegas: Array[TaticaDeMissao] = _colegas(eu, alvo)
	var frente := frente_do_jogador(alvo)
	var melhor: TaticaDeMissao = null
	var menor := INF
	for c in colegas:
		var v := c.corpo.global_position - alvo.global_position
		v.y = 0.0
		if v.length() < 0.01:
			continue
		var a := absf(rad_to_deg(frente.signed_angle_to(v, Vector3.UP)))
		if a < menor:
			menor = a
			melhor = c
	if eu == melhor and menor <= 60.0:
		return 0.0
	# Quem não é o da frente: arco de trás repartido, na ordem do ângulo em que cada um está agora.
	var de_tras: Array[TaticaDeMissao] = []
	for c in colegas:
		if c != melhor or menor > 60.0:
			de_tras.append(c)
	de_tras.sort_custom(func(a: TaticaDeMissao, b: TaticaDeMissao) -> bool:
		return _angulo_atual(a, alvo, frente) < _angulo_atual(b, alvo, frente))
	var i := de_tras.find(eu)
	var n := de_tras.size()
	if i < 0 or n == 0:
		return 180.0
	var t := (float(i) + 0.5) / float(n)
	var graus := lerpf(ARCO_DE_TRAS.x, ARCO_DE_TRAS.y, t)
	return wrapf(graus, -180.0, 180.0)


static func _angulo_atual(c: TaticaDeMissao, alvo: Node3D, frente: Vector3) -> float:
	var v := c.corpo.global_position - alvo.global_position
	v.y = 0.0
	return wrapf(rad_to_deg(frente.signed_angle_to(v, Vector3.UP)), -180.0, 180.0) if v.length() > 0.01 else 0.0


static func _colegas(eu: TaticaDeMissao, alvo: Node3D) -> Array[TaticaDeMissao]:
	var saida: Array[TaticaDeMissao] = []
	for n in eu.get_tree().get_nodes_in_group("personagens_east_blue"):
		var p := n as PersonagemMinePiece
		if p == null or not p.vivo() or p.cerebro == null or p.cerebro.alvo != alvo:
			continue
		var t := p.get_node_or_null("TaticaDeMissao") as TaticaDeMissao
		if t != null and t.papel == Papel.ESPADACHIM and t._contexto:
			saida.append(t)
	if not saida.has(eu):
		saida.append(eu)
	return saida


# ------------------------------------------------------------------ atirador

func _largar_posto() -> void:
	estado = Estado.SEM_POSTO
	posto = Vector3.INF
	pulos_dados = 0
	_no_ar_desde = -1.0


func _atirar_do_alto(alvo: Node3D, delta: float) -> void:
	match estado:
		Estado.SEM_POSTO:
			if _espera > 0.0:
				_seguir_pelo_chao(alvo)
				return
			var p: Variant = escolher_posto(alvo)
			if p == null:
				_espera = ESPERA_DEPOIS_DE_FALHAR
				return
			posto = p
			pulos_dados = 0
			_no_ar_desde = _tempo
			estado = Estado.INDO
		Estado.INDO:
			_ir_ao_posto(delta)
		Estado.NO_POSTO:
			_mirar(alvo, delta)


func _seguir_pelo_chao(alvo: Node3D) -> void:
	var d := corpo.global_position.distance_to(alvo.global_position)
	var perto := 9.0
	corpo.andar((alvo.global_position - corpo.global_position).normalized() * corpo.velocidade_de_andar() if d > perto else Vector3.ZERO)
	corpo.encarar(alvo.global_position)


## O topo sólido mais perto do atirador que serve de posto, ou null.
func escolher_posto(alvo: Node3D) -> Variant:
	var espaco := corpo.get_world_3d().direct_space_state
	var melhor: Variant = null
	var menor := INF
	var chao_y := corpo.global_position.y
	# Varre uma GRADE (passo `PASSO_DA_BUSCA`, com deslocamento aleatório) no anel de 6–20 m em volta do jogador: um prédio de 6 m sempre
	# leva alguns pontos; amostra aleatória solta falhava em ~40 % das buscas.
	var desloc := Vector2(_rng.randf(), _rng.randf()) * PASSO_DA_BUSCA
	var pontos: Array[Vector3] = []
	var lado := int(DISTANCIA_DO_POSTO.y / PASSO_DA_BUSCA) + 1
	for gx in range(-lado, lado + 1):
		for gz in range(-lado, lado + 1):
			var off := Vector3(gx * PASSO_DA_BUSCA + desloc.x, 0.0, gz * PASSO_DA_BUSCA + desloc.y)
			var dist := off.length()
			if dist >= DISTANCIA_DO_POSTO.x and dist <= DISTANCIA_DO_POSTO.y:
				pontos.append(alvo.global_position + off)
	for xz in pontos:
		var raio := PhysicsRayQueryParameters3D.create(Vector3(xz.x, chao_y + ALTURA_DO_POSTO.y + 6.0, xz.z), Vector3(xz.x, chao_y - 2.0, xz.z), 1)
		raio.exclude = [corpo.get_rid()]
		var h := espaco.intersect_ray(raio)
		if h.is_empty() or float((h["normal"] as Vector3).y) < 0.8:
			continue
		var topo: Vector3 = h["position"]
		var altura := topo.y - chao_y
		if altura < ALTURA_DO_POSTO.x or altura > ALTURA_DO_POSTO.y:
			continue
		var pe := topo + Vector3.UP * 0.05
		if not _cabe(espaco, pe) or not _linha_de_tiro(espaco, pe, alvo):
			continue
		var d := corpo.global_position.distance_to(pe)
		if d < menor and d <= 30.0:
			menor = d
			melhor = pe
	return melhor


func _cabe(espaco: PhysicsDirectSpaceState3D, pe: Vector3) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(0.25, float(corpo.ficha.get("largura", 0.6)) * 0.5)
	cap.height = maxf(float(corpo.ficha.get("altura", 1.8)), cap.radius * 2.0 + 0.05)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, pe + Vector3.UP * (cap.height * 0.5 + 0.12))
	q.collision_mask = 1
	q.exclude = [corpo.get_rid()]
	return espaco.intersect_shape(q, 1).is_empty()


func _linha_de_tiro(espaco: PhysicsDirectSpaceState3D, pe: Vector3, alvo: Node3D) -> bool:
	var de := pe + Vector3.UP * float(corpo.ficha.get("altura", 1.8)) * 0.8
	var ate := alvo.global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1)
	q.exclude = [corpo.get_rid(), (alvo as CollisionObject3D).get_rid()] if alvo is CollisionObject3D else [corpo.get_rid()]
	return espaco.intersect_ray(q).is_empty()


func _ir_ao_posto(_delta: float) -> void:
	var ate := posto - corpo.global_position
	var h := Vector3(ate.x, 0.0, ate.z)
	var vel := corpo.velocidade_de_andar() * (1.0 if corpo.is_on_floor() else 1.8)
	corpo.andar(h.normalized() * minf(vel, maxf(h.length() * 4.0, 1.0)))
	corpo.encarar(posto)
	# Primeiro pulo: perto da base e ainda abaixo do posto. Segundo (o DUPLO): no ápice do primeiro, se ainda falta subir.
	var falta := posto.y - corpo.global_position.y
	if corpo.is_on_floor() and h.length() < 6.0 and falta > 0.6 and pulos_dados == 0:
		corpo.pular(IMPULSO_DO_PULO)
		pulos_dados = 1
	elif pulos_dados == 1 and not corpo.is_on_floor() and corpo.velocity.y < 1.5 and falta > 0.4:
		corpo.pular(IMPULSO_DO_PULO)
		pulos_dados = 2
	elif corpo.is_on_floor() and falta > 0.6 and h.length() < 1.2 and pulos_dados >= 1:
		pulos_dados = 0                    # pousou perto do posto mais baixo que o esperado: tenta de novo
	if corpo.is_on_floor() and absf(falta) <= 0.6 and h.length() < 1.5:
		estado = Estado.NO_POSTO
		corpo.andar(Vector3.ZERO)
		_sem_linha = 0.0
		return
	if _tempo - _no_ar_desde > 6.0:
		_largar_posto()
		_espera = ESPERA_DEPOIS_DE_FALHAR


func _mirar(alvo: Node3D, delta: float) -> void:
	corpo.andar(Vector3.ZERO)
	corpo.encarar(alvo.global_position)
	var espaco := corpo.get_world_3d().direct_space_state
	if _linha_de_tiro(espaco, corpo.global_position, alvo):
		_sem_linha = 0.0
		if _tempo - _fase_aim >= 0.5:
			_fase_aim = _tempo
			corpo.tocar_clipe("right_arm_front", 0.6)       # a MIRA: braço estendido em laço enquanto vê o jogador
	else:
		_sem_linha += delta
	if _sem_linha > PACIENCIA or corpo.global_position.distance_to(alvo.global_position) > DISTANCIA_DO_POSTO.y + 6.0:
		_largar_posto()
