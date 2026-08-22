extends SceneTree
func _init():
    var s = load("res://Player.gd")
    if not s:
        print("FAILED TO LOAD Player.gd")
    else:
        var inst = s.new()
        print("LOADED Player.gd FINE: ", inst)
    quit()
