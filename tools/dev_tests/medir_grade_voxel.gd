extends SceneTree
## Custo da GradeVoxel contra o relevo de UMA malha: ilha de LADO×LADO colunas, cratera de raio R; mede o quadro da thread principal.
## O número a bater: troca de colisão do relevo atual = ~148 ms por corte (docs/DESEMPENHO_SKILLS_NO_CHAO_2026-11-11.md).
##   LADO=256 R=6 godot --headless --path . --script tools/dev_tests/medir_grade_voxel.gd
func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var lado := int(OS.get_environment("LADO")) if OS.get_environment("LADO") != "" else 256
	var raio := int(OS.get_environment("R")) if OS.get_environment("R") != "" else 6
	var g := GradeVoxel.new()
	root.add_child(g)
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.02
	var t0 := Time.get_ticks_msec()
	for x in lado:
		for z in lado:
			var alt := 6 + int((ruido.get_noise_2d(x, z) + 1.0) * 5.0)
			for y in alt:
				g.definir(Vector3i(x, y, z), GradeVoxel.GRAMA if y == alt - 1 else (GradeVoxel.TERRA if y > alt - 4 else GradeVoxel.PEDRA))
	var t_dados := Time.get_ticks_msec() - t0
	t0 = Time.get_ticks_msec()
	g.esperar_tudo()
	print("VOXEL ilha %dx%d: dados %d ms, malhas %d ms (threads), %d seções, %d triângulos, %d vértices de colisão" % [
		lado, lado, t_dados, Time.get_ticks_msec() - t0, g.secoes_com_malha(), g.triangulos(), g.vertices_de_colisao()])
	await physics_frame
	await physics_frame
	# Cratera esférica no meio, na superfície (≈ BlockDestroyAllDirection): marca os blocos e deixa o jogo rodar.
	var centro := Vector3i(lado / 2, 9, lado / 2)
	var t1 := Time.get_ticks_usec()
	var tirados := 0
	for x in range(-raio, raio + 1):
		for y in range(-raio, raio + 1):
			for z in range(-raio, raio + 1):
				if x * x + y * y + z * z <= raio * raio and g.obter(centro + Vector3i(x, y, z)) != GradeVoxel.AR:
					g.definir(centro + Vector3i(x, y, z), GradeVoxel.AR)
					tirados += 1
	var t_cavar := (Time.get_ticks_usec() - t1) / 1000.0
	var piores := 0.0
	var soma := 0.0
	var quadros := 0
	var pior_quadro := 0.0                           # quadro INTEIRO (inclui a física depois da troca da forma)
	var t_total := Time.get_ticks_msec()
	var r_antes := g.reconstrucoes
	while not g.pronto():
		var ta := Time.get_ticks_usec()
		g.processar()
		var ms := (Time.get_ticks_usec() - ta) / 1000.0
		piores = maxf(piores, ms)
		soma += ms
		quadros += 1
		await physics_frame
		pior_quadro = maxf(pior_quadro, (Time.get_ticks_usec() - ta) / 1000.0)
	for i in 5:
		var tb := Time.get_ticks_usec()
		await physics_frame
		pior_quadro = maxf(pior_quadro, (Time.get_ticks_usec() - tb) / 1000.0)
	print("VOXEL cratera r=%d: %d blocos, definir=%.1f ms, %d seções refeitas, processar(): pior %.1f ms, soma %.1f ms em %d quadros; QUADRO INTEIRO pior %.1f ms" % [
		raio, tirados, t_cavar, g.reconstrucoes - r_antes, piores, soma, quadros, pior_quadro])
	quit()
