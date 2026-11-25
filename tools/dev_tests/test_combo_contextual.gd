extends SceneTree
# ============================================================================
#  SEGURAR W E CLICAR VÁRIAS VEZES DÁ O COMBO M1
#
#  Relato do dono (2026-09-01): segurar W repetia a mesma cotovelada. Em
#  2026-09-13 o dono pediu para apagar de vez as variações de movimento simples
#  (W/A/S/D + clique): andar + clique é o combo M1, e o único W que muda o
#  clique é o do QUARTO golpe, que vira Lançamento.
#
#  ⚠️ ESTE TESTE MEDE A SEQUÊNCIA, não um golpe: a troca só aparece no quarto
#  clique.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_combo_contextual.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)

	print("=== segurando W, quatro cliques seguidos ===")
	_tecla(KEY_W, true)
	await _quadros(10)

	var saiu: Array[String] = []
	for i in 4:
		var id := await _um_golpe(p)
		saiu.append(id)
		print("   clique %d -> %s" % [i + 1, id])
	_tecla(KEY_W, false)
	await _quadros(20)

	_ok("os três primeiros cliques com W são combo M1", saiu[0] == "m1" and saiu[1] == "m1" and saiu[2] == "m1")
	_ok("o 4º clique com W vira o Lançamento", saiu[3] == "context_launcher")

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Dispara um golpe e devolve o que saiu: o id contextual, ou "m1" quando foi o
## combo normal, ou "" se nada saiu.
func _um_golpe(p: Node3D) -> String:
	p._melee.pedir(p._yaw)
	await _quadros(3)
	var id := String(p._melee.contextual_id())
	if not id.is_empty():
		# espera o golpe terminar para o próximo clique ser aceito
		await _esperar_livre(p)
		return id
	if p._melee.passo_em_curso() >= 0:
		await _esperar_livre(p)
		return "m1"
	await _esperar_livre(p)
	return ""


## Espera a trava abrir — é ela que decide quando o próximo clique é aceito.
func _esperar_livre(p: Node3D) -> void:
	var n := 0
	while p._melee.trava() > 0.0 and n < 180:
		await process_frame
		n += 1
	await _quadros(3)


func _tecla(c: Key, d: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = c
	e.keycode = c
	e.pressed = d
	Input.parse_input_event(e)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
