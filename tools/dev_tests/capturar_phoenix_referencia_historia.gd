extends "res://tools/dev_tests/test_phoenix.gd"
## Cena e entrada reais, progresso descartável e mouse liberado a cada quadro.
const SAIDA := "res://art_src/validation/phoenix_referencia_2026-10-14/historia/"
func _process(_delta: float) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var erro := root.get_texture().get_image().save_png(SAIDA+nome+".png")
	assert(erro == OK)
	print("HISTORIA_FOTO ",nome)
func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado","user://captura_fenix_referencia_descartavel.json")
	if OS.get_environment("PHOENIX_ENSAIO") == "1":
		modo.set("mapa_forcado","res://tools/dev_tests/fixtures/mapa_baseplate.json")
	root.get_node("GameFlow").start_story()
	await frames(150)
	p = get_first_node_in_group("player")
	assert(p != null)
	current_scene.progressao.comer_fruta("tori_tori_phoenix")
	p.combat_mode = "fruit"
	await frames(10)
	await cast("Z")
	await frames(50)
	await foto("01_camera_jogador_chao")
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 45
	cam.current = true
	var centro: Vector3 = p.global_position
	cam.global_position = centro+Vector3(5,3,-8)
	cam.look_at(centro+Vector3(0,1,.6))
	await foto("02_forma_chao")
	await cast("F")
	await frames(80)
	# Subir em voo real, sem substituir o controlador ou a pose do modelo.
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await frames(100)
	e.pressed = false
	Input.parse_input_event(e)
	centro = p.global_position
	cam.global_position = centro+Vector3(0,2,-17)
	cam.look_at(centro+Vector3(0,1,.2))
	await foto("03_forma_voo_frente")
	cam.global_position = centro+Vector3(10,4,-12)
	cam.look_at(centro+Vector3(0,1,1.2))
	await foto("04_forma_voo_tres_quartos")
	cam.current = false
	p._cam.make_current()
	await foto("05_camera_jogador_voo")
	# Simula somente o scroll já disponível, sem mudar a câmera de produção.
	p._camera.ajustar_distancia(7.0)
	await frames(75)
	await foto("06_camera_jogador_scroll")
	p._phoenix.cancelar()
	modo.set("mapa_forcado","")
	modo.set("progresso_forcado","")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_fenix_referencia_descartavel.json"))
	print("PHOENIX_HISTORIA_CAPTURE_OK")
	quit()
