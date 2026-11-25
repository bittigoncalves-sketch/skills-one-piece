extends SceneTree
## DISPLAY=:1 godot --path . -s tools/dev_tests/captura_central_minecraft.gd -- <pasta>
var saida := "/tmp/central_mc"
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
	modo.set("progresso_forcado", "user://captura_central_mc.json")
	root.get_node("GameFlow").start_story()
	await quadros(500)
	var hud: HistoriaHud = get_first_node_in_group("hud")
	for aba in ["blocos", "bancada"]:
		hud._central.abrir(aba)
		await quadros(60)
		if aba == "mochila":
			var pv: PreviaDoPersonagem = hud._central.find_child("PreviaMochila", true, false)
			print("PREVIA ", pv, " modelo=", pv.modelo if pv else null, " vp=", pv.viewport.size if pv and pv.viewport else null, " cam=", pv.camera.position if pv and pv.camera else null, " size=", pv.size if pv else null, " vis=", pv.is_visible_in_tree() if pv else null)
		await foto("aba_" + aba)
	quit()
