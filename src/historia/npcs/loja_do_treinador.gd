extends LojaDeNpc
# ============================================================================
#  INSTRUTOR DO CAMPO DE TREINO (20/11/2026) — a "loja" que começa o minigame (`TreinoDeSoco`), como o organizador da corrida começa a corrida.
#  As falas são PROVISÓRIAS: o Codex escreve as definitivas em `art_src/references/treino/` (diálogo e personagem).
# ============================================================================
var progressao: ProgressaoDoPersonagem = null


func fala() -> String:
	if progressao == null:
		return "Quer aprender a lutar? Treine comigo neste campo."
	var motivo := RegrasDoTreino.motivo_para_nao_treinar(progressao)
	if not motivo.is_empty():
		return motivo
	if RegrasDoTreino.treinos_feitos(progressao) == 0:
		return "Quer aprender a lutar? Treine comigo neste campo."
	return "Vamos treinar mais uma vez?"


## Legendas da caixa cinematográfica (`DialogosDeNpc`): `data/dialogos/treino.json` (Codex) manda; estas são o PADRÃO provisório.
func dialogo() -> Array[Dictionary]:
	var estado := "primeira"
	if progressao != null:
		if not RegrasDoTreino.motivo_para_nao_treinar(progressao).is_empty():
			estado = "recusa_nivel"
		elif RegrasDoTreino.treinos_feitos(progressao) > 0:
			estado = "repeticao"
	var padrao: Array[Dictionary] = []
	match estado:
		"recusa_nivel":
			padrao.append(DialogosDeNpc.linha("Instrutor", fala()))
		"repeticao":
			padrao.append(DialogosDeNpc.linha("Instrutor", "Vamos treinar mais uma vez?"))
		_:
			padrao.append(DialogosDeNpc.linha("Instrutor", "Quer aprender a lutar? Treine comigo neste campo."))
			padrao.append(DialogosDeNpc.linha("Instrutor", "Acerte a tecla indicada antes do tempo acabar. Z, X ou C."))
	return DialogosDeNpc.linhas("treino", estado, padrao)


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var motivo := RegrasDoTreino.motivo_para_nao_treinar(prog)
	var treino := _treino()
	var impedimento: String = motivo if not motivo.is_empty() else (str(treino.call("motivo_para_nao_iniciar")) if treino != null else "O campo não está pronto.")
	var detalhe := "%d comandos Z/X/C, %.1f s cada  ·  %d+ acertos = %d XP, 1 a %d = %d XP, nenhum = 0" % [RegrasDoTreino.PROMPTS, RegrasDoTreino.TEMPO_DO_PROMPT, RegrasDoTreino.ACERTOS_PARA_XP_CHEIO, RegrasDoTreino.XP_POR_TREINO, RegrasDoTreino.ACERTOS_PARA_XP_CHEIO - 1, RegrasDoTreino.XP_PARCIAL]
	if not impedimento.is_empty():
		detalhe = impedimento
	var como := LojaDeNpc.linha("instrucao", "Como funciona", "Acerte a tecla indicada antes do tempo acabar. Z: soco leve; X: pesado; C: três socos.", [])
	return [como, LojaDeNpc.linha("treino", "Treino de socos", detalhe, [LojaDeNpc.botao("Treinar", "treinar", impedimento.is_empty())])]


func executar(_prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, _id: String) -> String:
	if acao != "treinar":
		return ""
	var treino := _treino()
	if treino == null:
		return "O campo não está pronto."
	var erro: String = treino.pedir_inicio()
	return erro


func fecha_a_janela() -> bool:
	return true


static func _treino() -> Node:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.get_first_node_in_group("treino_de_soco") if arvore != null else null
