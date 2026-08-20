@tool
extends EditorScript

func _run() -> void:
	var root = Node3D.new()
	root.name = "TestArena"

	# Floor
	var floor_static = StaticBody3D.new()
	floor_static.name = "Floor"
	var floor_col = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(50, 1, 50)
	floor_col.shape = floor_shape
	floor_static.add_child(floor_col)
	var floor_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(50, 50)
	floor_mesh.mesh = plane_mesh
	floor_static.add_child(floor_mesh)
	root.add_child(floor_static)
	floor_static.position.y = -0.5

	# Wall (For wall bounce testing)
	var wall = StaticBody3D.new()
	wall.name = "Wall"
	var wall_col = CollisionShape3D.new()
	var wall_shape = BoxShape3D.new()
	wall_shape.size = Vector3(10, 5, 1)
	wall_col.shape = wall_shape
	wall.add_child(wall_col)
	var wall_mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(10, 5, 1)
	wall_mesh.mesh = box_mesh
	wall.add_child(wall_mesh)
	root.add_child(wall)
	wall.position = Vector3(0, 2.5, -12)

	# Training Dummy
	var dummy = load("res://src/entities/TrainingDummy.gd").new()
	dummy.name = "TrainingDummy"
	root.add_child(dummy)
	dummy.position = Vector3(0, 4, -8)

	var spawn = Node3D.new()
	spawn.name = "SpawnPoint"
	spawn.add_to_group("spawn")
	spawn.position = Vector3(0, 1, 0)
	root.add_child(spawn)
	
	var sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.position = Vector3(0, 10, 0)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	root.add_child(sun)

	for child in root.get_children():
		child.owner = root
		for c2 in child.get_children():
			c2.owner = root

	var scene = PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, "res://TestArena.tscn")
	print("TestArena.tscn created successfully!")
