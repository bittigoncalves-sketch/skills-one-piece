class_name PlayerState
extends Node

var player: CharacterBody3D
var state_machine: Node

func enter(_previous_state_path: String, _data := {}) -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
