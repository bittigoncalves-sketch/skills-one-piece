class_name YoruWave
extends Node3D
## Frente finita de corte. Z voa; V exige piso em cada avanço de até 20 cm.
## A geometria local limita a apresentação em todos os peers; só o servidor
## pode aplicar dano. Não depende do relógio/controller após a liberação.

const MASK := 15
const MAX_RESULTS := 256
const GROUND_SAMPLE := 0.20
const MAX_STEP := 0.35
const FLOOR_CLEARANCE := 0.75
const HEIGHT := 0.8
const DEPTH := 0.20

var _owner: Node3D
var _direction := Vector3.FORWARD
var _data: Dictionary = {}
var _cast_id := 0
var _hit: Dictionary = {}
var _distance := 0.0
var _configured := false
var _ground := false
var _ground_initialized := false
var _floor_y := 0.0
var _width := 1.5
var _speed := 22.0
var _range := 16.0
var _age := 0.0
var _visual: Node3D
var _basis := Basis.IDENTITY


func setup(owner: Node3D, id: String, direction: Vector3, data: Dictionary) -> void:
	if _configured:
		return
	_owner = owner
	_data = data.duplicate(true)
	_direction = direction.slide(Vector3.UP).normalized()
	if _direction.length_squared() < 0.001:
		_direction = Vector3.FORWARD
	_ground = data.get("ground", id.to_lower() == "v")
	_width = maxf(0.1, float(data.get("width", 2.1 if _ground else 1.5)))
	_speed = maxf(0.1, float(data.get("speed", 14.0 if _ground else 22.0)))
	_range = maxf(0.1, float(data.get("range", 18.0 if _ground else 16.0)))
	_basis = Basis.looking_at(_direction, Vector3.UP)
	if _authority():
		_cast_id = CombatResolver.novo_cast()
	_configured = true
	_build_visual()
	# Área de detecção do Boss (BossProjectileSensor): a onda não tem Area3D.
	add_to_group("projetil_em_voo")


## Interface lida pelo BossProjectileSensor.
func velocidade_de_voo() -> Vector3:
	return _direction * _speed

func raio_de_voo() -> float:
	return _width * 0.5

func lancado_por() -> Node:
	return _owner


func _authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _exclude_owner() -> Array[RID]:
	var result: Array[RID] = []
	if is_instance_valid(_owner) and _owner is CollisionObject3D:
		result.append(_owner.get_rid())
	return result


func _physics_process(delta: float) -> void:
	if not _configured or is_queued_for_deletion():
		return
	_age += delta
	if _age > _range / _speed + 1.0:
		queue_free()
		return
	var space := get_world_3d().direct_space_state
	if _ground and not _ground_initialized:
		var floor_hit := _find_floor(space, global_position, true)
		if floor_hit.is_empty():
			queue_free()
			return
		_floor_y = float(floor_hit.y)
		global_position.y = _floor_y + FLOOR_CLEARANCE
		_ground_initialized = true
	var remaining := minf(_speed * delta, _range - _distance)
	while remaining > 0.00001:
		var travel := minf(remaining, GROUND_SAMPLE) if _ground else remaining
		var next := global_position + _direction * travel
		if _ground:
			var floor_hit := _find_floor(space, next, false)
			if floor_hit.is_empty():
				queue_free()
				return
			_floor_y = float(floor_hit.y)
			next.y = _floor_y + FLOOR_CLEARANCE
		if not _advance(space, next):
			queue_free()
			return
		_distance += travel
		remaining -= travel
	if _distance >= _range - 0.0001:
		queue_free()


func _find_floor(space: PhysicsDirectSpaceState3D, point: Vector3, initial: bool) -> Dictionary:
	var floor_height := point.y - FLOOR_CLEARANCE if initial else _floor_y
	var rise := 2.0 if initial else MAX_STEP + 0.05
	var fall := 4.0 if initial else MAX_STEP + 0.05
	var heights: Array[float] = []
	# A frente precisa de piso no centro e nos dois lados da faixa.
	for side in [0.0, -0.45, 0.45]:
		var offset: Vector3 = _basis.x * _width * float(side)
		var start := Vector3(point.x, floor_height + rise, point.z) + offset
		var end := Vector3(point.x, floor_height - fall, point.z) + offset
		var ray := PhysicsRayQueryParameters3D.create(start, end, MASK, _exclude_owner())
		var found := false
		for _i in MAX_RESULTS:
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				break
			if hit.collider.has_method("take_damage"):
				var skip := ray.exclude
				skip.append(hit.rid)
				ray.exclude = skip
				continue
			var normal: Vector3 = hit.normal
			var position: Vector3 = hit.position
			if normal.y < 0.7 or (not initial and absf(position.y - _floor_y) > MAX_STEP):
				return {}
			heights.append(position.y)
			found = true
			break
		if not found:
			return {}
	if heights.max() - heights.min() > MAX_STEP:
		return {}
	return {"y": heights.max()}


func _box_query(start: Vector3, finish: Vector3, exclude: Array[RID]) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	var delta := finish - start
	# Movimento horizontal tem volume exato; pequenos ajustes de altura no V
	# usam a caixa envolvente conservadora do trecho de 20 cm.
	shape.size = Vector3(_width, (1.4 if _ground else HEIGHT) + absf(delta.y), DEPTH + delta.slide(Vector3.UP).length())
	query.shape = shape
	query.transform = Transform3D(_basis, (start + finish) * 0.5)
	query.collision_mask = MASK
	query.exclude = exclude
	query.margin = 0.0
	return query


func _advance(space: PhysicsDirectSpaceState3D, next: Vector3) -> bool:
	var start := global_position
	var skip := _exclude_owner()
	var candidates := space.intersect_shape(_box_query(start, next, skip), MAX_RESULTS)
	var wall_skip: Array[RID] = skip.duplicate()
	for hit in candidates:
		if hit.collider.has_method("take_damage"):
			wall_skip.append(hit.rid)
	var wall_query := _box_query(start, start, wall_skip)
	# cast_motion não detecta uma parede que já envolve a origem.
	if not space.intersect_shape(wall_query, MAX_RESULTS).is_empty():
		return false
	wall_query.motion = next - start
	var fractions := space.cast_motion(wall_query)
	var blocked := fractions.size() == 2 and fractions[0] < 1.0
	if blocked:
		next = start.lerp(next, maxf(0.0, fractions[0] - 0.001))
		candidates = space.intersect_shape(_box_query(start, next, skip), MAX_RESULTS)
	if _authority():
		for hit in candidates:
			var body := hit.collider as Node3D
			if not is_instance_valid(body) or not body.has_method("take_damage") or body == _owner:
				continue
			var key := body.get_instance_id()
			if _hit.has(key):
				continue
			_hit[key] = true
			var damage := float(_data.get("damage", 180.0 if _ground else 110.0))
			var kb := float(_data.get("kb", 18.0))
			var stun := float(_data.get("hitstun", 0.35))
			var point := Geometry3D.get_closest_point_to_segment(body.global_position, start, next)
			CombatResolver.aplicar(body, damage, _cast_id, damage, point, _direction * kb, stun)
			var board := get_tree().get_first_node_in_group("scoreboard")
			if board and board.has_method("register_hit") and is_instance_valid(_owner):
				board.register_hit(body, _owner)
	global_position = next
	return not blocked


func _exit_tree() -> void:
	if _cast_id != 0:
		CombatResolver.encerrar(_cast_id)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.basis = _basis
	add_child(_visual)
	# Duas fitas sólidas curvadas: núcleo quase preto e fio verde. Sem assets
	# externos, luz pontual ou transparência que lavaria a silhueta.
	for layer in 2:
		var mesh := ImmediateMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# ⚠️ A FRENTE ERA VERDE SATURADO (0,18/1,5/0,52 — saturação 0,88). A
		# referência de 09/09/2026 mede a onda quase BRANCA, com saturação 0,06.
		# Mantida a energia acima de 1,0 para o brilho continuar estourando no
		# bloom; o que muda é a SATURAÇÃO, não o brilho. Ver o bloco do rastro em
		# `YoruController` — é a mesma correção, na mesma referência.
		# Cores opcionais por dado (o corte do Boss usa as dele); padrão = Yoru.
		material.albedo_color = _data.get("core_color", Color(0.015, 0.035, 0.025)) if layer == 0 else _data.get("edge_color", Color(1.38, 1.50, 1.43))
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
		var thickness := 0.18 if layer == 0 else 0.055
		var layer_offset := -0.015 * layer
		for i in 24:
			var x0 := lerpf(-_width * 0.5, _width * 0.5, float(i) / 24.0)
			var x1 := lerpf(-_width * 0.5, _width * 0.5, float(i + 1) / 24.0)
			var y0 := 0.38 * (1.0 - pow(x0 / (_width * 0.5), 2.0))
			var y1 := 0.38 * (1.0 - pow(x1 / (_width * 0.5), 2.0))
			if _ground:
				y0 = 1.4 * (1.0 - absf(x0 / (_width * 0.5))) - 0.65
				y1 = 1.4 * (1.0 - absf(x1 / (_width * 0.5))) - 0.65
			var a := Vector3(x0, y0, layer_offset)
			var b := Vector3(x1, y1, layer_offset)
			var c := Vector3(x1, y1 - thickness, layer_offset)
			var d := Vector3(x0, y0 - thickness, layer_offset)
			for vertex in [a, b, c, a, c, d]:
				mesh.surface_add_vertex(vertex)
		mesh.surface_end()
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(instance)
