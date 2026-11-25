class_name RegrasDaAlvida
extends RefCounted
# ============================================================================
#  REGRAS DA ALVIDA (22/11/2026, 5ª missão) — só estado, condições, prêmio e penalidade, sem nó nem tela (testável). Fluxo (pedido do dono + decisões de 22/11):
#  baú entregue → a missão `alvida_no_navio` entra (bússola → vendedor de navios) → o vendedor só dá o BARRIL a quem ACERTOU os copos do Buggy (fase `copos_certo`; "entregue" não basta:
#  errar também encerra a missão dos copos) → cena do barril → duelo de pedra-papel-tesoura (`DueloPpt`, 7 vidas) → VITÓRIA: 1000 moedas + 8000 XP (tabela `Missoes`, uma vez) e o jogador
#  volta à Ilha dos Macacos; DERROTA: volta à Ilha dos Macacos SEM OS ITENS (só os permanentes ficam) e a missão FALHA para sempre: some da lista, o vendedor só abre a loja e ela não se repete (decisão do dono, 21/11/2026; antes dava para tentar de novo).
#
#  Estado em `prog.sistemas["alvida"]` = {"vitorias": 0|1, "derrotas": n} (persistido). A missão em si mora em `prog.missoes`. Meio da cena/duelo NÃO é salvo: fechar o jogo no meio
#  recomeça da conversa com o vendedor (política: nada de derrota nem prêmio silencioso — `iniciada` só vive na memória do orquestrador).
#
#  PERMANENTE x ITEM (decisão minha, 22/11 — o dono disse "apenas os permanentes como frutas, combate corpo a corpo etc"): a derrota apaga o que se CARREGA — mochila, hotbar, armadura, mão
#  secundária, grade, cursor, peixes, madeira, equipamentos (vara, espada, machado, lâminas do Epic Fight) e provisões do estoque (pão, água…) — e mantém o que é do PERSONAGEM: nível, XP, moedas, fruta comida e frutas guardadas,
#  estilo de luta, skills, habilidades desbloqueadas (Geppo, dash…), missões, barcos, pets e tripulantes. GATILHO: o dono achar que moedas também devem cair → `perder_moedas` em `PENALIDADE`.
# ============================================================================
const Missoes := preload("res://src/historia/missoes/missoes.gd")
const CHAVE := "alvida"
const MISSAO := "alvida_no_navio"
const MISSAO_ANTERIOR := "resgate_do_bau"
const ILHA_DE_VOLTA := "ilha_dos_macacos"

## Por que o vendedor não dá o barril (para a fala certa).
const SEM_MISSAO := "sem_missao"          # o baú ainda não foi entregue
const SEM_VITORIA := "sem_vitoria"        # não ganhou os copos do Buggy
const JA_VENCEU := "ja_venceu"
const LIBERADO := "liberado"
const PERDEU := "perdeu"                  # perdeu o duelo: a missão falhou e não volta


static func _dados(prog: ProgressaoDoPersonagem) -> Dictionary:
	return prog.sistemas.get(CHAVE, {})


static func vitorias(prog: ProgressaoDoPersonagem) -> int:
	return int(_dados(prog).get("vitorias", 0))


static func derrotas(prog: ProgressaoDoPersonagem) -> int:
	return int(_dados(prog).get("derrotas", 0))


## A missão entra na lista quando o baú foi entregue (a ordem da tabela, `depois_de`, é reforçada por `aceitar_missao`). Idempotente; devolve true só na vez em que entrou.
static func liberar(prog: ProgressaoDoPersonagem) -> bool:
	if prog.estado_da_missao(MISSAO_ANTERIOR) != "entregue":
		return false
	# 22/11/2026 (pedido do dono): o barril só existe depois de VENCER o Buggy num dos dois jogos (copos, ou o boxe da missão de revanche). Quem recebeu a missão
	# antes dessa regra (aceita sem vitória, sem duelo feito) a perde até vencer.
	if not venceu_o_buggy(prog):
		if prog.estado_da_missao(MISSAO) == "aceita" and vitorias(prog) == 0 and derrotas(prog) == 0:
			prog.missoes.erase(MISSAO)
			prog.mudou.emit()
		return false
	return prog.aceitar_missao(MISSAO)


## Ganhou os copos do Buggy? (`desafio_buggy.fase == copos_certo`; saves antigos sem a fase contam como NÃO — não se inventa vitória.)
static func venceu_o_buggy(prog: ProgressaoDoPersonagem) -> bool:
	return RegrasDoDesafioBuggy.venceu_o_buggy(prog)       # copos certos OU a luta do ringue (22/11/2026)


## O que o vendedor responde agora.
static func situacao(prog: ProgressaoDoPersonagem) -> String:
	if prog.estado_da_missao(MISSAO) == "entregue" or vitorias(prog) > 0:
		return JA_VENCEU
	if prog.estado_da_missao(MISSAO) == Missoes.FALHOU:
		return PERDEU
	if prog.estado_da_missao(MISSAO) != "aceita":
		return SEM_MISSAO
	return LIBERADO if venceu_o_buggy(prog) else SEM_VITORIA


static func pode_comecar(prog: ProgressaoDoPersonagem) -> bool:
	return situacao(prog) == LIBERADO


## VITÓRIA no duelo: cumpre e entrega a missão (1000 moedas + 8000 XP da tabela) numa transação só — a meta é preenchida SEM emitir `mudou` (um `contar_abate` salvaria "pronta" sem prêmio e,
## se o jogo fechasse ali, a missão ficaria presa; `recuperar` conserta mesmo assim saves nesse estado). Idempotente: só paga na vez em que a missão estava aceita.
## → {"ok", "ouro", "xp", "niveis"}; ok=false (nada mudou) se não era a hora.
static func registrar_vitoria(prog: ProgressaoDoPersonagem) -> Dictionary:
	if not pode_comecar(prog):
		return {"ok": false, "ouro": 0, "xp": 0, "niveis": 0}
	var d := preload("res://src/historia/missoes/missoes.gd").dados(MISSAO)
	var antes := prog.nivel
	(prog.missoes[MISSAO] as Dictionary)["abates"] = int(d.get("meta", 1))
	var dados := _dados(prog).duplicate()
	dados["vitorias"] = 1                                       # entra no mesmo salvamento que o prêmio (`entregar_missao` emite o `mudou`)
	prog.sistemas[CHAVE] = dados
	if not prog.entregar_missao(MISSAO):
		return {"ok": false, "ouro": 0, "xp": 0, "niveis": 0}
	return {"ok": true, "ouro": int(d.get("ouro", 0)), "xp": int(d.get("xp", 0)), "niveis": prog.nivel - antes}


## Save preso no estado intermediário (missão PRONTA sem entrega, de uma versão/queda anterior): entrega agora, uma vez. Devolve true se entregou.
static func recuperar(prog: ProgressaoDoPersonagem) -> bool:
	if prog.estado_da_missao(MISSAO) != "pronta":
		return false
	if not prog.entregar_missao(MISSAO):
		return false
	var dados := _dados(prog).duplicate()
	dados["vitorias"] = 1
	prog.gravar_dados(CHAVE, dados)
	return true


## DERROTA: aplica a penalidade, conta e FALHA a missão (não há segunda chance). Sem prêmio. Só vale se a missão está liberada.
## `tentativa` identifica O duelo (o orquestrador gera um id novo por duelo; os últimos 32 ficam guardados): repetir um id já usado, mesmo fora de ordem, não apaga nem conta de novo; um id novo é outra tentativa real. Sem id = sempre conta (testes antigos).
## → {"ok", "itens"} (quantas pilhas/itens foram perdidas)
static func registrar_derrota(prog: ProgressaoDoPersonagem, tentativa := "") -> Dictionary:
	if not pode_comecar(prog):
		return {"ok": false, "itens": 0}
	var dados := _dados(prog).duplicate()
	var usadas: Array = dados.get("tentativas", []).duplicate()
	if not tentativa.is_empty() and tentativa in usadas:
		return {"ok": false, "itens": 0}                        # o mesmo duelo (mesmo fora de ordem: A → B → A): nada apaga, nada conta
	if not tentativa.is_empty():
		usadas.append(tentativa)
		dados["tentativas"] = usadas.slice(maxi(0, usadas.size() - 32))
	dados["derrotas"] = int(dados.get("derrotas", 0)) + 1
	prog.missoes[MISSAO] = {"estado": Missoes.FALHOU, "abates": 0}
	prog.sistemas[CHAVE] = dados                                 # o contador e o id entram ANTES da penalidade: `perder_itens` emite o único `mudou` (um save só, sem estado intermediário)
	var perdidos := perder_itens(prog)
	return {"ok": true, "itens": perdidos}


## Esvazia o que o jogador CARREGA (ver o cabeçalho). Devolve quantos itens havia. Os dados permanentes não são tocados.
static func perder_itens(prog: ProgressaoDoPersonagem) -> int:
	var perdidos := prog.inventario.esvaziar(true)      # as frutas ficam (permanentes)
	for id in prog.pesca:
		perdidos += int(prog.pesca[id])
	prog.pesca = {}
	var estoque: Variant = (prog.sistemas.get("sobrevivencia", {}) as Dictionary).get("estoque")      # provisões (pão, água…) também se carregam
	if estoque is Dictionary:
		for id in estoque:
			perdidos += int(estoque[id])
		(estoque as Dictionary).clear()
	perdidos += prog.madeira
	prog.madeira = 0
	perdidos += prog.equipamentos.size()
	prog.equipamentos = {}
	for bandeira in ["espada_equipada", "vara_equipada", "machado_equipado"]:
		prog.set(bandeira, false)
	prog.lamina_ef = ""
	prog.lamina_ef_sec = ""
	if prog.item_ativo in ["espada", "vara", "pistola", "comida", "agua", "pokebola", "bandeira"]:
		prog.item_ativo = "luta"           # o que estava na mão não existe mais; o estilo de luta é permanente
	prog.mudou.emit()
	return perdidos
