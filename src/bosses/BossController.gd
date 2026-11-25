class_name BossController
extends RefCounted
var stun_remaining := 0.0
var brain := BossBrain.new()
var reaction := BossHitReaction.new()
var mobility := BossMobility.new()

func controlled(actor: Node) -> bool:
	return stun_remaining > 0 or actor.get_meta("is_frozen", false) or actor.get_meta("in_vortex", false) or actor.get_meta("in_kurouzu", false) or actor.get_meta("in_black_hole", false) or actor.get_meta("custom_pose", "") == "knockdown"

func tick(actor: CharacterBody3D, delta: float) -> void:
	stun_remaining = maxf(0, stun_remaining - delta)
	RecepcaoDeDano.tick(actor, delta)
	brain.tick(actor, delta)
	if not actor.is_on_floor():
		actor.velocity.y -= actor.definition.gravity * delta
	var free: bool = actor.reaction == "" and not controlled(actor) and not actor.combat.busy()
	var moving := mobility.tick(actor, delta, actor.sensor, free)
	if actor.reaction != "" or controlled(actor):
		mobility.cancel(actor)
		moving = false
	if reaction.tick(actor, delta):
		pass
	elif controlled(actor):
		actor.combat.cancel("control")
		actor.state = "stunned"
		actor.velocity.x = move_toward(actor.velocity.x, 0, 9 * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0, 9 * delta)
	elif moving:
		pass
	elif actor.combat.busy():
		var step: Vector3 = actor.combat.step_velocity(delta)
		actor.velocity.x = step.x
		actor.velocity.z = step.z
	else:
		_decide(actor, delta)
	actor.move_and_slide()
	mobility.after_move(actor)
	if actor.global_position.y < -35:
		# Perda por queda conclui o ator uma vez; não usa o reset do Dummy.
		actor.set_meta(VidaEmBarras.META_MORTE_ABSOLUTA, true)   # queda no vazio ignora as 10 barras
		actor.take_damage(actor.health)

func _decide(actor: CharacterBody3D, delta: float) -> void:
	var destination: Vector3 = actor.home_position
	var target := brain.target
	if is_instance_valid(target):
		destination = target.global_position
	var offset := destination - actor.global_position
	offset.y = 0
	var distance := offset.length()
	# Pulo: alvo no alto ou buraco no caminho (BossMobility decide se cabe).
	if is_instance_valid(target) and (mobility.try_high_ground(actor, target) or mobility.try_cross_gap(actor, target)):
		return
	var slash: BossSlashAbility = actor.definition.slash
	if slash and is_instance_valid(target) and brain.flee_rate >= slash.flee_speed \
			and distance >= slash.min_distance and distance <= slash.slash_range and BossBrain.visible(actor, target):
		# Alvo fugindo além do alcance dos punhos: para e lança o corte.
		actor.velocity.x = 0
		actor.velocity.z = 0
		if actor.combat.begin_slash(target):
			return
	# Encostado conta como alcance: colado no alvo, o desvio local bloqueia toda
	# direção e, acima de `attack_distance` por poucos cm, o Boss ficava parado sem
	# atacar (medido: 1,29 m entre centros, jogador de frente).
	# Alvo muito acima (em cima de bloco que o pulo não alcança) não é alcance de soco.
	var level: bool = absf(BossMobility.ground_below(actor, target) - BossMobility.floor_height(actor)) < BossMobility.HIGH_GROUND if is_instance_valid(target) else false
	if is_instance_valid(target) and level and actor.is_on_floor() and (distance <= actor.definition.attack_distance or touching(actor, target)) and BossBrain.visible(actor, target):
		actor.velocity.x = 0
		actor.velocity.z = 0
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-offset.x, -offset.z), minf(1, 8 * delta))
		actor.state = "guard"
		actor.combat.begin(target)
		return
	if distance < 0.25:
		actor.state = "idle"
		actor.velocity.x = 0
		actor.velocity.z = 0
		return
	actor.state = "chase" if is_instance_valid(target) else "return"
	var direction := safe_direction(actor, offset.normalized(), delta)
	actor.velocity.x = direction.x * actor.definition.speed
	actor.velocity.z = direction.z * actor.definition.speed
	if direction.length_squared() > 0:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-direction.x, -direction.z), minf(1, 7 * delta))

static func touching(actor: CharacterBody3D, target: Node3D) -> bool:
	var toward := target.global_position - actor.global_position
	toward.y = 0
	if toward.length_squared() < 0.0001:
		return true
	var collision := KinematicCollision3D.new()
	return actor.test_move(actor.global_transform, toward.normalized() * 0.3, collision) and collision.get_collider() == target

func safe_direction(actor: CharacterBody3D, wanted: Vector3, delta: float) -> Vector3:
	# Desvio local conservador. Não promete navegação global em labirintos.
	for angle in [0.0, 0.7, -0.7, 1.3, -1.3]:
		var direction := wanted.rotated(Vector3.UP, angle)
		var point := actor.global_position + direction * maxf(0.8, actor.definition.speed * delta)
		if MapBuilder.is_hole_area(point.x, point.z, actor.definition.width, actor.definition.width):
			continue
		if not actor.test_move(actor.global_transform, direction * maxf(0.15, actor.definition.speed * delta)):
			return direction
	return Vector3.ZERO
