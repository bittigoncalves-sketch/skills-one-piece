extends MainLoop

func _process(delta):
	var script = load("res://src/effects/FireFX.gd")
	if script:
		print("✅ FireFX.gd compilou com sucesso.")
	else:
		print("❌ ERRO: FireFX.gd não compilou.")
		
	var pc = load("res://Player.gd")
	if pc:
		print("✅ Player.gd compilou com sucesso.")
	else:
		print("❌ ERRO: Player.gd não compilou.")
	return true
