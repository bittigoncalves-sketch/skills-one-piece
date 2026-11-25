extends SceneTree
## Alimentos (18/11/2026): a banca do Vendedor de provisões vende vários tipos; comida e bebida têm barra própria, consumo do mais fraco ao mais forte.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_alimentos_variados.gd
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const Loja := preload("res://src/historia/npcs/loja_de_comida.gd")
var total := 0
var falhas := 0
func _init() -> void: rodar.call_deferred()
func ok(sim: bool, m: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("  ✅ " if sim else "  ❌ ") + m)
func rodar() -> void:
	await process_frame
	ok(P.VENDIDOS.size() >= 8, "a banca vende vários alimentos (%d)" % P.VENDIDOS.size())
	for id in P.VENDIDOS:
		ok(P.ITENS.has(id) and int(P.ITENS[id].preco) >= 1 and (float(P.ITENS[id].fome) > 0 or float(P.ITENS[id].sede) > 0), id + ": tem preço e devolve fome ou sede")
	var na_barra := {}
	for id in P.COMIDAS_NA_BARRA + P.BEBIDAS_NA_BARRA: na_barra[id] = true
	ok(P.ITENS.keys().all(func(k): return na_barra.has(k)), "todo alimento está numa das barras (comida ou água)")
	var ordem := -1.0
	var crescente := true
	for id in P.COMIDAS_NA_BARRA:
		crescente = crescente and float(P.ITENS[id].fome) >= ordem
		ordem = float(P.ITENS[id].fome)
	ok(crescente, "a barra de comida gasta do mais fraco ao mais forte")
	var prog := ProgressaoDoPersonagem.new()
	var loja := Loja.new()
	var linhas := loja.linhas(prog, null)
	ok(linhas.size() == P.VENDIDOS.size(), "a loja lista um item por alimento (%d)" % linhas.size())
	# compra e consumo pela barra
	prog.ouro = 20
	for id in ["maca", "carne_assada", "leite", "suco_de_laranja", "sopa_de_peixe", "peixe_assado"]:
		loja.executar(prog, null, "comprar", id)
	ok(int(P.estado(prog).estoque.get("carne_assada", 0)) == 1 and prog.ouro == 20 - 1 - 5 - 2 - 3 - 3 - 2, "comprar cobra o preço de cada alimento (sobram %d)" % prog.ouro)
	loja.executar(prog, null, "comprar", "ouro_falso")
	ok(not P.estado(prog).estoque.has("ouro_falso"), "id inválido não entra no estoque")
	prog.ouro = 0
	loja.executar(prog, null, "comprar", "carne_assada")
	ok(int(P.estado(prog).estoque.carne_assada) == 1, "sem moedas não compra")
	var d := P.estado(prog)
	d.fome = 100.0
	d.sede = 100.0
	prog.item_ativo = "comida"
	ok(P.quantidade_comida(prog) == 4, "contagem da barra de comida soma todos os tipos (%d)" % P.quantidade_comida(prog))
	ok(P.comer_da_barra(prog) and int(d.estoque.maca) == 0 and is_equal_approx(float(d.fome), 115.0) and is_equal_approx(float(d.sede), 105.0), "1º clique come a maçã (fome 115, sede +5)")
	ok(P.comer_da_barra(prog) and int(d.estoque.peixe_assado) == 0, "2º clique come o peixe (o seguinte mais fraco)")
	prog.item_ativo = "agua"
	d.sede = 100.0
	ok(P.quantidade_agua(prog) == 2, "contagem da barra de água soma as bebidas (%d)" % P.quantidade_agua(prog))
	ok(P.beber_da_barra(prog) and int(d.estoque.leite) == 0 and is_equal_approx(float(d.sede), 150.0), "bebe o leite primeiro (sede 150)")
	ok(P.beber_da_barra(prog) and int(d.estoque.suco_de_laranja) == 0 and float(d.sede) >= 240.0, "depois o suco")
	ok(not P.beber_da_barra(prog), "sem bebida não faz nada")
	# consumo pelo menu B: recusa o que não serve, aceita o que serve só pela sede
	d.estoque["maca"] = 1
	d.fome = P.FOME_MAX
	d.sede = P.SEDE_MAX
	ok(not P.consumir(prog, "maca") and int(d.estoque.maca) == 1, "saciado de fome e sede: não gasta a maçã")
	d.sede = 100.0
	ok(P.consumir(prog, "maca") and int(d.estoque.maca) == 0, "com sede, a maçã serve")
	print("ALIMENTOS: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
