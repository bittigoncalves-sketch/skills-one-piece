extends SceneTree
## Capturas do combo de quatro socos com a marca de alcance no chão (renderer real).
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
	boss.position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	player.position = Vector3(0, 0.8, -1.2)
	player.health = 99999
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(-3.2, 4.2, -3.4)
	camera.look_at(Vector3(0, 0.4, -0.6))
	camera.fov = 40
	camera.make_current()
	await physics_frame
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	var shots := {}
	var frames := 0
	while boss.combat.busy() and frames < 400:
		frames += 1
		var move: BossAbility = boss.presentation.current_move()
		var key := "%d_%s_%s" % [boss.combo_index + 1, move.hand, boss.state]
		var mid_windup: bool = boss.state == "windup" and boss.action_elapsed >= move.windup * 0.6
		var full: bool = boss.state == "active" and boss.action_elapsed >= move.windup + move.active * 0.6
		if (mid_windup or full) and not shots.has(key):
			shots[key] = true
			boss.presentation.present(0.0)
			await capture(key)
		boss.combat.tick(1.0 / 60.0)
		boss.presentation.present(1.0 / 60.0)
	quit()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://art_src/validation/buggy_boss/combo/%s.png" % label
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", label, " = ", error)
