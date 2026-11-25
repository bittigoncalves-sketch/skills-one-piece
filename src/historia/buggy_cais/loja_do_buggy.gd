extends LojaDeNpc
# ============================================================================
#  A OFERTA DO BUGGY (21/11/2026) — depois de errar os copos: "proteger a vila?" Reaproveita a `JanelaDeLoja` (duas opções) em vez de uma tela nova.
#  Aceitar → a missão da luta passa a existir (bloqueada até o nível 7); recusar → o Buggy vai embora com a vila na mão (a luta não nasce). Dá para mudar de ideia.
# ============================================================================
var progressao: ProgressaoDoPersonagem = null


func fala() -> String:
	if progressao != null and RegrasDoDesafioBuggy.fase(progressao) == RegrasDoDesafioBuggy.ACEITOU:
		return "Volte quando for forte o bastante. Nível %d, nem um a menos." % RegrasDoDesafioBuggy.NIVEL_DA_LUTA
	return "Você perdeu. Volte no nível %d e lute comigo se quiser salvar a vila." % RegrasDoDesafioBuggy.NIVEL_DA_LUTA


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var aceitou := RegrasDoDesafioBuggy.fase(prog) == RegrasDoDesafioBuggy.ACEITOU
	var detalhe := "Quando chegar ao nível %d, a luta do cais abre. Você tem o nível %d." % [RegrasDoDesafioBuggy.NIVEL_DA_LUTA, prog.nivel]
	if aceitou:
		return [LojaDeNpc.linha("proteger", "Proteger a vila", "Aceito. " + detalhe, [])]
	return [
		LojaDeNpc.linha("proteger", "Proteger a vila", "Aceitar o desafio. " + detalhe, [LojaDeNpc.botao("Aceitar", "aceitar", true)]),
		LojaDeNpc.linha("recusar", "Deixar o Buggy levar a vila", "Recusar: a missão da luta não existirá.", [LojaDeNpc.botao("Recusar", "recusar", true)]),
	]


func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, _id: String) -> String:
	if acao == "aceitar" and RegrasDoDesafioBuggy.responder_oferta(prog, true):
		return "Você aceitou proteger a vila. A luta abre no nível %d." % RegrasDoDesafioBuggy.NIVEL_DA_LUTA
	if acao == "recusar" and RegrasDoDesafioBuggy.responder_oferta(prog, false):
		return "Você recusou. O Buggy ri de você."
	return ""


func fecha_a_janela() -> bool:
	return true
