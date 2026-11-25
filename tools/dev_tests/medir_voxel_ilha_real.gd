extends SceneTree
## V2 no MAPA REAL: o terreno da ilha onde o jogador começa, como blocos gerados sob demanda.
## Mede geração e malha de uma região ao redor do jogador, confere a superfície por raios contra o relevo atual e cava uma cratera.
##   RAIO=8 R=6 godot --headless --path . --script tools/dev_tests/medir_voxel_ilha_real.gd     (com MemoryMax)
func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_voxel_real.json")
	root.get_node("GameFlow").start_story()
	await frames(300)
	var raiz := current_scene.find_child("Mapa", true, false)
	var j := get_first_node_in_group("player") as Node3D
	var raio_secoes := int(OS.get_environment("RAIO")) if OS.get_environment("RAIO") != "" else 8
	var cratera := int(OS.get_environment("R")) if OS.get_environment("R") != "" else 6
	var corpo: StaticBody3D = null
	for c in raiz.get_children():
		if c.has_meta(RelevoEmBlocos.META):
			var r0: RelevoEmBlocos = c.get_meta(RelevoEmBlocos.META)
			var h := r0.altura(j.global_position.x, j.global_position.z)
			if not is_nan(h):
				corpo = c
				break
	if corpo == null:
		print("VOXREAL sem relevo sob o jogador")
		quit(1)
		return
	var rel: RelevoEmBlocos = corpo.get_meta(RelevoEmBlocos.META)
	print("VOXREAL ilha %s: %d x %d meios, jogador em %s" % [corpo.get_meta("ilha"), rel.largura, rel.profundidade, str(j.global_position)])
	corpo.collision_layer = 2                          # o relevo atual sai da camada do mundo (só para comparar)
	var t0 := Time.get_ticks_usec()
	var g := GeradorDeRelevo.new(rel)
	print("VOXREAL gerador criado em %.1f ms, caixa %s .. %s" % [(Time.get_ticks_usec() - t0) / 1000.0, str(g.caixa_min), str(g.caixa_max)])
	var cel := GradeVoxel.celula_em(j.global_position)
	var sc0 := GradeVoxel.secao_de(cel)
	# custo de gerar uma seção (uma thread só)
	var soma := 0.0
	var n := 0
	var pior := 0.0
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			for dy in range(-1, 2):
				var ta := Time.get_ticks_usec()
				g.gerar(sc0 + Vector3i(dx, dy, dz))
				var ms := (Time.get_ticks_usec() - ta) / 1000.0
				soma += ms
				n += 1
				pior = maxf(pior, ms)
	print("VOXREAL gerar(): %d seções, média %.2f ms, pior %.2f ms (uma thread)" % [n, soma / n, pior])
	var gv := GradeVoxel.new()
	gv.gerador = g
	gv.trocas_por_quadro = 1000000
	root.add_child(gv)
	var a := Vector3i(cel.x - raio_secoes * 16, cel.y - 32, cel.z - raio_secoes * 16)
	var b := Vector3i(cel.x + raio_secoes * 16, cel.y + 32, cel.z + raio_secoes * 16)
	var t1 := Time.get_ticks_msec()
	gv.carregar_caixa(a, b)
	var quadros := 0
	var pior_quadro := 0.0
	while not gv.pronto():
		var tq := Time.get_ticks_usec()
		gv.processar(4)
		await physics_frame
		pior_quadro = maxf(pior_quadro, (Time.get_ticks_usec() - tq) / 1000.0)
		quadros += 1
	print("VOXREAL carga de %dx%d seções ao redor: %d seções com malha, %d triângulos, %d vértices de colisão, %d ms de relógio, %d quadros, pior quadro %.1f ms (4 trocas/quadro)" % [
		raio_secoes * 2 + 1, raio_secoes * 2 + 1, gv.secoes_com_malha(), gv.triangulos(), gv.vertices_de_colisao(), Time.get_ticks_msec() - t1, quadros, pior_quadro])
	await frames(3)
	# superfície igual à do relevo atual (raios na região carregada)
	var espaco := root.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var testados := 0
	var outros := 0
	var difere := 0
	var maior := 0.0
	var origem := j.global_position
	for k in 600:
		var x := origem.x + rng.randf_range(-1.0, 1.0) * raio_secoes * 16 * GradeVoxel.BLOCO * 0.8
		var z := origem.z + rng.randf_range(-1.0, 1.0) * raio_secoes * 16 * GradeVoxel.BLOCO * 0.8
		var q1 := PhysicsRayQueryParameters3D.create(Vector3(x, origem.y + 60, z), Vector3(x, origem.y - 60, z), 2)
		var q2 := PhysicsRayQueryParameters3D.create(Vector3(x, origem.y + 60, z), Vector3(x, origem.y - 60, z), 1)
		var h1 := espaco.intersect_ray(q1)
		var h2 := espaco.intersect_ray(q2)
		# Só conta onde o terreno é a PRIMEIRA coisa atingida nos dois (construções e árvores também estão na camada do mundo).
		if (not h1.is_empty() and h1.collider != corpo) or (not h2.is_empty() and not gv.is_ancestor_of(h2.collider)):
			outros += 1
			continue
		if h1.is_empty() and h2.is_empty():
			continue
		testados += 1
		if h1.is_empty() != h2.is_empty():
			difere += 1
			continue
		var d := absf(h1.position.y - h2.position.y)
		maior = maxf(maior, d)
		if d > 0.02:
			difere += 1
	print("VOXREAL raios: %d acertam o terreno nos dois (%d ignorados por baterem em construção/árvore), %d divergem (> 2 cm), maior diferença %.4f m" % [testados, outros, difere, maior])
	# cratera esférica na superfície, na frente do jogador
	gv.trocas_por_quadro = 2
	var centro := GradeVoxel.celula_em(Vector3(origem.x + 6.0, origem.y, origem.z))
	while gv.obter(centro + Vector3i.UP) != TiposDeBloco.AR:
		centro += Vector3i.UP
	var tirados := 0
	var t2 := Time.get_ticks_usec()
	for x in range(-cratera, cratera + 1):
		for y in range(-cratera, cratera + 1):
			for z in range(-cratera, cratera + 1):
				if x * x + y * y + z * z <= cratera * cratera and gv.obter(centro + Vector3i(x, y, z)) != TiposDeBloco.AR:
					gv.definir(centro + Vector3i(x, y, z), TiposDeBloco.AR)
					tirados += 1
	var t_cavar := (Time.get_ticks_usec() - t2) / 1000.0
	var r_antes := gv.reconstrucoes
	var pior_proc := 0.0
	var pior_q := 0.0
	while not gv.pronto():
		var tq := Time.get_ticks_usec()
		gv.processar()
		pior_proc = maxf(pior_proc, (Time.get_ticks_usec() - tq) / 1000.0)
		await physics_frame
		pior_q = maxf(pior_q, (Time.get_ticks_usec() - tq) / 1000.0)
	for i in 5:
		var tq := Time.get_ticks_usec()
		await physics_frame
		pior_q = maxf(pior_q, (Time.get_ticks_usec() - tq) / 1000.0)
	print("VOXREAL cratera r=%d: %d blocos, cavar (obter+definir) %.1f ms, %d seções refeitas, %d guardadas, processar() pior %.1f ms, QUADRO INTEIRO pior %.1f ms" % [
		cratera, tirados, t_cavar, gv.reconstrucoes - r_antes, gv.secoes_com_blocos(), pior_proc, pior_q])
	modo.set("progresso_forcado", "")
	quit()
