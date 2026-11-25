extends LojaDeNpc
# ============================================================================
#  CONVERSA DE MISSÃO (08/10/2026) — o NPC da "?" amarela usa a mesma janela das lojas
#  (`JanelaDeLoja`): uma linha com a missão e o botão do momento (Aceitar → em
#  andamento → Entregar → concluída). Regras e recompensa: `Missoes` + o progresso.
#  Com `npc`, a missão é a DA VEZ na cadeia dele (Guarda: madeira → bandidos → pet → fruta →
#  corrida → provisões); entregue uma, a próxima aparece na mesma janela.
# ============================================================================

const Missoes := preload("res://src/historia/missoes/missoes.gd")

## O NPC (tipo da ficha em `NpcDaIlha.FICHAS`), a missão fixa (sem cadeia) e o
## progresso, postos por quem cria a conversa.
var npc := ""
var missao := ""
var progressao: ProgressaoDoPersonagem


## A missão a mostrar: a da vez na cadeia do NPC; com todas entregues, a última.
func atual(prog: ProgressaoDoPersonagem = null) -> String:
	var p := prog if prog != null else progressao
	if npc.is_empty() or p == null:
		return missao
	var id := Missoes.atual_do_npc(npc, p)
	return id if not id.is_empty() else Missoes.ultima_do_npc(npc)


func fala() -> String:
	var missao := atual()
	var d := Missoes.dados(missao)
	if d.is_empty() or progressao == null:
		return ""
	match progressao.estado_da_missao(missao):
		Missoes.DISPONIVEL: return str(d["oferta"])
		Missoes.ACEITA: return str(d["andamento"])
		Missoes.PRONTA: return str(d["pronta"])
	return str(d["concluida"])


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var missao := atual(prog)
	var d := Missoes.dados(missao)
	if d.is_empty():
		return []
	var premio := "Recompensa: %d XP + %s" % [int(d["xp"]), moedas(int(d["ouro"]))]
	if d.has("premio"):
		premio += " + a bússola"
	if d.has("fruta"):
		premio += " + " + PerfilDeFrutas.nome_da_fruta(str(d["fruta"]))
	if d.has("equipamento"): premio = "Recompensa: machado"
	elif d.has("alimentos"): premio = "Recompensa: 60 pães"
	elif int(d.xp) == 0 and int(d.ouro) == 0: premio = "Sem recompensa"
	var botoes: Array
	var detalhe := "%s  ·  %s" % [d["tarefa"], premio]
	var andamento := "%s: %s  ·  %s" % [d["contador"], Missoes.contagem(missao, prog), premio]
	match prog.estado_da_missao(missao):
		Missoes.DISPONIVEL:
			botoes = [botao("Aceitar", "aceitar")]
		Missoes.ACEITA:
			detalhe = andamento
			botoes = [botao("Em andamento", "", false)]
		Missoes.PRONTA:
			detalhe = andamento
			botoes = [botao("Entregar", "entregar")]
		_:
			detalhe = "Concluída  ·  %s" % premio
			botoes = [botao("Concluída", "", false)]
	var anterior := str(d.get("depois_de", ""))
	if not anterior.is_empty() and prog.estado_da_missao(anterior) != Missoes.ENTREGUE:
		botoes = [botao("Conclua a missão anterior", "", false)]
	if missao == "faccao_inicial" and prog.estado_da_missao("ferraria") == Missoes.ENTREGUE and prog.estado_da_missao(missao) != Missoes.ENTREGUE:
		botoes = [botao("Pirata", "pirata"), botao("Marinheiro", "marinheiro")]
	return [linha(missao, str(d["nome"]), detalhe, botoes)]


func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, _id: String) -> String:
	var missao := atual(prog)
	var d := Missoes.dados(missao)
	if acao in ["pirata", "marinheiro"] and missao == "faccao_inicial" and prog.estado_da_missao("ferraria") == Missoes.ENTREGUE and prog.estado_da_missao(missao) != Missoes.ENTREGUE:
		prog.aceitar_missao(missao)
		prog.sistemas["faccao"] = {"id": acao}
		prog.contar_abate("faccao_inicial")
		if prog.entregar_missao(missao): return "Você escolheu %s e recebeu 60 pães. Coma pelo menu B." % acao.capitalize()
	if acao == "aceitar" and prog.aceitar_missao(missao):
		return "Missão aceita: %s  ·  0 / %d" % [d["nome"], int(d["meta"])]
	if acao == "entregar" and prog.entregar_missao(missao):
		var texto := "Missão concluída: %s  ·  +%d XP  ·  +%s" % [d["nome"], int(d["xp"]), moedas(int(d["ouro"]))]
		if d.has("premio"):
			texto += "  ·  BÚSSOLA: aponta para a Ilha dos Macacos"
		if d.has("fruta"):
			texto += "  ·  %s (N › FRUTAS)" % PerfilDeFrutas.nome_da_fruta(str(d["fruta"]))
		return texto
	return ""
