extends SceneTree
func _init():
	var err = false
	var scripts = ["res://Player.gd", "res://src/effects/FireFX.gd", "res://src/effects/FireFXGrande.gd", "res://src/player/cast_controller.gd"]
	for s in scripts:
		var res = load(s)
		if res == null:
			print("FAILED: ", s)
			err = true
		else:
			print("OK: ", s)
	if err:
		quit(1)
	quit(0)
