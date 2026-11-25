extends SceneTree
## Capturas do corte do Boss (renderer real): poses do arremesso de lado e de frente,
## e a linha vermelha + a frente em voo numa execução real.
func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(3).timeout
	var boss := get_first_node_in_group("boss") as CharacterBody3D
	var player := get_first_node_in_group("player") as CharacterBody3D
	boss.set_physics_process(false)
	player.set_physics_process(false)
	player.health = 99999
	player.global_position = Vector3(40, 0.8, 40)
	boss.global_position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 42
	camera.make_current()
	var slash: BossSlashAbility = boss.definition.slash
	boss.action_id = str(slash.id)
	var poses := [["1_mira", slash.aim_time], ["2_carregado", slash.windup * 0.8], ["3_impulso", slash.windup], ["4_por_cima", slash.windup + slash.active * 0.45], ["5_soltou", slash.windup + slash.active], ["6_acompanha", slash.windup + slash.active + slash.recovery * 0.4]]
	for view in [["lado", Vector3(4.2, 1.5, -0.2)], ["frente", Vector3(1.8, 1.7, -4.0)]]:
		camera.global_position = view[1]
		camera.look_at(Vector3(0, 1.0, 0))
		for item in poses:
			boss.presentation.pose_at(item[1])
			await shot("%s_%s" % [view[0], item[0]])
	boss.action_id = ""
	# Execução real: jogador foge, linha aparece, corte sai.
	boss.presentation.pose_at(-1)
	boss.set_physics_process(true)
	player.global_position = Vector3(0, 0.8, -5)
	boss.controller.brain.target = player
	camera.global_position = Vector3(6.5, 7.5, 3.0)
	camera.look_at(Vector3(0, 0, -6))
	camera.fov = 60
	var line_done := false
	var wave_done := false
	for i in 240:
		await physics_frame
		if boss.action_id != str(slash.id):
			player.global_position.z -= 4.5 / 60.0
		elif not line_done and boss.action_elapsed >= slash.windup - 0.1:
			line_done = true
			await shot("7_linha")
		elif line_done and not wave_done and boss.action_elapsed >= slash.windup + 0.25:
			wave_done = true
			await shot("8_corte_em_voo")
			break
	quit()

func shot(label: String) -> void:
	var boss := get_first_node_in_group("boss") as Node3D
	var running := boss.is_physics_processing()
	boss.set_physics_process(false)
	for wave in get_nodes_in_group(BossCombat.SLASH_GROUP):
		wave.set_physics_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://art_src/validation/buggy_boss/corte/%s.png" % label
	print("CAPTURE ", label, " = ", root.get_texture().get_image().save_png(path))
	boss.set_physics_process(running)
	for wave in get_nodes_in_group(BossCombat.SLASH_GROUP):
		wave.set_physics_process(true)
