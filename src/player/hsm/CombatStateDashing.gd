class_name CombatStateDashing
extends PlayerState

func physics_update(delta: float) -> void:
	if player.get("_dash") and not player.get("_dash").ativo():
		state_machine.transition_to("Idle")
