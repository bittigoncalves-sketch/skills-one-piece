extends SceneTree
# ============================================================================
#  COMPARAR DOIS MODELOS DA LOJA lado a lado, com a luz do jogo (01/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/comparar_modelos.gd -- \
#        <id_a> <id_b> [res://art_src/validation/<pasta>]
#
#  Feito para conferir uma malha simplificada contra a original (o cavalo da vila):
#  os dois no MESMO tamanho (o do A), A à esquerda, B à direita, fotografados de
#  vários ângulos e de perto. Mede também o tempo de quadro com cada um sozinho.
# ============================================================================

const ANGULOS := [["lado", 90.0, 0.35], ["frente_34", 35.0, 0.45], ["tras_34", 215.0, 0.45], ["cima", 60.0, 1.4]]


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("precisa de tela (rode sem --headless)")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var bib := BibliotecaDeModelos.padrao()
	var a: String = args[0]
	var b: String = args[1]
	var saida: String = args[2] if args.size() > 2 else "res://art_src/validation/comparar"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = Vector2i(1280, 720)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(60, 60)
	chao.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#71965a")
	chao.material_override = mat
	mundo.add_child(chao)
	var tamanho: Vector3 = bib.info(a)["tamanho"]
	var vao := maxf(tamanho.x, tamanho.z) * 0.8 + 0.6
	var pecas := []
	for i in 2:
		var corpo := Node3D.new()
		mundo.add_child(corpo)
		var id: String = [a, b][i]
		bib.aplicar_em(corpo, {"id": id, "modelo": id, "tamanho": tamanho})
		corpo.position = Vector3((-1 if i == 0 else 1) * vao, tamanho.y * 0.5, 0)
		pecas.append(corpo)
	var camera := Camera3D.new()
	mundo.add_child(camera)
	camera.make_current()
	var alcance := maxf(tamanho.y, maxf(tamanho.x, tamanho.z)) * 2.4 + vao
	for ang in ANGULOS:
		var r := deg_to_rad(ang[1])
		camera.position = Vector3(sin(r), ang[2], cos(r)) * alcance + Vector3.UP * tamanho.y * 0.5
		camera.look_at(Vector3(0, tamanho.y * 0.5, 0))
		await _foto(saida.path_join("%s_vs_%s_%s.png" % [a.left(12), b.left(12), ang[0]]))
	# Perto: a cabeça de cada um (frente do modelo = +Z, cabeça no alto da frente).
	for i in 2:
		var c: Vector3 = pecas[i].position + Vector3(0, tamanho.y * 0.35, tamanho.z * 0.4)
		camera.position = c + Vector3(1.2, 0.2, 0.9)
		camera.look_at(c)
		await _foto(saida.path_join("perto_%s.png" % ["a", "b"][i]))
	# Quadro com cada um sozinho, vista de lado.
	camera.position = Vector3(alcance, tamanho.y * 0.6, 0)
	camera.look_at(Vector3(0, tamanho.y * 0.5, 0))
	for i in 2:
		pecas[i].visible = true
		pecas[1 - i].visible = false
		for k in 30:
			await process_frame
		var t0 := Time.get_ticks_usec()
		for k in 120:
			await process_frame
		print("QUADRO %s: %.2f ms" % [[a, b][i], (Time.get_ticks_usec() - t0) / 120000.0])
	quit()


func _foto(caminho: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(caminho))
