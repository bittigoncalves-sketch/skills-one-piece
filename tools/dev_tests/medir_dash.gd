extends SceneTree
# ============================================================================
#  O DASH SAI PARA OS QUATRO LADOS, E O DE COSTAS ROLA?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_dash.gd
#
#  Pedido do dono (2026-08-27): dash lateral e dash para trás, com ROLAMENTO no
#  de trás.
#
#  ⚠️ O dash JÁ ia para os lados e para trás — a direção sempre veio da tecla
#  (`q.dir`). O que não existia era a LEITURA: os quatro usavam a mesma pose, e
#  na tela dar um passo para trás e mergulhar para a frente ficavam iguais.
#  Por isso esta sonda mede DUAS coisas separadas:
#    • para onde o corpo SE MOVE (já funcionava)
#    • qual POSE toca (é o que mudou)
#
#  E mede o giro: rolamento é giro, não encolhimento. Sem conferir a volta
#  completa, uma pose agachada passaria por rolamento.
# ============================================================================

const TOL := 0.9

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

	print("=== para onde o corpo se MOVE, e que RUMO o dash reporta ===")
	print("tecla | rumo esperado | rumo dado | dot(deslocamento, esperado) | giro máx")
	for caso in [[KEY_W, "frente"], [KEY_S, "tras"], [KEY_A, "esquerda"], [KEY_D, "direita"]]:
		await _um(p, caso[0], String(caso[1]))

	# sem tecla: a esquiva vai para a frente da câmera
	await _um(p, KEY_NONE, "frente")

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _um(p: Node3D, tecla: Key, esperado: String) -> void:
	p.global_position = Vector3(0, 2.0, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = -0.2
	p._camera.apontar(0.0, -0.2)
	p._dash._recarga = 0.0
	for i in 25:
		await process_frame
	var antes: Vector3 = p.global_position
	var pose_antes: Vector3 = p._char_model.position

	var esperada := RosaDosVentos.frente(0.0)
	match esperado:
		"tras":     esperada = -RosaDosVentos.frente(0.0)
		"esquerda": esperada = -RosaDosVentos.direita(0.0)
		"direita":  esperada = RosaDosVentos.direita(0.0)

	# segurar Q MIRA, soltar DISPARA
	if tecla != KEY_NONE:
		_tecla(tecla, true)
	_tecla(KEY_Q, true)
	for i in 8:
		await process_frame
	_tecla(KEY_Q, false)

	var rumo_dado := ""
	var giro_max := 0.0
	var rotx_max := 0.0
	for i in 40:
		await process_frame
		if p._dash.ativo():
			rumo_dado = p._dash.rumo_nome()
			giro_max = maxf(giro_max, p._dash.giro_do_rolamento())
			rotx_max = maxf(rotx_max, absf(p._char_model.rotation.x))
	if tecla != KEY_NONE:
		_tecla(tecla, false)
	for i in 25:
		await process_frame

	var desloc: Vector3 = p.global_position - antes
	desloc.y = 0.0
	var d: float = desloc.normalized().dot(esperada.normalized()) if desloc.length() > 0.5 else 0.0
	print("%-5s | %-13s | %-9s | %+.3f | %.2f" % [
		("(nenhuma)" if tecla == KEY_NONE else char(tecla)), esperado, rumo_dado, d, giro_max])
	_ok("%s: o corpo se move para lá" % esperado, d >= TOL)
	_ok("%s: o dash reporta o rumo certo" % esperado, rumo_dado == esperado)
	if esperado == "tras":
		_ok("o rolamento de costas GIRA o corpo (volta completa)", rotx_max > TAU * 0.9)
		# ⚠️ CONTRA O REPOUSO, não contra ZERO. O modelo repousa em y = −0,80 (o
		# rig o abaixa para os pés tocarem o chão); comparar com zero deixou
		# passar um bug em que o personagem SUBIA 0,8 m a cada dash de costas.
		_ok("e o corpo volta ao repouso no fim (não sobe)",
			absf(p._char_model.rotation.x) < 0.01
			and p._char_model.position.is_equal_approx(pose_antes))
		print("      pose do modelo: antes y=%.3f | depois y=%.3f" % [
			pose_antes.y, p._char_model.position.y])
	else:
		_ok("%s: NÃO gira o corpo (só o de trás rola)" % esperado, rotx_max < 0.01)


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
