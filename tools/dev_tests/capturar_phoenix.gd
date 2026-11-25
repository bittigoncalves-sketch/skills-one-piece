extends "res://tools/dev_tests/test_phoenix.gd"
## Captura na cena real, sem capturar o mouse ou alterar o save do jogador.
func _process(_delta: float) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/phoenix/%s.png" % nome)
func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1280,720)
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://capturar_phoenix.json")
	root.get_node("GameFlow").start_story()
	await frames(100)
	p = get_first_node_in_group("player")
	current_scene.progressao.comer_fruta("tori_tori_phoenix")
	await frames(10)
	p.combat_mode = "fruit"
	alvo = Alvo.new()
	current_scene.add_child(alvo)
	await preparar()
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position = Vector3(7,4,-10)
	cam.look_at(Vector3(0,1.1,0))
	cam.current = true
	await foto("antes")
	await cast("Z")
	await frames(35)
	await foto("transformacao")
	cam.global_position = p.global_position + Vector3(0,2,-11)
	cam.look_at(p.global_position + Vector3(0,1.3,0))
	await foto("frente")
	cam.global_position = p.global_position + Vector3(8,3,7)
	cam.look_at(p.global_position + Vector3(0,0.8,1.5))
	await foto("caudas")
	cam.global_position = Vector3(7,4,-10)
	cam.look_at(p.global_position + Vector3.UP)
	await cast("F")
	await frames(40)
	cam.look_at(p.global_position)
	await foto("voo")
	for tecla in ["X","C","V"]:
		await preparar()
		await cast("Z")
		await frames(35)
		p.energy = p.max_energy
		cam.global_position = Vector3(9,5,-10)
		cam.look_at(Vector3(0,1,-3))
		await cast(tecla)
		await frames(22 if tecla == "X" else (16 if tecla == "C" else 45))
		cam.global_position = p.global_position + Vector3(10,6,-12)
		cam.look_at(p.global_position + Vector3.UP)
		await foto(tecla)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
