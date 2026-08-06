extends SceneTree
func _init():
	print("Testando CharacterBuilder...")
	var cb = load("res://CharacterBuilder.gd")
	var res = cb.build_character("buggy")
	print("Sucesso! Nome da raiz: ", res["node"].name)
	quit()
