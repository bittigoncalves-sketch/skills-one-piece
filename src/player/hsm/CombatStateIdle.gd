class_name CombatStateIdle
extends PlayerState

func physics_update(delta: float) -> void:
	if player.has_method("_consume_input") and player._consume_input("attack"):
		player.hit_confirmed = false
		if player.get("_melee"):
			player.get("_melee").pedir(player._yaw)
		state_machine.transition_to("Attacking")
	elif player.get("_dash") and player.get("_dash").ativo():
		state_machine.transition_to("Dashing")
