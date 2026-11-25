extends SceneTree
## Capturas do balanço do tórax no soco do Boss (guarda, carga, contato, recuperação),
## de frente e de cima, para os dois punhos.
func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(3).timeout
	var boss := get_first_node_in_group("boss") as Node3D
	var player := get_first_node_in_group("player") as Node3D
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = Vector3(30, 0.8, 30)
	boss.global_position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 40
	camera.make_current()
	for view in [["frente", Vector3(1.6, 2.3, -3.6)], ["cima", Vector3(0.01, 5.5, -0.4)]]:
		camera.global_position = view[1]
		camera.look_at(Vector3(0, 1.3, -0.3))
		for id in ["jab", "jab_right"]:
			boss.action_id = id
			var move: BossAbility = boss.presentation.current_move()
			for item in [["1_guarda", -1.0], ["2_carga", move.windup * 0.98], ["3_contato", move.windup + move.active * 0.6], ["4_recuperacao", move.windup + move.active + move.recovery * 0.5]]:
				boss.presentation.pose_at(item[1])
				await process_frame
				await RenderingServer.frame_post_draw
				boss.presentation.pose_at(item[1])
				var path := "res://art_src/validation/buggy_boss/torax/%s_%s_%s.png" % [view[0], move.hand, item[0]]
				print("CAPTURE ", path, " = ", root.get_texture().get_image().save_png(path))
	quit()
