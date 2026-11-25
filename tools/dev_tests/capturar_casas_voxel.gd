extends SceneTree
## Foto das casas voxel (lado a lado): DISPLAY=:1 godot --path . --script tools/dev_tests/capturar_casas_voxel.gd -- saida.png id1 id2 ...
func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var args := OS.get_cmdline_user_args()
	var bib := BibliotecaDeModelos.padrao()
	var raiz := Node3D.new()
	root.add_child(raiz)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 30, 0)
	raiz.add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	raiz.add_child(env)
	var x := 0.0
	for id in args.slice(1):
		var m := bib.instanciar(id)
		if m == null:
			continue
		var caixa: AABB = BibliotecaDeModelos.medir(m)["aabb"]
		var maior := maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
		m.scale = Vector3.ONE * (4.0 / maior)
		raiz.add_child(m)
		m.position = Vector3(x - caixa.get_center().x * m.scale.x, -caixa.position.y * m.scale.y, -caixa.get_center().z * m.scale.z)
		x += 6.0
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.position = Vector3(x * 0.5 - 2.5, 4.5, 10.0)
	cam.look_at(Vector3(x * 0.5 - 2.5, 1.5, 0))
	cam.fov = 60
	cam.make_current()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args[0])
	quit()
