extends Node3D
## A bola em voo (CapturaDeInimigos.arremessar): varre o trecho do quadro contra o mundo e contra os corpos capturáveis.
## Acertou um corpo → `captura.acertou(alvo)` (captura ou mensagem) e some; acertou o cenário ou ficou longe → quica e some.
## AbstractArrow.tick: por tick de 0,05 s, atrito 0,99 e gravidade 0,05 blocos/tick² (= 17,6 m/s² com o bloco de 0,88 m).
const TICK := 0.05
const ATRITO_POR_TICK := 0.99
const GRAVIDADE := 0.05 * 0.88 / (0.05 * 0.05)
const RAIO_MINIMO := 0.7
const VIDA := 5.0

var captura: Node
var dono: Node3D
var velocidade := Vector3.ZERO
## Potência 1,0 do arco: o "crítico" (rastro de faíscas, como a flecha crítica).
var critica := false
var _restante := VIDA
var _rastro := 0.0
var _visual: MeshInstance3D


func _ready() -> void:
	name = "PokebolaArremessada"
	_visual = MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE * 0.2
	_visual.mesh = caixa
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.3, 0.25)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.3, 0.25)
	material.emission_energy_multiplier = 0.4
	_visual.material_override = material
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)


## O primeiro obstáculo de CENÁRIO entre os pontos. Corpo que leva dano (jogador, inimigo, bicho) não conta aqui: quem
## decide o acerto neles é a varredura por alvo logo abaixo.
func _cenario(de: Vector3, para: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(de, para, 1)
	var excluir: Array[RID] = []
	if dono is CollisionObject3D:
		excluir.append((dono as CollisionObject3D).get_rid())
	for _i in 6:
		consulta.exclude = excluir
		var hit := get_world_3d().direct_space_state.intersect_ray(consulta)
		if hit.is_empty() or not (hit.collider is Node and (hit.collider as Node).has_method("take_damage")):
			return hit
		excluir.append((hit.collider as CollisionObject3D).get_rid())
	return {}


func _physics_process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0:
		queue_free()
		return
	velocidade *= pow(ATRITO_POR_TICK, delta / TICK)
	velocidade.y -= GRAVIDADE * delta
	var de := global_position
	var para := de + velocidade * delta
	var parede := _cenario(de, para)
	var fim: Vector3 = parede.position if not parede.is_empty() else para
	var melhor: Node3D = null
	var melhor_t := INF
	for alvo in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("animais") + get_tree().get_nodes_in_group("bestas_do_mar"):
		if alvo == dono or not CapturaDeInimigos.e_alvo(alvo):
			continue
		var centro := AlvosDeGolpe.centro(alvo as Node3D)
		var altura := float(alvo.call("altura")) if alvo.has_method("altura") else 1.8
		var ponto := Geometry3D.get_closest_point_to_segment(centro, de, fim)
		if centro.distance_to(ponto) <= maxf(RAIO_MINIMO, altura * 0.5):
			var t := de.distance_to(ponto)
			if t < melhor_t:
				melhor_t = t
				melhor = alvo
	if melhor != null:
		global_position = fim
		McVisual.som(get_tree(), "entity.arrow.hit", McVec3.de_godot(fim), 1.0, 1.0)
		if captura != null and is_instance_valid(captura):
			captura.acertou(melhor)
		queue_free()
		return
	global_position = fim
	_visual.rotate_y(delta * 9.0)
	_visual.rotate_x(delta * 6.0)
	if critica:
		_rastro -= delta
		if _rastro <= 0.0:
			_rastro = TICK
			McVisual.particula(get_tree(), "minecraft:crit", McVec3.de_godot(global_position), 2, 0.05, 0.05, 0.05, 0.1)
	if not parede.is_empty():
		queue_free()      # quicou no cenário
