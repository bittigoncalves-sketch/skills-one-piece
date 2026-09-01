class_name PlayerModelKit
extends RefCounted
# Helpers SEM ESTADO extraídos do Player.gd: construção da pistola voxel, medição
# de AABB do modelo (malhas OU esqueleto) e "bake" de profundidade. Tudo estático —
# só recebe nós/valores, não depende do Player. Reduz o monólito Player.gd.

# Modelo voxel de pistola. Se sair virada, girar o nó "Pistol" no eixo -Y (o cano).
static func build_pistol() -> Node3D:
	var gun := Node3D.new()
	gun.name = "Pistol"
	var body := Color(0.13, 0.14, 0.17)
	var dark := Color(0.07, 0.07, 0.09)
	var steel := Color(0.36, 0.38, 0.42)
	# corpo/slide (ao longo de -Y = frente) e cano fino saindo à frente
	gun.add_child(hand_box(Vector3(0.07, 0.26, 0.08), Vector3(0, -0.13, 0.0), Vector3.ZERO, body))
	gun.add_child(hand_box(Vector3(0.045, 0.34, 0.05), Vector3(0, -0.2, 0.005), Vector3.ZERO, dark))
	# grão de mira em cima (-Z = topo)
	gun.add_child(hand_box(Vector3(0.02, 0.03, 0.03), Vector3(0, -0.24, -0.05), Vector3.ZERO, steel))
	# empunhadura descendo/atrás (lado da palma = +Z), angulada
	gun.add_child(hand_box(Vector3(0.06, 0.17, 0.085), Vector3(0, 0.04, 0.1), Vector3(32, 0, 0), dark))
	# guarda-mato / gatilho
	gun.add_child(hand_box(Vector3(0.035, 0.04, 0.05), Vector3(0, -0.02, 0.06), Vector3.ZERO, steel))
	return gun

# Pistolas criadas para o saque da Mera Mera Z. O cano aponta no eixo -Y local,
# igual à pistola comum, para o cálculo de mira continuar usando a ponta visível.
static func build_mera_pistol() -> Node3D:
	var gun := Node3D.new()
	gun.name = "MeraFirelock"
	var charcoal := Color(0.075, 0.045, 0.035)
	var iron := Color(0.22, 0.16, 0.12)
	var brass := Color(0.78, 0.29, 0.045)
	var ember := Color(1.0, 0.18, 0.015)
	# Corpo compacto, slide superior e cano longo — silhueta legível mesmo de longe.
	gun.add_child(hand_box(Vector3(0.09, 0.25, 0.11), Vector3(0, -0.10, 0.0), Vector3.ZERO, charcoal))
	gun.add_child(hand_box(Vector3(0.065, 0.39, 0.065), Vector3(0, -0.22, 0.0), Vector3.ZERO, iron))
	# Câmara incandescente e duas faixas de latão, marcando que é uma arma de fogo.
	gun.add_child(emissive_box(Vector3(0.10, 0.045, 0.115), Vector3(0, -0.05, 0.0), brass, 1.2))
	gun.add_child(emissive_box(Vector3(0.078, 0.028, 0.078), Vector3(0, -0.31, 0.0), ember, 3.5))
	gun.add_child(hand_box(Vector3(0.104, 0.022, 0.118), Vector3(0, -0.16, 0.0), Vector3.ZERO, brass))
	# Mira, guarda-mato e empunhadura inclinada para a palma.
	gun.add_child(emissive_box(Vector3(0.025, 0.042, 0.035), Vector3(0, -0.27, -0.065), ember, 2.5))
	gun.add_child(hand_box(Vector3(0.070, 0.18, 0.10), Vector3(0, 0.055, 0.10), Vector3(28, 0, 0), charcoal))
	gun.add_child(hand_box(Vector3(0.052, 0.055, 0.065), Vector3(0, -0.005, 0.065), Vector3.ZERO, brass))
	# Três aletas emissivas formam uma chama estilizada na traseira da arma.
	for i in 3:
		gun.add_child(emissive_box(Vector3(0.018, 0.055 + i * 0.018, 0.024),
			Vector3((i - 1) * 0.026, 0.105 + i * 0.012, -0.005), ember, 2.2))
	return gun

static func hand_box(size: Vector3, pos: Vector3, rot_deg: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	mi.material_override = m
	return mi

static func emissive_box(size: Vector3, pos: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mi := hand_box(size, pos, Vector3.ZERO, color)
	var material := mi.material_override as StandardMaterial3D
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return mi

# Estica o eixo Z (profundidade) dos vértices de cada malha, embutindo a grossura.
static func bake_depth(root: Node3D, factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	for node in mesh_descendants(root):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mesh: Mesh = mi.mesh
		if not (mesh is ArrayMesh) or (mesh as ArrayMesh).get_surface_count() == 0:
			continue
		var arr := (mesh as ArrayMesh).surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i].z *= factor
		arr[Mesh.ARRAY_VERTEX] = verts
		var m2 := ArrayMesh.new()
		m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mi.mesh = m2

# AABB pela POSE dos ossos (personagem skinnado); cai no model_aabb se não achar esqueleto.
static func skeleton_aabb(root: Node3D) -> AABB:
	var skel: Skeleton3D = null
	for c in all_nodes_in(root):
		if c is Skeleton3D:
			skel = c as Skeleton3D
			break
	if skel == null or skel.get_bone_count() == 0:
		return model_aabb(root)
	var rel: Transform3D = root.global_transform.affine_inverse() * skel.global_transform
	var min_y := INF
	var max_y := -INF
	for i in range(skel.get_bone_count()):
		var pose_y: float = (rel * skel.get_bone_global_pose(i)).origin.y
		if pose_y < min_y:
			min_y = pose_y
		if pose_y > max_y:
			max_y = pose_y
	if min_y == INF:
		return model_aabb(root)
	var ab := AABB()
	ab.position.y = min_y
	ab.size.y = max_y - min_y
	return ab

# AABB pelas MALHAS (voxel), em espaço-root.
static func model_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in mesh_descendants(root):
		var a: AABB = mi.get_aabb()
		var rel: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var wa: AABB = rel * a
		if first:
			out = wa
			first = false
		else:
			out = out.merge(wa)
	return out

static func mesh_descendants(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out += mesh_descendants(c)
	return out

static func all_nodes_in(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out += all_nodes_in(c)
	return out
