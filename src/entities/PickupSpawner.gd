class_name PickupSpawner
extends RefCounted
# Coletáveis de Akuma no Mi (adições), posicionados por fórmula: anel paramétrico.
# Ao encostar no player, chama `on_collect.call(body, fruto, cor, area)`.

const RING_RADIUS := 56.0

static func spawn(parent: Node, data_path: String, on_collect: Callable) -> void:
	var frutos := _load(data_path)
	var n: int = min(8, frutos.size())
	if n == 0:
		return
	for i in n:
		var fruto: Dictionary = frutos[i]
		var ang := float(i) * TAU / float(n)
		var x := cos(ang) * RING_RADIUS
		var z := sin(ang) * RING_RADIUS
		var cor := Color.html(str(fruto.get("cor", "#cccccc")))
		_make(parent, Vector3(x, 1.6, z), cor, fruto, on_collect)

static func _make(parent: Node, pos: Vector3, cor: Color, fruto: Dictionary, on_collect: Callable) -> void:
	var area := Area3D.new()
	area.position = pos

	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 1.6
	mesh.material_override = mat
	area.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.3
	col.shape = shape
	area.add_child(col)

	parent.add_child(area)

	# Bob + giro (animação via tween em loop).
	var tw := area.create_tween().set_loops()
	tw.tween_property(mesh, "position:y", 0.35, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(mesh, "position:y", -0.35, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	var spin := area.create_tween().set_loops()
	spin.tween_property(mesh, "rotation:y", TAU, 4.0)

	area.body_entered.connect(on_collect.bind(fruto, cor, area))

static func _load(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("JSON não encontrado: " + path)
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed.get("frutos", [])
	return []
