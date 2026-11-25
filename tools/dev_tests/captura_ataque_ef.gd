extends SceneTree
## Frames de um ataque com arma do Epic Fight, em tela: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_ataque_ef.gd -- <pasta>
var saida := "/tmp/ataque_ef"
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
	modo.set("progresso_forcado", "user://captura_ataque_ef.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_ataque_ef.json"))
	root.get_node("GameFlow").start_story()
	await quadros(500)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	prog.equipar_lamina("ef_iron_longsword", true)
	await quadros(40)
	await foto("0_parado")
	var ex: ExecutorCorpoACorpo = j.get("combate_direcional")
	ex.pedir_ataque(0)
	for i in 6:
		await quadros(6)
		await foto("%d_ataque" % (i + 1))
	quit()
