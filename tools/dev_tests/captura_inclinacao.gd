extends SceneTree
## Tronco acompanhando a câmera, em tela: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_inclinacao.gd -- <pasta>
var saida := "/tmp/inclinacao"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://captura_inclinacao.json")
	root.get_node("GameFlow").start_story()
	await quadros(600)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	for par in [["baixo", -1.15], ["nivel", -0.25], ["cima", 1.2]]:
		j._pitch = par[1]
		j._update_pivot()
		await quadros(40)
		await foto(par[0])
	quit()
