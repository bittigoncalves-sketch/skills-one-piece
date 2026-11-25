extends SceneTree
## Abre a arena real com Ope equipada. -- --capture salva fases reproduzíveis.
## Nenhum ajuste de dano, cooldown ou render do jogo é aplicado na versão jogável.

const OUTPUT := "res://multimodal/cache/ope-validation/captures"
var _actor: Node3D
var _dummy: Node3D
var _camera: Camera3D

func _init() -> void:
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for node in get_nodes_in_group("player"):
			if node.is_multiplayer_authority():
				_actor = node
		if is_instance_valid(_actor) and _actor.get("_proc_anim") != null:
			break
	if not is_instance_valid(_actor):
		push_error("Ope: a arena não criou o jogador.")
		quit(1)
		return
	await create_timer(0.7).timeout
	_actor.equip_fruit("ope_ope")
	_actor.combat_mode = "fruit"
	var hud := get_first_node_in_group("hud")
	if hud:
		hud.update_combat_mode("fruit", _actor.estilo_atual(), "ope_ope")
	print("OPE OPE — Z ROOM | X Shambles | C Takt | V Gamma Knife")
	if not "--capture" in OS.get_cmdline_user_args():
		return
	create_timer(55.0).timeout.connect(func():
		push_error("Captura Ope excedeu 55 segundos.")
		quit(2))
	await _capture_sequence()

func _capture_sequence() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await create_timer(1.0).timeout
	for node in get_nodes_in_group("dummy"):
		if node.name == "TrainingDummy":
			_dummy = node
			break
	if _dummy == null:
		_dummy = get_first_node_in_group("dummy") as Node3D
	if _dummy == null:
		push_error("Ope: alvo de treino ausente.")
		quit(1)
		return
	var scoreboard := get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.time_left = 300.0
	_dummy.set_physics_process(false)
	_actor.velocity = Vector3.ZERO
	var start := _actor.global_position
	_dummy.global_position = start + Vector3.FORWARD * 7.0
	_camera = Camera3D.new()
	_camera.name = "CameraRevisaoOpe"
	_camera.fov = 58.0
	current_scene.add_child(_camera)
	_camera.make_current()
	_view(start + Vector3(8, 4, 9), start + Vector3.FORWARD * 2.5)
	await _save("00_equipada.png")
	_actor._do_server_cast("Z", Vector3.FORWARD, start + Vector3.UP, 0.0, 9001, "fruit", "ope_ope")
	await create_timer(0.34).timeout
	await _save("01_room_abertura.png")
	await create_timer(0.7).timeout
	_view(start + Vector3(29, 21, 31), start + Vector3.UP * 1.0)
	await _save("02_room_completa.png")
	_view(start + Vector3(8, 4, 9), start + Vector3.FORWARD * 3.5)
	_actor._do_server_cast("C", Vector3.FORWARD, _actor.global_position + Vector3.UP, 0.0, 9002, "fruit", "ope_ope")
	await create_timer(0.50).timeout
	await _save("03_takt_suspensao.png")
	await create_timer(0.30).timeout
	await _save("04_takt_arremesso.png")
	await create_timer(1.7).timeout
	_actor._do_server_cast("V", Vector3.FORWARD, _actor.global_position + Vector3.UP, 0.0, 9003, "fruit", "ope_ope")
	await create_timer(0.27).timeout
	await _save("05_gamma_preparacao.png")
	await create_timer(0.17).timeout
	await _save("06_gamma_impacto.png")
	await create_timer(1.0).timeout
	_actor.global_position = start
	_actor.velocity = Vector3.ZERO
	_dummy.global_position = start + Vector3.FORWARD * 7.0
	await physics_frame
	_actor._do_server_cast("X", Vector3.FORWARD, start + Vector3.UP, 0.0, 9004, "fruit", "ope_ope")
	await create_timer(0.39).timeout
	await _save("07_shambles.png")
	await create_timer(0.8).timeout
	_camera.queue_free()
	(_actor.get("_cam") as Camera3D).make_current()
	await _save("08_camera_jogador.png")
	print("Ope: capturas do jogo salvas em ", OUTPUT)
	quit(0)

func _view(position_value: Vector3, focus: Vector3) -> void:
	_camera.global_position = position_value
	_camera.look_at(focus)

func _save(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var snapshot := root.get_texture().get_image()
	var result := snapshot.save_png(OUTPUT.path_join(file))
	print("OPE CAPTURE ", file, " result=", result)
