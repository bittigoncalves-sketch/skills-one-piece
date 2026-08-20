extends SceneTree
func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await process_frame
	await process_frame
	var p = get_root().get_tree().get_nodes_in_group("player")
	print("PLAYERS IN TREE: ", p.size())
	quit()
