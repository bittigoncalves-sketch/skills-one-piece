extends Node

var membro := TorusMesh.new()

func _ready() -> void:
	var cyl := CylinderMesh.new()
	cyl.radius = 1.0
	var sph := SphereMesh.new()
	sph.radius = 2.0
	var luz := OmniLight3D.new()
	luz.range = 5.0
	membro.radius = 3.0
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_colour = Color.RED

func teste2(mi: MeshInstance3D, luz2: OmniLight3D) -> void:
	mi.mesh = CylinderMesh.new()
	mi.mesh.radius = 0.5
	mi.transparency = 0.3
	luz2.range = 1.0
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = 1.0
	sh.height = 2.0
	var pp := ParticleProcessMaterial.new()
	pp.emission_sphere_radius = 1.0
	pp.explosivenes = 0.5
