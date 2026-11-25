extends SceneTree
## Capturas (renderer real): flash de dano no jogador e no Boss; jogador arremessado
## pelo último golpe voando, deitado e levantando.
var boss: CharacterBody3D
var player: CharacterBody3D
var camera: Camera3D
var shots := {}

func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(3).timeout
	boss = get_first_node_in_group("boss")
	player = get_first_node_in_group("player")
	player.health = 99999
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	camera = Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 45
	camera.make_current()
	boss.global_position = Vector3(0, 1.12, 0)
	boss.rotation = Vector3.ZERO
	player.global_position = Vector3(0, 0.8, -1.2)
	boss.combat.detached.cooldown = 30.0   # 4 socos: o 4º arremessa (enquadramento mais curto)
	var t0 := Time.get_ticks_msec()
	var flashed := false
	while Time.get_ticks_msec() - t0 < 8000:
		await physics_frame
		var intensity := 0.0
		if player._char_model.has_meta("_flash_dano_mat"):
			var value = (player._char_model.get_meta("_flash_dano_mat") as ShaderMaterial).get_shader_parameter("intensidade")
			intensity = float(value) if value != null else 0.0
		if not flashed and intensity > 0.8:
			flashed = true
			await shot("1_flash_jogador", Vector3(-2.6, 1.6, -2.6), player.global_position + Vector3.UP * 0.8)
		if player.esta_arremessado():
			var fase: String = player._arremesso.fase
			if fase == PlayerArremesso.LAUNCHED and player._arremesso.tempo > 0.25:
				await shot("2_voo", Vector3(4.5, 1.2, 0.6), player.global_position + Vector3.UP * 0.3)
			elif fase == PlayerArremesso.KNOCKDOWN and player._arremesso.tempo > 0.5:
				await shot("3_deitado", Vector3(3.8, 1.6, 0.4), player.global_position)
			elif fase == PlayerArremesso.GETUP and player._arremesso.tempo > 0.35:
				await shot("4_levantando", Vector3(3.8, 1.4, 0.4), player.global_position + Vector3.UP * 0.4)
		elif shots.has("4_levantando"):
			break
	# Flash no Boss, no pico da piscada.
	boss.set_physics_process(false)
	await create_timer(0.8).timeout
	var hit := DamageZone.new()
	current_scene.add_child(hit)
	hit.setup(5, 0, Vector3.ZERO, 1, player, 0.3)
	hit.monitoring = false
	hit._on_body(boss)
	boss._physics_process(0.016)
	var mat: ShaderMaterial = boss.presentation.model.get_meta("_flash_dano_mat")
	var wait_until := Time.get_ticks_msec() + 500
	while (mat.get_shader_parameter("intensidade") == null or float(mat.get_shader_parameter("intensidade")) < 0.8) and Time.get_ticks_msec() < wait_until:
		await process_frame
	await shot("5_flash_boss", boss.global_position + Vector3(2.2, 0.9, -3.4), boss.global_position + Vector3.UP * 0.2, true)
	quit()

func shot(label: String, offset: Vector3, focus: Vector3, absolute := false) -> void:
	if shots.has(label):
		return
	shots[label] = true
	var running_player := player.is_physics_processing()
	var running_boss := boss.is_physics_processing()
	player.set_physics_process(false)
	boss.set_physics_process(false)
	camera.global_position = offset if absolute else focus + offset
	camera.look_at(focus)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://art_src/validation/buggy_boss/arremesso_flash/%s.png" % label)
	print("CAPTURE ", label, " = ", error)
	player.set_physics_process(running_player)
	boss.set_physics_process(running_boss)
