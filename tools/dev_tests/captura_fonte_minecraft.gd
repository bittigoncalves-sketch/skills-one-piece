extends SceneTree
## DISPLAY=:1 godot --path . --script tools/dev_tests/captura_fonte_minecraft.gd -- /tmp/saida.png
func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var f := FonteMinecraft.fonte()
	print("fonte: ", f != null)
	var fundo := ColorRect.new()
	fundo.color = Color(0.25, 0.25, 0.28)
	fundo.size = Vector2(1000, 500)
	root.add_child(fundo)
	var y := 10
	for tam in [10, 11, 12, 13, 14, 15, 17, 20]:
		var l := Label.new()
		l.text = "Inventário — Poção de Cura: ação, coração, órfão, lã, çã! 0123456789 ABCxyz"
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", tam)
		l.add_theme_color_override("font_shadow_color", Color(0.1, 0.1, 0.1, 0.9))
		l.add_theme_constant_override("shadow_offset_x", maxi(1, tam / 8))
		l.add_theme_constant_override("shadow_offset_y", maxi(1, tam / 8))
		l.position = Vector2(10, y)
		fundo.add_child(l)
		y += tam * 2 + 4
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/fonte.png")
	quit()
