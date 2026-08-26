class_name CombatStateStunned
extends PlayerState
# ============================================================================
#  ATORDOADO — o estado que era REFERENCIADO EM SETE LUGARES E NÃO EXISTIA.
#
#  Até 2026-08-25 o `Player.gd` fazia `_fsm.transition_to("Stunned")` no funil
#  de dano e checava `_fsm.state.name == "Stunned"` em outros seis pontos. Não
#  havia nó "Stunned": `PlayerStateMachine.transition_to` faz
#  `if not has_node(target): return` — ou seja, a transição era um NO-OP
#  SILENCIOSO, e as seis checagens eram todas falsas para sempre.
#
#  O que estava morto por causa disso, tudo de uma vez:
#
#   • `_request_melee` não recusava clique sob hitstun — dava para socar
#     enquanto apanhava;
#   • `golpe_prende` nunca cedia ao tranco — atacar era imunidade a empurrão,
#     que é exatamente o contrário do que o comentário lá diz;
#   • o wall bounce do knockback (`Player.gd`, depois do `move_and_slide`)
#     nunca disparou uma vez;
#   • o combo breaker (G) exigia estar em "Stunned" para ativar e só conseguia
#     ler o `_hitstop_timer`;
#   • `_slot_em_uso` nunca via combate travado por stun.
#
#  Não é bug desta frente: é um buraco antigo que a frente de FSM (§7, Ordem 1)
#  tinha justamente a tarefa de fechar. O §0.1 do plano já o havia apontado.
#
#  ------------------------------------------------------------ QUEM DESLIGA
#  Não há timer aqui. O relógio do hitstun é o `RecepcaoDeDano.tick()`, que já
#  roda no `_physics_process` do Player e já devolve `true` enquanto o tranco
#  vale — e é ele que volta para Idle quando acaba.
#
#  Um segundo contador seria a mesma dupla fonte de verdade que o §4.1 manda
#  matar, e pior: a paralisia (Hie Hie, Kurouzu) alonga o tranco por caminhos
#  que este estado não conhece. Quem sabe quando o corpo volta é quem o
#  prendeu.
# ============================================================================

func enter(_previous_state_path: String, _data := {}) -> void:
	# O golpe em voo morre junto. Sem isto o `MeleeController` continuaria
	# contando fases de um golpe que o tranco já interrompeu, e a `fase()`
	# mentiria para a FSM assim que o stun acabasse.
	if player._melee:
		player._melee.cancelar_golpe()

func physics_update(_delta: float) -> void:
	pass
