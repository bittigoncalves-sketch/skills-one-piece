extends SceneTree

func _init():
    var peer = OfflineMultiplayerPeer.new()
    get_multiplayer().multiplayer_peer = peer
    
    var root = Node.new()
    root.name = "Root"
    get_root().add_child(root)
    
    var spawner = MultiplayerSpawner.new()
    spawner.name = "Spawner"
    spawner.spawn_path = root.get_path()
    spawner.spawn_function = func(data):
        print("Spawn called!")
        var n = Node.new()
        return n
    
    root.add_child(spawner)
    
    print("Spawning...")
    var n = spawner.spawn({"test": 1})
    print("Spawn returned: ", n)
    quit()
