extends SceneTree
func _init():
    var scn = load("res://assets/models/yami_blackhole.glb")
    if scn:
        var inst = scn.instantiate()
        _print_tree(inst, "")
    quit()
func _print_tree(node, indent):
    print(indent + node.name + " (" + node.get_class() + ")")
    for c in node.get_children():
        _print_tree(c, indent + "  ")
