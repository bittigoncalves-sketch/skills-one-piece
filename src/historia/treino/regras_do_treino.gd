class_name RegrasDoTreino
extends RefCounted
# ============================================================================
#  REGRAS DO TREINO (20/11/2026) — só decisões, sem cena: quem pode treinar, quanto de XP, como a missão fecha.
#  O minigame (`treino_de_soco.gd`) pergunta aqui; o NPC (`loja_do_treinador.gd`) também. Assim os números têm UM dono e são testáveis sem jogo.
#
#  Decisões do dono (20/11/2026): 500 XP por treino; a MISSÃO só acontece uma vez, o treino se repete até o nível 3; depois o instrutor recusa
#  ("a sua força excede este campo"). Escolhidas por ele: sequência de 6 teclas Z/X/C; XP cheio com ≥ 4 acertos, metade abaixo disso; recusa AO ATINGIR o nível 3.
#  GATILHO: mais missões/instrutores → `NIVEL_LIMITE` e `XP_POR_TREINO` viram campos da ficha do instrutor, não constantes globais.
# ============================================================================

const MISSAO := "treino"
const XP_POR_TREINO := 500
const XP_PARCIAL := 250
const NIVEL_LIMITE := 3                  # ao ATINGIR este nível o instrutor recusa
const PROMPTS := 6
const ACERTOS_PARA_XP_CHEIO := 4
const TECLAS: Array[String] = ["Z", "X", "C"]
const TEMPO_DO_PROMPT := 1.2             # segundos para apertar a tecla certa
const CHAVE := "treino"                  # `ProgressaoDoPersonagem.sistemas[CHAVE]` = {"feitos": n}

const FALA_DE_RECUSA := "Sua força excede este campo. Não tenho mais o que lhe ensinar aqui."


## "" = pode treinar; senão o motivo (a fala de recusa).
static func motivo_para_nao_treinar(prog: ProgressaoDoPersonagem) -> String:
	if prog.nivel >= NIVEL_LIMITE:
		return FALA_DE_RECUSA
	return ""


## Save que já passou do limite ANTES de fazer a missão: o instrutor nunca o aceitaria e a "?" ficaria para sempre. Marca a missão como entregue SEM pagar nada
## (decisão provisória do Claude, a confirmar com o dono: não concede XP nem inventa exceção). Devolve se migrou.
static func migrar_save_acima_do_limite(prog: ProgressaoDoPersonagem) -> bool:
	if prog.nivel < NIVEL_LIMITE or prog.estado_da_missao(MISSAO) == "entregue":
		return false
	prog.missoes[MISSAO] = {"estado": "entregue", "abates": 1}
	prog.mudou.emit()
	return true


static func treinos_feitos(prog: ProgressaoDoPersonagem) -> int:
	return int((prog.sistemas.get(CHAVE, {}) as Dictionary).get("feitos", 0))


## O XP de uma sessão com `acertos` de `PROMPTS`. Sem nenhum acerto não há treino de verdade: 0.
static func xp_da_sessao(acertos: int) -> int:
	if acertos <= 0:
		return 0
	return XP_POR_TREINO if acertos >= ACERTOS_PARA_XP_CHEIO else XP_PARCIAL


## Fecha uma sessão: paga o XP, conta o treino e entrega a MISSÃO na primeira sessão com pelo menos um acerto. Devolve o que aconteceu, para a HUD.
## {"xp": int, "niveis": int, "missao_entregue": bool, "recusa_agora": bool}
static func concluir(prog: ProgressaoDoPersonagem, acertos: int) -> Dictionary:
	var xp := xp_da_sessao(acertos)
	var resultado := {"xp": xp, "niveis": 0, "missao_entregue": false, "recusa_agora": false}
	if xp <= 0:
		return resultado
	var dados: Dictionary = prog.sistemas.get(CHAVE, {})
	dados["feitos"] = int(dados.get("feitos", 0)) + 1
	prog.sistemas[CHAVE] = dados
	if prog.estado_da_missao(MISSAO) != "entregue":
		prog.aceitar_missao(MISSAO)
		prog.contar_abate(MISSAO)
		resultado["missao_entregue"] = prog.entregar_missao(MISSAO)
	resultado["niveis"] = prog.ganhar_xp(xp)
	resultado["recusa_agora"] = not motivo_para_nao_treinar(prog).is_empty()
	return resultado

