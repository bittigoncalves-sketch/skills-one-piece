extends RefCounted
# ============================================================================
#  ILHAS DO MODO HISTÓRIA (08/10/2026) — o cadastro: nome, baseplate e mar. (O teto de nível por
#  ilha saiu em 26/10/2026: o nível vem só da recompensa, como no Mine Piece.)
#  Fonte ÚNICA (progressão, aviso de chegada, bússola e desenho por distância leem daqui).
#
#  Pedido do dono: "adicionar mais uma ilha a ilha dos macacos"; plano e decisões em
#  docs/ILHA_DOS_MACACOS_PLANO.md. O teto que vale é o da ilha MAIS AVANÇADA já
#  visitada (`ProgressaoDoPersonagem.ilhas_visitadas`): chegar à dos macacos libera o 20.
#
#  Ilha nova = uma entrada aqui + a baseplate dela no mapa (`baseplate_<algo>`). A forma
#  da ilha no mundo sai do MAPA: as baseplates que se tocam formam uma ilha (a mesma
#  regra do `FundoDoMar`), então aumentar a ilha no editor não pede mudança aqui.
# ============================================================================

const INICIAL := "ilha_inicial"
const MACACOS := "ilha_dos_macacos"
## Ilha do East Blue (17/10/2026): os personagens do Mine Piece, uma zona por bando
## (docs/EAST_BLUE_PLANO.md; gerada por tools/mapa_ilha/gerar_ilha_east_blue.gd).
const EAST_BLUE := "ilha_east_blue"
## Ilhas das estruturas do Mine Piece (18/10/2026, docs/ESTRUTURAS_MINE_PIECE_PLANO.md; geradas
## por tools/mapa_ilha/gerar_ilhas_mine_piece.gd): uma por facção em volta do East Blue
## (teto 30) e as da Grand Line a leste, com teto maior.
const TABELA := {
	INICIAL: {"nome": "Ilha Inicial", "base": "baseplate", "mar": "east_blue", "elenco_mp": ["pirate", "suzume", "chouchou"]},
	MACACOS: {"nome": "Ilha dos Macacos", "base": "baseplate_macacos", "mar": "east_blue"},
	EAST_BLUE: {"nome": "Ilha do East Blue", "base": "baseplate_east_blue", "mar": "east_blue"},
	"ilha_marinha_153": {"nome": "Base da Marinha 153", "base": "baseplate_marinha_153", "mar": "east_blue"},
	"ilha_acampamento_pirata": {"nome": "Acampamento Pirata", "base": "baseplate_acampamento_pirata", "mar": "east_blue"},
	"ilha_acampamento_bandido": {"nome": "Acampamento Bandido", "base": "baseplate_acampamento_bandido", "mar": "east_blue"},
	"ilha_vila_foosha": {"nome": "Vila Foosha", "base": "baseplate_vila_foosha", "mar": "east_blue"},
	"ilha_vila_shimotsuki": {"nome": "Vila Shimotsuki", "base": "baseplate_vila_shimotsuki", "mar": "east_blue"},
	"ilha_water_seven": {"nome": "Water Seven", "base": "baseplate_water_seven", "mar": "grand_line"},
	"ilha_wano": {"nome": "Wano", "base": "baseplate_wano", "mar": "grand_line"},
	"ilha_shandora": {"nome": "Shandora", "base": "baseplate_shandora", "mar": "grand_line"},
}
## Além da placa ainda é "na ilha": o anel de praia (24 m) e o raso da costa.
const MARGEM := 40.0


## Elenco do Mine Piece liberado no spawn natural da ilha (ids de ficha). Vazio = sem restrição.
## Decisão do dono (25/11/2026): a primeira ilha só tem pirata, suzume (o "galo") e Chouchou;
## os demais voltam em outras ilhas conforme forem reconstruídos (ver docs/MINE_PIECE_MEDICAO_MODIFICACAO.md).
static func elenco_mp(id: String) -> Array:
	return TABELA.get(id, {}).get("elenco_mp", [])


static func existe(id: String) -> bool:
	return TABELA.has(id)


static func nome(id: String) -> String:
	return str(TABELA.get(id, {}).get("nome", id))


## O mar da ilha (o da raid do Mine Piece): "east_blue" ou "grand_line".
static func mar(id: String) -> String:
	return str(TABELA.get(id, {}).get("mar", ""))


## A placa (Rect2 em x, z) de cada ilha cadastrada que existe no mapa: id → Rect2.
static func caixas(mapa: Dictionary) -> Dictionary:
	var bases: Array = []
	for p: Dictionary in mapa.get("pecas", []):
		var id := String(p.get("id", ""))
		if p.get("tipo") == "caixa" and (id == "baseplate" or id.begins_with("baseplate_")):
			bases.append(p)
	var saida := {}
	for grupo in FundoDoMar.agrupar(bases):
		for ilha in TABELA:
			if grupo.any(func(b: Dictionary) -> bool: return b["id"] == TABELA[ilha]["base"]):
				saida[ilha] = FundoDoMar.caixa_de(grupo)
	return saida


## Distância (m, no plano) de `p` até a placa: 0 em cima dela.
static func distancia(caixa: Rect2, p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	return q.distance_to(q.clamp(caixa.position, caixa.end))


## Em qual ilha `p` está (até `margem` da placa); "" = no mar.
static func ilha_em(caixas_: Dictionary, p: Vector3, margem := MARGEM) -> String:
	var melhor := ""
	var menor := INF
	for id in caixas_:
		var d := distancia(caixas_[id], p)
		if d <= margem and d < menor:
			melhor = id
			menor = d
	return melhor
