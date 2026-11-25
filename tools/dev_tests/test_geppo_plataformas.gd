extends SceneTree
# ============================================================================
#  SUBIDA DAS PLATAFORMAS DO GEPPO (18/11/2026): um robô de teclado (W + Espaço com a física real do jogador) sobe as 8 plataformas da Ilha dos Macacos.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_geppo_plataformas.gd
#  Com o Geppo, cada plataforma tem de ser alcançada pulando no ar; SEM o Geppo, a 1ª já não deve ser a única alcançável (a 3ª+ fica fora de alcance).
# ============================================================================
var _ok_n := 0
var _falhas := 0
func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)
func _init() -> void:
	_executar.call_deferred()
func _executar() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var plat: Array = lido["mapa"]["pecas"].filter(func(p): return String(p["id"]).begins_with("macacos_floresta_plataforma_"))
	plat.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	_ok("8 plataformas no mapa", plat.size() == 8)
	var modo = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_geppo_plat.json"))
	modo.set("progresso_forcado", "user://test_geppo_plat.json")
	var pe := ProgressaoDoPersonagem.carregar("user://test_geppo_plat.json")
	pe.corpo = "masculino"
	pe.salvar("user://test_geppo_plat.json")
	root.get_node("GameFlow").start_story()
	for i in 300:
		await physics_frame
	var cena := current_scene
	var j = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	cena.call("ir_a_ilha", "ilha_dos_macacos")
	for i in 400:
		await physics_frame
	j.set_meta("damage_immune", true)
	var com_geppo := OS.get_cmdline_user_args().has("--sem-geppo") == false
	if com_geppo:
		prog.ouro = ProgressaoDoPersonagem.PRECO_DO_GEPPO
		prog.aprender_geppo()
		for i in 10:
			await physics_frame
	var alcancadas := 0
	for i in plat.size():
		var alvo: Vector3 = plat[i]["posicao"]
		var topo := alvo.y + 0.4
		if i == 0:
			# parte do chão, a 5 m da plataforma, do lado da clareira
			var dir0 := (Vector3(alvo.x, 0, alvo.z) - Vector3(1488, 0, 4)).normalized()
			j.global_position = Vector3(alvo.x, alvo.y - 2.2, alvo.z) - dir0 * 6.0 + Vector3.UP * 1.0
			j.velocity = Vector3.ZERO
			for k in 30:
				await physics_frame
		var chegou := false
		var ult_pulo := 0
		for q in 360:
			var d := Vector3(alvo.x - j.global_position.x, 0, alvo.z - j.global_position.z)
			j.set("_yaw", atan2(-d.x, -d.z))
			j.rotation.y = atan2(-d.x, -d.z)
			_tecla(KEY_W, d.length() > 0.8)
			# toca Espaço a cada 14 quadros (no ar vira Geppo; no chão, pulo)
			if q - ult_pulo >= 14 and j.global_position.y < topo + 3.0:
				_tecla(KEY_SPACE, true)
				ult_pulo = q
			elif q - ult_pulo >= 2:
				_tecla(KEY_SPACE, false)
			await physics_frame
			if j.is_on_floor() and absf(j.global_position.y - topo) < 1.3 and d.length() < 4.0:
				chegou = true
				break
		_tecla(KEY_W, false)
		_tecla(KEY_SPACE, false)
		print("   plataforma %d: alvo y=%.1f  jogador y=%.1f  alcançou=%s (quadros %d)" % [i, topo, j.global_position.y, str(chegou), 0])
		if chegou:
			alcancadas += 1
		else:
			break
		for k in 10:
			await physics_frame
	if com_geppo:
		_ok("com o Geppo o robô sobe as 8 plataformas (%d)" % alcancadas, alcancadas == plat.size())
	else:
		_ok("sem o Geppo NÃO sobe todas (%d de 8)" % alcancadas, alcancadas < plat.size())
	print("\nGEPPO_PLATAFORMAS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
