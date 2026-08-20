extends SceneTree

func _init() -> void:
    print("[TEST] starting game launch test")
    change_scene_to_file("res://Main.tscn")
    
    var t = Timer.new()
    t.wait_time = 1.0
    t.one_shot = true
    t.timeout.connect(func():
        print("[TEST] Main scene has run for 1s. Quitting.")
        quit()
    )
    root.add_child(t)
    t.start()
