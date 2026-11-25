extends SceneTree
# ============================================================================
#  ROLL (Q) E AGACHAR (Ctrl) — atualizado em 20/10/2026.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_roll_deslize.gd
#
#  Preserva os contratos A–D do roll. Desde 20/10/2026, E prova que Ctrl
#  substituiu o deslize por agachar. Teto/borda/rede em test_agachar.gd.
# ============================================================================

var _ok_n := 0
var _falhas := 0
var p: Node3D
var dt := 1.0 / 60.0
var _aneis := 0


func _init() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_roll_deslize.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	if p == null:
		print("❌ sem jogador"); quit(1); return
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	# O roll herdou a trava do dash: o Civil só esquiva quando a progressão libera.
	p.capacidades = CapacidadesDoJogador.completas()
	var anim = p._proc_anim
	var leg: float = anim._m.get("leg_len", 0.8)

	print("-- A. roll com D --")
	await _posicionar(Vector3(0, 0.81, 0))
	var x0: float = p.global_position.x
	_tecla(KEY_D, true)
	await physics_frame
	var aneis_antes := _contar_aneis()
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	await physics_frame
	_aneis = _contar_aneis() - aneis_antes
	var dot_frente := 1.0
	var clipe_ok := false
	var quadril_min := 0.0
	var imune_cedo: bool = p.get_meta("damage_immune", false)
	var imune_tarde := true
	var quadros := 0
	for i in 60:
		await physics_frame
		if not p._dash.ativo():
			break
		quadros += 1
		if i >= 5:
			dot_frente = minf(dot_frente, (-p._char_model.global_basis.z).normalized().dot(Vector3.RIGHT))
		clipe_ok = clipe_ok or (anim.acao_clipe == DashController.CLIPE and anim._acao_w > 0.9)
		quadril_min = minf(quadril_min, (anim._n.Torso as Node3D).position.y - anim._rest_torso_pos.y)
		if i == 24:
			imune_tarde = p.get_meta("damage_immune", false)
	_tecla(KEY_D, false)
	var dx: float = p.global_position.x - x0
	_ok("rolou para a DIREITA %.2f m em %.2f s (8 m ±0,8)" % [dx, quadros * dt], absf(dx - 8.0) <= 0.8)
	_ok("o corpo vai de frente para onde rola (dot %.3f ≥ 0,9)" % dot_frente, dot_frente >= 0.9)
	_ok("toca o clipe do Mixamo \"Sprinting Forward Roll\"", clipe_ok)
	_ok("o quadril desce no rolamento (%.2f m; ≥ 30%% da perna %.2f)" % [quadril_min, leg], -quadril_min >= 0.3 * leg)
	print("-- B. invulnerabilidade --")
	_ok("invulnerável no começo (%s) e não mais em 0,4 s (%s)" % [imune_cedo, imune_tarde], imune_cedo and not imune_tarde)
	_ok("o roll não solta o anel de choque do dash antigo (%d anéis na cena)" % _aneis, _aneis == 0)

	print("-- C. recarga --")
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	await physics_frame
	var de_novo: bool = p._dash.ativo()
	for i in 100:
		await physics_frame
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	await physics_frame
	var depois: bool = p._dash.ativo()
	_ok("logo depois o Q não rola (recarga); passado 1,5 s rola (%s → %s)" % [de_novo, depois], not de_novo and depois)
	for i in 60:
		await physics_frame

	print("-- D. sem tecla rola para a frente --")
	await _posicionar(Vector3(0, 0.81, 0))
	var z0: float = p.global_position.z
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	for i in 50:
		await physics_frame
	_ok("sem WASD rola para a frente da câmera (%.2f m)" % (z0 - p.global_position.z), z0 - p.global_position.z >= 7.0)

	# 20/10/2026: Ctrl agora agacha; a cobertura completa mora em test_agachar.gd.
	print("-- E. Ctrl substitui o deslize --")
	await _posicionar(Vector3(0, 0.81, 0))
	_tecla(KEY_W, true)
	for i in 45:
		await physics_frame
	_tecla(KEY_CTRL, true)
	for i in 20:
		await physics_frame
	_ok("Ctrl em movimento agacha e não dispara deslize", p._agachar.ativo and not p._deslize.ativo())
	_ok("agachar reduz a velocidade a 30%", absf(_plano() - p.SPEED * 0.3) < 0.08)
	_tecla(KEY_CTRL, false)
	_tecla(KEY_W, false)
	for i in 20:
		await physics_frame
	_ok("soltar Ctrl levanta", not p._agachar.ativo)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nROLL_DESLIZE %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## O anel de choque do dash antigo era um TorusMesh solto na cena (FxUtil.dash_effect).
func _contar_aneis() -> int:
	var n := 0
	for filho in current_scene.get_children():
		if filho is MeshInstance3D and (filho as MeshInstance3D).mesh is TorusMesh:
			n += 1
		for neto in filho.get_children():
			if neto is MeshInstance3D and (neto as MeshInstance3D).mesh is TorusMesh:
				n += 1
	return n


func _altura_colisor() -> float:
	var forma = p._colisor.shape
	return forma.size.y if forma is BoxShape3D else forma.height


func _posicionar(pos: Vector3) -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE, KEY_CTRL, KEY_Q]:
		_tecla(k, false)
	p._deslize.cancelar()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	for i in 40:
		await physics_frame


func _plano() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


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
