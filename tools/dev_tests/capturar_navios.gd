extends SceneTree
# ============================================================================
#  NAVIOS NO MAPA VIVO — inventário + fotos (03/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_navios.gd -- <pasta>
#
#  Sobe o Modo História com o MAPA DE VERDADE (mapas/historia/baseplate.json), lista
#  os navios que viraram barcos vivos e confere, para cada um, se flutua na água
#  (ou fica parado se o dono o pôs em terra). Depois embarca no primeiro com Y,
#  acelera e fotografa (de lado e de trás). Sem pasta, só mede.
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else ""
	# Progresso de TESTE: nunca o save da campanha do dono.
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://capturar_navios.json")
	get_root().get_node("GameFlow").start_story()
	for i in 180:
		await physics_frame
	var p: Node3D = get_first_node_in_group("player")
	var nav = current_scene.get("_navegacao")
	p.set_meta("damage_immune", true)
	var barcos: Array = nav.barcos
	print("barcos vivos no mapa: %d" % barcos.size())
	_ok("o mapa vivo tem barcos dirigíveis", barcos.size() > 0)
	var poses: Array[Transform3D] = []
	for b in barcos:
		poses.append(b.global_transform)
	for i in 240:
		await physics_frame
	var na_agua: Array = []
	for indice in barcos.size():
		var b: CharacterBody3D = barcos[indice]
		_ok("%s sem piloto fica estacionado" % b.name, not b.is_physics_processing() and b.global_transform.is_equal_approx(poses[indice]))
		var h := AguaDoMundo.superficie_em(b.global_position.x, b.global_position.z)
		var d: float = b.global_position.y - h if not is_nan(h) else NAN
		print("   %-24s %-12s em %s  água: %s  desvio %s" % [b.name, b.modelo_id, b.global_position.snapped(Vector3.ONE * 0.1), b.esta_na_agua(), "%.2f" % d if not is_nan(d) else "terra"])
		if b.esta_na_agua():
			na_agua.append(b)
	if na_agua.is_empty():
		quit(1 if _falhas else 0)
		return
	var b: CharacterBody3D = na_agua[0]
	p.global_position = b.leme.global_position + Vector3.UP * 0.85 + b.global_basis.z * 0.8
	p.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	await _toque(KEY_Y)
	_ok("Y assume o leme de %s" % b.name, nav.ativo())
	_tecla(KEY_W, true)
	for i in 150:
		await physics_frame
	if not saida.is_empty():
		var cam := Camera3D.new()
		current_scene.add_child(cam)
		cam.fov = 50
		cam.make_current()
		var tam: Vector3 = b.tamanho_casco
		var dist := maxf(tam.z * 1.4, 8.0)
		for vista in [["lado", b.global_basis.x * dist + Vector3.UP * dist * 0.35], ["tras", b.global_basis.z * dist + Vector3.UP * dist * 0.45]]:
			cam.global_position = b.global_position + vista[1]
			cam.look_at(b.global_position + Vector3.UP * 1.0)
			for i in 3:
				await physics_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida.path_join("navio_%s.png" % vista[0]))
	_tecla(KEY_W, false)
	print("\nNAVIOS_MAPA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas else 0)


func _toque(k: Key) -> void:
	_tecla(k, true)
	await physics_frame
	_tecla(k, false)
	await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)
