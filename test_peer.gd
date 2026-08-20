extends SceneTree
func _init():
    var peer = OfflineMultiplayerPeer.new()
    multiplayer.multiplayer_peer = peer
    print("is_server: ", multiplayer.is_server())
    print("get_unique_id: ", multiplayer.get_unique_id())
    quit()
