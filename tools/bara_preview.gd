extends SceneTree
## Arena real com Bara equipada. -- --capture registra fases e custo do renderer.
## Captura desativa o Boss e o sparring; o launcher jogável conserva a arena.

const BARA := preload("res://src/combat/BaraController.gd")
const PICKUP := preload("res://src/world/BaraFruitPickup.gd")
const OUTPUT := "res://art_src/validation/bara_bara/captures"
var _actor: Node3D
var _dummy: Node3D
var _camera: Camera3D
var _start := Vector3.ZERO
var _metrics: Dictionary = {"baseline": [], "festival": [], "restored": []}
var _captured: Array[String] = []
var _errors: Array[String] = []
var _base_nodes: Dictionary = {}
var _peak_nodes: Dictionary = {}
var _measure_label := ""
var _measures_supported := false
var _skip_measure := 0

func _init() -> void:
	await process_frame
	var capturing := "--capture" in OS.get_cmdline_user_args()
	if capturing and DisplayServer.get_name() == "headless":
		push_error("Bara: capturas exigem renderer com janela; remova --headless.")
		quit(1)
		return
	if capturing:
		OS.set_environment("SOP_BOSS_ENABLED", "0")
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	if capturing:
		flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for node in get_nodes_in_group("player"):
			if node.is_multiplayer_authority():
				_actor = node
		if is_instance_valid(_actor) and _actor.get("_proc_anim") != null:
			break
	if not is_instance_valid(_actor):
		_fail("A arena não criou o jogador.")
		quit(1)
		return
	await create_timer(0.8).timeout
	_actor.equip_fruit("bara_bara")
	_actor.combat_mode = "fruit"
	var hud := get_first_node_in_group("hud")
	if hud:
		hud.update_combat_mode("fruit", _actor.estilo_atual(), "bara_bara")
	print("BARA BARA — Z Punho Destacado | X Pinça Bara | C Buggy Ball | V Festival Bara")
	if not capturing:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	create_timer(90.0).timeout.connect(func():
		_fail("Captura excedeu 90 segundos.")
		_write_report()
		quit(2))
	await _capture_sequence()

func _capture_sequence() -> void:
	for node in get_nodes_in_group("dummy"):
		if node.name == "TrainingDummy":
			_dummy = node
			break
	if _dummy == null:
		_fail("TrainingDummy ausente.")
		quit(1)
		return
	var scoreboard := get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.time_left = 300.0
	# Apenas o alvo de captura fica imóvel; os casts e a animação do player rodam.
	_dummy.set_physics_process(false)
	_actor.velocity = Vector3.ZERO
	_actor.rotation.y = 0.0
	_start = _actor.global_position
	_target(6.0)
	_camera = Camera3D.new()
	_camera.name = "CameraRevisaoBara"
	_camera.fov = 48.0
	current_scene.add_child(_camera)
	_camera.make_current()
	_measures_supported = RenderingServer.has_method("viewport_set_measure_render_time")
	if _measures_supported:
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_combat_view()
	await _save("00_equipada.png")
	var fruit := PICKUP.new()
	current_scene.add_child(fruit)
	fruit.global_position = _start + Vector3(2.8, -0.25, 0.0)
	_camera.fov = 36.0
	_view(fruit.global_position + Vector3(1.05, 0.58, 1.6), fruit.global_position + Vector3.UP * 0.30)
	await _save("01_fruta.png")
	fruit.queue_free()
	await process_frame
	_combat_view()
	_base_nodes = _bara_nodes()
	_peak_nodes = _base_nodes.duplicate()
	await _measure_frames("baseline", 50)
	var action := await _cast("Z", 9011)
	if action != null:
		await _until(action, 0.38)
		await _save("02_z_punho_ida.png")
		await _until(action, 0.78)
		await _save("03_z_retorno.png")
		await _finish(action)
	_target(5.8)
	action = await _cast("X", 9012)
	if action != null:
		await _until(action, 0.56)
		await _save("04_x_pinca.png")
		await _finish(action)
	_target(9.0)
	action = await _cast("C", 9013)
	if action != null:
		_view(_start + Vector3(3.8, 1.8, 2.5), _start + Vector3(0, -0.1, -0.8))
		await _until(action, 0.49)
		await _save("05_c_canhao_preparacao.png")
		_combat_view()
		await _until(action, 0.75)
		await _save("06_c_bala.png")
		var blast_deadline := Time.get_ticks_msec() + 4000
		while is_instance_valid(action) and Time.get_ticks_msec() < blast_deadline:
			await process_frame
			if action._emitted > 0 and not action._ball_active:
				await _save("07_c_explosao.png")
				break
		await _finish(action)
	_target(6.0)
	_combat_view()
	_measure_label = "festival"
	action = await _cast("V", 9014)
	if action != null:
		await _until(action, 0.73)
		await _save("08_v_alternado.png")
		await _until(action, 2.22)
		await _save("09_v_final.png")
		await _finish(action)
	_measure_label = ""
	await create_timer(0.95).timeout
	_combat_view()
	await _measure_frames("restored", 50)
	await _save("10_restaurado.png")
	var after := _bara_nodes()
	if int(after.actions) != int(_base_nodes.actions) or int(after.transients) != int(_base_nodes.transients):
		_fail("Nós de ação/efeitos Bara não voltaram à base: " + str(after))
	if BARA.action_for(_actor) != null or str(_actor.get_meta("custom_pose", "")).begins_with("bara_"):
		_fail("A ação/pose permaneceu após o kit.")
	_camera.queue_free()
	(_actor.get("_cam") as Camera3D).make_current()
	await _save("11_camera_jogador.png")
	_write_report(after)
	print("BARA CAPTURE COMPLETE files=", _captured.size(), " failures=", _errors.size(), " output=", OUTPUT)
	quit(0 if _errors.is_empty() else 1)

func _target(distance: float) -> void:
	_actor.global_position = _start
	_actor.velocity = Vector3.ZERO
	_dummy.global_position = _start + Vector3.FORWARD * distance
	_dummy.velocity = Vector3.ZERO
	_dummy.health = TrainingDummy.MAX_HP

func _cast(slot: String, token: int) -> Node:
	_actor._do_server_cast(slot, Vector3.FORWARD, _actor.global_position + Vector3.UP * 0.3,
		0.0, token, "fruit", "bara_bara")
	await process_frame
	var action := BARA.action_for(_actor)
	if action == null:
		_fail("Cast " + slot + " recusado: " + str(_actor.get_meta("bara_feedback", "sem mensagem")))
	return action

func _until(action: Node, time: float) -> void:
	while is_instance_valid(action) and not action.is_queued_for_deletion() and float(action.elapsed) < time:
		await process_frame
		_record_measure()
	_update_peak()

func _finish(action: Node) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(action) and Time.get_ticks_msec() < deadline:
		await process_frame
		_record_measure()
		_update_peak()
	if is_instance_valid(action):
		_fail("Ação não terminou no prazo.")
	await create_timer(0.1).timeout

func _combat_view() -> void:
	_camera.fov = 48.0
	_view(_start + Vector3(7.3, 4.1, 7.7), _start + Vector3(0, 0.15, -3.6))

func _view(position_value: Vector3, focus: Vector3) -> void:
	_camera.global_position = position_value
	_camera.look_at(focus)

func _save(file: String) -> void:
	# Freeze only the still's exposure: no different projectile timeline is used.
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT.path_join(file))
	paused = false
	_skip_measure = 3
	if result != OK:
		_fail("Erro ao salvar " + file + ": " + str(result))
	else:
		_captured.append(file)
	print("BARA CAPTURE ", file, " result=", result)

func _bara_nodes() -> Dictionary:
	var actions := get_nodes_in_group("bara_effect").size()
	var transient := 0
	var props := 0
	var pending: Array[Node] = [current_scene]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if str(node.name) in ["BaraHandTrail", "BaraImpact", "BaraBlast", "BaraMuzzle"]:
			transient += 1
		if str(node.name) in ["BaraCannon", "BaraBuggyBall", "BaraTrajectoryWarning"]:
			props += 1
		for child in node.get_children():
			pending.append(child)
	return {"actions": actions, "transients": transient, "props": props}

func _update_peak() -> void:
	var counts := _bara_nodes()
	for key in counts:
		_peak_nodes[key] = maxi(int(_peak_nodes.get(key, 0)), int(counts[key]))

func _measure_frames(label: String, count: int) -> void:
	_measure_label = label
	for index in count:
		await process_frame
		_record_measure()
	_measure_label = ""

func _record_measure() -> void:
	if _measure_label.is_empty():
		return
	if _skip_measure > 0:
		_skip_measure -= 1
		return
	var viewport := root.get_viewport_rid()
	var sample := {"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
	if _measures_supported:
		sample["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		sample["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	_metrics[_measure_label].append(sample)

func _write_report(after: Dictionary = {}) -> void:
	var summary := {}
	for label in _metrics:
		var samples: Array = _metrics[label]
		var values := {"samples": samples.size()}
		if not samples.is_empty():
			for key in samples[0]:
				var total := 0.0
				var peak := 0.0
				for sample in samples:
					total += float(sample[key])
					peak = maxf(peak, float(sample[key]))
				values[key + "_mean"] = total / samples.size()
				values[key + "_peak"] = peak
		summary[label] = values
	var report := {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(), "resolution": str(root.size),
		"avatar_override": OS.get_environment("SOP_TEST_CHARACTER_VISUAL"),
		"measurements": summary, "nodes_before": _base_nodes, "nodes_peak": _peak_nodes,
		"nodes_after": after, "captures": _captured, "errors": _errors,
		"limits": "One local player in the real arena; capture disables Boss/AutoDummy. Fixed camera for baseline/festival/restored. Render CPU/GPU timing excludes PNG encoding; no network/performance claim for multiple players."}
	var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))

func _fail(message: String) -> void:
	_errors.append(message)
	push_error("Bara preview: " + message)
