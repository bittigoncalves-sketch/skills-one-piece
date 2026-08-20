extends SceneTree

func _init():
    var timer = Timer.new()
    timer.wait_time = 3.0
    timer.one_shot = true
    timer.autostart = true
    timer.timeout.connect(_on_timeout)
    var root = get_root()
    root.add_child(timer)
    
    # Simulate singleplayer
    var game_flow = load("res://autoload/GameFlow.gd").new()
    game_flow.name = "GameFlow"
    root.add_child(game_flow)
    
    var server_manager = load("res://network/ServerManager.gd").new()
    server_manager.name = "ServerManager"
    root.add_child(server_manager)
    
    var hud = load("res://src/ui/Hud.gd").new()
    hud.name = "Hud"
    root.add_child(hud)
    
    # Emulate the scene loading
    var packed = load("res://Main.tscn")
    var scene = packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    
    game_flow.start_singleplayer()

func _on_timeout():
    print("\n\n=== DUMPING SCENE TREE ===")
    _print_tree(get_root(), 0)
    quit()

func _print_tree(node: Node, depth: int):
    var indent = ""
    for i in range(depth): indent += "  "
    print(indent + node.name + " (" + node.get_class() + ")")
    for c in node.get_children():
        _print_tree(c, depth + 1)
