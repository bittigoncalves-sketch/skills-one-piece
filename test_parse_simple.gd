extends MainLoop

func _process(delta):
	var script = load("res://src/effects/FireFX.gd")
	if script:
		print("✅ FireFX.gd compilou com sucesso.")
	else:
		print("❌ ERRO: FireFX.gd não compilou.")
	return true
