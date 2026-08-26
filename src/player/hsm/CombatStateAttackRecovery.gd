class_name CombatStateAttackRecovery
extends PlayerState
# ============================================================================
#  RECUPERAÇÃO — o rabo do golpe. O corpo ainda está preso, mas é AQUI que o
#  contra-jogo existe.
#
#  ------------------------------------------------------ AS DUAS EXCEÇÕES
#  1. DASH-CANCEL, só com `hit_confirmed`. Já valia antes desta frente, e a
#     regra não mudou: cancelar um golpe que ERROU seria apagar a punição de
#     whiff, que é justamente o que segura o rusher (§4.3).
#
#  2. CANCELAR PARA BLOQUEIO — decisão do dono, 2026-08-25.
#     O §1 do plano deixou esta em aberto porque estende um princípio que o
#     dono fixou ("ao clicar não vai ser possível se mover até a animação do
#     combate se encerrar", 2026-08-15). Ele confirmou: vale.
#
#     A regra do dono continua inteira — o que muda é que a animação passou a
#     durar 0,40 s em vez de 1,5 s, e o que se libera não é MOVIMENTO, é
#     DEFESA. Sem isso, quem levou o combo tem um escape só (o dash lateral,
#     recarga de 2 s) contra quatro golpes, e o §4.3 desmonta.
#
#     ⚠️ ELA NÃO ESTÁ LIGADA AINDA, e isto é fronteira de frente, não
#     esquecimento: `CombatStateBlocking` é Ordem 2 do §7 e ainda não existe.
#     O que está pronto aqui é a PERMISSÃO (`pode_cancelar_para_bloqueio()`),
#     com a janela de carência já contada. Quem implementar o bloqueio pergunta
#     e entra; nada mais precisa ser decidido.
#
#  ------------------------------------------------------ A JANELA DE CARÊNCIA
#  O §4.1 escreve "✓ após alguns quadros" para o bloqueio, e "alguns quadros"
#  não é número. É 0,05 s — 3 quadros a 60 fps — declarado aqui e não escondido
#  num `if`: sem carência nenhuma, soltar o clique e apertar F no mesmo quadro
#  tornaria a recuperação inteira cancelável, e o golpe voltaria a não ter
#  custo. Com carência longa demais o escape vira sorteio de reflexo.
# ============================================================================

const CARENCIA_BLOQUEIO := 0.05

func pode_cancelar_para_dash() -> bool:
	return bool(player.get("hit_confirmed"))

# Ver a exceção 2 no cabeçalho. Diferente do dash, NÃO exige `hit_confirmed`:
# o dash é recompensa por acertar, o bloqueio é defesa de quem errou e sabe
# que vai ser punido. Exigir acerto para poder se defender inverteria o sinal.
func pode_cancelar_para_bloqueio() -> bool:
	if player._melee == null:
		return false
	var w = player.equipped_weapon if "equipped_weapon" in player else ""
	var i: int = player._melee.passo_em_curso()
	if i < 0:
		return false
	var entrou_na_recuperacao: float = Melee.startup(i, w) + Melee.ativo(i, w)
	return player._melee.tempo_na_fase() - entrou_na_recuperacao >= CARENCIA_BLOQUEIO

func physics_update(_delta: float) -> void:
	if player._melee == null or player._melee.fase() == "":
		state_machine.transition_to("Idle")
