class_name MapBuilder
extends RefCounted
# Mapa base FIXO = plataforma cinza plana + blocos cinza (idêntico à base do jogo).

const PLATFORM_SIZE := 200.0   # lado da plataforma
const PLATFORM_THICK := 2.0
const OBSTACLE_COUNT := 90     # blocos cinza espalhados
const WORLD_SEED := 20260725   # semente fixa => mapa sempre igual

static func build(parent: Node) -> Array:
	_platform(parent)
	return _blocks(parent)

static func _platform(parent: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "Plataforma"

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(PLATFORM_SIZE, PLATFORM_THICK, PLATFORM_SIZE)
	mesh.mesh = box
	mesh.material_override = _gray(0.52, 0.85)
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(PLATFORM_SIZE, PLATFORM_THICK, PLATFORM_SIZE)
	col.shape = shape
	body.add_child(col)

	body.position = Vector3(0, -PLATFORM_THICK * 0.5, 0)  # topo em y=0
	parent.add_child(body)

static func _blocks(parent: Node) -> Array:
	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3.ONE
	var shared_shape := BoxShape3D.new()
	shared_shape.size = Vector3.ONE

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED

	var half := PLATFORM_SIZE * 0.5 - 6.0
	var out: Array = []
	for i in OBSTACLE_COUNT:
		var w := rng.randf_range(2.0, 6.0)
		var h := rng.randf_range(1.5, 9.0)
		var d := rng.randf_range(2.0, 6.0)
		var px := rng.randf_range(-half, half)
		var pz := rng.randf_range(-half, half)

		# Clareira no ponto de spawn do jogador.
		if Vector2(px, pz).length() < 8.0:
			continue

		var block := StaticBody3D.new()
		var m := MeshInstance3D.new()
		m.mesh = shared_mesh
		var g := rng.randf_range(0.32, 0.62)
		m.material_override = _gray(g, 0.8)
		block.add_child(m)

		var c := CollisionShape3D.new()
		c.shape = shared_shape
		block.add_child(c)

		block.scale = Vector3(w, h, d)
		block.position = Vector3(px, h * 0.5, pz)
		parent.add_child(block)

		out.append({"x": px, "z": pz, "top": h, "w": w, "d": d})
	return out

static func _gray(value: float, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(value, value, value)
	mat.roughness = rough
	mat.metallic = 0.0
	return mat
