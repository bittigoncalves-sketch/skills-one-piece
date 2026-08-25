extends SceneTree
func _init():
	print("Starting test...")
	var peer = OfflineMultiplayerPeer.new()
	get_multiplayer().multiplayer_peer = peer
	print("Offline peer created.")
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	print("Main instantiated.")
	quit()
