extends SceneTree
## Capturas (renderer real): Boss desviando de flecha de gelo com o dash e pulando
## projétil rasteiro com pulo duplo.
var boss: CharacterBody3D
var player: CharacterBody3D
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
	player.global_position = Vector3(60, 0.8, 60)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	camera = Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 50
	camera.make_current()
	var spot := Vector3(-30, 1.12, -30)
	await settle(spot)
	camera.global_position = spot + Vector3(-7, 2.4, 6)
	camera.look_at(spot + Vector3(0, 0.3, -1))
	await shot("1_parado")
	IceFX.bullet(current_scene, boss.global_position + Vector3(-10, 0.2, 0), Vector3.RIGHT, 1.0, player)
	await until_state(func(): return boss.mobility == BossMobility.DASH and boss.mobility_elapsed > 0.08, 1.0)
	await shot("2_dash")
	await settle(spot)
	boss.controller.mobility.dash_cooldown = 3.0
	var feet: float = boss.global_position.y - boss.definition.height * 0.5
	var low := DamageZone.new()
	current_scene.add_child(low)
	low.global_position = Vector3(boss.global_position.x - 9, feet + 0.5, boss.global_position.z)
	low.setup(1.0, 0.0, Vector3(24, 0, 0), 1.5, player, 0.4)
	await until_state(func(): return boss.mobility == BossMobility.JUMP and boss.jumps_used == 1 and boss.velocity.y > 4.0, 1.0)
	await shot("3_pulo")
	await until_state(func(): return boss.jumps_used == 2 and boss.velocity.y < 2.0, 1.5)
	await shot("4_pulo_duplo")
	quit()

func settle(point: Vector3) -> void:
	boss.controller.mobility.cancel(boss)
	boss.controller.brain.target = null
	boss.velocity = Vector3.ZERO
	boss.global_position = point
	boss.home_position = point
	boss.rotation = Vector3.ZERO
	for i in 40:
		await physics_frame
	while not boss.is_on_floor():
		await physics_frame
	boss.controller.mobility.cancel(boss)
	boss.controller.mobility.dash_cooldown = 0.0

func until_state(condition: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until and not condition.call():
		await physics_frame

## Sem congelar a física: congelar só o Boss deixava o projétil voando e acertando
## o corpo parado (e o jogava para cima).
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	print("CAPTURE ", label, " = ", root.get_texture().get_image().save_png("res://art_src/validation/buggy_boss/mobilidade/%s.png" % label), " mob=", boss.mobility, " jumps=", boss.jumps_used, " y=", boss.global_position.y)
