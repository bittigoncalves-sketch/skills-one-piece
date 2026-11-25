extends SceneTree
## Abre a arena real com a Mera equipada. `-- --capture` salva as fases em PNG.
##
## Espelha `tools/ope_preview.gd`: mesma arena, mesmo canal de cast, câmera de
## revisão só no modo captura. Existe porque contagem de vértice não prova que o
## fogo FICOU BOM — para isso é preciso olhar, e olhar precisa de imagem.
##
## ⚠️ PRECISA DE TELA (não use `--headless`): sem servidor de vídeo não há
## `frame_post_draw`, e a captura sai preta ou não sai.

const OUTPUT := "res://multimodal/cache/mera-validation/captures"
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
		push_error("Mera: a arena não criou o jogador.")
		quit(1)
		return
	await create_timer(0.7).timeout
	_actor.equip_fruit("mera_mera")
	_actor.combat_mode = "fruit"
	var hud := get_first_node_in_group("hud")
	if hud:
		hud.update_combat_mode("fruit", _actor.estilo_atual(), "mera_mera")
	print("MERA MERA — Z Higan | X Hiken | C Vagalumes | V Entei")
	if not "--capture" in OS.get_cmdline_user_args():
		return
	create_timer(70.0).timeout.connect(func():
		push_error("Captura Mera excedeu 70 segundos.")
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
		push_error("Mera: alvo de treino ausente.")
		quit(1)
		return
	var scoreboard := get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.time_left = 300.0
	_dummy.set_physics_process(false)
	_actor.velocity = Vector3.ZERO
	var start := _actor.global_position
	_dummy.global_position = start + Vector3.FORWARD * 9.0

	_camera = Camera3D.new()
	_camera.name = "CameraRevisaoMera"
	_camera.fov = 58.0
	current_scene.add_child(_camera)
	_camera.make_current()

	_view(start + Vector3(6, 3, 7), start + Vector3.FORWARD * 2.0)
	await _save("00_equipada.png")

	# Z — o clarão de cano é curto (0,22 s): a captura tem que cair logo depois
	# do disparo, senão fotografa o vazio.
	_actor._do_server_cast("Z", Vector3.FORWARD, start + Vector3.UP, 0.0, 8101, "fruit", "mera_mera")
	await create_timer(0.10).timeout
	await _save("01_higan_clarao.png")
	await create_timer(0.22).timeout
	await _save("02_higan_rastro.png")

	# X — o punho voa a 25 m/s; perto da saída ele ainda está enquadrado.
	await create_timer(1.2).timeout
	_actor.global_position = start
	_actor.velocity = Vector3.ZERO
	await physics_frame
	_view(start + Vector3(5, 2.5, 6), start + Vector3.FORWARD * 3.0)
	_actor._do_server_cast("X", Vector3.FORWARD, start + Vector3.UP, 0.0, 8102, "fruit", "mera_mera")
	await create_timer(0.12).timeout
	await _save("03_hiken_punho.png")
	await create_timer(0.30).timeout
	await _save("04_hiken_voo.png")
	await create_timer(0.55).timeout
	await _save("05_hiken_explosao.png")

	# C — a nuvem nasce em volta do conjurador; a câmera abre para caber.
	await create_timer(1.4).timeout
	_view(start + Vector3(13, 8, 14), start + Vector3.UP * 1.5)
	_actor._do_server_cast("C", Vector3.FORWARD, start + Vector3.UP, 0.0, 8103, "fruit", "mera_mera")
	await create_timer(0.8).timeout
	await _save("06_vagalumes_nuvem.png")
	await create_timer(2.2).timeout
	await _save("07_vagalumes_cascata.png")

	# V — o sol cresce com a carga; duas fotos mostram o `heat` subindo.
	await create_timer(2.0).timeout
	_actor.global_position = start
	_actor.velocity = Vector3.ZERO
	await physics_frame
	_view(start + Vector3(11, 9, 12), start + Vector3.UP * 7.0)
	_actor._do_server_cast("V", Vector3.FORWARD, start + Vector3.UP, 0.4, 8104, "fruit", "mera_mera")
	await create_timer(0.35).timeout
	await _save("08_entei_carga.png")
	await create_timer(0.7).timeout
	_view(start + Vector3(14, 7, 15), start + Vector3.FORWARD * 6.0)
	await _save("09_entei_voo.png")
	await create_timer(1.6).timeout
	await _save("10_entei_explosao.png")

	await create_timer(1.0).timeout
	_camera.queue_free()
	var cam := _actor.get("_cam") as Camera3D
	if cam != null:
		cam.make_current()
	await _save("11_camera_jogador.png")
	print("Mera: capturas do jogo salvas em ", OUTPUT)
	quit(0)


func _view(position_value: Vector3, focus: Vector3) -> void:
	_camera.global_position = position_value
	_camera.look_at(focus)


func _save(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var snapshot := root.get_texture().get_image()
	var result := snapshot.save_png(OUTPUT.path_join(file))
	if result != OK:
		push_error("Mera: falhou ao salvar %s (erro %d)" % [file, result])
