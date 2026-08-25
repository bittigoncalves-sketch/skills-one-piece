class_name CombatStateAttackActive
extends PlayerState
# ============================================================================
#  ATIVO — a hitbox está no ar.
#
#  A fase mais curta das três (0,06-0,08 s) e a única em que NADA é permitido:
#  nem mover, nem atacar, nem esquivar, nem bloquear. É o quadro de contato, e
#  §6.3 do plano pede que ele seja CONGELADO em tela em vez de trocar de pose —
#  quem estica esse instante é o hitstop, no relógio real, sem gastar
#  orçamento do clipe.
#
#  Ela existe como estado próprio mesmo durando 4 quadros porque é ela que dá
#  sentido à conta do §2.3:
#
#      vantagem_no_acerto = hitstun − (ativo + recuperacao)
#
#  Sem separar ativo de recuperação não há como medir a vantagem — e sem medir
#  a vantagem o combo volta a ser ajustado no olho.
# ============================================================================

func physics_update(_delta: float) -> void:
	if player._melee == null:
		state_machine.transition_to("Idle")
		return
	match player._melee.fase():
		"recuperacao":
			state_machine.transition_to("AttackRecovery")
		"":
			state_machine.transition_to("Idle")
