extends SceneTree

func _init() -> void:
	print("--- INICIANDO TESTE GOMUFX ---")
	var root = Node3D.new()
	root.name = "Root"
	root_set(root)
	
	var player = Node3D.new()
	player.name = "Player"
	root.add_child(player)
	
	var arm = Node3D.new()
	arm.name = "UpperArm_R"
	player.add_child(arm)
	
	print("Chamando GomuFX.cast")
	GomuFX.cast(root, Vector3.ZERO, Vector3.FORWARD, 0, 25.0, player)
	print("GomuFX.cast terminou com sucesso")
	
	# Process one frame
	for i in range(10):
		root.propagate_notification(Node.NOTIFICATION_PROCESS)
		print("Process", i, "OK")
		
	print("--- TESTE GOMUFX CONCLUIDO ---")
	quit(0)

func root_set(r: Node):
	root.add_child(r)
