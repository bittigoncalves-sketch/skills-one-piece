extends SceneTree

func _init() -> void:
	var s1 = load("res://Player.gd")
	print("ANTES do frame: can_instantiate=", s1.can_instantiate(), " valid=", s1.is_valid() if s1.has_method("is_valid") else "?")
	var p1 = s1.new()
	print("ANTES: new() -> ", p1)
	await process_frame
	var s2 = load("res://Player.gd")
	print("DEPOIS do frame: can_instantiate=", s2.can_instantiate())
	var p2 = s2.new()
	print("DEPOIS: new() -> ", p2)
	print("autoloads na arvore: ", get_root().get_node_or_null("FruitNet"), " ", get_root().get_node_or_null("GameFlow"))
	quit(0)
