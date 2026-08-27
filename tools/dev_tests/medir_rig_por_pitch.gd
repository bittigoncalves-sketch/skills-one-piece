extends SceneTree
# ============================================================================
#  O RIG QUEBRA EM FUNÇÃO DE PARA ONDE A CÂMERA OLHA?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_rig_por_pitch.gd
#
#  Os tres defeitos relatados pelo dono — ao olhar para tras, ao pular, e blocos
#  invisiveis — tem um suspeito em comum que eu ainda nao tinha testado: o
#  `_pitch` da camera e PASSADO PARA O ANIMADOR (`ProceduralAnimator.update`,
#  parametro `pitch`). Ou seja, para onde a camera olha muda a POSE do corpo.
#
#  Minhas sondas anteriores fixaram pitch em -0,25 ou -0,5 e por isso nunca
#  varreram essa dimensao. O jogador varre ela o tempo todo, com o mouse.
#
#  A faixa real e a do Player: `clamp(_pitch, -1.2, 0.5)` — de -1,2 (olhando
#  bem para baixo) a +0,5 (para cima).
#
#  Mede tres coisas por pitch, porque cada uma enxerga um defeito diferente:
#    • angulo do tronco com a vertical  -> corpo tombado
#    • extensao vertical do rig         -> corpo amassado
#    • altura da cabeca sobre os pes     -> cabeca afundando no corpo
# ============================================================================

var _p: Node3D
var _torso: Node3D
var _head: Node3D
var _ossos: Array = []
var _repouso := 0.0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000: await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar: placar.time_left = 1.0e9
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority(): _p = n; break
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true); e.global_position = Vector3(0, 1, -900)
	_torso = _achar(_p, "Torso"); _head = _achar(_p, "Head")
	for nome in ["Head", "Neck", "Torso", "UpperArm_R", "ForeArm_R", "UpperArm_L",
			"ForeArm_L", "Thigh_R", "Shin_R", "Foot_R", "Thigh_L", "Shin_L", "Foot_L"]:
		var no := _achar(_p, nome)
		if no: _ossos.append(no)
	_p.equip_fruit("mera_mera")
	_p.global_position = Vector3(0, 2.0, 0); _p.velocity = Vector3.ZERO
	_p._yaw = 0.0; _p._pitch = 0.0; _p._camera.apontar(0.0, 0.0)
	for i in 60: await process_frame
	_repouso = _extensao()
	print("altura de repouso: %.3f m" % _repouso)

	for correndo in [false, true]:
		print("\n=== %s ===" % ("CORRENDO" if correndo else "PARADO"))
		print("pitch  | tronco | altura do rig | cabeça acima dos pés")
		for pi in [0.5, 0.25, 0.0, -0.25, -0.5, -0.75, -1.0, -1.2]:
			await _caso(float(pi), correndo)
	quit()

func _caso(pitch: float, correndo: bool) -> void:
	_p.global_position = Vector3(0, 2.0, 0)
	_p.velocity = Vector3.ZERO
	_p._yaw = 0.0
	_p._pitch = pitch
	_p._camera.apontar(0.0, pitch)
	if correndo:
		_tecla(KEY_W, true); _tecla(KEY_SHIFT, true)
	for i in 40: await process_frame
	var ang_max := 0.0
	var ext_min := 1e9
	var cab_min := 1e9
	for q in 60:
		await process_frame
		_p._pitch = pitch
		_p._camera.apontar(0.0, pitch)
		var cima: Vector3 = _torso.global_transform.basis.y.normalized()
		ang_max = maxf(ang_max, rad_to_deg(acos(clampf(cima.dot(Vector3.UP), -1.0, 1.0))))
		ext_min = minf(ext_min, _extensao())
		if _head:
			var pe := 1e9
			for o in _ossos:
				pe = minf(pe, (o as Node3D).global_position.y)
			cab_min = minf(cab_min, _head.global_position.y - pe)
	if correndo:
		_tecla(KEY_W, false); _tecla(KEY_SHIFT, false)
	for i in 20: await process_frame
	var pct := 100.0 * ext_min / _repouso
	var marca := ""
	if ang_max > 25.0 or pct < 75.0 or cab_min < _repouso * 0.5:
		marca = "  ❌"
	print("%+5.2f | %5.1f° | %5.1f%% (%.3f m) | %.3f m%s" % [
		pitch, ang_max, pct, ext_min, cab_min, marca])

func _extensao() -> float:
	var alto := -1e9
	var baixo := 1e9
	for o in _ossos:
		var y: float = (o as Node3D).global_position.y
		alto = maxf(alto, y); baixo = minf(baixo, y)
	return alto - baixo

func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo; ev.keycode = codigo; ev.pressed = pressionada
	Input.parse_input_event(ev)

func _achar(raiz: Node, nome: String) -> Node3D:
	if raiz.name == nome and raiz is Node3D: return raiz
	for f in raiz.get_children():
		var r := _achar(f, nome)
		if r: return r
	return null
