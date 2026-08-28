extends SceneTree
# ============================================================================
#  O CORPO OLHA PARA A MIRA, MESMO ANDANDO PARA OUTRO LADO?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_facing.gd
#
#  Decisão do dono (2026-08-27): a frente do jogador segue SEMPRE a mira. Antes
#  seguia o MOVIMENTO — andar para o lado virava o corpo, e o adversário via as
#  costas de quem ia acertá-lo de lado. O golpe sempre saiu pelo `_yaw`
#  (`melee_controller`, skills); era o corpo que discordava dele.
#
#  A MEDIDA é o produto escalar entre a frente do MODELO e a direção da mira,
#  usando a convenção canônica do projeto (`RosaDosVentos.frente`). Tem de ser
#  ~+1 em toda combinação de rumo × direção de caminhada.
#
#  ⚠️ E é a MESMA medida que denunciou o bug do lunge em 2026-08-25 (dot = −1,00
#  em todo yaw). Direção se confere com produto escalar, não com opinião.
# ============================================================================

const TOL := 0.985      # ~10° de folga: a frente persegue a mira, não teleporta

var _ok_n := 0
var _falhas := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	p.set_meta("damage_immune", true)

	print("=== dot(frente do corpo, direção da mira) — tem de ser ~+1 ===")
	print("rumo | parado | W (frente) | S (ré) | A (esq) | D (dir) | W+D (diagonal)")
	for graus in [0, 45, 90, 135, 180, 225, 270, 315]:
		var yaw := deg_to_rad(float(graus))
		var linha := "%4d |" % graus
		var pior := 1.0
		for caso in [[], [KEY_W], [KEY_S], [KEY_A], [KEY_D], [KEY_W, KEY_D]]:
			var d := await _medir(p, yaw, caso)
			pior = minf(pior, d)
			linha += " %+.3f |" % d
		print(linha)
		_ok("rumo %d°: o corpo acompanha a mira em toda direção (pior %+.3f)" % [graus, pior],
			pior >= TOL)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _medir(p: Node3D, yaw: float, teclas: Array) -> float:
	p.global_position = Vector3(0, 2.0, 0)
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p._pitch = -0.2
	p._camera.apontar(yaw, -0.2)
	for k in teclas:
		_tecla(k, true)
	# tempo de sobra para a perseguição alcançar: o corpo persegue a mira, não
	# salta para ela — medir cedo demais mediria a rampa, não o resultado.
	for i in 70:
		await process_frame
		p._yaw = yaw
	for k in teclas:
		_tecla(k, false)
	var modelo: Node3D = p._char_model
	var frente_corpo: Vector3 = -modelo.global_transform.basis.z
	var frente_mira: Vector3 = RosaDosVentos.frente(yaw)
	for i in 15:
		await process_frame
	return frente_corpo.normalized().dot(frente_mira.normalized())


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
