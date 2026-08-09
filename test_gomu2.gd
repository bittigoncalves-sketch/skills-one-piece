extends SceneTree

func _init():
	var world = Node3D.new()
	root.add_child(world)
	
	var player = preload("res://Player.tscn").instantiate()
	world.add_child(player)
	
	# wait 1 frame for ready
	await get_tree().process_frame
	
	print("Chamando GomuFX.cast")
	GomuFX.cast(world, player.global_position, player.basis.z * -1, 0, 25.0, player)
	print("GomuFX.cast executado")
	
	# Wait a bit to let GomuArm process
	for i in range(10):
		await get_tree().process_frame
		
	print("Processamento finalizado sem erros críticos aparentes")
	quit()
