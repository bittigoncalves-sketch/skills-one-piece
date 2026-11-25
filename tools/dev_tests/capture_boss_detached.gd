extends SceneTree
func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(2).timeout
	var boss := get_first_node_in_group("boss") as Node3D
	var player := get_first_node_in_group("player") as Node3D
	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	player.position = Vector3(0, 0.8, -5)
	player.health = 99999
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(6, 5, -0.5)
	camera.look_at(Vector3(0, 0.8, -2.2))
	camera.fov = 48
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await physics_frame
	boss.presentation.present(0)
	await capture("attached")
	boss.combat._target = player
	boss.combat._start_move(4)
	var shots := {}
	for i in 180:
		boss.combat.tick(1.0 / 60.0)
		boss.combat.detached.tick(1.0 / 60.0)
		boss.presentation.present(1.0 / 60.0)
		var label: String = boss.part_state
		if boss.state == "windup" and boss.action_elapsed > 0.3:
			label = "telegraph"
		elif label == "outbound" and boss.part_transform.origin.distance_to(boss.position) < 2:
			continue
		if label != "attached" and not shots.has(label):
			shots[label] = true
			await capture(label)
	await capture("returned")
	# Close do encaixe real, com a mesma câmera para comparação antes/depois.
	camera.position = Vector3(1.8, 1.9, -2)
	camera.look_at(Vector3(0.2, 1.5, -0.25))
	camera.fov = 35
	await capture("wrist_attached")
	var source: Node3D = load("res://assets/models/bosses/buggy/buggyBoss.glb").instantiate()
	var arm := boss.presentation.model.find_child("tripo_part_8", true, false) as MeshInstance3D
	var prepared := arm.mesh
	arm.mesh = source.find_child("tripo_part_8", true, false).mesh
	boss.presentation.hand_binding.attached.visible = false
	await capture("wrist_original")
	arm.mesh = prepared
	boss.presentation.hand_binding.attached.visible = true
	source.free()
	boss.combat.detached.cooldown = 0
	boss.combat._target = player
	boss.combat._start_move(4)
	for i in 40:
		boss.combat.tick(1.0 / 60.0)
		boss.combat.detached.tick(1.0 / 60.0)
		boss.presentation.present(1.0 / 60.0)
	await capture("wrist_detached")
	quit()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://art_src/validation/buggy_detached/%s.png" % label)
	print("CAPTURE ", label, " = ", error)
	if error != OK:
		quit(1)
