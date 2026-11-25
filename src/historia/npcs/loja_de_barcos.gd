extends LojaDeNpc
# ============================================================================
#  VENDEDOR DE BARCOS (10/10/2026) — vende os barcos dirigíveis, 1 moeda cada.
#
#  Pedido do dono: "adicionar um npc que vende barcos, 1 moeda cada barco e retirar os
#  barcos que estão no mapa atualmente". Decisões dele: o barco comprado FICA SEU (salvo
#  no progresso), nasce na água do porto ao lado do vendedor e volta ao cais ao abrir o
#  jogo; um de cada tipo.
#
#  A lista sai da loja do editor: todo modelo da categoria "navios" com ficha de navio
#  que navega (os barcos-casa são cenário — `perfil_barco.gd`). Barco novo na loja do
#  editor = barco novo à venda. Quem põe na água é a `Navegacao` (`comando.gd`).
#  "Trazer ao cais": o barco já é seu e ficou longe (ou encalhou) — volta para a vaga.
# ============================================================================

const Barco := preload("res://src/historia/navios/barco.gd")
const Perfil := preload("res://src/historia/navios/perfil_barco.gd")
## Preço de TODO navio (22/11/2026, pedido do dono: "preço de todos os navios em 100 mil moedas"). Constante PRÓPRIA (não dá para sombrear `LojaDeNpc.PRECO`, que as outras lojas usam).
## GATILHO: preço por navio → coluna `preco` na ficha de navio, não aqui.
const PRECO_DO_NAVIO := 100000


## 5ª missão (22/11/2026): a missão da Alvida toma a conversa do vendedor quando é a vez dela (`MissaoDaAlvida.ao_conversar`). Devolve true = a loja NÃO abre agora.
var ao_conversar: Callable = Callable()


func intercepta() -> bool:
	return ao_conversar.is_valid() and bool(ao_conversar.call())


func fala() -> String:
	return "Quer um barco? Qualquer um por %s. Fica atracado aqui no cais." % moedas(PRECO_DO_NAVIO)


## [{id, nome, ficha}] dos barcos à venda, do menor para o maior.
static func barcos_a_venda(bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if bib == null:
		return saida
	for id in bib.ids():
		# Os 3 barcos antigos saíram da venda (18/10/2026); quem já tem um continua com ele.
		if not bib.categorias_do_modelo(id).has("navios") or not Perfil.e_navegavel(id) or id in Perfil.LEGADO:
			continue
		var f := bib.ficha_de_navio(id)
		if f.is_empty():
			continue
		saida.append({"id": id, "nome": Barco.nome_do_navio(id, f, str(bib.info(id)["nome"])), "ficha": f})
	saida.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["ficha"].get("comprimento", 0)) < float(b["ficha"].get("comprimento", 0)))
	return saida


func linhas(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for b in barcos_a_venda(bib):
		var f: Dictionary = b["ficha"]
		var detalhe := "%d m  ·  %.1f m/s  ·  tripulação %d" % [roundi(float(f.get("comprimento", 0))),
			float(f.get("velocidade", 0)), int(f.get("tripulacao", 0))]
		var botoes: Array
		if prog.barcos.has(b["id"]):
			detalhe += "  ·  é seu"
			botoes = [botao("Trazer ao cais", "trazer")]
		else:
			detalhe += "  ·  " + moedas(PRECO_DO_NAVIO)
			botoes = [botao("Comprar", "comprar", prog.ouro >= PRECO_DO_NAVIO)]
		saida.append(linha(b["id"], b["nome"], detalhe, botoes))
	return saida


func executar(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	var nome := ""
	for b in barcos_a_venda(bib):
		if b["id"] == id:
			nome = b["nome"]
	if nome.is_empty():
		return ""
	var nav := _navegacao()
	if acao == "comprar":
		if prog.barcos.has(id):
			return "%s já é seu." % nome
		if prog.ouro < PRECO_DO_NAVIO:
			return "Sem moedas  ·  venda peixes ao pescador"
		if not prog.comprar_barco(id, PRECO_DO_NAVIO):
			return ""
		var motivo: String = nav.lancar(id) if nav != null else "O porto não está pronto."
		if not motivo.is_empty():
			return "Comprado: %s  ·  %s Atraca aqui ao abrir o jogo." % [nome, motivo]
		return "Comprado: %s  ·  no cais, ao lado do vendedor  ·  Y no leme para pilotar" % nome
	if acao == "trazer" and prog.barcos.has(id):
		var motivo: String = nav.lancar(id) if nav != null else "O porto não está pronto."
		return "%s de volta ao cais." % nome if motivo.is_empty() else motivo
	return ""


static func _navegacao() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.get_first_node_in_group("navegacao_historia") if arvore != null else null
