extends SceneTree
func _init():
    var anim = load("res://assets/animations/right_upper_hook_from_guard.res")
    if anim:
        for i in anim.get_track_count():
            var path = String(anim.track_get_path(i))
            if path.begins_with("UpperArm") or path.begins_with("ForeArm"):
                print("Track: ", path)
                var k_count = anim.track_get_key_count(i)
                if k_count > 0:
                    var v0 = anim.track_get_key_value(i, 0)
                    var vmax = 0.0
                    for k in range(k_count):
                        var v = anim.track_get_key_value(i, k)
                        vmax = max(vmax, (v - v0).length())
                    print("  Max deviation: ", vmax)
    quit(0)
