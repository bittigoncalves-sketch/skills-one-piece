extends SceneTree
## HUD de toque (celular) forçado, com o tema: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_toque_minecraft.gd -- <arquivo.png>
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	GuiMinecraft.ligar_normalizacao(self)
	var fundo := ColorRect.new()
	fundo.color = Color(0.3, 0.45, 0.3)
	fundo.size = Vector2(1280, 720)
	root.add_child(fundo)
	ToqueHud.forcar = true
	var cl := CanvasLayer.new()
	root.add_child(cl)
	cl.add_child(ToqueHud.new())
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/toque_mc.png")
	quit()
