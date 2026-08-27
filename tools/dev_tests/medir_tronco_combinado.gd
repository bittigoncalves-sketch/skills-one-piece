extends SceneTree
# ============================================================================
#  O TOMBAMENTO APARECE NA COMBINAÇÃO, NÃO NA AÇÃO ISOLADA.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_tronco_combinado.gd
#
#  Rastro: isolados, TODOS passam — correr 12,7°, socar 6,4°, dash 2,0°, trocar
#  fruta 2,7°. Mas a bateria que encadeava as acoes mediu 51,0°, e o video do
#  dono mostra o boneco desmontado em jogo normal.
#
#  Ou seja: o defeito nasce da SOMA. O `ProceduralAnimator` acumula deslocamento
#  por papel (`_add(off, "Torso", ...)`) vindo de varias fontes — marcha,
#  corrida, pose de arma, balanco do corpo a corpo — e `play_baked` ainda
#  SOBREPOE o corpo inteiro por cima. Nenhuma fonte sozinha estoura; juntas,
#  estouram.
#
#  E por isso testar acao isolada nao encontrou nada: o portao errado nao e o
#  limite, e a COBERTURA. Este teste cobre as combinacoes que o jogador faz sem
#  pensar.
# ============================================================================

const LIMITE := 25.0
var _p: Node3D
var _torso: Node3D

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
	_torso = _achar(_p, "Torso")
	if _torso == null: print("❌ sem Torso"); quit(1); return
	_p.equip_fruit("mera_mera")

	print("=== combinações (ângulo do tronco com a vertical) ===")
	print("combinação                    |  máx  | quadros acima de %.0f°" % LIMITE)
	await _caso("andar + socar",            [KEY_W], true, "")
	await _caso("correr + socar",           [KEY_W, KEY_SHIFT], true, "")
	await _caso("correr + pular + socar",   [KEY_W, KEY_SHIFT, KEY_SPACE], true, "")
	await _caso("correr + dash + socar",    [KEY_W, KEY_SHIFT, KEY_Q], true, "")
	await _caso("andar de re + socar",      [KEY_S], true, "")
	await _caso("correr + skill Z",         [KEY_W, KEY_SHIFT], false, "Z")
	await _caso("correr + skill X",         [KEY_W, KEY_SHIFT], false, "X")
	await _caso("pular + socar",            [KEY_SPACE], true, "")
	await _caso("dash + socar",             [KEY_Q], true, "")
	quit()

func _caso(nome: String, teclas: Array, soco: bool, slot: String) -> void:
	_p.global_position = Vector3(0, 2.0, 0)
	_p.velocity = Vector3.ZERO
	_p._yaw = 0.0; _p._pitch = -0.25; _p._camera.apontar(0.0, -0.25)
	for i in 25: await process_frame
	for k in teclas: _tecla(k, true)
	for i in 12: await process_frame     # deixa a locomoção entrar em regime
	if soco:
		_mouse(true)
	elif slot != "":
		_p._skill_cooldowns[slot] = 0.0
		_p.energy = _p.max_energy
		_p._fire_skill(slot, Vector3(0, 0, -1), _p.global_position + Vector3.UP * 1.2)
	var maior := 0.0
	var acima := 0
	var pico := 0
	for q in 110:
		await process_frame
		if q == 5 and soco:
			_mouse(false)
		var cima: Vector3 = _torso.global_transform.basis.y.normalized()
		var ang := rad_to_deg(acos(clampf(cima.dot(Vector3.UP), -1.0, 1.0)))
		if ang > maior: maior = ang; pico = q
		if ang > LIMITE: acima += 1
	for k in teclas: _tecla(k, false)
	if soco: _mouse(false)
	for i in 30: await process_frame
	var v := "ok" if maior <= LIMITE else "❌ %d quadros (~%.2f s), pico no %d" % [acima, acima / 60.0, pico]
	print("%-29s | %5.1f | %s" % [nome, maior, v])

func _mouse(pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
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
