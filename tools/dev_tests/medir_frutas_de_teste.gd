extends SceneTree
## Com janela e build de desenvolvimento, o inventário já nasce com as frutas de teste (5 Nikyu); idempotente entre aberturas.
##   godot --path . --resolution 800x450 --script res://tools/dev_tests/medir_frutas_de_teste.gd
func _init() -> void:
	call_deferred("_r")
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_frutas_teste.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://medir_frutas_teste.json"))
	root.get_node("GameFlow").start_story()
	var j: Node = null
	var limite := Time.get_ticks_msec() + 150000
	while j == null and Time.get_ticks_msec() < limite:
		await process_frame
		j = get_first_node_in_group("player")
	for i in 60: await process_frame
	var prog = current_scene.progressao
	print("FRUTAS janela=%s debug=%s nikyu=%d" % [DisplayServer.get_name() != "headless", OS.is_debug_build(), int(prog.frutas_compradas.get("nikyu_nikyu_mine_piece", 0))])
	modo.set("progresso_forcado", "")
	quit()
