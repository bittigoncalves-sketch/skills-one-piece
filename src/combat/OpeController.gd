extends Node3D
## Cirurgia espacial. A esfera é estado persistente; os demais nós são casts
## com startup/recuperação próprios. Dano e deslocamentos só resolvem no servidor.

const VFX := preload("res://src/effects/OpeVfx.gd")
const ZONE := preload("res://src/combat/OpeDamageZone.gd")
const ROOM_RADIUS := 18.0
const ROOM_DURATION := 18.0
const ROOM_EXPANSION := 0.65
const DURATIONS := {"Z": 0.85, "X": 0.65, "C": 1.65, "V": 0.95}
const POSES := {"Z": "ope_room", "X": "ope_shambles", "C": "ope_takt", "V": "ope_gamma"}

var owner_actor: Node3D
var center := Vector3.ZERO
var radius := ROOM_RADIUS
var remaining := ROOM_DURATION
var elapsed := 0.0
var slot := "Z"
var cast_token := 0
var aim := Vector3.FORWARD
var origin := Vector3.ZERO
var target_point := Vector3.ZERO
var target_actor: Node3D
var damage_spec: DamageSpec
var room: Node3D
var _presentation: Node3D
var _resolved := false
var _pose_finished := false
var _launched := 0
var _cancelled := false


static func room_for(actor: Node) -> Node3D:
	if not is_instance_valid(actor):
		return null
	var value = actor.get_meta("ope_room", null)
	if is_instance_valid(value) and value is Node3D and not value.is_queued_for_deletion():
		return value
	return null


static func actor_available(actor: Node3D) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return false
	if str(actor.get("current_fruit_id")) != "ope_ope" or str(actor.get("combat_mode")) != "fruit":
		return false
	if float(actor.get("health")) <= 0.0 or actor.get("is_suppressed") == true:
		return false
	if actor.get_meta("is_frozen", false) or actor.get_meta("in_black_hole", false):
		return false
	return true


static func validation_reason(actor: Node3D, wanted_slot: String, direction: Vector3) -> String:
	if not actor_available(actor):
		return "Poder indisponível."
	if not wanted_slot in DURATIONS:
		return "Técnica desconhecida."
	if not direction.is_finite() or direction.length_squared() < 0.001:
		return "Mira inválida."
	if actor.has_method("fruta_bloqueada_por_dano") and actor.fruta_bloqueada_por_dano():
		return "Recupere-se do impacto."
	if actor.get_meta("ope_action", null) != null:
		return "Conclua a técnica atual."
	if wanted_slot == "Z":
		return ""
	var active_room := room_for(actor)
	if active_room == null:
		return "Crie uma ROOM com Z."
	if not active_room.ready_for_skills():
		return "A ROOM está expandindo."
	if not active_room.contains_point(actor.global_position):
		return "Entre na sua ROOM."
	if wanted_slot == "X" and shambles_destination(actor, direction).is_empty():
		return "Mire um alvo ou chão livre dentro da ROOM."
	if wanted_slot == "C" and pick_target(actor, direction, 36.0) == null:
		return "Mire um inimigo dentro da ROOM."
	if wanted_slot == "V":
		var end := actor.global_position + direction.normalized() * 3.0
		if not active_room.contains_point(end):
			return "Direcione Gamma Knife para dentro da ROOM."
	return ""


static func can_cast(actor: Node3D, wanted_slot: String, direction: Vector3) -> bool:
	return validation_reason(actor, wanted_slot, direction) == ""


static func feedback(actor: Node, reason: String) -> void:
	if is_instance_valid(actor):
		actor.set_meta("ope_feedback", reason)
		actor.set_meta("ope_feedback_until", Time.get_ticks_msec() + 2200)


static func cast(parent: Node, wanted_slot: String, direction: Vector3,
		cast_origin: Vector3, actor: Node3D, spec: DamageSpec, token: int) -> Node3D:
	var effect: Node3D = load("res://src/combat/OpeController.gd").new()
	effect.name = "Ope_" + wanted_slot
	effect.owner_actor = actor
	effect.slot = wanted_slot
	effect.aim = direction.normalized()
	effect.origin = cast_origin
	effect.center = cast_origin - Vector3.UP
	effect.damage_spec = spec
	effect.cast_token = token
	parent.add_child(effect)
	return effect


func _ready() -> void:
	add_to_group("ope_effect")
	if not is_instance_valid(owner_actor):
		queue_free()
		return
	owner_actor.set_meta("ope_action", self)
	owner_actor.set_meta("ope_cast_token", cast_token)
	owner_actor.set_meta("ope_pending_until", 0)
	owner_actor.set_meta("is_casting", true)
	owner_actor.set_meta("active_skill", slot)
	owner_actor.set_meta("custom_pose", POSES[slot])
	owner_actor.set_meta("ope_pose_t", 0.0)
	owner_actor.set_meta("ope_feedback", "")
	if owner_actor.has_method("pausar_animacao"):
		owner_actor.pausar_animacao(false)
	if slot == "Z":
		var previous := room_for(owner_actor)
		if previous != null:
			previous.cancel()
		owner_actor.set_meta("ope_room", self)
		_presentation = VFX.room(self, center, radius, ROOM_DURATION)
		return
	room = room_for(owner_actor)
	if room == null:
		cancel()
		return
	if slot == "C":
		target_actor = pick_target(owner_actor, aim, 36.0)
		target_point = target_actor.global_position if is_instance_valid(target_actor) else origin + aim * 10.0
		center = owner_actor.global_position
		_presentation = VFX.takt(self, center, target_point)
	elif slot == "V":
		# A pose é vulnerável por .35s antes do avanço e da agulha.
		_presentation = VFX.gamma(self, owner_actor.global_position + Vector3.UP * 0.35, aim, 8.0)


func contains_point(point: Vector3, margin: float = 0.0) -> bool:
	return not _cancelled and remaining > 0.0 and center.distance_to(point) <= radius - margin


func ready_for_skills() -> bool:
	return slot == "Z" and not _cancelled and elapsed >= ROOM_EXPANSION and remaining > 0.0


func _physics_process(delta: float) -> void:
	if not actor_available(owner_actor):
		cancel()
		return
	elapsed += delta
	if slot == "Z":
		remaining = maxf(ROOM_DURATION - elapsed, 0.0)
		if not _pose_finished and not _owns_pose():
			cancel()
			return
		_tick_pose()
		if remaining <= 0.0:
			cancel()
		return
	if not is_instance_valid(room) or room.is_queued_for_deletion() \
			or not room.contains_point(owner_actor.global_position):
		cancel()
		return
	if not _pose_finished and not _owns_pose():
		cancel()
		return
	_tick_pose()
	if slot == "X" and not _resolved and elapsed >= 0.30:
		_resolved = true
		if _server():
			_resolve_shambles()
	elif slot == "C":
		while _launched < 5 and elapsed >= 0.65 + float(_launched) * 0.12:
			_launch_rock(_launched)
			_launched += 1
	elif slot == "V" and not _resolved and elapsed >= 0.35:
		_resolved = true
		if _server():
			_resolve_gamma()
	# Takt conserva sus proyectiles hasta el último impacto. Cada zona mantiene
	# la dependencia de ROOM y se cancela en cuanto desaparezca.
	var lifespan := 3.5 if slot == "C" else float(DURATIONS[slot]) + 0.5
	if elapsed >= lifespan:
		queue_free()


func _owns_pose() -> bool:
	return owner_actor.get_meta("ope_action", null) == self \
		and owner_actor.get_meta("is_casting", false) == true


func _tick_pose() -> void:
	if _pose_finished:
		return
	owner_actor.set_meta("ope_pose_t", elapsed)
	if elapsed >= float(DURATIONS[slot]):
		_finish_pose()


func _finish_pose() -> void:
	_pose_finished = true
	if not is_instance_valid(owner_actor) or owner_actor.get_meta("ope_action", null) != self:
		return
	owner_actor.remove_meta("ope_action")
	owner_actor.set_meta("is_casting", false)
	owner_actor.set_meta("active_skill", "")
	if str(owner_actor.get_meta("custom_pose", "")) == str(POSES[slot]):
		owner_actor.remove_meta("custom_pose")
	owner_actor.set_meta("ope_pose_t", 0.0)


func cancel() -> void:
	if _cancelled:
		return
	_cancelled = true
	_finish_pose()
	if is_instance_valid(owner_actor) and owner_actor.get_meta("ope_room", null) == self:
		owner_actor.remove_meta("ope_room")
	queue_free()


func _exit_tree() -> void:
	_finish_pose()
	if is_instance_valid(owner_actor) and owner_actor.get_meta("ope_room", null) == self:
		owner_actor.remove_meta("ope_room")
	if damage_spec != null:
		CombatResolver.encerrar(damage_spec.cast_id)


func _server() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _resolve_shambles() -> void:
	var result := shambles_destination(owner_actor, aim)
	if result.is_empty():
		feedback(owner_actor, "Destino obstruído: Shambles interrompido.")
		return
	var victim: Node3D = result.get("target")
	var victim_path := victim.get_path() if is_instance_valid(victim) else NodePath("")
	owner_actor.ope_relocate(owner_actor.global_position, result["destination"],
		victim_path, result.get("target_destination", Vector3.ZERO), true)


func _launch_rock(index: int) -> void:
	if not _server():
		return
	var start: Vector3 = VFX.takt_start(center, index)
	if not room.contains_point(start):
		return
	var trajectory := target_point - start
	var zone := ZONE.new()
	zone.name = "OpeTaktRock_%d" % index
	zone.room_ref = weakref(room)
	zone.stop_on_collision = true
	add_child(zone)
	zone.global_position = start
	zone.setup(damage_spec.dano, 7.0, trajectory.normalized() * 30.0,
		trajectory.length() / 30.0 + 0.12, owner_actor, 0.7, null, 0.18)
	damage_spec.marcar(zone)


func _resolve_gamma() -> void:
	var horizontal := Vector3(aim.x, 0.0, aim.z).normalized()
	if horizontal.length_squared() < 0.001:
		horizontal = Vector3.FORWARD
	var from := owner_actor.global_position
	var victim := pick_target(owner_actor, aim, 9.0)
	var distance := 5.8
	if is_instance_valid(victim):
		horizontal = (victim.global_position - from).normalized()
		horizontal.y = 0.0
		horizontal = horizontal.normalized()
		distance = clampf(from.distance_to(victim.global_position) - 1.5, 0.0, 5.8)
	var desired := from + horizontal * distance
	var floor_result := ground_position(owner_actor, desired, [])
	if not floor_result.is_empty() and room.contains_point(floor_result["position"], 0.8):
		var to: Vector3 = floor_result["position"]
		var body_query := _body_query(owner_actor, from, [])
		body_query.motion = to - from
		if is_instance_valid(victim) and victim is CollisionObject3D:
			body_query.exclude.append(victim.get_rid())
		var sweep := get_world_3d().direct_space_state.cast_motion(body_query)
		if sweep.size() == 2 and sweep[0] > 0.95:
			owner_actor.ope_relocate(from, to, NodePath(""), Vector3.ZERO, false)
	# Alcance curto: elipsoide frente à mão, com linha de visão para cobertura.
	var zone := ZONE.new()
	zone.name = "OpeGammaKnife"
	zone.room_ref = weakref(room)
	zone.exige_linha_de_visao = true
	zone.origem_linha_de_visao = owner_actor.global_position
	add_child(zone)
	zone.global_position = owner_actor.global_position + horizontal * 1.8
	zone.setup(damage_spec.dano, 10.0, Vector3.ZERO, 0.20, owner_actor, 2.0, null, 0.55)
	damage_spec.marcar(zone)


static func pick_target(actor: Node3D, direction: Vector3, maximum: float) -> Node3D:
	var active_room := room_for(actor)
	if active_room == null:
		return null
	var best: Node3D
	var best_score := -INF
	var forward := direction.normalized()
	var candidates := actor.get_tree().get_nodes_in_group("player") + actor.get_tree().get_nodes_in_group("enemy")
	for candidate in candidates:
		if candidate == actor or not candidate is Node3D or not candidate.has_method("take_damage"):
			continue
		if not active_room.contains_point(candidate.global_position, 0.5):
			continue
		var offset: Vector3 = candidate.global_position - actor.global_position
		var distance := offset.length()
		if distance < 0.1 or distance > maximum:
			continue
		var alignment := forward.dot(offset.normalized())
		if alignment < 0.90:
			continue
		if not line_clear(actor, actor.global_position, candidate.global_position, [candidate]):
			continue
		var score := alignment * 40.0 - distance * 0.15
		if score > best_score:
			best_score = score
			best = candidate
	return best


static func shambles_destination(actor: Node3D, direction: Vector3) -> Dictionary:
	var active_room := room_for(actor)
	if active_room == null:
		return {}
	var target := pick_target(actor, direction, 36.0)
	if is_instance_valid(target):
		var at_target := ground_position(actor, target.global_position, [target])
		var at_owner := ground_position(target, actor.global_position, [actor])
		if not at_target.is_empty() and not at_owner.is_empty() \
				and active_room.contains_point(at_target["position"], 0.8) \
				and active_room.contains_point(at_owner["position"], 0.8):
			return {"target": target, "destination": at_target["position"],
				"target_destination": at_owner["position"]}
		return {}
	var start := actor.global_position + Vector3.UP * 0.3
	var endpoint := start + direction.normalized() * 20.0
	var query := PhysicsRayQueryParameters3D.create(start, endpoint, 15, _excluded(actor, []))
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit["position"] + hit["normal"] * 0.9
	# Clamp to sphere boundary, then require an actual free floor below it.
	var offset: Vector3 = endpoint - active_room.center
	if offset.length() > active_room.radius - 1.2:
		endpoint = active_room.center + offset.normalized() * (active_room.radius - 1.2)
	var result := ground_position(actor, endpoint, [])
	if result.is_empty() or not active_room.contains_point(result["position"], 0.8):
		return {}
	if actor.global_position.distance_to(result["position"]) < 1.5:
		return {}
	if not line_clear(actor, start, result["position"], []):
		return {}
	return {"destination": result["position"]}


static func _excluded(actor: Node3D, extra: Array) -> Array[RID]:
	var excluded: Array[RID] = []
	if actor is CollisionObject3D:
		excluded.append(actor.get_rid())
	for item in extra:
		if is_instance_valid(item) and item is CollisionObject3D:
			excluded.append(item.get_rid())
	return excluded


static func line_clear(actor: Node3D, start: Vector3, endpoint: Vector3, extra: Array) -> bool:
	var query := PhysicsRayQueryParameters3D.create(start, endpoint, 15, _excluded(actor, extra))
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _body_query(actor: Node3D, at: Vector3, extra: Array) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	var col: CollisionShape3D
	for child in actor.get_children():
		if child is CollisionShape3D and child.shape != null:
			col = child
			break
	if col != null:
		query.shape = col.shape
		query.transform = Transform3D(actor.global_basis, at) * col.transform
	else:
		var shape := CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 1.6
		query.shape = shape
		query.transform.origin = at
	query.collision_mask = 15
	query.exclude = _excluded(actor, extra)
	query.margin = 0.025
	return query


static func ground_position(actor: Node3D, desired: Vector3, extra: Array) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(desired + Vector3.UP * 5.0,
		desired + Vector3.DOWN * 10.0, 15, _excluded(actor, extra))
	var space := actor.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return {}
	if (hit["collider"] as Node).has_method("take_damage"):
		return {}
	var half_height := 0.8
	for child in actor.get_children():
		if child is CollisionShape3D and child.shape != null:
			var bounds: AABB = child.shape.get_debug_mesh().get_aabb()
			half_height = maxf(0.3, -bounds.position.y * child.global_basis.get_scale().y - child.position.y)
			break
	var candidate: Vector3 = hit["position"] + Vector3.UP * (half_height + 0.075)
	var body_query := _body_query(actor, candidate, extra)
	if not space.intersect_shape(body_query, 1).is_empty():
		return {}
	return {"position": candidate}
