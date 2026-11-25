extends LojaDeNpc
# ============================================================================
#  LOJA DO BARBA NEGRA (15/10/2026) — o mesmo Barba Negra da arena, na cidade inicial.
#
#  Quatro coisas, decisão do dono (a ROLETA é de 15/10/2026, mesma data):
#    • RETIRAR a Akuma no Mi do corpo. A fruta se PERDE (não volta ao inventário) e é
#      de graça; o domínio aprendido (skill Fruta) continua, como em `tirar_fruta`.
#    • GEPPO (era "pulo no ar") — 10 moedas, uma vez. Pula no ar sem limite de vezes; cada pulo gasta 30 de energia (20/11/2026).
#    • DASH NO AR — 10 moedas, uma vez (20/11/2026; era 1000). Cada dash gasta 20 de energia, sem recarga. O roll do chão é de graça e não passa por aqui.
#
#    • ROLETA DE TRIPULANTES — 100 moedas por giro: comum (Nami, Sanji e os quatro
#      cozinheiros), incomum (Crocodile) ou lendário (Barba Negra), sem repetir. Quem vai a bordo: `Tripulacao`.
#  A janela lista as opções por PREÇO crescente (grátis primeiro), com cor, símbolo e preço
#  em cada uma, e mede `ESCALA_DA_UI` vezes a loja padrão.
#
#  Só regras: o preço e o desbloqueio moram na `ProgressaoDoPersonagem`
#  (`comprar_habilidade`, `PRECO_HABILIDADE`); os custos de energia, nas capacidades.
# ============================================================================

const ACAO_RETIRAR := "retirar"
const ACAO_COMPRAR := "comprar"
const ACAO_GIRAR := "girar"
const ID_FRUTA := "retirar_fruta"
const ID_ROLETA := "roleta"
## 19/11/2026, pedido do dono ("muito grande"): era 1,3. Agora 0,9; a janela ainda encolhe sozinha se a tela for menor (`JanelaDeLoja._caber_na_tela`).
const ESCALA_DA_UI := 0.9
## Cores de destaque das linhas (a janela pinta a faixa, o símbolo e o preço com elas).
const COR_GRATIS := Color(0.40, 0.82, 0.50)
const COR_ROLETA := Color(0.72, 0.45, 0.95)
const COR_PULO := Color(0.35, 0.72, 0.98)
const COR_DASH := Color(0.98, 0.58, 0.28)
const COR_DA_HABILIDADE := {"pulo_duplo": COR_PULO, "dash": COR_DASH}
const SIMBOLO_DA_HABILIDADE := {"pulo_duplo": "pulo", "dash": "dash"}
## Injetável: o teste fixa o sorteio.
var rng := RandomNumberGenerator.new()
var _giro := {}
## chave de `desbloqueios` → nome mostrado e custo de energia (texto).
const HABILIDADES := {
	"pulo_duplo": {"nome": "Geppo (pulo no ar)", "energia": ProgressaoDoPersonagem.CUSTO_PULO_NO_AR},
	"dash": {"nome": "Dash no ar", "energia": ProgressaoDoPersonagem.CUSTO_DASH_NO_AR},
}


func _init() -> void:
	rng.randomize()


func escala_da_ui() -> float:
	return ESCALA_DA_UI


## Missão "Resgate o baú" (21/11/2026): a conversa de missão é a genérica (`LojaDeMissao`), posta NO TOPO da janela; quem a cria (`NpcDaIlha.loja`) preenche `npc`/`missao`/`progressao`.
var npc := ""
var missao := ""
var progressao: ProgressaoDoPersonagem = null
var _conversa: LojaDeNpc = null


func _conversa_de_missao() -> LojaDeNpc:
	if _conversa == null:
		_conversa = preload("res://src/historia/missoes/loja_de_missao.gd").new()
	_conversa.set("npc", npc)
	_conversa.set("missao", missao)
	_conversa.set("progressao", progressao)
	return _conversa


## A fala do Barba Negra: na missão do baú ela vem do `data/dialogos/bau.json` (Codex) nos QUATRO estados — oferta (disponível E desbloqueada), andamento, pronta e concluída (depois de entregue
## a missão sai da "vez" do NPC, então se usa a última da cadeia). Missão BLOQUEADA (falta o desafio do Buggy) ou sem missão: a fala das lojas, como sempre.
func fala() -> String:
	if progressao == null or missao.is_empty():
		return _fala_das_lojas()
	var Missoes = preload("res://src/historia/missoes/missoes.gd")
	var m := Missoes_da_vez()
	if m.is_empty():
		m = Missoes.ultima_do_npc(npc)             # tudo entregue: a última (concluída)
	if m != "resgate_do_bau":
		return _fala_das_lojas()
	var estado_da_missao := progressao.estado_da_missao(m)
	var estado := ""
	match estado_da_missao:
		"disponivel":
			var antes := str(Missoes.dados(m).get("depois_de", ""))
			if antes.is_empty() or progressao.estado_da_missao(antes) == "entregue":
				estado = "oferta"                  # desbloqueada
		"aceita": estado = "andamento"
		"pronta": estado = "pronta"
		"entregue": estado = "concluida"
	if estado.is_empty():
		return _fala_das_lojas()
	var padrao: Array[Dictionary] = [DialogosDeNpc.linha("Barba Negra", _conversa_de_missao().fala())]
	var falas := DialogosDeNpc.linhas("bau", estado, padrao)       # as falas do Codex
	return " ".join(falas.map(func(l: Dictionary) -> String: return str(l["texto"])))


func Missoes_da_vez() -> String:
	return preload("res://src/historia/missoes/missoes.gd").atual_do_npc(npc, progressao) if progressao != null else ""


func _fala_das_lojas() -> String:
	return "Gwahaha! Tiro a fruta do seu corpo de graça, giro a sorte da tripulação por %s, ensino o Geppo, pulos no ar enquanto durar a energia, por %s e o dash por %s." \
		% [moedas(CatalogoDeTripulantes.PRECO_DA_ROLETA), moedas(ProgressaoDoPersonagem.preco_da_habilidade("pulo_duplo")),
			moedas(ProgressaoDoPersonagem.preco_da_habilidade("dash"))]


func consumir_giro() -> Dictionary:
	var g := _giro
	_giro = {}
	return g


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not missao.is_empty():
		progressao = prog
		saida.append_array(_conversa_de_missao().linhas(prog, _bib))      # a missão da vez vem primeiro
	var detalhe := "tira a Akuma no Mi do corpo  ·  a fruta se perde"
	if prog.fruta.is_empty():
		detalhe = "você não comeu nenhuma fruta"
	else:
		detalhe = "%s  ·  %s" % [PerfilDeFrutas.nome_da_fruta(prog.fruta), detalhe]
	saida.append(linha(ID_FRUTA, "Retirar fruta", detalhe,
		[botao("Retirar", ACAO_RETIRAR, not prog.fruta.is_empty())], 0, COR_GRATIS, "cruz"))
	var restam := CatalogoDeTripulantes.restantes(prog.recrutados).size()
	var preco_roleta := CatalogoDeTripulantes.PRECO_DA_ROLETA
	var texto_roleta := "Comuns: Nami, Sanji e cozinheiros  ·  incomum: Crocodile  ·  lendário: Barba Negra  ·  restam %d de %d" \
		% [restam, CatalogoDeTripulantes.ids().size()] if restam > 0 else "todos os tripulantes já são seus"
	saida.append(linha(ID_ROLETA, "Roleta de tripulantes", texto_roleta,
		[botao("Girar", ACAO_GIRAR, restam > 0 and prog.ouro >= preco_roleta)], preco_roleta, COR_ROLETA, "roleta"))
	for chave: String in ProgressaoDoPersonagem.HABILIDADES_A_VENDA:
		var h: Dictionary = HABILIDADES[chave]
		var comprada := bool(prog.desbloqueios[chave])
		var texto := "%s  ·  gasta %d de energia por uso" % [
			"já aprendida" if comprada else "uma vez só", int(h["energia"])]
		saida.append(linha(chave, str(h["nome"]), texto, [botao("Aprender" if not comprada else "Aprendida", ACAO_COMPRAR,
			not comprada and prog.ouro >= ProgressaoDoPersonagem.preco_da_habilidade(chave))],
			ProgressaoDoPersonagem.preco_da_habilidade(chave), COR_DA_HABILIDADE[chave], SIMBOLO_DA_HABILIDADE[chave]))
	# Do mais barato ao mais caro (a retirada grátis no topo); empate fica na ordem acima.
	var indexada: Array[Dictionary] = []
	for i in saida.size():
		saida[i]["_ordem"] = i
		indexada.append(saida[i])
	indexada.sort_custom(func(a, b): return a["preco"] < b["preco"] or (a["preco"] == b["preco"] and a["_ordem"] < b["_ordem"]))
	return indexada


func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao == "entregar" and not missao.is_empty() and Missoes_da_vez() == "resgate_do_bau":
		progressao = prog
		var r := RegrasDoResgateDoBau.entregar(prog)          # consome o Baú misterioso da mochila e paga
		if bool(r["ok"]):
			var d := preload("res://src/historia/missoes/missoes.gd").dados("resgate_do_bau")
			var texto := "Missão concluída: %s  ·  +%d XP  ·  +%s" % [d["nome"], int(d["xp"]), moedas(int(d["ouro"]))]
			if d.has("fruta"):
				texto += "  ·  %s (N › FRUTAS)" % PerfilDeFrutas.nome_da_fruta(str(d["fruta"]))
			return texto
		return str(r["motivo"])
	if (acao == "aceitar" or acao == "entregar") and not missao.is_empty():
		progressao = prog
		return _conversa_de_missao().executar(prog, _bib, acao, id)
	if acao == ACAO_RETIRAR and id == ID_FRUTA:
		if prog.fruta.is_empty():
			return "Você não comeu nenhuma fruta"
		var nome := PerfilDeFrutas.nome_da_fruta(prog.fruta)
		prog.tirar_fruta()
		return "%s retirada  ·  a fruta se perdeu" % nome
	if acao == ACAO_GIRAR and id == ID_ROLETA:
		return _girar(prog)
	if acao != ACAO_COMPRAR or not HABILIDADES.has(id):
		return ""
	if bool(prog.desbloqueios[id]):
		return "Você já aprendeu isso"
	var preco := ProgressaoDoPersonagem.preco_da_habilidade(id)
	if prog.ouro < preco:
		return "Sem moedas  ·  venda peixes ao pescador"
	if prog.comprar_habilidade(id, preco):
		return "%s aprendido  ·  gasta %d de energia por uso" % [HABILIDADES[id]["nome"], int(HABILIDADES[id]["energia"])]
	return ""


## O giro: sorteia ANTES de cobrar (sem sorteio não há cobrança) e grava tudo de uma vez.
func _girar(prog: ProgressaoDoPersonagem) -> String:
	var preco := CatalogoDeTripulantes.PRECO_DA_ROLETA
	if CatalogoDeTripulantes.restantes(prog.recrutados).is_empty():
		return "Você já tem todos os tripulantes"
	if prog.ouro < preco:
		return "Sem moedas  ·  a roleta custa %s" % moedas(preco)
	var id := CatalogoDeTripulantes.sortear(prog.recrutados, rng)
	if id.is_empty() or not prog.recrutar_por_sorteio(id, preco):
		return ""
	var raridade := CatalogoDeTripulantes.raridade(id)
	_giro = {"id": id, "nome": CatalogoDeTripulantes.nome(id), "raridade": raridade}
	return "%s (%s) entrou para a tripulação" % [CatalogoDeTripulantes.nome(id),
		CatalogoDeTripulantes.nome_da_raridade(raridade).to_lower()]
