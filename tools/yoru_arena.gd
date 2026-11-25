extends SceneTree
## Arena real equipada; -- --capture executa os inputs e registra cada técnica.
var actor: Node3D
func _init() -> void:
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(2.0).timeout
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority(): actor = p
	if actor == null:
		push_error("Yoru: jogador não nasceu")
		quit(1)
		return
	actor.set_combat_mode("sword")
	print("YORU: M1 horizontal/vertical | Z Horizonte | X Predador | C Guarda | V Ruptura")
	if not "--capture" in OS.get_cmdline_user_args(): return
	create_timer(35).timeout.connect(func(): quit(2))
	root.size = Vector2i(1280,900)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.current = true
	var anchor := actor.global_position
	var dummy := get_first_node_in_group("dummy") as Node3D
	if dummy:
		dummy.set_physics_process(false)
		dummy.global_position = anchor+Vector3.FORWARD*5.0
	DirAccess.make_dir_recursive_absolute("res://art_src/previews/yoru_arena")
	for id in ["M1","M1","Z","X","C","V"]:
		actor.global_position = anchor
		actor.velocity = Vector3.ZERO
		await create_timer(0.1).timeout
		if id == "M1": actor._request_melee()
		else: actor.begin_charge(id)
		var actual: String = actor._yoru_combat.action_id
		if actual == "":
			push_error("Yoru captura: input recusado "+id)
			quit(1)
			return
		var data := YoruMoves.get_move(actual)
		var startup := float(data.startup)
		var peak := startup+float(data.active)*0.55
		var t := 0.0
		while t < YoruMoves.duration(actual)+0.06:
			camera.global_position = anchor+Vector3(4.0,2.5,-6.5)
			camera.look_at(anchor+Vector3(0,0.55,-1.5))
			var before := t
			await process_frame
			t += root.get_process_delta_time()
			if before <= peak and t > peak:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://art_src/previews/yoru_arena/"+actual+".png")
		print("YORU CAPTURE ",actual)
	quit()
