extends SceneTree
func _init():
    var g = load("res://autoload/GameFlow.gd").new()
    g._enter_world()
    print("Called _enter_world()")
    quit()
