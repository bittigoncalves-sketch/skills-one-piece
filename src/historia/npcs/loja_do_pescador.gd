extends "res://src/historia/missoes/loja_de_missao.gd"
# ============================================================================
#  LOJA DO PESCADOR (03/10/2026) — dá a vara de graça e COMPRA os peixes pescados.
#
#  Pedido do dono: vender os peixes, 1 moeda por peixe, independente da raridade
#  "por enquanto" (`LojaDeNpc.PRECO`).
# ============================================================================


func fala() -> String:
	return "Peixe fresco? Compro todos: %s cada. E a vara é de graça!" % moedas(PRECO)


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = super.linhas(prog, _bib)
	if prog.equipamentos.has("vara_de_pesca"):
		saida.append(linha("vara", "Vara de pesca", "você já tem  ·  equipe no N › PESCA", []))
	else:
		saida.append(linha("vara", "Vara de pesca", "de graça", [botao("Pegar", "pegar_vara")]))
	var peixes := _peixes(prog)
	var total := 0
	for id in peixes:
		total += int(prog.pesca[id])
	if total == 0:
		saida.append(linha("", "Nenhum peixe para vender", "pesque com a vara e volte aqui", []))
		return saida
	saida.append(linha("todos", "Todos os peixes", "%d peixe%s  ·  %s" % [total, "" if total == 1 else "s", moedas(total * PRECO)],
		[botao("Vender tudo", "vender_tudo")]))
	for id in peixes:
		var n := int(prog.pesca[id])
		saida.append(linha(id, TabelaDePeixes.nome(id), "%s  ·  × %d  ·  %s cada" % [
			TabelaDePeixes.NOME_DA_RARIDADE[TabelaDePeixes.raridade(id)], n, moedas(PRECO)],
			[botao("Vender 1", "vender_1")] if n == 1 else [botao("Vender 1", "vender_1"), botao("Vender %d" % n, "vender_todos")]))
	return saida


func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao in ["aceitar", "entregar"]: return super.executar(prog, _bib, acao, id)
	match acao:
		"pegar_vara":
			if prog.ganhar_equipamento("vara_de_pesca"):
				prog.contar_abate("vara_inicial")
				prog.entregar_missao("vara_inicial")
				return "Pescador: Toma, uma vara de pesca. É de graça! Ela já está na sua barra: equipe e pesque."
		"vender_1", "vender_todos":
			if not TabelaDePeixes.eh_peixe(id):
				return ""
			var n := prog.vender_item_de_pesca(id, 1 if acao == "vender_1" else int(prog.pesca.get(id, 0)), PRECO)
			if n > 0:
				return "Vendeu %d %s  ·  +%s" % [n, TabelaDePeixes.nome(id), moedas(n * PRECO)]
		"vender_tudo":
			var soma := 0
			for p in _peixes(prog):
				soma += prog.vender_item_de_pesca(p, int(prog.pesca.get(p, 0)), PRECO)
			if soma > 0:
				return "Vendeu %d peixe%s  ·  +%s" % [soma, "" if soma == 1 else "s", moedas(soma * PRECO)]
	return ""


## Os peixes do inventário (só os da tabela), pelo nome.
func _peixes(prog: ProgressaoDoPersonagem) -> Array[String]:
	var ids: Array[String] = []
	for id: String in prog.pesca:
		if TabelaDePeixes.eh_peixe(id) and int(prog.pesca[id]) > 0:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String): return TabelaDePeixes.nome(a) < TabelaDePeixes.nome(b))
	return ids
