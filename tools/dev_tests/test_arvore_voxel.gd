extends SceneTree
# Seis formas voxel: malha válida, 2 superfícies, altura <= 6,4 m, pivô na base.
func _init() -> void:
	var falhas := 0
	for f in ArvoreVoxel.FORMAS:
		var m := ArvoreVoxel.malha(f)
		var b := m.get_aabb()
		var ok := m.get_surface_count() >= 2 and b.position.y >= -0.001 and b.end.y <= 6.41 and b.size.y > 3.0
		print("%s %s aabb=%s faces=%d" % ["OK " if ok else "FALHA", f, b, m.get_faces().size() / 3])
		if not ok: falhas += 1
	# Face frontal no Godot = ordem HORÁRIA: (v1-v0)x(v2-v0) tem de apontar contra a normal.
	for f in ArvoreVoxel.FORMAS:
		var m := ArvoreVoxel.malha(f)
		var ruins := 0
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for t in range(0, idx.size(), 3):
				var c := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
				if c.dot(n[idx[t]]) >= 0.0:
					ruins += 1
		if ruins > 0:
			print("FALHA: %s tem %d triângulos com a face de frente para dentro" % [f, ruins])
			falhas += 1
	var formas := {}
	for d in TreeAndFruitGenerator._todas_as_definicoes():
		formas[TreeAndFruitGenerator.forma_da_arvore(d["id"])] = true
	if formas.size() != 6: print("FALHA: formas usadas = ", formas.size()); falhas += 1
	var t := TreeAndFruitGenerator.create_tree_3d(TreeAndFruitGenerator._todas_as_definicoes()[0])
	if t.get_node_or_null("Modelo") == null: print("FALHA: sem Modelo"); falhas += 1
	t.free()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d falhas" % falhas)
	quit(falhas)
