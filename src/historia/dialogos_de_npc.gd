class_name DialogosDeNpc
extends RefCounted
# ============================================================================
#  DIÁLOGOS DE NPC (21/11/2026) — as legendas da caixa cinematográfica (`CaixaDeFalaCinematografica`) vivem em DADOS: `data/dialogos/<id>.json`,
#  escritos pelo Codex sem tocar em código. Formato:
#    {"id": "treino", "estados": {"primeira": [{"falante": "Instrutor", "texto": "..."}], "repeticao": [...], "recusa_nivel": [...]}}
#  Cada loja de NPC passa um PADRÃO (as falas provisórias no código): arquivo ausente, estado ausente ou linha inválida → o padrão vale, então o jogo
#  nunca fica sem fala. GATILHO: mais de ~6 NPCs com diálogo → trocar o fallback por um arquivo-padrão por NPC e validar no teste de dados.
# ============================================================================
const PASTA := "res://data/dialogos/"
const MAX_CARACTERES := 90        # o contrato com o Codex: legenda curta (a faixa tem 2 linhas visíveis)


## Linhas `{falante, texto}` do estado. `padrao` é o fallback já no formato final.
static func linhas(id: String, estado: String, padrao: Array[Dictionary]) -> Array[Dictionary]:
	var do_arquivo := _do_arquivo(id, estado)
	return do_arquivo if not do_arquivo.is_empty() else padrao


static func _do_arquivo(id: String, estado: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var caminho := PASTA + id + ".json"
	if not FileAccess.file_exists(caminho):
		return saida
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not (dados is Dictionary):
		return saida
	var estados: Variant = (dados as Dictionary).get("estados", {})
	if not (estados is Dictionary) or not (estados as Dictionary).get(estado) is Array:
		return saida
	for item: Variant in (estados as Dictionary)[estado]:
		if item is Dictionary and str((item as Dictionary).get("texto", "")).strip_edges() != "":
			saida.append({"falante": str((item as Dictionary).get("falante", "")), "texto": str((item as Dictionary)["texto"]).strip_edges()})
	return saida


static func linha(falante: String, texto: String) -> Dictionary:
	return {"falante": falante, "texto": texto}
