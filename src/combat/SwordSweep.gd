extends RefCounted
## Varredura linear de cada esfera entre dois ticks. A cápsula cobre a translação
## completa; a curvatura entre amostras de animação continua uma aproximação.

const MAX_RESULTS := 256

static func query_segment(space: PhysicsDirectSpaceState3D, start: Vector3,
		finish: Vector3, radius: float, mask: int, exclude: Array[RID]) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	var length := start.distance_to(finish)
	if length < 0.0001:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, start)
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = length + 2.0 * radius
		query.shape = capsule
		var direction := (finish - start) / length
		var axis := Vector3.RIGHT if absf(direction.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x := direction.cross(axis).normalized()
		query.transform = Transform3D(Basis(x, direction, x.cross(direction)), (start + finish) * 0.5)
	query.collision_mask = mask
	query.exclude = exclude
	query.collide_with_areas = false
	query.margin = 0.0
	return space.intersect_shape(query, MAX_RESULTS)


static func contacts(space: PhysicsDirectSpaceState3D, start: Vector3,
		finish: Vector3, radius: float, mask: int, exclude: Array[RID]) -> Array[Dictionary]:
	var candidates := query_segment(space, start, finish, radius, mask, exclude)
	var walls_exclude: Array[RID] = exclude.duplicate()
	for hit in candidates:
		# Hurtbox de combate (Modo História) conta como corpo: não é parede.
		if hit.collider.has_method("take_damage") or HurtboxDeCombate.e_hurtbox(hit.collider):
			walls_exclude.append(hit.rid)
	# A lâmina não atravessa um obstáculo entre as amostras. cast_motion ignora
	# overlap inicial, por isso este caso é consultado explicitamente primeiro.
	var wall_start := query_segment(space, start, start, radius, mask, walls_exclude)
	if not wall_start.is_empty():
		return []
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = finish - start
	query.collision_mask = mask
	query.exclude = walls_exclude
	query.margin = 0.0
	var fraction := space.cast_motion(query)
	var end := finish
	if fraction.size() == 2 and fraction[0] < 1.0:
		end = start.lerp(finish, maxf(0.0, fraction[0] - 0.001))
		candidates = query_segment(space, start, end, radius, mask, exclude)
	var result: Array[Dictionary] = []
	for hit in candidates:
		# A hurtbox vira o DONO dela; a mesma vítima pela cápsula e pela hurtbox é
		# deduplicada por quem chama (`_ja_acertados` do executor).
		var body: Node3D = HurtboxDeCombate.dono_de(hit.collider) as Node3D
		if body == null or not body.has_method("take_damage"):
			continue
		var position := Geometry3D.get_closest_point_to_segment(body.global_position, start, end)
		result.append({"body": body, "position": position})
	return result


static func visible(space: PhysicsDirectSpaceState3D, start: Vector3,
		finish: Vector3, mask: int, exclude: Array[RID]) -> bool:
	if start.distance_squared_to(finish) < 0.000001:
		return true
	var query := PhysicsRayQueryParameters3D.create(start, finish, mask, exclude)
	query.hit_from_inside = true
	# Personagens não fazem papel de parede. O limite impede laço patológico.
	for _i in MAX_RESULTS:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		if not hit.collider.has_method("take_damage") and not HurtboxDeCombate.e_hurtbox(hit.collider):
			return false
		var skip := query.exclude
		skip.append(hit.rid)
		query.exclude = skip
	return false


static func sphere_clash(a0: Vector3, a1: Vector3, b0: Vector3,
		b1: Vector3, radius_sum: float) -> Dictionary:
	var relative := a0 - b0
	var motion := (a1 - a0) - (b1 - b0)
	var time := 0.0
	if motion.length_squared() > 0.000001:
		time = clampf(-relative.dot(motion) / motion.length_squared(), 0.0, 1.0)
	if (relative + motion * time).length_squared() > radius_sum * radius_sum:
		return {}
	return {"position": (a0.lerp(a1, time) + b0.lerp(b1, time)) * 0.5}
