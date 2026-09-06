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
	_floor.position.y = 0.065
	add_child(_floor)
	_update_visual()

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
	_floor.scale = Vector3.ONE * maxf(0.001, radius * expansion)
	for material: ShaderMaterial in [_shell_material, _floor_material]:
		material.set_shader_parameter("presence", presence)
		material.set_shader_parameter("age", _age)
