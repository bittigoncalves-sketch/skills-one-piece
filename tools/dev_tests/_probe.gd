extends SceneTree
func _init() -> void:
	var s = load("res://tools/dev_tests/_fixture_bug.gd")
	print("carregou: ", s)
	quit()
