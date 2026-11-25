extends SceneTree
## Derivação reproduzível, sem alterar o GLB: corta a malha no plano do punho R.
const OUT := "res://assets/models/bosses/buggy/detached/"
var split_points: Array[Vector3] = []
var skin_indices := PackedInt32Array([0, 0, 0, 0])
var plane: Plane
var to_hand: Transform3D
var body := SurfaceTool.new()
var hand := SurfaceTool.new()
var rigid := SurfaceTool.new()

func _init() -> void:
	await process_frame
	var scene: Node3D = load("res://assets/models/bosses/buggy/buggyBoss.glb").instantiate()
	root.add_child(scene)
	var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh_node := scene.find_child("tripo_part_8", true, false) as MeshInstance3D
	if mesh_node == null:
		push_error("Malha auditada não encontrada")
		quit(1)
		return
	var wrist := skeleton.find_bone("R_Hand")
	var forearm := skeleton.find_bone("R_Forearm")
	var wrist_world := skeleton.global_transform * skeleton.get_bone_global_rest(wrist)
	var elbow_world: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(forearm).origin
	var center := mesh_node.to_local(wrist_world.origin)
	var normal := (center - mesh_node.to_local(elbow_world)).normalized()
	plane = Plane(normal, center)
	to_hand = wrist_world.affine_inverse() * mesh_node.global_transform
	for i in mesh_node.skin.get_bind_count():
		if str(mesh_node.skin.get_bind_name(i)) == "R_Hand" or mesh_node.skin.get_bind_bone(i) == wrist:
			skin_indices[0] = i
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	for st in [body, hand, rigid]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mesh_node.get_active_material(0))
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var triangle: Array[Dictionary] = []
		for j in 3:
			var id := indices[i + j]
			var weights := {}
			for k in 4:
				weights[arrays[Mesh.ARRAY_BONES][id * 4 + k]] = arrays[Mesh.ARRAY_WEIGHTS][id * 4 + k]
			triangle.append({"p": arrays[Mesh.ARRAY_VERTEX][id], "n": arrays[Mesh.ARRAY_NORMAL][id], "uv": arrays[Mesh.ARRAY_TEX_UV][id], "w": weights})
		polygon(body, clip(triangle, false), false)
		var separated := clip(triangle, true)
		polygon(hand, separated, false)
		polygon(rigid, separated, true)
	var body_mesh := finish(body)
	var hand_mesh := finish(hand)
	var rigid_mesh := finish(rigid)
	# Tampa convexa no pulso. O contorno anatômico nessa seção é uma única ilha.
	var u := normal.cross(Vector3.UP).normalized()
	if u.length_squared() < 0.1:
		u = normal.cross(Vector3.RIGHT).normalized()
	var v := normal.cross(u)
	var projected := PackedVector2Array()
	for p in split_points:
		projected.append(Vector2((p - center).dot(u), (p - center).dot(v)))
	var hull := Geometry2D.convex_hull(projected)
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color(0.94, 0.84, 0.68)
	cap_material.roughness = 0.9
	cap_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for target in [[body_mesh, false, 1.0], [hand_mesh, false, -1.0], [rigid_mesh, true, -1.0]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(cap_material)
		for i in range(hull.size() - 1):
			for point in [Vector2.ZERO, hull[i], hull[i + 1]]:
				vertex(st, {"p": center + u * point.x + v * point.y, "n": normal * target[2], "uv": point,
					"w": {skin_indices[0]: 1.0}}, target[1])
		st.index()
		st.commit(target[0])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var results := [ResourceSaver.save(body_mesh, OUT + "right_arm.res"), ResourceSaver.save(hand_mesh, OUT + "right_hand_attached.res"), ResourceSaver.save(rigid_mesh, OUT + "right_hand_rigid.res")]
	print("HAND BUILD results=", results, " seam samples=", split_points.size(), " hull=", hull.size(), " wrist=", center, " normal=", normal)
	quit(0 if results.all(func(x): return x == OK) else 1)

func interpolate(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var weights := {}
	for key in a.w.keys() + b.w.keys():
		weights[key] = lerpf(a.w.get(key, 0), b.w.get(key, 0), weight)
	return {"p": a.p.lerp(b.p, weight), "n": a.n.lerp(b.n, weight).normalized(), "uv": a.uv.lerp(b.uv, weight), "w": weights}

func clip(points: Array[Dictionary], positive: bool) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var da := plane.distance_to(a.p)
		var db := plane.distance_to(b.p)
		var inside: bool = da >= 0 if positive else da <= 0
		var next_inside: bool = db >= 0 if positive else db <= 0
		if inside:
			output.append(a)
		if inside != next_inside:
			var crossing := interpolate(a, b, da / (da - db))
			output.append(crossing)
			if positive:
				split_points.append(crossing.p)
	return output

func polygon(st: SurfaceTool, points: Array[Dictionary], rigid_mesh: bool) -> void:
	for i in range(1, points.size() - 1):
		for point in [points[0], points[i], points[i + 1]]:
			vertex(st, point, rigid_mesh)

func vertex(st: SurfaceTool, point: Dictionary, rigid_mesh: bool) -> void:
	st.set_normal((to_hand.basis * point.n).normalized() if rigid_mesh else point.n)
	st.set_uv(point.uv)
	if not rigid_mesh:
		var keys: Array = point.w.keys()
		keys.sort_custom(func(a, b): return point.w[a] > point.w[b])
		var joints := PackedInt32Array([0, 0, 0, 0])
		var weights := PackedFloat32Array([0, 0, 0, 0])
		var total := 0.0
		for i in mini(4, keys.size()):
			joints[i] = keys[i]
			weights[i] = point.w[keys[i]]
			total += weights[i]
		for i in 4:
			weights[i] /= maxf(total, 0.00001)
		st.set_bones(joints)
		st.set_weights(weights)
	st.add_vertex(to_hand * point.p if rigid_mesh else point.p)

func finish(st: SurfaceTool) -> ArrayMesh:
	st.index()
	return st.commit()
