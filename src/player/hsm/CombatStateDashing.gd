class_name CombatStateDashing
extends PlayerState

func physics_update(delta: float) -> void:
	if player.has_method("esquivando") and not player.esquivando():
		state_machine.transition_to("Idle")
