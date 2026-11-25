extends SceneTree
## Foto do menu inicial com o tema global: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_menu_minecraft.gd -- <arquivo.png>
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	root.add_child(load("res://MainMenu.tscn").instantiate())
	for i in 120:
		await process_frame
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/menu_mc.png")
	quit()
