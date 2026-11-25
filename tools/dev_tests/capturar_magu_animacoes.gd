extends "res://tools/dev_tests/test_magu_historia.gd"
## Captura (com render) do soco do Z e do surfe do X, câmera de inspeção ao lado do jogador.
func _process(_delta: float) -> bool:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	return false
func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/magu/anim_%s.png" % nome)
func _rodar() -> void:
	await process_frame
	root.size=Vector2i(1280,720)
	modo=load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado","res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado","user://capturar_magu_anim.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p=get_first_node_in_group("player")
	current_scene.progressao.comer_fruta("magu_magu")
	await frames(10)
	p.combat_mode="fruit"
	alvo=Alvo.new()
	current_scene.add_child(alvo)
	alvo.position=Vector3(300,1,300)
	var cam:=Camera3D.new()
	current_scene.add_child(cam)
	cam.current=true
	await _limpar()
	alvo.position=Vector3(300,1,300)
	var ponto: Vector3=p.global_position
	# Câmera à DIREITA do jogador (o braço do soco), olhando de lado.
	cam.global_position=ponto+Vector3(5,1.6,0)
	cam.look_at(ponto+Vector3(0,1.2,0))
	# Poses do Z isoladas (sem o punho de lava na frente), de lado e da frente.
	for pose in ["magu_z_prep","magu_z_soco"]:
		p.set_meta("custom_pose",pose)
		await frames(25)
		await _foto(pose+"_lado")
		cam.global_position=ponto+Vector3(0,1.6,-5)
		cam.look_at(ponto+Vector3(0,1.2,0))
		await _foto(pose+"_frente")
		cam.global_position=ponto+Vector3(5,1.6,0)
		cam.look_at(ponto+Vector3(0,1.2,0))
	p.remove_meta("custom_pose")
	await _limpar()
	alvo.position=Vector3(300,1,300)
	await _cast("X")
	await frames(60)
	cam.global_position=p.global_position+Vector3(-4,1.4,2.5)
	cam.look_at(p.global_position+Vector3(0,.9,0))
	await _foto("X_surf_a")
	await frames(40)
	cam.global_position=p.global_position+Vector3(0,2.5,5)
	cam.look_at(p.global_position+Vector3(0,.9,-1))
	await _foto("X_surf_b")
	quit(0)
