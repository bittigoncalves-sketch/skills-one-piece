class_name PlayerStateMachine
extends Node

var initial_state: NodePath
var state: PlayerState

func init(_player: CharacterBody3D, _initial_state_path: NodePath) -> void:
	for child in get_children():
		if child is PlayerState:
			child.player = _player
			child.state_machine = self
	
	if not _initial_state_path.is_empty():
		state = get_node_or_null(_initial_state_path)
	
	if state:
		state.enter("")

func _unhandled_input(event: InputEvent) -> void:
	if state:
		state.handle_input(event)

func _process(delta: float) -> void:
	if state:
		state.update(delta)

func _physics_process(delta: float) -> void:
	if state:
		state.physics_update(delta)

func transition_to(target_state_path: String, msg: Dictionary = {}) -> void:
	if not has_node(target_state_path):
		return

	var target_state = get_node(target_state_path)
	if state:
		state.exit()
	state = target_state
	state.enter(state.get_path(), msg)
