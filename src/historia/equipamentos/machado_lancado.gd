class_name MachadoLancado
extends Node3D
## O machado do Z, em voo (17/10/2026): sai da mão girando, fere o primeiro inimigo que
## cruza o caminho e cai ali; sem inimigo, crava no cenário. Parado, volta à mão quando o
## jogador ENCOSTA nele (`recolhido`).
##
## Só o dono do corpo o cria e o move (a campanha é offline/host); os outros peers não o veem.
## GATILHO: replicar o voo quando o Modo História ganhar cooperativo com o machado.

signal recolhido
signal acertou(alvo: Node3D)

const MODELO := preload("res://mapas/modelos/machado_lenhador.glb")
const Sweep := preload("res://src/combat/SwordSweep.gd")
const MASCARA_DE_ALVOS := 15 | (1 << 20)
const MASCARA_DE_CENARIO := 1
const VELOCIDADE := 26.0
const GRAVIDADE := 9.0
const GIRO := TAU * 2.6
const ALCANCE_DE_VOO := 0.95        # s de voo antes de cair sem achar nada
const RAIO_DE_ACERTO := 0.38
const ALCANCE_DE_RECOLHER := 1.15   # m, do centro do corpo ao machado parado
const ESPERA_PARA_RECOLHER := 0.45  # s depois de parar: não volta na hora em que cai
const DANO := 40.0
const EMPURRAO := 9.0

enum Estado { VOANDO, CAINDO, PARADO }

var estado := Estado.VOANDO
var jogador: Node3D
var velocidade := Vector3.ZERO
var _visual: Node3D
var _eixo_do_giro := Vector3.RIGHT
var _tempo := 0.0
var _parado_ha := 0.0
var _anel: MeshInstance3D


## `origem` e `direcao` em coordenadas de mundo; `orientacao` = a do machado na mão.
static func lancar(dono: Node3D, origem: Vector3, direcao: Vector3, orientacao: Basis) -> MachadoLancado:
	var m := MachadoLancado.new()
	m.name = "MachadoLancado"
	m.jogador = dono
	m.velocidade = direcao.normalized() * VELOCIDADE
	dono.get_parent().add_child(m)
	m.global_position = origem
	m._visual.global_basis = orientacao
	return m


func _init() -> void:
	_visual = MODELO.instantiate() as Node3D
	_visual.name = "Visual"
	add_child(_visual)


func _ready() -> void:
	var lado := velocidade.cross(Vector3.UP)
	# Rola de ponta a ponta, no plano vertical do arremesso.
	_eixo_do_giro = lado.normalized() if lado.length() > 0.01 else Vector3.RIGHT


func _physics_process(delta: float) -> void:
	if not is_instance_valid(jogador):
		queue_free()
		return
	_tempo += delta
	match estado:
		Estado.VOANDO, Estado.CAINDO:
			_voar(delta)
		Estado.PARADO:
			_esperar(delta)


func _voar(delta: float) -> void:
	velocidade.y -= GRAVIDADE * delta * (1.0 if estado == Estado.CAINDO else 0.35)
	var de := global_position
	var para := de + velocidade * delta
	var espaco := get_world_3d().direct_space_state
	var excluir: Array[RID] = []
	if jogador is CollisionObject3D:
		excluir.append((jogador as CollisionObject3D).get_rid())
	if estado == Estado.VOANDO:
		for contato in Sweep.contacts(espaco, de, para, RAIO_DE_ACERTO, MASCARA_DE_ALVOS, excluir):
			var alvo: Node3D = contato.body
			if not alvo.is_in_group("enemy") or alvo.get("health") == null or float(alvo.get("health")) <= 0.0:
				continue
			var rumo := velocidade
			rumo.y = 0.0
			CombatResolver.aplicar(alvo, DANO, 0, 0.0, contato.position,
				rumo.normalized() * EMPURRAO, 0.35, 0.0, false, jogador)
			acertou.emit(alvo)
			global_position = contato.position
			# Bate e cai ao pé do inimigo, quicando para trás.
			velocidade = -velocidade.normalized() * 3.0 + Vector3.UP * 3.0
			estado = Estado.CAINDO
			return
	var raio := PhysicsRayQueryParameters3D.create(de, para, MASCARA_DE_CENARIO, excluir)
	var bateu := espaco.intersect_ray(raio)
	if not bateu.is_empty() and not (bateu.collider as Object).has_method("take_damage") \
			and not HurtboxDeCombate.e_hurtbox(bateu.collider):
		_parar(bateu.position, bateu.normal)
		return
	global_position = para
	_visual.rotate(_eixo_do_giro, GIRO * delta * (1.0 if estado == Estado.VOANDO else 0.5))
	if estado == Estado.VOANDO and _tempo > ALCANCE_DE_VOO:
		estado = Estado.CAINDO
	# Caiu no vazio: volta para quem o jogou, em vez de se perder.
	if global_position.y < jogador.global_position.y - 60.0:
		recolhido.emit()


## Crava/pousa: o cabo fica inclinado, a cabeça no chão.
func _parar(ponto: Vector3, normal: Vector3) -> void:
	estado = Estado.PARADO
	velocidade = Vector3.ZERO
	global_position = ponto + normal * 0.08
	var frente := Vector3(normal.x, 0.0, normal.z)
	if frente.length() < 0.1:
		frente = -jogador.global_basis.z
	_visual.global_basis = Basis.looking_at(frente.normalized(), Vector3.UP) \
		* Basis(Vector3.RIGHT, deg_to_rad(80.0))
	_marcar()


## Um anel no chão, pulsando: onde buscar o machado.
func _marcar() -> void:
	_anel = MeshInstance3D.new()
	var malha := TorusMesh.new()
	malha.inner_radius = 0.55
	malha.outer_radius = 0.62
	_anel.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.3, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_anel.material_override = mat
	_anel.top_level = true
	add_child(_anel)
	_anel.global_position = global_position - Vector3.UP * 0.04
	_anel.global_basis = Basis.IDENTITY


func _esperar(delta: float) -> void:
	_parado_ha += delta
	if is_instance_valid(_anel):
		var pulso := 1.0 + 0.12 * sin(_parado_ha * 5.0)
		_anel.scale = Vector3(pulso, 1.0, pulso)
	if _parado_ha < ESPERA_PARA_RECOLHER:
		return
	# O corpo do jogador (cápsula de ~1,8 m): perto na horizontal e na altura do peito.
	var eu := jogador.global_position
	var delta_h := Vector2(eu.x - global_position.x, eu.z - global_position.z).length()
	var delta_v := global_position.y - eu.y
	if delta_h < ALCANCE_DE_RECOLHER and delta_v > -2.2 and delta_v < 2.2:
		recolhido.emit()


func esta_parado() -> bool:
	return estado == Estado.PARADO
