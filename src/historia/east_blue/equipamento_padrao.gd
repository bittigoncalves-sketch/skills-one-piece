class_name EquipamentoPadrao
extends RefCounted
# ============================================================================
#  EQUIPAMENTO PADRÃO DAS ENTIDADES DO MOD (30/10/2026).
#
#  No Mine Piece a entidade já nasce com itens postos no CONSTRUTOR Java (`setItemSlot(MAINHAND, rifle)`):
#  Yasopp e Benn Beckman com fuzil, Helmeppo com pistola, Charlos com a pistola dourada… O jogo cria personagens
#  pela ficha, então isso se perdia e o atirador ficava de mãos vazias (a IA do mod, que só atira com arma de fogo na
#  mão — `LogicRifleProcedure` —, nunca disparava). Os dados vêm de `tools/mine_piece/extrair_equipamento.py`
#  (`mapas/east_blue/equipamento_padrao.json`); quem aplica é o `PersonagemMinePiece`, antes do `ao_nascer` do mod
#  (SetTagMarine/SetTagPirate), na ordem do Java: construtor primeiro, depois o sorteio do nascimento.
#
#  Só ARMAS DE FOGO por enquanto (as dos grupos `forge:rifle` e `forge:launcher` do mod). Gatilho para o resto
#  (espadas, roupas): quando o dono pedir o equipamento completo — os dados já trazem todos os 163.
# ============================================================================
const ARQUIVO := "res://mapas/east_blue/equipamento_padrao.json"
const ARMAS_DE_FOGO: Array[String] = ["rifle", "pistol", "pistol_gold", "senriku", "rocket_launcher"]
const MAOS: Array[String] = ["MAINHAND", "OFFHAND"]

static var _dados: Dictionary = {}


static func _carregar() -> void:
	if not _dados.is_empty():
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
	_dados = (d as Dictionary).get("entidades", {}) if d is Dictionary else {"_": {}}


## Os itens que o construtor do mod põe nas mãos de `id`, só os de fogo: {"MAINHAND": "rifle"}.
static func armas_de_fogo(id: String) -> Dictionary:
	_carregar()
	var saida := {}
	var todos: Dictionary = _dados.get(id, {})
	for mao in MAOS:
		if str(todos.get(mao, "")) in ARMAS_DE_FOGO:
			saida[mao] = str(todos[mao])
	return saida
