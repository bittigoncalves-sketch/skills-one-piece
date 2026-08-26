extends Node3D
class_name SeismicOrb

var charge: float = 0.0
var _orb_mesh: MeshInstance3D
var _cracks_mesh: MeshInstance3D

func _ready() -> void:
	# Esfera externa (vidro/distorção)
	_orb_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 4.8
	sphere.height = 9.6
	sphere.radial_segments = 16
	sphere.rings = 8
	_orb_mesh.mesh = sphere
	
	var mat_orb = StandardMaterial3D.new()
	mat_orb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_orb.albedo_color = Color(1.0, 1.0, 1.0, 0.3)
	mat_orb.roughness = 0.1
	mat_orb.emission_enabled = true
	mat_orb.emission = Color(0.8, 0.9, 1.0)
	mat_orb.emission_energy_multiplier = 0.5
	_orb_mesh.material_override = mat_orb
	add_child(_orb_mesh)
	
	# Rachaduras internas (simulação)
	_cracks_mesh = MeshInstance3D.new()
	var crack_sphere = SphereMesh.new()
	crack_sphere.radius = 4.4
	crack_sphere.height = 8.8
	crack_sphere.radial_segments = 8
	crack_sphere.rings = 4
	_cracks_mesh.mesh = crack_sphere
	
	var mat_cracks = StandardMaterial3D.new()
	mat_cracks.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cracks.albedo_color = FxUtil.brilho(Color(1.0, 1.0, 1.0, 0.8), 2.0)
	# Falsa aparência de linhas pra simular rachaduras via subdivisão low poly
	mat_cracks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cracks_mesh.material_override = mat_cracks
	add_child(_cracks_mesh)

func _process(_delta: float) -> void:
	# O charge vai de 0.0 a 3.0
	var scale_mult = 1.0 + charge * 0.2
	scale = Vector3(scale_mult, scale_mult, scale_mult)
	
	# Vibração das rachaduras internas baseado no charge
	if _cracks_mesh and is_instance_valid(_cracks_mesh):
		var mat = _cracks_mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 0.3 + (charge / 3.0) * 0.7
			mat.emission_energy_multiplier = 1.0 + (charge / 3.0) * 3.0
			
		var shake = (charge / 3.0) * 0.03
		_cracks_mesh.position = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), randf_range(-shake, shake))
