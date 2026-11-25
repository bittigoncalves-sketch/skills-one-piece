extends SceneTree
# ============================================================================
#  RAID DO MINE PIECE (18/10/2026, docs/MINE_PIECE_SISTEMAS_PLANO.md, F8).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_raid_mine_piece.gd
#
#  Na cena real (mapa vivo, save de teste), no East Blue: bandeira + segurar Z inicia a
#  raid 1 (Higuma); nunca mais de 5 vivos; o Higuma nasce por último; vencer marca o
#  estágio e o próximo é o 2; afastar-se cancela e tira os inimigos; na Grand Line avisa.
# ============================================================================

var total := 0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_raid_mine_piece.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_raid_mine_piece.json"))
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	var raid: Node = cena.get("raid")
	var jogador: Node3D = get_first_node_in_group("player")
	ok(raid != null and jogador != null, "a raid existe no Modo História e o jogador nasceu")
	if raid == null or jogador == null:
		quit(1)
		return
	jogador.set_meta("damage_immune", true)
	cena.call("ir_a_ilha", "ilha_east_blue")
	await quadros(30)
	ok(raid.mar_em(jogador.global_position) == "east_blue" and raid.proximo_estagio("east_blue") == 1,
		"no East Blue o próximo estágio é o 1")

	print("\n-- bandeira + segurar Z --")
	prog.ativar_item("luta")
	await _segurar_z(1.3)
	ok(not raid.ativa, "sem a bandeira, segurar Z não inicia")
	prog.ativar_item("bandeira")
	await _segurar_z(0.4)
	ok(not raid.ativa, "toque curto (0,4 s) não inicia")
	await _segurar_z(1.3)
	ok(raid.ativa and raid.estagio == 1 and raid.restantes + raid.vivos.size() == 15, "segurar Z 1 s inicia a raid 1 com 15 inimigos")

	print("\n-- ondas --")
	var xp0 := prog.xp + prog.nivel * 1000000
	# Sem matar ninguém por 8 s: as ondas param em 5 vivos.
	var maximo := 0
	var vistos := {}
	for i in 480:
		await physics_frame
		maximo = maxi(maximo, raid.vivos.size())
		for v in raid.vivos:
			if is_instance_valid(v):
				vistos[v.get_instance_id()] = [v.name, v.global_position, v.get("health")]
		for k in vistos.keys():
			var o := instance_from_id(k)
			if o == null or o.get_meta("raid_caiu", false):
				print("     · caiu sozinho: %s em %s (vida antes %s; ultimo_agressor %s)" % [vistos[k][0], vistos[k][1], vistos[k][2],
					str(o.get("ultimo_agressor")) if o != null else "-"])
				vistos.erase(k)
	ok(maximo == 5 and raid.restantes == 10, "sem abates as ondas param em 5 vivos (máximo %d, por nascer %d)" % [maximo, raid.restantes])
	var ultimo := ""
	var nascidos := 0
	for i in 2400:
		await physics_frame
		maximo = maxi(maximo, raid.vivos.size())
		for v in raid.vivos.duplicate():
			if is_instance_valid(v) and not v.get_meta("raid_caiu", false) and v.get("health") > 0.0:
				ultimo = str(v.get_meta("modelo_recrutavel", ""))
				nascidos += 1
				# Golpe do jogador sem a marca de recrutamento: cai direto (sem a escolha).
				v.set_meta("autor_do_dano", jogador.get_instance_id())
				v.set("capanga", false)      # 08/11/2026: capanga cai em 5 golpes; aqui o que se mede é o fluxo da raid (ver test_chefes_e_capangas)
				v.call("take_damage", 99999.0, v.global_position)
				v.remove_meta("autor_do_dano")
		if not raid.ativa:
			break
	if raid.ativa:
		print("     · ainda ativa: por nascer %d, vivos %s" % [raid.restantes, str(raid.vivos.map(func(v): return [v.name, v.get("health"), v.get("_morto"), v.get_meta("aguardando_recrutamento", false), v.global_position] if is_instance_valid(v) else "x"))])
	ok(maximo <= 5, "nunca mais de 5 vivos (máximo %d)" % maximo)
	ok(ultimo == "mp_higuma", "o chefe (Higuma) nasce por último (%s)" % ultimo)
	ok(not raid.ativa and raid.vencidos("east_blue").has(1), "todos caem: RAID VENCIDA e o estágio 1 fica marcado")
	ok(raid.proximo_estagio("east_blue") == 2, "o próximo estágio é o 2 (Alvida)")
	ok(prog.xp + prog.nivel * 1000000 > xp0, "os abates deram XP")

	print("\n-- cancelar --")
	await _segurar_z(1.3)
	ok(raid.ativa and raid.estagio == 2, "a raid 2 começa")
	await quadros(90)
	var antes: Array = raid.vivos.duplicate()
	jogador.global_position += Vector3(200, 0, 0)
	await quadros(10)
	ok(not raid.ativa and antes.all(func(v): return not is_instance_valid(v) or v.is_queued_for_deletion()),
		"afastar-se 200 m cancela e tira os inimigos (%d)" % antes.size())

	print("\n-- Grand Line --")
	cena.call("ir_a_ilha", "ilha_wano")
	await quadros(30)
	ok(raid.iniciar().contains("Grand Line") and not raid.ativa, "na Grand Line a raid avisa e não começa")
	print("\n%d/%d" % [total - falhas, total])
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)


func _segurar_z(segundos: float) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_Z
	ev.keycode = KEY_Z
	ev.pressed = true
	Input.parse_input_event(ev)
	await create_timer(segundos).timeout
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await quadros(3)
