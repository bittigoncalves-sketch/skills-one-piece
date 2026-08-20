extends SceneTree

func _init():
	print("Carregando MainMenu...")
	var menu_scn = load("res://MainMenu.tscn")
	var inst = menu_scn.instantiate()
	root.add_child(inst)
	print("Menu instanciado. Clicando em singleplayer...")
	inst._on_singleplayer_pressed()
	
	var timer = root.get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		print("3 segundos se passaram. Árvore atual:")
		_print_tree(root, "")
		quit()
	)

func _print_tree(node, indent):
	print(indent + node.name)
	for child in node.get_children():
		_print_tree(child, indent + "  ")
