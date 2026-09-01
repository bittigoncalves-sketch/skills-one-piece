extends SceneTree
# ============================================================================
#  SEGURAR W E CLICAR VÁRIAS VEZES DÁ UM COMBO, NÃO A MESMA COTOVELADA
#
#  Relato do dono (2026-09-01): "ao segurar W e clicar, o jogador só dá um tipo
#  de soco; caso outro soco seja dado, mesmo apertando W, os socos normais devem
#  ser dados, resultando numa sequência de movimentos que originam um combo".
#
#  ⚠️ ESTE TESTE MEDE A SEQUÊNCIA, não um golpe. O defeito só aparece no
#  SEGUNDO clique: o primeiro está certo (é a cotovelada mesmo). Um teste que
#  clicasse uma vez passaria com o bug inteiro no lugar.
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

	_ok("o 1º clique com W dá a cotovelada", saiu[0] == "context_elbow")
	# ⚠️ O CORAÇÃO DO RELATO: o segundo não pode repetir o primeiro.
	_ok("o 2º clique NÃO repete a cotovelada", saiu[1] != "context_elbow")
	_ok("o 3º clique NÃO repete a cotovelada", saiu[2] != "context_elbow")
	var repetidos := 0
	for id in saiu:
		if id == "context_elbow":
			repetidos += 1
	print("   cotoveladas em 4 cliques: %d" % repetidos)
	_ok("a cotovelada sai UMA vez na sequência", repetidos == 1)
	_ok("os cliques seguintes viram combo M1", saiu[1] == "m1" and saiu[2] == "m1")

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
