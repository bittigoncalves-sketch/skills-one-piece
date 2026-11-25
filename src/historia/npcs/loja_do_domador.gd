extends LojaDeNpc
# ============================================================================
#  LOJA DO DOMADOR (03/10/2026) — vende animais de estimação novos, 1 moeda cada.
#
#  Decisão do dono: os DOMÁVEIS da ilha e também os bichos SELVAGENS (predadores
#  etc.). Fica de fora o chefe (`boss` na ficha): os chefes dos morros são para
#  derrotar, não para comprar — GATILHO: o dono pedir chefe à venda.
#  O pet comprado vai para o inventário (N › PETS), como o domado excedente.
#
#  A lista sai da loja do editor (todo modelo com ficha de animal) mais os pets de
#  corpo próprio (`CatalogoDePets`: gaivota, caranguejo). Modelo com comportamento
#  especial (o caranguejo grande do mapa) já é um desses — não repete.
# ============================================================================

const TIPO := {"domestico": "doméstico", "presa": "presa", "territorial": "territorial", "predador": "predador"}


func fala() -> String:
	return "Procurando um companheiro? Qualquer um por %s." % moedas(PRECO)


## [{id, nome, detalhe}] dos animais à venda, pelo nome.
static func especies(bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for id in CatalogoDePets.ids():
		saida.append({"id": id, "nome": CatalogoDePets.nome(id), "detalhe": "companheiro"})
	if bib != null:
		for id in bib.ids():
			var f := bib.ficha_de_animal(id)
			if f.is_empty() or bool(f.get("boss", false)) or not bib.comportamento_do_modelo(id).is_empty():
				continue
			var partes: Array[String] = []
			var t := str(f.get("comportamento", ""))
			if TIPO.has(t):
				partes.append(TIPO[t])
			if bib.categorias_do_modelo(id).has("montarias"):
				partes.append("montaria")
			saida.append({"id": id, "nome": str(f.get("nome", bib.info(id)["nome"])), "detalhe": "  ·  ".join(partes)})
	saida.sort_custom(func(a: Dictionary, b: Dictionary): return str(a["nome"]) < str(b["nome"]))
	return saida


func linhas(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for e in especies(bib):
		var detalhe: String = moedas(PRECO) if str(e["detalhe"]).is_empty() else "%s  ·  %s" % [e["detalhe"], moedas(PRECO)]
		saida.append(linha(e["id"], e["nome"], detalhe,
			[botao("Comprar", "comprar", prog.ouro >= PRECO)]))
	return saida


func executar(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao != "comprar":
		return ""
	for e in especies(bib):
		if e["id"] == id:
			if prog.ouro < PRECO:
				return "Sem moedas  ·  venda peixes ao pescador"
			if prog.comprar_pet(id, e["nome"], PRECO).is_empty():
				return ""
			return "%s comprado  ·  foi para o inventário (N › PETS)" % e["nome"]
	return ""
