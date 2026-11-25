extends SceneTree
# ============================================================================
#  Q: ROLAR NO CHÃO, DASH NO AR — arena e Modo História (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_q_rolar_e_dash.gd
#
#  Pedido do dono: "transformar o rolamento do Q atual do modo história no Q do
#  singleplayer, sendo que quando Q pressionado no ar passará a ser o dash com seu
#  efeito de VFX e som característico". Decisão: vale nos DOIS modos. Teclas de
#  verdade (Input). Mede, em cada modo:
#    chão — rola ~8 m, toca o clipe do roll, sem anel de choque;
#    ar   — dash de ~5 m em ~0,28 s (12 até 07/10, 8 até 08/10/2026), sem cair durante ele, e o
#           impulso NÃO continua depois (a velocidade volta à de andar), com o anel de choque e o
#           som da esquiva, invulnerável, sem o clipe do roll.
# ============================================================================

var _ok_n := 0
var _falhas := 0
var p: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_q_rolar_e_dash.json")
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	print("-- Modo História --")
	await _medir("história")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")

	root.get_node("GameFlow").start_singleplayer()
	await _fisica(180)
	print("-- Arena (singleplayer) --")
	await _medir("arena")
	print("\nQ_ROLAR_E_DASH %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _medir(rotulo: String) -> void:
	p = null
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
	if p == null:
		_ok("%s: há jogador" % rotulo, false)
		return
	if p.get("capacidades") != null:
		p.capacidades = CapacidadesDoJogador.completas()
	var anim = p._proc_anim

	# --- no chão: o roll de hoje
	await _no_lugar(p.global_position + Vector3(0, 0.3, 0))
	await _fisica(30)
	var x0: float = p.global_position.x
	var aneis := _aneis()
	_tecla(KEY_D, true)
	await physics_frame
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	var clipe := false
	var quadros := 0
	for i in 60:
		await physics_frame
		if not p._dash.ativo():
			break
		quadros += 1
		clipe = clipe or anim.acao_clipe == DashController.CLIPE
	_tecla(KEY_D, false)
	var dx: float = p.global_position.x - x0
	_ok("%s, chão: rola %.1f m (8 ±0,8) com o clipe do roll e sem anel (%d)" % [rotulo, dx, _aneis() - aneis],
		absf(dx - 8.0) <= 0.8 and clipe and _aneis() == aneis)

	# --- no ar: o dash no ar (`DashNoAr`, separado do roll em 15/10/2026)
	await _fisica(100)                       # recarga do roll (1,5 s)
	var alto: Vector3 = p.global_position + Vector3(0, 9.0, 0)
	await _no_lugar(alto)
	p.velocity = Vector3.ZERO
	await _fisica(2)
	var no_ar := not (p as CharacterBody3D).is_on_floor()
	var de: Vector3 = p.global_position
	aneis = _aneis()
	var sons := _sons()
	_tecla(KEY_D, true)
	await physics_frame
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	# Anel e som NASCEM no aperto: contar já (um som curto acaba antes do fim do dash).
	await physics_frame
	var aneis_dash := _aneis() - aneis
	var sons_dash := _sons() - sons
	var imune: bool = p.get_meta("damage_immune", false)
	var dash := false
	var clipe_ar := false
	var clipe_mergulho := false
	var y_min: float = de.y
	quadros = 0
	for i in 40:
		await physics_frame
		if not p._dash_ar.ativo():
			break
		quadros += 1
		dash = dash or p._dash_ar.ativo()
		clipe_ar = clipe_ar or anim.acao_clipe == DashController.CLIPE
		clipe_mergulho = clipe_mergulho or (anim.acao_clipe == DashNoAr.CLIPES["direita"] and anim.acao_tempo >= DashNoAr.CLIPE_INICIO - 0.001 and anim.acao_tempo <= DashNoAr.CLIPE_FIM + 0.001)
		y_min = minf(y_min, p.global_position.y)
	await physics_frame
	var depois := Vector2(p.velocity.x, p.velocity.z).length()
	_tecla(KEY_D, false)
	var andou := Vector2(p.global_position.x - de.x, p.global_position.z - de.z).length()
	var t := quadros / float(Engine.physics_ticks_per_second)
	_ok("%s, ar: começa no ar (%s) e o Q vira o DASH (%s)" % [rotulo, no_ar, dash], no_ar and dash)
	_ok("%s, ar: %.1f m em %.2f s (%.0f m em ~0,28 s), sem cair (desceu %.2f m)" % [rotulo, andou, t, DashNoAr.DISTANCIA, de.y - y_min],
		absf(andou - DashNoAr.DISTANCIA) <= 0.8 and t <= 0.36 and de.y - y_min < 0.3)
	# 08/10/2026 ("o impulso recebido é resetado ao final do dash voltando à velocidade
	# normal"): logo depois do dash a velocidade horizontal é a de andar/correr, não a
	# do dash (5 m / 0,28 s ≈ 18 m/s).
	var de_andar: float = p.SPEED * 1.5
	_ok("%s, ar: depois do dash a velocidade volta à normal (%.1f m/s; correr ≤ %.1f; dash %.1f)" % [rotulo, depois, de_andar, DashNoAr.DISTANCIA / DashNoAr.TEMPO],
		depois <= de_andar + 0.1)
	_ok("%s, ar: anel de choque (+%d) e som da esquiva (+%d)" % [rotulo, aneis_dash, sons_dash],
		aneis_dash > 0 and sons_dash > 0)
	_ok("%s, ar: invulnerável no dash e sem o clipe do roll" % rotulo, imune and not clipe_ar)
	_ok("%s, ar: toca o chute de dash à direita na janela %.2f–%.2f s" % [rotulo, DashNoAr.CLIPE_INICIO, DashNoAr.CLIPE_FIM], clipe_mergulho)


# ------------------------------------------------------------------ apoio

func _aneis() -> int:
	var n := 0
	for mi in current_scene.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh is TorusMesh and not (mi as Node).is_queued_for_deletion():
			n += 1
	return n


func _sons() -> int:
	return current_scene.find_children("*", "AudioStreamPlayer3D", true, false).size()


func _no_lugar(pos: Vector3) -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE, KEY_CTRL, KEY_Q]:
		_tecla(k, false)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	await physics_frame


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
