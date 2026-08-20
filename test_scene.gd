extends Node

func _ready():
    var main_menu = get_tree().root.get_node("MainMenu")
    if main_menu:
        print("Clicking singleplayer...")
        main_menu._on_singleplayer_pressed()
        
        await get_tree().create_timer(1.0).timeout
        print("Game is still alive!")
        get_tree().quit()
