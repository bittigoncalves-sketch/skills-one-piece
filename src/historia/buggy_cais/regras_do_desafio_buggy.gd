class_name RegrasDoDesafioBuggy
extends RefCounted
# ============================================================================
#  REGRAS DO DESAFIO DO BUGGY (21/11/2026) — só estado e recompensa, sem nó nem tela (testável). Pedido do dono (docs/DESAFIO_DO_BUGGY_PLANO.md):
#  concluído o treino → cena da chegada do Buggy no cais → jogo dos 3 copos (UMA tentativa): acertou = missão cumprida + 4000 XP; errou = o Buggy manda voltar no
#  NÍVEL 7 para lutar, e a missão da luta SÓ existe se o jogador ACEITAR proteger a vila e fica bloqueada até o nível 7.
#
#  O estado mora em `prog.sistemas["desafio_buggy"]` (já persistido): {"fase": ...}. Fases, em ordem:
#    ""            nada aconteceu (o treino ainda não foi entregue ou a cena não tocou)
#    "chegou"      a cena da chegada passou; a missão `desafio_dos_copos` está aceita; falta jogar
#    "copos_certo" acertou os copos (4000 XP pagos; fim da história desta rodada)
#    "copos_errado" errou; o Buggy fez a oferta "proteger a vila"
#    "aceitou" / "recusou"   resposta à oferta (dá para mudar de ideia depois: aceitar vale de "recusou" também)
#  Cada transição é IDEMPOTENTE: repetir o sinal (recarregar, reabrir) não paga duas vezes nem volta atrás.
#  A luta de nível 7 contra o Buggy é a PRÓXIMA fatia: aqui só a missão `defender_a_vila` (liberada por `liberar_luta`).
# ============================================================================
const CHAVE := "desafio_buggy"
const MISSAO_COPOS := "desafio_dos_copos"
const MISSAO_LUTA := "defender_a_vila"
const NIVEL_DA_LUTA := 3                    # 22/11/2026 (pedido do dono): era 7. É também o nível em que o instrutor recusa mais treino (`RegrasDoTreino.NIVEL_LIMITE`)
const XP_DOS_COPOS := 4000

const NADA := ""
const CHEGOU := "chegou"
const COPOS_CERTO := "copos_certo"
const COPOS_ERRADO := "copos_errado"
const ACEITOU := "aceitou"
const RECUSOU := "recusou"
## Venceu a luta do ringue (22/11/2026, `RegrasDaLutaDoBuggy`): vale como "venceu o Buggy" para o barril da Alvida, como os copos certos.
const LUTA_VENCIDA := "luta_vencida"


static func fase(prog: ProgressaoDoPersonagem) -> String:
	return str((prog.sistemas.get(CHAVE, {}) as Dictionary).get("fase", NADA))


static func _gravar(prog: ProgressaoDoPersonagem, nova: String) -> void:
	var d: Dictionary = prog.sistemas.get(CHAVE, {})
	d["fase"] = nova
	prog.sistemas[CHAVE] = d
	prog.mudou.emit()


## A cena da chegada deve tocar? (treino entregue e ainda nada do desafio.)
static func deve_chegar(prog: ProgressaoDoPersonagem) -> bool:
	return fase(prog) == NADA and prog.estado_da_missao("treino") == "entregue"


## A cena passou: a missão dos copos entra na lista do jogador. Idempotente.
static func marcar_chegada(prog: ProgressaoDoPersonagem) -> bool:
	if not deve_chegar(prog):
		return false
	prog.aceitar_missao(MISSAO_COPOS)
	_gravar(prog, CHEGOU)
	return true


## Os copos podem ser jogados? (depois da chegada, uma vez.)
static func pode_jogar_copos(prog: ProgressaoDoPersonagem) -> bool:
	return fase(prog) == CHEGOU


## Resultado do jogo. Acerto: a missão se cumpre e entrega (4000 XP, uma vez). Erro: a missão se encerra sem prêmio e o Buggy faz a oferta.
## Devolve {"acertou": bool, "xp": int, "niveis": int}; {} se não era a hora (já jogou) — é o que impede pagar duas vezes.
static func resolver_copos(prog: ProgressaoDoPersonagem, acertou: bool) -> Dictionary:
	if not pode_jogar_copos(prog):
		return {}
	var r := {"acertou": acertou, "xp": 0, "niveis": 0}
	if acertou:
		prog.contar_abate("copos")
		var antes := prog.nivel
		if prog.entregar_missao(MISSAO_COPOS):
			r["xp"] = int(Missoes_dados(MISSAO_COPOS).get("xp", 0))
		r["niveis"] = prog.nivel - antes
		_gravar(prog, COPOS_CERTO)
	else:
		prog.missoes[MISSAO_COPOS] = {"estado": "entregue", "abates": 0}       # encerrada sem prêmio
		# 22/11/2026 (pedido do dono): errar os copos JÁ entrega a missão da luta (sem a pergunta "aceita proteger a vila?"): treinar com o instrutor até o
		# nível `NIVEL_DA_LUTA` e desafiar o Buggy no ringue. A fase vai direto a `aceitou`.
		_gravar(prog, ACEITOU)
		prog.aceitar_missao(MISSAO_LUTA)
	return r


static func Missoes_dados(id: String) -> Dictionary:
	return preload("res://src/historia/missoes/missoes.gd").dados(id)


## O jogador respondeu à oferta "proteger a vila". Só vale depois de errar os copos; devolve false se não era a hora.
static func responder_oferta(prog: ProgressaoDoPersonagem, aceita: bool) -> bool:
	var f := fase(prog)
	if f != COPOS_ERRADO and f != RECUSOU:
		return false
	if f == RECUSOU and not aceita:
		return false
	_gravar(prog, ACEITOU if aceita else RECUSOU)
	return true


## Chegou ao nível da luta com a missão em andamento: devolve true UMA vez (para o aviso "o Buggy espera por você"); a missão já existe desde que errou os copos.
static func liberar_luta(prog: ProgressaoDoPersonagem) -> bool:
	migrar(prog)
	if not luta_disponivel(prog):
		return false
	var d: Dictionary = prog.sistemas.get(CHAVE, {})
	if bool(d.get("avisou_nivel", false)):
		return false
	d["avisou_nivel"] = true
	prog.sistemas[CHAVE] = d
	prog.mudou.emit()
	return true


## Saves de antes de 22/11/2026: quem errou os copos parou em `copos_errado`/`recusou` (a pergunta "proteger a vila?"). Agora a missão da luta é automática: leva a `aceitou`
## com a missão em andamento. Idempotente; devolve true se mudou algo.
static func migrar(prog: ProgressaoDoPersonagem) -> bool:
	var f := fase(prog)
	if f == COPOS_ERRADO or f == RECUSOU:
		_gravar(prog, ACEITOU)
		f = ACEITOU
	if f == ACEITOU and prog.estado_da_missao(MISSAO_LUTA) == "disponivel":
		return prog.aceitar_missao(MISSAO_LUTA) or f == ACEITOU
	return false


## A luta está bloqueada? (aceitou, mas ainda sem o nível) — para o diálogo do Buggy e a janela de missões.
static func luta_bloqueada(prog: ProgressaoDoPersonagem) -> bool:
	return fase(prog) == ACEITOU and prog.nivel < NIVEL_DA_LUTA


## A luta do ringue pode começar? (errou os copos, a missão da luta está em andamento e o jogador chegou ao nível da luta.)
static func luta_disponivel(prog: ProgressaoDoPersonagem) -> bool:
	return fase(prog) == ACEITOU and prog.estado_da_missao(MISSAO_LUTA) == "aceita" and prog.nivel >= NIVEL_DA_LUTA


## A missão da luta está em andamento mas o nível ainda não chegou: o jogador deve TREINAR (a bússola aponta o instrutor).
static func deve_treinar(prog: ProgressaoDoPersonagem) -> bool:
	return fase(prog) == ACEITOU and prog.estado_da_missao(MISSAO_LUTA) == "aceita" and prog.nivel < NIVEL_DA_LUTA


## Venceu a luta: a fase vira `luta_vencida` (idempotente — só sai de `aceitou`).
static func marcar_luta_vencida(prog: ProgressaoDoPersonagem) -> bool:
	if fase(prog) != ACEITOU:
		return false
	_gravar(prog, LUTA_VENCIDA)
	return true


## Ganhou do Buggy de algum jeito: copos certos OU a luta do ringue.
static func venceu_o_buggy(prog: ProgressaoDoPersonagem) -> bool:
	var f := fase(prog)
	return f == COPOS_CERTO or f == LUTA_VENCIDA
