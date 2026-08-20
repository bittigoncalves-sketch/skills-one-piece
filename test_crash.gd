extends SceneTree

func _init():
    var root = get_root()
    var scene = load("res://MainMenu.tscn").instantiate()
    root.add_child(scene)
    
    await create_timer(0.2).timeout
    print("Clicking singleplayer...")
    scene._on_singleplayer_pressed()
    
    await create_timer(1.0).timeout
    print("Game is still alive!")
    quit()
