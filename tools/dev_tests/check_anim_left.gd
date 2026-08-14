extends SceneTree
func _init():
    var anim = load("res://assets/animations/left_uppercut_from_guard.res")
    if anim:
        var l_max = 0.0
        var r_max = 0.0
        for i in anim.get_track_count():
            var path = String(anim.track_get_path(i))
            var k_count = anim.track_get_key_count(i)
            if k_count > 0:
                var v0 = anim.track_get_key_value(i, 0)
                var vmax = 0.0
                for k in range(k_count):
                    var v = anim.track_get_key_value(i, k)
                    vmax = max(vmax, (v - v0).length())
                if path.find("UpperArm_L") >= 0: l_max = max(l_max, vmax)
                if path.find("UpperArm_R") >= 0: r_max = max(r_max, vmax)
        print("LEFT UpperArm max dev: ", l_max)
        print("RIGHT UpperArm max dev: ", r_max)
    quit(0)
