extends SceneTree
## Capturas da recepção de M1 do Boss (renderer real): tranco 1 e 2, voo, chão, levantar.
var boss: CharacterBody3D
var player: CharacterBody3D
var shots := {}
var camera: Camera3D

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
	player.set_physics_process(false)
	player.health = 99999
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	camera = Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 45
	camera.make_current()
	boss.global_position = Vector3(0, 1.12, 0)
	boss.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.8, -1.5)
	await physics_frame
	for step in 3:
		boss.global_position.x = 0
		player.global_position.x = 0
		Melee.golpear(current_scene, player, step, player.global_position + Vector3.UP * 0.5, Vector3.BACK)
		await watch(Melee.startup(step) + 0.7, step)
	var deadline := Time.get_ticks_msec() + 4000
	while boss.reaction != "" and Time.get_ticks_msec() < deadline:
		await physics_frame
		await shoot_phase()
	await capture("5_de_pe")
	quit()

func watch(duration: float, step: int) -> void:
	var until := Time.get_ticks_msec() + int(duration * 1000)
	while Time.get_ticks_msec() < until:
		await physics_frame
		if step < 2 and boss.reaction == BossHitReaction.STAGGER and boss.reaction_elapsed >= 0.1 and not shots.has(step):
			shots[step] = true
			await capture("%d_tranco_%d" % [step + 1, step + 1])
		if step == 2:
			await shoot_phase()

func shoot_phase() -> void:
	var key := ""
	if boss.reaction == BossHitReaction.LAUNCHED and boss.reaction_elapsed >= 0.28:
		key = "3_voo"
	elif boss.reaction == BossHitReaction.KNOCKDOWN and boss.reaction_elapsed >= 0.5:
		key = "4_deitado"
	elif boss.reaction == BossHitReaction.GETUP and boss.reaction_elapsed >= 0.35:
		key = "4b_levantando"
	if key != "" and not shots.has(key):
		shots[key] = true
		await capture(key)

func capture(label: String) -> void:
	# Pausa a simulação só durante a foto, para a fase não andar.
	var paused := boss.is_physics_processing()
	boss.set_physics_process(false)
	# Câmera de lado, acompanhando o Boss (voa para +Z, jogador fica em -Z).
	var focus := boss.global_position + Vector3(0, -0.2, -0.6)
	camera.global_position = focus + Vector3(4.6, 1.3, 0.4)
	camera.look_at(focus)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://art_src/validation/buggy_boss/recepcao/%s.png" % label)
	print("CAPTURE ", label, " = ", error, " reaction=", boss.reaction, " pos=", boss.global_position)
	boss.set_physics_process(paused)
