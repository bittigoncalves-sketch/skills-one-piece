extends SceneTree
## Captures the actual Player model and a walking pose in Godot.
## godot --path . --display-server x11 -s tools/base_v2_preview.gd
func _init() -> void:
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(3).timeout
	var player := get_first_node_in_group("player") as Node3D
	if player == null:
		push_error("Player unavailable")
		quit(1)
		return
	player.set_physics_process(false)
	var model := player.get("_char_model") as Node3D
	var anim := player.get("_proc_anim") as ProceduralAnimator
	for child in player.get_children():
		if child is Node3D and child != model:
			(child as Node3D).visible = false
	model.rotation = Vector3.ZERO
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.position = player.global_position + Vector3(2.2, 1.0, -4)
	camera.look_at(player.global_position + Vector3(0, -.02, 0), Vector3.UP)
	camera.make_current()
	# Use the real player's geometry/materials; remove HUD just for the captures.
	for node in root.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for role in anim._n:
		(anim._n[role] as Node3D).rotation = anim._rest[role]
	(anim._n.Torso as Node3D).position = anim._rest_torso_pos
	await _capture("base_v2_godot_rest.png")
	for i in 30:
		anim.update(Vector3(0, 0, -4.2), true, false, 1.0/60.0, 0, false)
	await _capture("base_v2_godot_walk.png")
	quit()

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png("res://art_src/previews/" + filename)
	print("CAPTURE ", filename)
