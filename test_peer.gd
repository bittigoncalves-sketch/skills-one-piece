extends SceneTree
func _init():
    var peer = OfflineMultiplayerPeer.new()
    get_multiplayer().multiplayer_peer = peer
    print("is_server: ", get_multiplayer().is_server())
    print("get_unique_id: ", get_multiplayer().get_unique_id())
    quit()
