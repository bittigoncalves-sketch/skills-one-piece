extends SceneTree
func _init():
    var z_rot = -1.2
    var b = Basis.from_euler(Vector3(0, 0, z_rot))
    # Vector3.DOWN is (0, -1, 0)
    var v = b * Vector3.DOWN
    print("If bone points DOWN (0, -1, 0), rotated by Z=-1.2:")
    print("New direction: ", v)
    quit(0)
