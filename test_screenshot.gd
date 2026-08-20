extends SceneTree
func _init():
    var timer = Timer.new()
    timer.wait_time = 0.5
    timer.one_shot = true
    timer.autostart = true
    timer.timeout.connect(func():
        var game_flow = root.get_node("/root/GameFlow")
        game_flow.start_singleplayer()
        
        var timer2 = Timer.new()
        timer2.wait_time = 2.0
        timer2.autostart = true
        timer2.timeout.connect(func():
            var img = root.get_viewport().get_texture().get_image()
            img.save_png("screenshot.png")
            print("Screenshot saved!")
            quit()
        )
        root.add_child(timer2)
    )
    root.add_child(timer)
