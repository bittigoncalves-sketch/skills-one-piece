extends SceneTree
## Vitrine dos blocos com textura vanilla (sem o jogo): DISPLAY=:1 godot --path . --script tools/dev_tests/captura_blocos_texturizados.gd -- /tmp/saida
func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var pasta := "/tmp/blocos_tex"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		pasta = a[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	var raiz := Node3D.new()
	root.add_child(raiz)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 30, 0)
	luz.shadow_enabled = true
	raiz.add_child(luz)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.72, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	raiz.add_child(env)
	var g := GradeVoxel.new()
	raiz.add_child(g)
	TiposDeBloco.iniciar()
	print("textura: ", TexturasDeBloco.tem_textura())
	# chão de grama 20×20, 3 de terra, pedra
	for x in 20:
		for z in 14:
			g.definir(Vector3i(x, 0, z), TiposDeBloco.PEDRA)
			g.definir(Vector3i(x, 1, z), TiposDeBloco.TERRA)
			g.definir(Vector3i(x, 2, z), TiposDeBloco.TERRA)
			g.definir(Vector3i(x, 3, z), TiposDeBloco.GRAMA)
	var tipos := [TiposDeBloco.AREIA, TiposDeBloco.MADEIRA, TiposDeBloco.TRONCO, TiposDeBloco.FOLHAS, TiposDeBloco.TIJOLO,
		TiposDeBloco.PEDREGULHO, TiposDeBloco.NEVE, TiposDeBloco.OBSIDIANA, TiposDeBloco.ARGILA, TiposDeBloco.BASALTO,
		TiposDeBloco.LA_BRANCA, TiposDeBloco.LA_VERMELHA, TiposDeBloco.LA_AZUL, TiposDeBloco.LA_VERDE, TiposDeBloco.LA_AMARELA,
		TiposDeBloco.GELO, TiposDeBloco.VIDRO, TiposDeBloco.AGUA]
	for i in tipos.size():
		g.definir(Vector3i(1 + i, 4, 3), tipos[i])
	# escada, laje, porta, painel
	RegrasDeBloco.colocar_escada(g, Vector3i(2, 4, 6), TiposDeBloco.MADEIRA, 0)
	RegrasDeBloco.colocar_laje(g, Vector3i(4, 4, 6), TiposDeBloco.PEDREGULHO)
	RegrasDeBloco.colocar_porta(g, Vector3i(6, 4, 6), 0)
	for i in 3:
		RegrasDeBloco.colocar_painel(g, Vector3i(9 + i, 4, 6))
	# um paredão para ver a lateral grande, com degrau de terra
	for y in range(4, 8):
		for x in range(12, 19):
			g.definir(Vector3i(x, y, 9), TiposDeBloco.PEDRA if y < 6 else TiposDeBloco.TIJOLO)
	# todos os blocos extras (128) numa parede de 16 colunas
	var todos := BlocosExtras.todas()
	for i in todos.size():
		g.definir(Vector3i(i % 16, 4 + i / 16, 11), int(todos[i].id))
	g.esperar_tudo()
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 60
	cam.make_current()
	var B := GradeVoxel.BLOCO
	var vistas := {
		"alto": [Vector3(10, 11, 18), Vector3(10, 4, 5)],
		"rente": [Vector3(5, 6.5, 12), Vector3(10, 4.2, 3.5)],
		"parede": [Vector3(15, 8, 16), Vector3(15, 5, 9)],
		"extras": [Vector3(8, 8, 19), Vector3(8, 8, 11)],
	}
	for nome in vistas:
		cam.global_position = vistas[nome][0] * B
		cam.look_at(vistas[nome][1] * B, Vector3.UP)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [pasta, nome])
	quit()
