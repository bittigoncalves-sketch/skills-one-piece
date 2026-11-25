extends "res://tools/dev_tests/test_magu_historia.gd"
## Captura do jogo real, com câmera de inspeção e sem capturar o mouse.
func _process(_delta: float) -> bool:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	return false
func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/magu/historia_%s.png" % nome)
func _rodar() -> void:
	await process_frame
	root.size=Vector2i(1280,720)
	modo=load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado","res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado","user://capturar_magu_historia.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p=get_first_node_in_group("player")
	current_scene.progressao.comer_fruta("magu_magu")
	await frames(10)
	p.combat_mode="fruit"
	alvo=Alvo.new()
	current_scene.add_child(alvo)
	var cam:=Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position=Vector3(9,6,10)
	cam.look_at(Vector3(0,1,-2))
	cam.current=true
	await _limpar()
	await _foto("antes")
	for tecla in ["Z","X","C","V"]:
		await _limpar()
		var e=await _cast(tecla)
		await frames(50 if tecla in ["Z","C"] else (80 if tecla=="X" else 210))
		if tecla=="V":
			cam.global_position=Vector3(13,12,14)
			cam.look_at(Vector3(0,0,-5))
		await _foto(tecla)
		if tecla=="C":
			var agua:=Mar.new()
			current_scene.add_child(agua)
			AguaDoMundo.registrar({"pecas":[]},agua)
			await frames(3)
			await _foto("pedra")
			AguaDoMundo.esquecer()
			agua.queue_free()
		if is_instance_valid(e): e.encerrar()
	modo.set("mapa_forcado","")
	modo.set("progresso_forcado","")
	quit()
