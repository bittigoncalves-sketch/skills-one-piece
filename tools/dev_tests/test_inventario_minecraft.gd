extends SceneTree
## Inventário estilo Minecraft (modelo): empilhar, limites, cliques esquerdo/direito/shift/número, armadura, grade 2×2 com receitas do jar e do mod,
## salvar/carregar. Rodar: godot --headless --path . --script tools/dev_tests/test_inventario_minecraft.gd
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func N(id: String, q := 1) -> McItem.Pilha: return InventarioMinecraft.nova(id, q)
func _init() -> void:
	await process_frame
	var I := InventarioMinecraft
	var inv := I.new()
	# ---- limites e inserção
	ok(RegrasDeItens.limite("minecraft:stone") == 64 and RegrasDeItens.limite("minecraft:iron_sword") == 1 and RegrasDeItens.limite("minecraft:ender_pearl") == 16
		and RegrasDeItens.limite("minepiece:biscuit") == 64 and RegrasDeItens.limite("minepiece:yoru") == 1, "limites de pilha (64 / 16 / 1; espada do mod 1)")
	var resto := inv.inserir(N("minecraft:stone", 150))
	ok(resto.isEmpty() and inv.contar("minecraft:stone") == 150, "150 pedras cabem (3 pilhas)")
	ok(inv.pilha(I.HOTBAR_INI).quantidade == 64 and inv.pilha(I.HOTBAR_INI + 2).quantidade == 22, "enche a hotbar primeiro, pilhas de 64")
	inv.inserir(N("minecraft:stone", 50))
	ok(inv.pilha(I.HOTBAR_INI + 2).quantidade == 64 and inv.pilha(I.HOTBAR_INI + 3).quantidade == 8, "completa a pilha antes de abrir vaga nova")
	var cheio := I.new()
	for k in 36:
		cheio.inserir(N("minecraft:iron_sword", 1))
	ok(not cheio.inserir(N("minecraft:iron_sword", 3)).isEmpty() and cheio.inserir(N("minecraft:iron_sword", 3)).quantidade == 3, "inventário cheio devolve o resto")
	ok(inv.remover("minecraft:stone", 100) and inv.contar("minecraft:stone") == 100 and not inv.remover("minecraft:stone", 500) and inv.contar("minecraft:stone") == 100, "remover gasta o que tem e recusa o que falta")
	# ---- cliques
	var c := I.new()
	c.slots[I.MOCHILA_INI] = N("minecraft:stone", 10)
	c.clique(I.MOCHILA_INI, 0)
	ok(c.cursor.quantidade == 10 and c.pilha(I.MOCHILA_INI).isEmpty(), "esquerdo pega a pilha inteira")
	c.clique(I.MOCHILA_INI + 1, 0)
	ok(c.pilha(I.MOCHILA_INI + 1).quantidade == 10 and c.cursor.isEmpty(), "esquerdo solta na vaga")
	c.clique(I.MOCHILA_INI + 1, 1)
	ok(c.cursor.quantidade == 5 and c.pilha(I.MOCHILA_INI + 1).quantidade == 5, "direito pega a metade (arredonda para cima: 5 de 10)")
	c.clique(I.MOCHILA_INI + 2, 1)
	ok(c.pilha(I.MOCHILA_INI + 2).quantidade == 1 and c.cursor.quantidade == 4, "direito com item no cursor solta UM")
	c.clique(I.MOCHILA_INI + 1, 0)
	ok(c.pilha(I.MOCHILA_INI + 1).quantidade == 9 and c.cursor.quantidade == 0 or c.cursor.isEmpty(), "esquerdo junta pilhas iguais (%d)" % c.pilha(I.MOCHILA_INI + 1).quantidade)
	var t := I.new()
	t.slots[I.MOCHILA_INI] = N("minecraft:stone", 3)
	t.cursor = N("minecraft:dirt", 2)
	t.clique(I.MOCHILA_INI, 0)
	ok(I.id_de(t.pilha(I.MOCHILA_INI)) == "minecraft:dirt" and I.id_de(t.cursor) == "minecraft:stone" and t.cursor.quantidade == 3, "esquerdo troca itens diferentes")
	# ---- shift
	var s := I.new()
	s.slots[I.MOCHILA_INI] = N("minecraft:stone", 8)
	s.clique(I.MOCHILA_INI, 0, true)
	ok(s.pilha(I.HOTBAR_INI).quantidade == 8 and s.pilha(I.MOCHILA_INI).isEmpty(), "shift: mochila → hotbar")
	s.clique(I.HOTBAR_INI, 0, true)
	ok(s.pilha(I.MOCHILA_INI).quantidade == 8, "shift: hotbar → mochila")
	s.slots[I.MOCHILA_INI + 5] = N("minecraft:iron_helmet", 1)
	s.clique(I.MOCHILA_INI + 5, 0, true)
	ok(I.id_de(s.pilha(I.ARMADURA_INI)) == "minecraft:iron_helmet", "shift: capacete vai para o slot da cabeça")
	s.clique(I.ARMADURA_INI, 0, true)
	ok(s.pilha(I.ARMADURA_INI).isEmpty() and s.contar("minecraft:iron_helmet") == 1, "shift: armadura volta para a mochila")
	# ---- armadura só aceita a peça certa
	var a := I.new()
	a.cursor = N("minecraft:iron_boots", 1)
	a.clique(I.ARMADURA_INI, 0)
	ok(a.pilha(I.ARMADURA_INI).isEmpty() and I.id_de(a.cursor) == "minecraft:iron_boots", "bota não entra no slot da cabeça")
	a.clique(I.ARMADURA_INI + 3, 0)
	ok(I.id_de(a.pilha(I.ARMADURA_INI + 3)) == "minecraft:iron_boots", "bota entra no slot dos pés")
	# ---- número troca com a hotbar
	var n := I.new()
	n.slots[I.MOCHILA_INI] = N("minecraft:apple", 4)
	n.slots[I.HOTBAR_INI + 2] = N("minecraft:stick", 7)
	n.trocar_com_hotbar(I.MOCHILA_INI, 2)
	ok(I.id_de(n.pilha(I.HOTBAR_INI + 2)) == "minecraft:apple" and I.id_de(n.pilha(I.MOCHILA_INI)) == "minecraft:stick", "tecla 3 troca o slot sob o mouse com a hotbar")
	# ---- fabricação 2×2 (receitas do jar)
	var f := I.new()
	f.slots[1] = N("minecraft:oak_log", 3)
	ok(I.id_de(f.pilha(0)) == "", "sem recalcular ainda não há resultado")
	f.clique(1, 0)                                           # (recalcula) pega o cursor e devolve
	f.clique(1, 0)
	ok(I.id_de(f.pilha(0)) == "minecraft:oak_planks" and f.pilha(0).quantidade == 4, "1 tronco de carvalho → 4 tábuas (tag de troncos) (%s ×%d)" % [I.id_de(f.pilha(0)), f.pilha(0).quantidade])
	f.clique(0, 0)
	ok(f.cursor.quantidade == 4 and f.pilha(1).quantidade == 2, "pegar o resultado gasta 1 tronco da grade")
	f.cursor = I.vazia()
	f.slots[1] = N("minecraft:oak_planks", 2)
	f.slots[3] = N("minecraft:oak_planks", 2)
	f._avisar()
	ok(I.id_de(f.pilha(0)) == "minecraft:stick" and f.pilha(0).quantidade == 4, "2 tábuas em coluna → 4 gravetos (%s ×%d)" % [I.id_de(f.pilha(0)), f.pilha(0).quantidade])
	var m := I.new()
	for k in 4:
		m.slots[1 + k] = N("minecraft:oak_planks", 1)
	m._avisar()
	ok(I.id_de(m.pilha(0)) == "minecraft:crafting_table", "4 tábuas 2×2 → bancada")
	var mod := I.new()                                       # receita do Mine Piece (sem forma): ferro + pólvora → 9 balas
	mod.slots[1] = N("minecraft:iron_ingot", 1)
	mod.slots[4] = N("minecraft:gunpowder", 1)
	mod._avisar()
	ok(I.id_de(mod.pilha(0)) == "minepiece:item_bullet" and mod.pilha(0).quantidade == 9, "receita do mod: ferro + pólvora → 9 balas (%s ×%d)" % [I.id_de(mod.pilha(0)), mod.pilha(0).quantidade])
	var sab := I.new()                                       # com forma: lingote em cima da espada → sabre (e o espelho/posição também)
	sab.slots[1] = N("minecraft:iron_ingot", 1)
	sab.slots[3] = N("minecraft:iron_sword", 1)
	sab._avisar()
	ok(I.id_de(sab.pilha(0)) == "minepiece:saber", "receita do mod com forma: lingote sobre espada → sabre")
	sab.slots[1] = I.vazia()
	sab.slots[3] = I.vazia()
	sab.slots[2] = N("minecraft:iron_ingot", 1)
	sab.slots[4] = N("minecraft:iron_sword", 1)
	sab._avisar()
	ok(I.id_de(sab.pilha(0)) == "minepiece:saber", "a mesma receita na outra coluna (posição livre na grade)")
	sab.slots[4] = N("minecraft:iron_ingot", 1)
	sab.slots[2] = N("minecraft:iron_sword", 1)
	sab._avisar()
	ok(I.id_de(sab.pilha(0)) == "", "ordem trocada (espada sobre lingote) não fabrica")
	# ---- fechar devolve a grade
	var g := I.new()
	g.slots[1] = N("minecraft:stone", 5)
	g.cursor = N("minecraft:dirt", 3)
	g.fechar()
	ok(g.pilha(1).isEmpty() and g.cursor.isEmpty() and g.contar("minecraft:stone") == 5 and g.contar("minecraft:dirt") == 3, "fechar devolve cursor e grade à mochila")
	# ---- salvar / carregar
	var p := I.new()
	p.inserir(N("minepiece:biscuit", 12))
	p.slots[I.ARMADURA_INI + 1] = N("minecraft:iron_chestplate", 1)
	p.selecionado = 4
	var q := I.de_dict(JSON.parse_string(JSON.stringify(p.para_dict())))
	ok(q.contar("minepiece:biscuit") == 12 and I.id_de(q.pilha(I.ARMADURA_INI + 1)) == "minecraft:iron_chestplate" and q.selecionado == 4, "salvar/carregar (JSON) mantém itens, armadura e hotbar")
	print("test_inventario_minecraft: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
