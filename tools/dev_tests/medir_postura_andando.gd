extends SceneTree
# Mede quanto cada osso balança ao CORRER/ANDAR: com a postura do machado e sem ela.
#   godot --headless --path . --script tools/dev_tests/medir_postura_andando.gd
const PAPEIS := ["Torso", "SpineMid", "Head", "Thigh_L", "Thigh_R", "Shin_L", "Arm_L", "Arm_R", "UpperArm_L", "UpperArm_R", "Elbow_L", "Elbow_R", "Wrist_R"]
var p: Node3D
func _init() -> void: _run.call_deferred()
func _f(n: int) -> void:
	for i in n: await physics_frame
func _tecla(k: Key, v: bool) -> void:
	var ev := InputEventKey.new(); ev.physical_keycode = k; ev.keycode = k; ev.pressed = v
	Input.parse_input_event(ev)
func _medir(rotulo: String, sprint: bool) -> void:
	var m: Node3D = p.modelo_visual()
	var ult := {}; var salto := {}; var ref := {}; var exc := {}
	if sprint: _tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	await _f(40)
	for i in 90:
		await process_frame
		for papel in PAPEIS:
			var n := m.find_child(papel, true, false) as Node3D
			if n == null: continue
			var q := n.quaternion
			if ult.has(papel):
				salto[papel] = maxf(salto.get(papel, 0.0), rad_to_deg(q.angle_to(ult[papel])))
				exc[papel] = maxf(exc.get(papel, 0.0), rad_to_deg(q.angle_to(ref[papel])))
			else:
				ref[papel] = q
			ult[papel] = q
	_tecla(KEY_W, false); _tecla(KEY_SHIFT, false)
	var s := "%s  v=%.1f\n" % [rotulo, Vector2(p.velocity.x, p.velocity.z).length()]
	for papel in ult:
		s += "   %-11s excursao %6.1f   maior salto/quadro %5.1f\n" % [papel, exc.get(papel, 0.0), salto.get(papel, 0.0)]
	print(s)
	p.global_position = Vector3(0, 0.8, 0); p.velocity = Vector3.ZERO
	await _f(40)
func _run() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = "user://medir_postura.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://medir_postura.json"))
	root.get_node("GameFlow").start_story()
	await _f(120)
	p = get_first_node_in_group("player")
	await _f(200)
	await _medir("SEM arma (punho, neutro)", false)
	await _medir("SEM arma correndo", true)
	var inv: Node = current_scene._hud.inventario()
	inv.mostrar_aba("armas")
	inv.find_child("EquiparMachado", true, false).pressed.emit()
	await _f(60)
	var ex = p.combate_direcional
	print("estilo=", ex.estilo.id, " peso_pose=", ex.peso_da_pose())
	await _medir("COM machado andando", false)
	await _medir("COM machado correndo", true)
	quit()
