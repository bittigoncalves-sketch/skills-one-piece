extends SceneTree
func _init():
    var arm_r = Node3D.new()
    arm_r.rotation = Vector3(0, 0, 1.2)
    var v_r = arm_r.transform.basis * Vector3.DOWN
    print("Arm R (Z = +1.2) points to: ", v_r)
    quit(0)
