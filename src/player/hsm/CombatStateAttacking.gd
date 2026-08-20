class_name CombatStateAttacking
extends PlayerState

func enter(_previous_state_path: String, msg: Dictionary = {}) -> void:
	if player.has_method("find_best_melee_target"):
		var target = player.find_best_melee_target(12.0)
		if target:
			player.perform_melee_lunge(target, 18.0)

func physics_update(delta: float) -> void:
	if player._melee and player._melee.trava() <= 0.0:
		state_machine.transition_to("Idle")
