extends SceneTree
## Captura reproduzível pela entrada real do jogador. YORU_CAPTURE_DIR define saída.
func _init() -> void:
	await process_frame
	var output := OS.get_environment("YORU_CAPTURE_DIR")
	if output.is_empty(): output = "/tmp/yoru-m1-capture"
	DirAccess.make_dir_recursive_absolute(output)
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(2.0).timeout
	var actor: Node3D
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority(): actor = p
	if actor == null:
		push_error("Yoru M1: jogador ausente")
		quit(1)
		return
	actor.set_combat_mode("sword")
	actor.set("_yaw", 0.0)
	var anchor := actor.global_position
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.global_position = anchor + Vector3(2.6,2.2,5.0)
	camera.look_at(anchor + Vector3(0,0.45,-0.7))
	camera.current = true
	var dummy := get_first_node_in_group("dummy") as Node3D
	if dummy:
		dummy.set_physics_process(false)
		dummy.global_position = anchor + Vector3.FORWARD*1.4
	await create_timer(0.2).timeout
	for attack in 2:
		actor._request_melee()
		var controller: YoruController = actor.get("_yoru_combat")
		var id := controller.action_id
		if id.is_empty():
			push_error("Yoru M1: input recusado")
			quit(1)
			return
		var frame := 0
		while controller.action_id != "":
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%s_%03d.png" % [id,frame]))
			frame += 1
		print("CAPTURE ",id," frames=",frame)
		await create_timer(0.12).timeout
	await create_timer(0.4).timeout
	quit()
