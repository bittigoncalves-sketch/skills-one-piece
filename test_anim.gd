extends SceneTree
func _init():
    var anim = load("res://assets/animations/right_upper_hook_from_guard.res")
    if not anim:
        print("Anim not found")
        quit(1)
        return
    var l_max = 0.0
    var r_max = 0.0
    for i in anim.get_track_count():
        var path = String(anim.track_get_path(i))
        var k_count = anim.track_get_key_count(i)
        var max_diff = 0.0
        var base_val = anim.track_get_key_value(i, 0) if k_count > 0 else Vector3()
        for k in range(1, k_count):
            var val = anim.track_get_key_value(i, k)
            max_diff = max(max_diff, (val - base_val).length())
        if path.find("UpperArm_L") >= 0 or path.find("ForeArm_L") >= 0:
            l_max = max(l_max, max_diff)
        if path.find("UpperArm_R") >= 0 or path.find("ForeArm_R") >= 0:
            r_max = max(r_max, max_diff)
    print("LEFT ARM diff: ", l_max)
    print("RIGHT ARM diff: ", r_max)
    quit(0)
