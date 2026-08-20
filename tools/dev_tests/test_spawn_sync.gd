extends SceneTree
func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await get_root().get_tree().create_timer(1.0).timeout
	var players = get_root().get_tree().get_nodes_in_group("player")
	print("SPAWNED PLAYERS: ", players.size())
	if players.size() > 0:
		print("PLAYER NAME: ", players[0].name)
	else:
		print("ERROR: NO PLAYERS SPAWNED!")
	quit()
