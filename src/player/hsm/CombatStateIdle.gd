class_name CombatStateIdle
extends PlayerState
# ============================================================================
#  PARADO — o estado em que tudo é permitido: mover, atacar, esquivar, (em
#  breve) bloquear.
#
#  É daqui que o clique vira golpe. O caminho é o REAL desde 2026-08-21: o
#  clique entra no buffer de input do Player (`_add_input_to_buffer`) e é
#  CONSUMIDO aqui — nunca `transition_to("Attack...")` na mão, que era o
#  defeito 3 do `src/tests/test_fsm.gd` (estado sem golpe nenhum, que durava um
#  quadro e voltava sozinho).
# ============================================================================

func physics_update(_delta: float) -> void:
	if player.has_method("_consume_input") and player._consume_input("attack"):
		# `hit_confirmed` também é zerado no `MeleeController.pedir()`, para o
		# segundo golpe do combo, que não passa por aqui. Zerar nos dois é de
		# propósito: o Idle cobre o primeiro clique, o controlador cobre o
		# encadeamento, e nenhum dos dois depende do outro ter rodado.
		player.hit_confirmed = false
		if player.get("_melee"):
			player.get("_melee").pedir(player._yaw)
		state_machine.transition_to("AttackStartup")
	elif player.get("_dash") and player.get("_dash").ativo():
		state_machine.transition_to("Dashing")
