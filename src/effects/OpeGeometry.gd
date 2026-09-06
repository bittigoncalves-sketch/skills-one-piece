extends RefCounted
## Original surgical geometry shared by the Ope effects. No particles or dynamic lights.
const CYAN := Color(0.08, 0.92, 1.0)
const GREEN := Color(0.44, 1.0, 0.13)

static func luminous(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	return material

static func instance(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual

static func ring(parent: Node3D, radius: float, width: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - width)
	mesh.outer_radius = radius + width
	mesh.rings = 64
	mesh.ring_segments = 6
	return instance(parent, mesh, material)

static func line(parent: Node3D, points: PackedVector3Array, width: float, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i: int in range(points.size()):
		var direction := Vector3.UP
		if i < points.size() - 1:
			direction = (points[i + 1] - points[i]).normalized()
		elif i > 0:
			direction = (points[i] - points[i - 1]).normalized()
		var tangent := direction.cross(Vector3.UP).normalized()
		if tangent.length_squared() < 0.01:
			tangent = Vector3.RIGHT
		var bitangent := direction.cross(tangent).normalized()
		for k: int in range(4):
			var angle := TAU * float(k) / 4.0
			vertices.append(points[i] + width * (tangent * cos(angle) + bitangent * sin(angle)))
		if i > 0:
			for k: int in range(4):
				var a := (i - 1) * 4 + k
				var b := (i - 1) * 4 + (k + 1) % 4
				indices.append_array(PackedInt32Array([a, b, a + 4, b, b + 4, a + 4]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return instance(parent, mesh, material)

static func crosshair(parent: Node3D, radius: float, material: Material) -> void:
	ring(parent, radius, 0.013, material)
	for axis: int in range(4):
		var angle := PI * 0.5 * axis
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		line(parent, PackedVector3Array([radial * radius * 0.75, radial * radius * 1.22]), 0.018, material)

static func fade(material: StandardMaterial3D, alpha: float) -> void:
	var color := material.albedo_color
	color.a = clampf(alpha, 0.0, 1.0)
	material.albedo_color = color
