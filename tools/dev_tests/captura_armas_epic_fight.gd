extends SceneTree
## O jogador do Modo História empunhando as armas do Epic Fight (modelo voxel da textura real do mod):
##   DISPLAY=:1 godot --path . -s tools/dev_tests/captura_armas_epic_fight.gd -- <pasta> [ids separados por vírgula]
var saida := "/tmp/armas_ef"
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
	modo.set("progresso_forcado", "user://captura_armas_ef.json")
	root.get_node("GameFlow").start_story()
	await quadros(700)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var ids: Array = LaminasEpicFight.ids()
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		ids = a[1].split(",")
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 40
	cam.current = true
	for id in ids:
		var par := str(id).split("+")            # "ef_iron_dagger+ef_golden_dagger" = dual
		prog.equipar_lamina(par[0], true)
		if par.size() > 1:
			prog.equipar_lamina_secundaria(par[1], true)
		await quadros(40)
		var arma_n = j.get_node_or_null("EspadaDaHistoria")
		if arma_n != null and arma_n.carga_max > 0.0:
			arma_n._carregar(arma_n.carga_max * 0.6)
			await quadros(5)
		var c := j.global_position + Vector3(0, 1.3, 0)
		var frente := -j.global_basis.z
		cam.global_position = c + frente * 3.2 + Vector3(1.2, 0.3, 0)
		cam.look_at(c, Vector3.UP)
		await foto(str(id).replace("+", "_e_"))
	quit()
