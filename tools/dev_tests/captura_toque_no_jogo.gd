extends SceneTree
## O HUD de toque DENTRO do Modo História (forçado, como num celular): DISPLAY=:1 godot --path . -s tools/dev_tests/captura_toque_no_jogo.gd -- <arquivo.png>
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	ToqueHud.forcar = true
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://captura_toque.json")
	root.get_node("GameFlow").start_story()
	for i in 700:
		await physics_frame
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/toque_jogo.png")
	quit()
