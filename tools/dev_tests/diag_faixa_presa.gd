extends SceneTree
# ============================================================================
#  A FAIXA ESTA PRESA AO MUNDO OU A TELA?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/diag_faixa_presa.gd -- <pasta>
#
#  SEIS hipoteses ja morreram uma a uma (sombra, grade, faixas do cel, contorno,
#  SSAO, nevoa), sempre com o mesmo salto de 0,138. Desligar efeito por efeito
#  parou de informar.
#
#  Entao esta sonda nao pergunta "qual efeito e"; pergunta a que o defeito esta
#  PRESO, que e a pergunta que classifica o problema sem adivinhar a causa:
#
#    • se as faixas ficam no MESMO Y DA TELA quando o jogador anda, elas sao de
#      pos-processamento / espaco de tela;
#    • se elas andam junto com o chao (mesmo Z do MUNDO), sao da geometria ou do
#      material do chao;
#    • se so mudam quando a camera GIRA, dependem da direcao de visao.
#
#  Ela acha as bordas com precisao de 1 pixel (a anterior amostrava de 12 em 12,
#  e por isso so dava para estimar o periodo) e converte cada borda para posicao
#  no MUNDO, disparando um raio pelo pixel da borda.
# ============================================================================

var _cam: Camera3D
var _espaco: PhysicsDirectSpaceState3D

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/diag_presa"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	_esconder_2d(get_root())

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	_cam = p._camera.camera()
	_espaco = (get_root().world_3d as World3D).direct_space_state

	# Tres posicoes ao longo de Z, mesmo rumo. Se a faixa e de tela, as bordas
	# caem no mesmo Y nas tres. Se e do mundo, o Y muda e o Z do mundo NAO muda.
	for dz in [0.0, 2.5, 5.0]:
		await _analisar(p, saida, "andou_%.1f" % dz, Vector3(0, 2.0, dz), PI, -0.25)
	# E um rumo diferente, para separar "depende da direcao" de "depende do lugar".
	await _analisar(p, saida, "rumo_90", Vector3(0, 2.0, 0.0), PI * 0.5, -0.25)

	print("\n✓ em %s" % saida)
	quit()

func _analisar(p: Node3D, saida: String, nome: String, pos: Vector3, yaw: float, pitch: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p._pitch = pitch
	p._camera.apontar(yaw, pitch)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 500:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [saida, nome])

	var col := img.get_width() / 2
	var vals: Array[float] = []
	var y0 := 340
	for y in range(y0, img.get_height() - 10):
		var c := img.get_pixel(col, y)
		vals.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)

	print("\n--- %s (jogador em z=%.1f, rumo %.0f°) ---" % [
		nome, pos.z, rad_to_deg(yaw)])
	print("   yTela | salto  | mundo(x, z)      | dist")
	for i in range(1, vals.size()):
		var d: float = vals[i] - vals[i - 1]
		if absf(d) < 0.02:
			continue
		var y := y0 + i
		var de := _cam.project_ray_origin(Vector2(col, y))
		var dir := _cam.project_ray_normal(Vector2(col, y))
		var par := PhysicsRayQueryParameters3D.create(de, de + dir * 600.0)
		var hit := _espaco.intersect_ray(par)
		if hit.is_empty():
			print("   %5d | %+.3f | (raio no vazio)" % [y, d])
		else:
			var q: Vector3 = hit["position"]
			print("   %5d | %+.3f | (%7.2f, %7.2f) | %5.1f" % [
				y, d, q.x, q.z, de.distance_to(q)])

func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem:
			f.visible = false
		else:
			_esconder_2d(f)
