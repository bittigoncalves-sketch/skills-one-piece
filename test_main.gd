extends SceneTree

func _init():
	print("Carregando Main...")
	var main_scn = load("res://Main.tscn")
	var inst = main_scn.instantiate()
	root.add_child(inst)
	print("Carregado! Checando Hud...")
	var hud = inst.get_node("Hud")
	if hud:
		print("Hud achado!")
		var menu = hud.get_node("MainMenu")
		if menu:
			print("Menu visible: ", menu.visible)
	quit()
