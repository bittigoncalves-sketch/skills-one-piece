extends SceneTree

func _init():
    var timer = Timer.new()
    timer.wait_time = 2.0
    timer.one_shot = true
    timer.timeout.connect(_on_timeout)
    var root = get_root()
    root.add_child(timer)
    timer.start()

    var packed = load("res://Main.tscn")
    var scene = packed.instantiate()
    root.add_child(scene)
    current_scene = scene

func _on_timeout():
    print("=== DUMPING SCENE TREE ===")
    _print_tree(get_root(), 0)
    quit()

func _print_tree(node: Node, depth: int):
    var indent = ""
    for i in range(depth): indent += "  "
    var vis = ""
    if node is CanvasItem: vis = " [vis: " + str(node.visible) + "]"
    print(indent + node.name + " (" + node.get_class() + ")" + vis)
    for c in node.get_children():
        _print_tree(c, depth + 1)
