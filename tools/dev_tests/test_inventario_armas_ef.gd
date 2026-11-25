extends SceneTree
## Inventário (12/11/2026): sem o kit de blocos de teste; armas do Epic Fight como itens `ef:` na mochila; escolher o slot na hotbar equipa a arma.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_inventario_armas_ef.gd
var total := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func q(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_inv_ef.json"))
	modo.set("progresso_forcado", "user://test_inv_ef.json")
	root.get_node("GameFlow").start_story()
	await q(200)
	var m = get_first_node_in_group("modo_historia")
	var prog: ProgressaoDoPersonagem = m.progressao
	var inv: InventarioMinecraft = prog.inventario
	var armas := 0
	var blocos := 0
	for i in range(InventarioMinecraft.MOCHILA_INI, InventarioMinecraft.MOCHILA_FIM):
		var id := InventarioMinecraft.id_de(inv.pilha(i))
		if ItensEpicFight.e_de(id):
			armas += 1
		elif ItensDeBloco.e_de_bloco(id):
			blocos += 1
	ok(prog.inventario_ef_entregue, "a limpeza aconteceu e foi marcada")
	ok(blocos == 0, "nenhum bloco de teste na mochila (%d)" % blocos)
	ok(armas == 0, "18/11/2026: nenhuma arma do Epic Fight entregue de graça (%d)" % armas)
	var com_lamina := 0
	for id in LaminasEpicFight.ids():
		com_lamina += 1 if prog.equipamentos.has(id) else 0
	ok(com_lamina == 0 and prog.lamina_ef == "", "personagem sem nenhuma lâmina nos equipamentos (%d)" % com_lamina)
	ok(prog.akumas_guardadas().is_empty(), "nenhuma fruta dada no inventário (%s)" % str(prog.akumas_guardadas()))
	# a limpeza de save antigo: lâminas e frutas dadas saem, o que passa da quantidade dada (comprado) fica, e só roda uma vez
	prog.sistemas.erase("limpeza")
	LaminasEpicFight.conceder_a(prog.equipamentos)
	prog.inventario.inserir(ItensEpicFight.nova_pilha(LaminasEpicFight.ids()[0]))
	prog.guardar_akuma("ope_ope_mine_piece", 10 + 2)
	prog.guardar_akuma("moku_moku_mine_piece", 10)
	ok(ItensEpicFight.limpar_concedidos(prog, {"ope_ope_mine_piece": 10, "moku_moku_mine_piece": 10}), "save antigo: a limpeza roda")
	ok(prog.equipamentos.keys().all(func(k): return not LaminasEpicFight.existe(str(k))) and inv.contar(ItensEpicFight.id_do_item(LaminasEpicFight.ids()[0])) == 0,
		"as lâminas dadas saem dos equipamentos e da mochila")
	ok(prog.quantas_akuma("ope_ope_mine_piece") == 2 and prog.quantas_akuma("moku_moku_mine_piece") == 0, "tira só o tanto de fruta que foi dado")
	ok(not ItensEpicFight.limpar_concedidos(prog, {"ope_ope_mine_piece": 10}) and prog.quantas_akuma("ope_ope_mine_piece") == 2, "a limpeza roda uma vez só")
	# daqui em diante o teste precisa de uma arma: concede uma de propósito
	LaminasEpicFight.conceder_a(prog.equipamentos)
	var primeira := ItensEpicFight.id_do_item(LaminasEpicFight.ids()[0])
	ok(RegrasDeItens.limite(primeira) == 1 and RegrasDeItens.nome(primeira) != "", "arma: limite 1 e nome (%s → %s)" % [primeira, RegrasDeItens.nome(primeira)])
	ok(RegrasDeItens.icone(primeira) != null, "arma: ícone do mod")
	# arrastar para a hotbar (slot 4) e escolher: equipa a lâmina
	var barra: BarraDeItensHud = null
	for n in get_nodes_in_group("hud"):
		for f in n.find_children("*", "BarraDeItensHud", true, false):
			barra = f
	ok(barra != null, "a barra de itens existe")
	if barra != null:
		var lamina := ItensEpicFight.lamina_do_item(primeira)
		var slot_h := InventarioMinecraft.HOTBAR_INI + 3
		var antes := inv.pilha(slot_h)
		inv.slots[slot_h] = ItensEpicFight.nova_pilha(lamina)
		barra.escolher(3)
		await q(5)
		ok(prog.lamina_ef == lamina and prog.espada_equipada, "escolher o slot equipa a arma (%s)" % prog.lamina_ef)
		ok(barra.slot_destacado() == 3, "o slot da arma fica destacado (%d)" % barra.slot_destacado())
		barra.selecionar(1)
		await q(3)
		ok(prog.item_em_uso() != "espada", "trocar de slot tira a arma da mão (%s)" % prog.item_em_uso())
	print("test_inventario_armas_ef: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
