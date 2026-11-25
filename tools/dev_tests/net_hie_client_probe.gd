extends SceneTree
# ============================================================================
#  HIE REFEITA EM REDE — LADO CLIENTE (2 processos). É o ALVO e quem MEDE (07/10/2026).
#
#  No próprio corpo (o que o cliente move): o congelamento pedido pelo servidor chega
#  (`is_frozen`), dura ~0,7 s e, com W apertado, o corpo não anda enquanto isso; depois o
#  Z novo do host congela de novo (o acerto é do servidor; o gelo chega pela rede).
#
#    (depois do host) godot --headless --path . --script tools/dev_tests/net_hie_client_probe.gd
# ============================================================================

var _p: Node3D = null
var _falhas: Array[String] = []


func _init() -> void:
	await process_frame
	if not get_root().get_node("GameFlow").join_room("127.0.0.1"):
		print("[CLI] ❌ join_room falhou"); quit(2); return
	for i in 1800:
		await process_frame
		_p = _corpo(str(root.multiplayer.get_unique_id()))
		if _p != null:
			break
	if _p == null:
		print("[CLI] ❌ corpo não apareceu"); quit(3); return
	_p.global_position = Vector3(0, 1.0, 0)
	_p.velocity = Vector3.ZERO
	# 1. O congelamento do servidor: mede no próprio corpo, segurando W.
	var r := await _medir(6.0, true)
	_ok("1. o gelo do servidor chegou ao meu corpo e durou %.2f s (0,7)" % r.dur, r.dur > 0.55 and r.dur < 0.9)
	_ok("1. com W apertado, congelado não andou (%.2f m)" % r.andou_preso, r.andou_preso < 0.15)
	# 2. O Z novo do host.
	var r2 := await _medir(9.0, false)
	_ok("2. o Z da Hie do host me congelou %.2f s (0,7)" % r2.dur, r2.dur > 0.55 and r2.dur < 0.95)
	print("%s" % ("✅ HIE EM REDE OK (cliente)" if _falhas.is_empty() else "❌ %d falha(s): %s" % [_falhas.size(), str(_falhas)]))
	quit(0 if _falhas.is_empty() else 1)


## Espera congelar (até `limite` s) e mede quanto dura; com `andar`, segura W o tempo todo.
func _medir(limite: float, andar: bool) -> Dictionary:
	var inicio := -1
	var de := Vector3.INF
	var andou := 0.0
	var t0 := Time.get_ticks_msec()
	if andar:
		_tecla(KEY_W, true)
	while Time.get_ticks_msec() - t0 < int(limite * 1000.0):
		await physics_frame
		var preso := bool(_p.get_meta("is_frozen", false))
		if preso and inicio < 0:
			inicio = Time.get_ticks_msec()
			de = _p.global_position
		elif preso:
			andou = maxf(andou, Vector2(_p.global_position.x - de.x, _p.global_position.z - de.z).length())
		elif inicio >= 0:
			_tecla(KEY_W, false)
			return {"dur": (Time.get_ticks_msec() - inicio) / 1000.0, "andou_preso": andou}
	_tecla(KEY_W, false)
	return {"dur": -1.0, "andou_preso": andou}


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)


func _ok(rotulo: String, cond: bool) -> void:
	print("   %s %s" % ["✅" if cond else "❌", rotulo])
	if not cond:
		_falhas.append(rotulo)


func _corpo(nome: String) -> Node3D:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null
