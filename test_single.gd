extends SceneTree

func _init() -> void:
	await process_frame
	var flow = get_root().get_node("GameFlow")
	flow.start_singleplayer()
	
	var timer = create_timer(1.0)
	await timer.timeout
	
	var main = get_root().get_node_or_null("Main")
	if main:
		print("Main encontrado.")
		var players = main.get_node_or_null("Players")
		if players:
			print("Jogadores em Players: ", players.get_child_count())
			for p in players.get_children():
				var rig = p.get_node_or_null("CameraRig")
				if rig:
					var cam = rig.get_node_or_null("Spring/Camera")
					if cam:
						print("Camera encontrada. current = ", cam.current)
					else:
						print("Camera NAO encontrada.")
				else:
					print("CameraRig NAO encontrado.")
		else:
			print("No Players nao encontrado.")
	else:
		print("Main nao encontrado.")
		
	quit()
