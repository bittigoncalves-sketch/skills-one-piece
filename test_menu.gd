extends SceneTree

func _init() -> void:
    print("[TEST] starting")
    var err = change_scene_to_file("res://MainMenu.tscn")
    if err != OK:
        print("[TEST] error loading MainMenu")
    else:
        print("[TEST] loaded MainMenu")
        
        var timer = Timer.new()
        timer.wait_time = 1.0
        timer.one_shot = true
        timer.timeout.connect(func():
            print("[TEST] changing to Main.tscn (Simulating GameFlow)")
            change_scene_to_file("res://Main.tscn")
            
            var t2 = Timer.new()
            t2.wait_time = 1.0
            t2.one_shot = true
            t2.timeout.connect(func():
                print("[TEST] done, quitting")
                quit()
            )
            root.add_child(t2)
            t2.start()
        )
        root.add_child(timer)
        timer.start()
