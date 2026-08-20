extends SceneTree

var arena: Node3D
var player: CharacterBody3D
var dummy: CharacterBody3D
var frames := 0
var max_frames := 600

func _init():
	for action in ["jump", "sprint", "dash", "aim", "fire"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	
	arena = load("res://TestArena.tscn").instantiate()
	root.add_child(arena)
	
	dummy = arena.get_node("TrainingDummy")
	
	player = load("res://Player.gd").new()
	player.name = "Player"
	arena.add_child(player)
	player.global_position = arena.get_node("SpawnPoint").global_position
	player.equipped_weapon = "sword"
	
	if player.has_method("_ready"):
		player._ready()

func _process(delta: float) -> bool:
	frames += 1
	# Rodar _physics_process na mão porque SceneTree headless não processa SceneTree normal às vezes
	if is_instance_valid(player) and player.has_method("_physics_process"):
		player._physics_process(delta)
	if is_instance_valid(dummy) and dummy.has_method("_physics_process"):
		dummy._physics_process(delta)
	
	test_step(frames, delta)
	
	if frames > max_frames:
		print(">>> TEST TIMEOUT")
		quit(1)
		return true
	
	if is_test_done():
		print(">>> TEST DONE")
		quit(0)
		return true
	
	return false

# TO BE OVERRIDDEN BY SUBCLASSES
func test_step(f: int, delta: float) -> void:
	pass

func is_test_done() -> bool:
	return frames >= 100
