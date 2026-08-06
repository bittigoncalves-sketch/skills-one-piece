extends SceneTree

func _init():
	var world = Node3D.new()
	var caster = Node3D.new()
	world.add_child(caster)
	SandFX.cast(world, Vector3.ZERO, Vector3.FORWARD, 2, 10.0, caster)
	print("Sand C casted. Children count: ", world.get_child_count())
	for c in world.get_children():
		print(" - ", c.name, " type: ", c.get_class(), " pos: ", c.get("global_position"))
	quit()
