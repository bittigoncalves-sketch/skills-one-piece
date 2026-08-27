extends SceneTree
# ============================================================================
#  O CORPO ENCOLHE? — a medida que descreve o que o vídeo mostra.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_corpo_encolhe.gd
#
#  ⚠️ MUDANÇA DE MEDIDA, e é o ponto desta sonda. Eu vinha medindo o ÂNGULO DO
#  TRONCO, porque era o número que o `ESQUELETO.md` já usava para os clipes
#  tombados. Mas o vídeo do dono não mostra só um tronco inclinado: mostra o
#  boneco ENCOLHIDO — pernas dobradas para dentro do corpo, cabeça afundada.
#  Ângulo de tronco não enxerga isso: dá para o corpo inteiro amassar com o
#  tronco perfeitamente em pé.
#
#  A medida certa é a EXTENSÃO VERTICAL: do ponto mais alto ao mais baixo do
#  rig. Em repouso ela é a altura do personagem; se o rig colapsa, ela despenca.
#  É independente de qual osso causou, que é justamente o que se quer quando
#  ainda não se sabe a causa.
# ============================================================================

const QUEDA_GRAVE := 0.75   # abaixo de 75% da altura de repouso = colapso

var _p: Node3D
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
	for nome in ["Head", "Neck", "Torso", "UpperArm_R", "ForeArm_R", "UpperArm_L",
			"ForeArm_L", "Thigh_R", "Shin_R", "Foot_R", "Thigh_L", "Shin_L", "Foot_L"]:
		var no := _achar(_p, nome)
		if no: _ossos.append(no)
	if _ossos.size() < 8:
		print("❌ só achei %d ossos" % _ossos.size()); quit(1); return
	_p.equip_fruit("mera_mera")
	_p.global_position = Vector3(0, 2.0, 0); _p.velocity = Vector3.ZERO
	_p._yaw = 0.0; _p._pitch = -0.25; _p._camera.apontar(0.0, -0.25)
	for i in 60: await process_frame
	_repouso = _extensao()
	print("altura em repouso: %.3f m  (%d ossos)" % [_repouso, _ossos.size()])
	print("=== extensão vertical do rig, como %% da altura de repouso ===")
	print("caso                          | mínimo | veredito")

	await _caso("parado",                   [], false)
	await _caso("correr",                   [KEY_W, KEY_SHIFT], false)
	await _caso("correr + socar",           [KEY_W, KEY_SHIFT], true)
	await _caso("correr + dash + socar",    [KEY_W, KEY_SHIFT, KEY_Q], true)
	await _caso("correr + pular + socar",   [KEY_W, KEY_SHIFT, KEY_SPACE], true)
	await _caso("socar repetido",           [], true, 4)
	await _caso("correr + socar repetido",  [KEY_W, KEY_SHIFT], true, 4)
	quit()

func _extensao() -> float:
	var alto := -1e9
	var baixo := 1e9
	for o in _ossos:
		var y: float = (o as Node3D).global_position.y
		alto = maxf(alto, y); baixo = minf(baixo, y)
	return alto - baixo

func _caso(nome: String, teclas: Array, soco: bool, socos := 1) -> void:
	_p.global_position = Vector3(0, 2.0, 0)
	_p.velocity = Vector3.ZERO
	_p._yaw = 0.0; _p._pitch = -0.25; _p._camera.apontar(0.0, -0.25)
	for i in 30: await process_frame
	for k in teclas: _tecla(k, true)
	for i in 12: await process_frame
	var menor := 1e9
	var pior := 0
	var quadros_ruins := 0
	for q in 150:
		if soco and q % 30 == 0 and q / 30 < socos:
			_mouse(true)
		if soco and q % 30 == 4:
			_mouse(false)
		await process_frame
		var e := _extensao()
		if e < menor: menor = e; pior = q
		if e < _repouso * QUEDA_GRAVE: quadros_ruins += 1
	for k in teclas: _tecla(k, false)
	_mouse(false)
	for i in 30: await process_frame
	var pct := 100.0 * menor / _repouso
	var v := "ok" if pct >= QUEDA_GRAVE * 100.0 else "❌ COLAPSA — %d quadros (~%.2f s), pior no %d" % [quadros_ruins, quadros_ruins / 60.0, pior]
	print("%-29s | %5.1f%% | %s" % [nome, pct, v])

func _mouse(pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pressionado
	Input.parse_input_event(ev)

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
