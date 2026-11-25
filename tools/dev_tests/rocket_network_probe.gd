extends SceneTree
## Dois processos com ENet e o MESMO MultiplayerSynchronizer usado por Main.
func _init() -> void:
	await process_frame
	var cena: Node = load("res://tools/dev_tests/rocket_network_fixture.gd").new()
	cena.name = "RocketNetwork"
	root.add_child(cena)
	current_scene = cena
