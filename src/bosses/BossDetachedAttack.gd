class_name BossDetachedAttack
extends RefCounted
## Estado da parte separado do estado do golpe: interrupção recolhe sem dano;
## morte/despawn recolocam a mão e encerram o orçamento imediatamente.
const Sweep = preload("res://src/combat/SwordSweep.gd")
var actor: Node3D
var cooldown := 0.0
var _data: BossDetachedAbility
var _zone: DamageZone
var _spec: DamageSpec
var _origin := Vector3.ZERO
var _end := Vector3.ZERO
var _elapsed := 0.0
var _delay := 0.0

func available() -> bool:
	return cooldown <= 0 and actor.part_state == "attached" and actor.presentation.hand_binding.valid

static func path(owner_actor: Node3D, data: BossDetachedAbility) -> Array[Vector3]:
	var start: Vector3 = owner_actor.presentation.hand_position("R")
	var finish := start - owner_actor.global_basis.z.normalized() * data.distance
	return [start, stop_at_wall(owner_actor, start, finish, data.hit_radius)]

static func stop_at_wall(owner_actor: Node3D, start: Vector3, finish: Vector3, radius: float) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = start
	query.motion = finish - start
	query.collision_mask = 15
	var skip: Array[RID] = [owner_actor.get_rid()]
	for body in owner_actor.get_tree().get_nodes_in_group("player") + owner_actor.get_tree().get_nodes_in_group("enemy"):
		if body is CollisionObject3D and not skip.has(body.get_rid()):
			skip.append(body.get_rid())
	query.exclude = skip
	var space := owner_actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return start
	var fractions := space.cast_motion(query)
	if fractions.size() == 2:
		finish = start.lerp(finish, fractions[0])
	return finish

func launch(data: BossDetachedAbility, delay: float) -> void:
	if not actor.authoritative() or not available():
		return
	_data = data
	actor.presentation.pose_at(data.windup + data.active * 0.6)
	actor.part_transform = actor.presentation.hand_binding.wrist_transform()
	var trajectory := path(actor, data)
	_origin = trajectory[0]
	_end = trajectory[1]
	actor.part_transform.origin = _origin
	actor.part_state = "outbound"
	_elapsed = 0
	_delay = delay
	cooldown = data.reuse_delay
	_spec = DamageSpec.criar(DamageSpec.Tipo.UNICO, data.damage, data.damage).para_cast()
	_zone = DamageZone.new()
	_zone.name = "DetachedHandHitbox"
	actor.combat.add_child(_zone)
	_zone.setup(data.damage, data.knockback, Vector3.ZERO, data.duration() + 1, actor, data.hit_radius, null, data.hitstun)
	_zone.monitoring = false
	_zone.override_kb_dir = -actor.global_basis.z
	_zone.exige_linha_de_visao = true
	_zone.origem_linha_de_visao = _origin
	_spec.marcar(_zone)

func tick(delta: float) -> void:
	if not actor.authoritative():
		return
	cooldown = maxf(0, cooldown - delta)
	if actor.part_state == "attached":
		return
	var consumed := minf(_delay, delta)
	_delay -= consumed
	delta -= consumed
	_elapsed += delta
	if actor.part_state == "returning":
		var wrist: Transform3D = actor.presentation.hand_binding.wrist_transform()
		actor.part_transform.origin = _origin.lerp(wrist.origin, clampf(_elapsed / _data.return_time, 0, 1))
		var rotation: Basis = actor.part_transform.basis.orthonormalized().slerp(wrist.basis.orthonormalized(), minf(1, delta * 16))
		actor.part_transform.basis = rotation.scaled(wrist.basis.get_scale())
		if _elapsed >= _data.return_time:
			reset()
		return
	var before: Vector3 = actor.part_transform.origin
	var after := _origin.lerp(_end, clampf(_elapsed / _data.active, 0, 1))
	# Recalcula obstáculos durante o voo: uma parede nova também bloqueia.
	var stopped := stop_at_wall(actor, before, after, _data.hit_radius)
	var blocked := stopped.distance_squared_to(after) > 0.000001
	after = stopped
	# Sweep.contacts resolve o volume e a oclusão do acerto.
	_zone.global_position = after
	for contact in Sweep.contacts(actor.get_world_3d().direct_space_state, before, after, _data.hit_radius, 15, [actor.get_rid()]):
		if contact.body.is_in_group("player"):
			_zone._on_body(contact.body)
			actor.combat.launch_if_hit(contact.body, _data, _zone)
			if actor.part_state != "outbound":
				return
			actor.part_transform.origin = contact.position
			return_now()
			return
	actor.part_transform.origin = after
	if blocked or _elapsed >= _data.active:
		return_now()

func return_now() -> void:
	_release()
	if actor.part_state != "outbound":
		return
	_origin = actor.part_transform.origin
	_elapsed = 0
	_delay = 0
	actor.part_state = "returning"

func reset() -> void:
	_release()
	actor.part_state = "attached"
	_elapsed = 0
	_delay = 0

func _release() -> void:
	if _spec:
		CombatResolver.encerrar(_spec.cast_id)
		_spec = null
	if is_instance_valid(_zone):
		_zone.queue_free()
	_zone = null
