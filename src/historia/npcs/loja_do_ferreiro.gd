extends "res://src/historia/missoes/loja_de_missao.gd"
var iniciar_ferraria := false
func linhas(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var r := super.linhas(prog, bib)
	if prog.estado_da_missao("ferraria") == Missoes.ACEITA:
		r.append(linha("ferraria", "Bancada de ferraria", "Três etapas · você pode tentar novamente", [botao("Forjar", "forjar")]))
	return r
func executar(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao == "forjar" and prog.estado_da_missao("ferraria") == Missoes.ACEITA:
		iniciar_ferraria = true
		return "Acenda a fornalha, martele os pontos marcados e esfrie a lâmina."
	return super.executar(prog, bib, acao, id)
