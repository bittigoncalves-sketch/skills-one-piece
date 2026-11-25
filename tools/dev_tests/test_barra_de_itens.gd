extends SceneTree
# ============================================================================
#  BARRA DE ITENS 1–6 do Modo História (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_barra_de_itens.gd
#
#  Pedido do dono: o que estiver equipado (fruta — a Rocket como foguete —, espada,
#  pistola, estilo de luta, vara) aparece num quadradinho no centro inferior, e a
#  tecla do quadrado libera o uso daquele item. Decisão: UM item ativo por vez;
#  a tecla do ativo de novo solta (volta para a luta).
#  Com teclas de verdade (1–6 pelo `Input`), progresso de TESTE.
# ============================================================================

const PROGRESSO := "user://test_barra_de_itens.json"

var _ok_n := 0
var _falhas := 0
var p: Node3D
var prog: ProgressaoDoPersonagem
var hud: HistoriaHud


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	prog = current_scene.get("progressao")
	hud = current_scene.get("_hud")
	var barra := hud.barra()

	# Água sempre antes da comida (18/10/2026).
	_ok("começo: luta ativa, água, comida, pokébola e bandeira (%s)" % str(barra.itens()), barra.itens() == (["luta", "agua", "comida", "pokebola", "bandeira"] as Array[String]) and prog.item_em_uso() == "luta")
	_ok("quatro quadrados no centro inferior, com o punho e a gota", _quadros(barra) == 4 and barra.icone_do_item("luta").ends_with("luta.svg") and barra.icone_do_item("agua").ends_with("agua.svg"))

	current_scene.dar_fruta("rocket")
	await _quadros_prontos()
	_ok("comer a Rocket: 2º quadrado, já ativo, com o FOGUETE (%s)" % barra.icone_do_item("fruta"),
		barra.itens() == (["luta", "fruta", "agua", "comida", "pokebola", "bandeira"] as Array[String]) and prog.item_em_uso() == "fruta" and barra.icone_do_item("fruta").ends_with("rocket.svg"))
	_ok("fruta ativa libera técnicas e voo", p.capacidades.can_use_fruit and p.capacidades.can_fly and p.capacidades.can_attack)
	_ok("o quadrado ativo tem a borda dourada", _borda(barra, "fruta") == EstiloDaHistoria.DOURADO and _borda(barra, "luta") != EstiloDaHistoria.DOURADO)

	# MENU DA FRUTA (03/10/2026): com a Rocket ativa, as técnicas e o tempo de recarga.
	var menu: TecnicasHud = hud.get("_tecnicas")
	await _quadros_prontos()
	_ok("Rocket ativa: o menu de técnicas aparece com a recarga de cada uma (\"%s\")" % menu.texto_da_linha("Z"),
		menu.visible and menu.texto_da_linha("Z") == "Missile Fist recarga 6 s" and menu.texto_da_linha("C").ends_with("recarga 12 s")
		and menu.slots_na_tela().size() == 4)
	var tela := Rect2(Vector2.ZERO, menu.get_viewport_rect().size)
	_ok("o menu fica DENTRO da tela, no canto inferior esquerdo (%s em %s)" % [menu.get_global_rect(), tela.size],
		tela.encloses(menu.get_global_rect()) and menu.get_global_rect().position.y > tela.size.y * 0.5)
	p.global_position = Vector3(0, 1, 0)
	p.begin_charge("Z")
	await _quadros_prontos()
	p.release_charge("Z")
	for i in 30:
		await physics_frame
	await process_frame
	_ok("usada, a técnica mostra quanto falta (\"%s\")" % menu.texto_da_linha("Z"), menu.texto_da_linha("Z").begins_with("Missile Fist faltam "))
	await _tecla(KEY_1)
	# 14/10/2026: a Luta virou o Estilo de Combate Base e leva o Z/X do Builder (can_use_fruit),
	# mas continua sem o voo e sem o menu da fruta comida.
	_ok("tecla 1: luta ativa — técnicas do estilo base, sem voo, soco liberado",
		prog.item_em_uso() == "luta" and p.capacidades.can_use_fruit == prog.tem_estilo_base() and not p.capacidades.can_fly and p.capacidades.can_attack)
	_ok("com a luta ativa o menu mostra as técnicas do estilo base (se publicado)", menu.visible == prog.tem_estilo_base())
	await _tecla(KEY_2)
	_ok("tecla 2: fruta ativa de novo (e o menu volta)", prog.item_em_uso() == "fruta" and p.capacidades.can_use_fruit and menu.visible)
	await _tecla(KEY_2)
	_ok("tecla 2 outra vez: SOLTA — nada selecionado, nem o 1 (bug 15/10)",
		prog.item_em_uso() == "" and not p.capacidades.can_fly and not p.capacidades.can_use_fruit)
	_ok("nada selecionado: nenhum quadrado dourado",
		_borda(barra, "luta") != EstiloDaHistoria.DOURADO and _borda(barra, "fruta") != EstiloDaHistoria.DOURADO)
	_ok("nada selecionado: socos básicos continuam", p.capacidades.can_attack)
	await _tecla(KEY_1)
	_ok("tecla 1 com nada selecionado: liga a luta", prog.item_em_uso() == "luta")
	await _tecla(KEY_1)
	_ok("tecla 1 outra vez: solta a luta também", prog.item_em_uso() == "")

	prog.ganhar_equipamento("vara_de_pesca")
	hud.inventario().equipar_vara(true)
	await _quadros_prontos()
	_ok("vara equipada no N: 3º quadrado, ativa (%s)" % str(barra.itens()),
		barra.itens() == (["luta", "fruta", "vara", "agua", "comida", "pokebola", "bandeira"] as Array[String]) and prog.item_em_uso() == "vara" and _quadros(barra) == 6)
	_ok("vara ativa: pesca sim, soco e fruta não", p.capacidades.can_fish and not p.capacidades.can_attack and not p.capacidades.can_use_fruit)
	await _tecla(KEY_9)
	_ok("tecla 9 sem item: nada muda", prog.item_em_uso() == "vara")

	hud.alternar_inventario()
	await _tecla(KEY_1)
	_ok("com o N aberto as teclas não trocam o item", prog.item_em_uso() == "vara")
	hud.alternar_inventario()
	await _tecla(KEY_1)
	_ok("N fechado: tecla 1 volta à luta", prog.item_em_uso() == "luta")

	await _tecla(KEY_2)
	var lido := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok("save guarda o item ativo (%s)" % lido.item_em_uso(), lido.item_em_uso() == "fruta")
	current_scene.tirar_fruta()
	await _quadros_prontos()
	_ok("sem fruta o quadrado some e o ativo cai para um que existe (%s, %s)" % [str(barra.itens()), prog.item_em_uso()],
		barra.itens() == (["luta", "vara", "agua", "comida", "pokebola", "bandeira"] as Array[String]) and prog.item_em_uso() == "luta")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nBARRA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _quadros(barra: BarraDeItensHud) -> int:
	var n := 0
	for f in barra.get_children():
		if f is Panel and not f.is_queued_for_deletion():
			n += 1
	return n


func _borda(barra: BarraDeItensHud, id: String) -> Color:
	var q := barra.get_node_or_null("Item_" + id) as Panel
	if q == null:
		return Color.BLACK
	return (q.get_theme_stylebox("panel") as StyleBoxFlat).border_color


func _quadros_prontos() -> void:
	for i in 4:
		await physics_frame
	await process_frame


func _tecla(codigo: Key) -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = codigo
		ev.keycode = codigo
		ev.pressed = pressionada
		Input.parse_input_event(ev)
		await physics_frame
	await _quadros_prontos()


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
