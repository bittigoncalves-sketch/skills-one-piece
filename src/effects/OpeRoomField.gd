extends Node3D
## A transparent operative volume. Eight-pixel-like rim, sparse latitude wires;
## the floor perimeter carries the boundary when the camera is inside the volume.
var radius: float = 18.0
var duration: float = 18.0
var _age: float = 0.0
var _shell: MeshInstance3D
var _floor: MeshInstance3D
var _shell_material: ShaderMaterial
var _floor_material: ShaderMaterial
var _floor_height := 0.0

func _ready() -> void:
	name = "OpeRoomVisual"
	_shell_material = ShaderMaterial.new()
	_shell_material.shader = preload("res://src/fx/shaders/ope_room.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	_shell = MeshInstance3D.new()
	_shell.mesh = sphere
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = preload("res://src/fx/shaders/ope_floor.gdshader")
	_floor_material.set_shader_parameter("radius", radius)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	_floor = MeshInstance3D.new()
	_floor.mesh = plane
	_floor.material_override = _floor_material
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor.visible = false
	add_child(_floor)
	_update_visual()

## Called after the API places the sphere in world space. Never draw an
## operative floor through an avatar or suspended above a hole.
func project_floor() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.15,
		global_position + Vector3.DOWN * radius, 15)
	var excluded: Array[RID] = []
	for actor in AlvosDeGolpe.todos(get_tree()):
		if actor is CollisionObject3D:
			excluded.append(actor.get_rid())
	query.exclude = excluded
	var space := get_world_3d().direct_space_state
	for attempt in range(16):
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return
		var collider: Node = hit["collider"]
		if collider is CharacterBody3D or collider.has_method("take_damage"):
			excluded.append(hit["rid"])
			query.exclude = excluded
			continue
		if (hit["normal"] as Vector3).y < 0.7:
			return
		_floor_height = (hit["position"] as Vector3).y - global_position.y
		_floor.position.y = _floor_height + 0.035
		_floor.visible = true
		_update_visual()
		return

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_update_visual()

func _update_visual() -> void:
	var enter := clampf(_age / 0.65, 0.0, 1.0)
	var expansion := 1.0 - pow(1.0 - enter, 3.0)
	var presence := minf(enter * 4.0, clampf((duration - _age) / 0.6, 0.0, 1.0))
	_shell.scale = Vector3.ONE * maxf(0.001, radius * expansion)
	var floor_radius := sqrt(maxf(0.0, pow(radius * expansion, 2.0) - pow(_floor_height, 2.0)))
	_floor.scale = Vector3.ONE * maxf(0.001, floor_radius)
	_floor_material.set_shader_parameter("radius", maxf(0.001, floor_radius))
	for material: ShaderMaterial in [_shell_material, _floor_material]:
		material.set_shader_parameter("presence", presence)
		material.set_shader_parameter("age", _age)
