class_name BossProjectileSensor
extends Area3D
## Área de detecção ao redor do Boss: enxerga os ataques do JOGADOR em voo e diz
## quais vão acertá-lo e quando. Só observa; quem reage é o BossMobility.
##
## O que conta como projétil: qualquer `DamageZone` (Area3D, camada 1) lançada por
## um jogador que VOA (>= MIN_SPEED) — gelo, fogo, Bara, Gura, Goro, laser da Pika,
## braço da Gomu, meia-lua da espada. Golpe corpo a corpo e explosão parada têm
## `vel` zero e ficam de fora. A onda da Yoru não tem Area3D: ela entra pelo grupo
## GROUP_EXTRA e responde `velocidade_de_voo()` / `raio_de_voo()` / `lancado_por()`.
const RADIUS := 12.0
const MIN_SPEED := 8.0
## Só reage ao que chega dentro desta janela; mais cedo o jogador ainda corrige a mira.
const REACTION_WINDOW := 0.6
## Folga somada aos raios na distância de passagem.
const MARGIN := 0.25
const GROUP_EXTRA := "projetil_em_voo"

var actor: CharacterBody3D

func setup(owner_actor: CharacterBody3D) -> void:
	actor = owner_actor
	name = "ProjectileSensor"
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)

## A ameaça mais urgente, ou {} se nada vai acertar dentro da janela.
## Campos: node, time (s até a passagem mais próxima), miss (m), velocity, point
## (posição do projétil na passagem), height (altura do projétil acima dos pés).
func most_urgent() -> Dictionary:
	var best := {}
	for candidate in _candidates():
		var threat := evaluate(actor, candidate.position, candidate.velocity, candidate.radius)
		if threat.is_empty():
			continue
		threat.node = candidate.node
		if best.is_empty() or threat.time < best.time:
			best = threat
	return best

func _candidates() -> Array:
	var found: Array = []
	for area in get_overlapping_areas():
		var zone := area as DamageZone
		# Corpo a corpo que se desloca (a Aú nasce a 26 m/s) não é projétil: a
		# recepção de M1 do Boss cuida dele.
		if zone == null or zone.corpo_a_corpo or not _from_player(zone.caster):
			continue
		var radius := 0.5
		for child in zone.get_children():
			if child is CollisionShape3D and child.shape is SphereShape3D:
				radius = (child.shape as SphereShape3D).radius
		found.append({"node": zone, "position": zone.global_position, "velocity": zone.vel, "radius": radius})
	for node in actor.get_tree().get_nodes_in_group(GROUP_EXTRA):
		if not node is Node3D or not _from_player(node.call("lancado_por")):
			continue
		if (node as Node3D).global_position.distance_to(actor.global_position) > RADIUS:
			continue
		found.append({"node": node, "position": (node as Node3D).global_position,
			"velocity": node.call("velocidade_de_voo"), "radius": float(node.call("raio_de_voo"))})
	return found

static func _from_player(caster: Variant) -> bool:
	return caster is Node and is_instance_valid(caster) and (caster as Node).is_in_group("player")

## Passagem mais próxima entre a trajetória reta do projétil e o corpo do Boss
## (cápsula tratada como segmento vertical). Sem ameaça: {}.
static func evaluate(owner_actor: Node3D, position: Vector3, velocity: Vector3, radius: float) -> Dictionary:
	var speed_sq := velocity.length_squared()
	if speed_sq < MIN_SPEED * MIN_SPEED:
		return {}
	var center := owner_actor.global_position
	var time := (center - position).dot(velocity) / speed_sq
	if time <= 0.0 or time > REACTION_WINDOW:
		return {}
	var point := position + velocity * time
	var half_height: float = owner_actor.definition.height * 0.5
	var body_radius: float = owner_actor.definition.width * 0.5
	var along := clampf(point.y - center.y, -half_height + body_radius, half_height - body_radius)
	var miss := point.distance_to(center + Vector3.UP * along)
	if miss > body_radius + radius + MARGIN:
		return {}
	return {"time": time, "miss": miss, "velocity": velocity, "point": point, "radius": radius,
		"height": point.y - (center.y - half_height)}
