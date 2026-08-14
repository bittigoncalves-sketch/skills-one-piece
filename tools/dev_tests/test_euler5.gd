extends SceneTree
func _init():
    var arm_r = Node3D.new()
    arm_r.rotation = Vector3(1.4, 0, 0.4)
    var v_r = arm_r.transform.basis * Vector3.DOWN
    print("Arm R (X = 1.4, Z = 0.4) points to: ", v_r)
    quit(0)
