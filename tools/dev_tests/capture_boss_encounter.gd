extends SceneTree
func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	OS.set_environment("SOP_TEST_CHARACTER_TARGET", "player")
	OS.set_environment("SOP_TEST_CHARACTER_VISUAL", "res://assets/models/bosses/buggy/buggy_boss_visual.tres")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(3).timeout
	await capture("arena")
	var boss := get_first_node_in_group("boss") as Node3D
	var player := get_first_node_in_group("player") as Node3D
	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	player.position = Vector3(2, 0.8, -1.5)
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.position = Vector3(-3.8, 2.6, -5)
	camera.look_at(Vector3(0, 1.05, -0.3))
	camera.fov = 36
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var jab: BossAbility = boss.definition.ability
	var contact_time := jab.windup + jab.active * 0.6
	for item in [["guard", -1.0], ["windup", jab.windup * 0.95], ["contact", contact_time], ["recovery", jab.windup + jab.active + jab.recovery * 0.5]]:
		boss.presentation.pose_at(item[1])
		await capture(item[0])
	camera.position = Vector3(-4, 2.2, -1.2)
	camera.look_at(Vector3(0, 1.1, -0.3))
	boss.presentation.pose_at(contact_time)
	await capture("contact_side")
	boss.take_damage(99999)
	boss.presentation.present(0)
	await capture("death")
	quit()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://art_src/validation/buggy_boss/%s.png" % label
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", label, " = ", error)
	if error != OK:
		quit(1)
