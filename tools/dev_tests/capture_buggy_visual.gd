extends SceneTree
## Captura A/B dos atores reais; execute com/sem SOP_TEST_CHARACTER_VISUAL.
## Precisa de renderer real. Não usa captura headless como evidência visual.
var tag := "original"

func _init() -> void:
	await process_frame
	if not OS.get_environment("SOP_TEST_CHARACTER_VISUAL").is_empty():
		tag = "buggy"
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(3.0).timeout
	var player := get_first_node_in_group("player") as CharacterBody3D
	var dummy := get_first_node_in_group("dummy") as CharacterBody3D
	if player == null or dummy == null:
		push_error("A arena não criou Player/Dummy")
		quit(1)
		return
	await _capture("gameplay")
	player.set_physics_process(false)
	dummy.set_physics_process(false)
	player.velocity = Vector3.ZERO
	dummy.velocity = Vector3.ZERO
	player.global_position = Vector3(1.0, 0.8, 0)
	dummy.global_position = Vector3(-1.0, 0.8, 0)
	if player.get("combat_mode") == "sword":
		player.call("_toggle_yoru_visual")
	var player_model := player.get("_char_model") as Node3D
	var dummy_model := dummy.get("_model") as Node3D
	player_model.rotation = Vector3.ZERO
	dummy_model.rotation = Vector3.ZERO
	for layer in root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Mesma câmera/luz de arena para original e override. Player à esquerda.
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(2.2, 2.0, -6.2)
	camera.look_at(Vector3(0, 0.75, 0))
	camera.fov = 42
	camera.make_current()
	await _capture("pair")
	var anim := player.get("_proc_anim") as ProceduralAnimator
	if anim:
		for i in 30:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
		await _capture("walk")
		anim.play_baked(Melee.clipe(0, ""), 1.0, 0.0)
		for i in 14:
			anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0, false)
		await _capture("punch")
		anim.play_baked(null)
		for i in 12:
			anim.update(Vector3(0, 4, 0), false, false, 1.0 / 60.0, 0.0, false)
		await _capture("jump_pose")
		for i in 12:
			anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0, false, false, "", "", false, 0.0, 0.0, -1, 0.0, "dano")
		await _capture("damage_pose")
	camera.position = Vector3(1.5, 1.3, -2.1)
	camera.look_at(Vector3(1.0, 0.9, 0))
	await _capture("detail")
	quit(0)

func _capture(view: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://art_src/validation/buggy/%s_%s.png" % [tag, view]
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " result=", error)
	if error != OK:
		quit(1)
