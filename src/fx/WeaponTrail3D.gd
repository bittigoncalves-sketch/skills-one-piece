class_name WeaponTrail3D
extends MeshInstance3D

@export var target_base: Node3D
@export var target_tip: Node3D
@export var life_time: float = 0.25
@export var startColor: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var endColor: Color = Color(1.0, 1.0, 1.0, 0.0)

var _points := [] # Array of dictionaries: {"base": Vector3, "tip": Vector3, "time": float}
var _is_emitting := false

func _ready() -> void:
	mesh = ImmediateMesh.new()
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = mat	
	# O rastro deve existir no espaço global para não se mover quando a espada for repousada
	top_level = true
	global_transform = Transform3D()

func emit(enable: bool) -> void:
	_is_emitting = enable

func clear() -> void:
	_points.clear()
	mesh.clear_surfaces()

func _process(delta: float) -> void:
	if _is_emitting and target_base and target_tip:
		_points.push_front({
			"base": target_base.global_position,
			"tip": target_tip.global_position,
			"time": life_time
		})
	
	var i := 0
	while i < _points.size():
		_points[i]["time"] -= delta
		if _points[i]["time"] <= 0.0:
			_points.remove_at(i)
		else:
			i += 1
			
	_draw_trail()

func _draw_trail() -> void:
	mesh.clear_surfaces()
	if _points.size() < 2:
		return
		
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	
	for i in range(_points.size()):
		var p = _points[i]
		var t = p["time"] / life_time # 1.0 no início, 0.0 no final
		var c = endColor.lerp(startColor, t)
		
		# UV x é o comprimento ao longo do rastro (0 a 1)
		# UV y é 0 para base, 1 para tip
		var uv_x = float(i) / float(_points.size() - 1)
		
		mesh.surface_set_color(c)
		mesh.surface_set_uv(Vector2(uv_x, 0.0))
		mesh.surface_add_vertex(to_local(p["base"]))
		
		mesh.surface_set_color(c)
		mesh.surface_set_uv(Vector2(uv_x, 1.0))
		mesh.surface_add_vertex(to_local(p["tip"]))
		
	mesh.surface_end()
