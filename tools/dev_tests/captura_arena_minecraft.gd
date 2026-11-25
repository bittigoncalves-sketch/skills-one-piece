extends SceneTree
## A arena (singleplayer) com o tema global: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_arena_minecraft.gd -- <arquivo.png>
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	root.get_node("GameFlow").start_singleplayer()
	for i in 900:
		await physics_frame
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/arena_mc.png")
	quit()
