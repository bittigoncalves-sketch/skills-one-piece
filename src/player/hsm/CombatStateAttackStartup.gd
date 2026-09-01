class_name CombatStateAttackStartup
extends PlayerState
# ============================================================================
#  STARTUP — do clique até a hitbox nascer.
#
#  Primeira das três fases em que o antigo `CombatStateAttacking` foi partido
#  (§4.1 de docs/PLANO_COMBATE_BATTLEGROUNDS.md, 2026-08-25). O estado único
#  não conseguia distinguir "ainda estou preparando" de "já soltei e estou
#  preso no rabo do golpe" — e é justamente nessa diferença que mora todo o
#  contra-jogo: o dash-cancel só vale na RECUPERAÇÃO, e só se o golpe conectou.
#
#  Aqui não se cancela nada. Startup é o compromisso: apertou, vai.
#
#  ⚠️ QUEM CONTA O TEMPO É O `MeleeController`, não este estado. Ver a nota
#  "A FASE" no cabeçalho de `src/player/melee_controller.gd` — dois relógios
#  para o mesmo golpe divergem no primeiro hitstop.
# ============================================================================

func enter(_previous_state_path: String, _data := {}) -> void:
	# As variações W/A/S/D já têm root motion próprio. Aplicar o auto-lunge do
	# M1 por cima transformaria uma esquiva lateral em avanço e faria a hitbox
	# nascer além da distância especificada.
	if player._melee and not player._melee.usa_auto_lunge():
		return
	# AUTO-MIRA + LUNGE. Estava no `CombatStateAttacking.enter()` e é daqui que
	# ele sempre quis ser: o puxão para o alvo é a PREPARAÇÃO do golpe, e é o
	# que dá ao startup de 0,20 s alcance suficiente para valer a pena.
	if player.has_method("find_best_melee_target"):
		var target = player.find_best_melee_target(12.0)
		if target:
			player.perform_melee_lunge(target, 18.0)

func physics_update(_delta: float) -> void:
	if player._melee == null:
		state_machine.transition_to("Idle")
		return
	match player._melee.fase():
		"ativo":
			state_machine.transition_to("AttackActive")
		"recuperacao":
			# Pulou o "ativo" inteiro num quadro só. Acontece quando o `ativo` é
			# menor que o delta (0,06 s são 3,6 quadros a 60 fps, mas 1,8 a 30) —
			# não é erro, e engolir a fase seria pior que atravessá-la.
			state_machine.transition_to("AttackRecovery")
		"":
			state_machine.transition_to("Idle")
