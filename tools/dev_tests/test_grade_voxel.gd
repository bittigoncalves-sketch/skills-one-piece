extends SceneTree
## GradeVoxel (etapa V1 do mundo de blocos): malha só das faces visíveis, refeitura só da seção suja, colisão real.
##   godot --headless --path . --script tools/dev_tests/test_grade_voxel.gd
var ok := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func confere(cond: bool, msg: String) -> void:
	if cond:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", msg)

func nova() -> GradeVoxel:
	var g := GradeVoxel.new()
	root.add_child(g)
	return g

func area(g: GradeVoxel) -> float:
	var a := 0.0
	for no: StaticBody3D in g._nos.values():
		var m := (no.get_node("Malha") as MeshInstance3D).mesh as ArrayMesh
		var v: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for t in v.size() / 3:
			a += (v[3 * t + 1] - v[3 * t]).cross(v[3 * t + 2] - v[3 * t]).length() * 0.5
	return a

func rodar() -> void:
	# 1. um bloco: 6 faces = 12 triângulos
	var g := nova()
	g.definir(Vector3i(3, 4, 5), GradeVoxel.PEDRA)
	g.esperar_tudo()
	confere(g.triangulos() == 12, "1 bloco = 12 triângulos (%d)" % g.triangulos())
	confere(g.obter(Vector3i(3, 4, 5)) == GradeVoxel.PEDRA and g.obter(Vector3i(3, 4, 6)) == GradeVoxel.AR, "obter/definir")
	g.queue_free()

	# 2. dois blocos iguais juntos: a face entre eles não existe e as laterais se fundem (6 quadros = 12 triângulos)
	g = nova()
	g.definir(Vector3i(1, 1, 1), GradeVoxel.PEDRA)
	g.definir(Vector3i(2, 1, 1), GradeVoxel.PEDRA)
	g.esperar_tudo()
	confere(g.triangulos() == 12, "2 blocos fundidos = 12 triângulos (%d)" % g.triangulos())
	g.definir(Vector3i(3, 1, 1), GradeVoxel.TERRA)   # outra cor: não funde com os de pedra
	g.esperar_tudo()
	confere(g.triangulos() == 20, "bloco de outra cor não funde, sem a face entre eles: 5+5 quadros (%d)" % g.triangulos())
	g.queue_free()

	# 3. face entre seções: bloco em x=15 e x=16 → cada seção sem a face voltada para a outra (10 quadros)
	g = nova()
	g.definir(Vector3i(15, 2, 2), GradeVoxel.PEDRA)
	g.definir(Vector3i(16, 2, 2), GradeVoxel.PEDRA)
	g.esperar_tudo()
	confere(g.triangulos() == 20, "faces entre seções vizinhas não existem (%d)" % g.triangulos())
	confere(g.secoes_com_malha() == 2, "2 seções com malha")

	# 4. refeitura só da seção suja (e da vizinha na borda)
	var r0 := g.reconstrucoes
	g.definir(Vector3i(15, 5, 5), GradeVoxel.PEDRA)        # borda +x da seção 0, vizinha existe
	g.esperar_tudo()
	confere(g.reconstrucoes - r0 == 2, "bloco na borda suja 2 seções (%d)" % (g.reconstrucoes - r0))
	r0 = g.reconstrucoes
	g.definir(Vector3i(8, 8, 8), GradeVoxel.PEDRA)         # miolo
	g.esperar_tudo()
	confere(g.reconstrucoes - r0 == 1, "bloco no miolo suja 1 seção (%d)" % (g.reconstrucoes - r0))
	r0 = g.reconstrucoes
	g.definir(Vector3i(8, 8, 8), GradeVoxel.PEDRA)         # mesmo valor: nada
	confere(g.pronto(), "definir o mesmo valor não suja nada")
	g.queue_free()

	# 5. equivalência com a conta bruta: área da malha = faces visíveis × B² (nuvem aleatória atravessando 2×2×2 seções)
	g = nova()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var sol := {}
	for x in range(10, 26):
		for y in range(10, 26):
			for z in range(10, 26):
				if rng.randf() < 0.45:
					var t := rng.randi_range(1, 3)
					sol[Vector3i(x, y, z)] = t
					g.definir(Vector3i(x, y, z), t)
	g.esperar_tudo()
	var visiveis := 0
	for c: Vector3i in sol:
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if not sol.has(c + d):
				visiveis += 1
	var esperado := visiveis * GradeVoxel.BLOCO * GradeVoxel.BLOCO
	var obtido := area(g)
	confere(absf(obtido / esperado - 1.0) < 0.03, "área da malha = faces visíveis (%.2f vs %.2f)" % [obtido, esperado])
	g.queue_free()

	# 6. colisão = a mesma malha; raio para baixo acha o topo do bloco
	g = nova()
	g.preencher(Vector3i(0, 0, 0), Vector3i(3, 1, 3), GradeVoxel.GRAMA)
	g.esperar_tudo()
	var no := g.no_da_secao(Vector3i.ZERO)
	var forma := (no.get_node("Colisao") as CollisionShape3D).shape as ConcavePolygonShape3D
	confere(forma.get_faces().size() == g.triangulos() * 3, "forma de colisão tem os mesmos vértices da malha")
	await physics_frame
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(1.0, 6.0, 1.0), Vector3(1.0, -1.0, 1.0), 1)
	var h := root.get_world_3d().direct_space_state.intersect_ray(q)
	confere(not h.is_empty() and absf(h.position.y - 2.0 * GradeVoxel.BLOCO) < 0.01, "raio acha o topo do chão (%s)" % str(h.get("position")))
	# cavar: o buraco aparece na colisão
	g.definir(Vector3i(1, 1, 1), GradeVoxel.AR)
	g.definir(Vector3i(1, 0, 1), GradeVoxel.AR)
	g.esperar_tudo()
	await physics_frame
	await physics_frame
	h = root.get_world_3d().direct_space_state.intersect_ray(q)
	confere(h.is_empty(), "depois de cavar as duas camadas o raio atravessa o buraco (%s)" % str(h.get("position")))

	# 7. esvaziar tudo some com os nós
	g.preencher(Vector3i(0, 0, 0), Vector3i(3, 1, 3), GradeVoxel.AR)
	g.esperar_tudo()
	confere(g.secoes_com_malha() == 0 and g.triangulos() == 0, "sem blocos, sem malha")
	g.queue_free()

	print("GRADE_VOXEL ok=%d falhas=%d" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
