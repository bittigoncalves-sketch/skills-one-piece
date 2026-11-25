extends LojaDeNpc
# ============================================================================
#  LOJA DO VENDEDOR DE FRUTAS (03/10/2026) — as Akuma no Mi da arena (singleplayer)
#  no Modo História, com preços definidos em PerfilDeFrutas.
#
#  Decisões do dono: o kit da arena na escala da história (`PerfilDeFrutas.da_arena`)
#  e a compra vai para o INVENTÁRIO (N › FRUTAS) — come-se quando quiser, trocando
#  a fruta atual. A Rocket não está aqui: ela é a fruta do mapa da história.
# ============================================================================


func fala() -> String:
	return "Frutas do diabo · menor preço primeiro. Só dá para ter uma no corpo."


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var ids := PerfilDeFrutas.frutas_a_venda()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa := PerfilDeFrutas.preco_na_loja(a)
		var pb := PerfilDeFrutas.preco_na_loja(b)
		return pa < pb if pa != pb else PerfilDeFrutas.nome_da_fruta(a).naturalnocasecmp_to(PerfilDeFrutas.nome_da_fruta(b)) < 0)
	for id in ids:
		var preco := PerfilDeFrutas.preco_na_loja(id)
		var partes: Array[String] = []
		var guardadas := prog.quantas_akuma(id)
		if guardadas > 0:
			partes.append("%d no inventário" % guardadas)
		if prog.fruta == id:
			partes.append("é a que você comeu")
		var item := linha(id, PerfilDeFrutas.nome_da_fruta(id), "  ·  ".join(partes),
			[botao("Comprar", "comprar", prog.ouro >= preco)])
		item["preco"] = preco
		item["imagem"] = PerfilDeFrutas.imagem_na_loja(id)
		saida.append(item)
	return saida


func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao != "comprar":
		return ""
	var preco := PerfilDeFrutas.preco_na_loja(id)
	if prog.ouro < preco:
		return "Sem moedas  ·  venda peixes ao pescador"
	if prog.comprar_fruta(id, preco):
		return "%s comprada  ·  N › FRUTAS para comer" % PerfilDeFrutas.nome_da_fruta(id)
	return ""
