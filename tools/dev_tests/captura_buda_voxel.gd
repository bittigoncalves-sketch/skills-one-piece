extends SceneTree
## Valida o caminho real de criação e renderiza a malha usada pelo jogo.
const PASTA := "res://art_src/validation/buda_voxel/"

func _init() -> void:
	executar.call_deferred()

func executar() -> void:
	var fruta := TreeAndFruitGenerator.create_fruit_3d({"id": "hito_hito_daibutsu"})
	root.add_child(fruta)
	fruta.process_mode = Node.PROCESS_MODE_DISABLED
	assert(fruta.get_node_or_null("PickupArea/CollisionShape3D") != null, "Coleta sem colisão")
	var malhas := fruta.find_children("*", "MeshInstance3D", true, false)
	assert(malhas.size() == 1, "Esperada uma malha consolidada")
	var malha: Mesh = malhas[0].mesh
	assert(malha.get_surface_count() == 1)
	assert(malha.get_aabb().size.y < 1.2, "Escala incompatível com o gerador")
	assert(PerfilDeFrutas.frutas_a_venda().has("hito_hito_daibutsu"), "Fruta ausente da loja")
	assert(PerfilDeFrutas.preco_na_loja("hito_hito_daibutsu") == PerfilDeFrutas.PRECO_POR_PODER[4])
	assert(PerfilDeFrutas.imagem_na_loja("hito_hito_daibutsu") == "res://assets/models/buda/buda_loja.png")
	root.remove_child(fruta)
	if DisplayServer.get_name() == "headless":
		var icone := load(PerfilDeFrutas.imagem_na_loja("hito_hito_daibutsu")) as Texture2D
		assert(icone != null and icone.get_width() == 256, "Imagem da loja não importada")
		fruta.free()
		print("BUDA_VOXEL_OK: criação real, malha, colisão, escala, catálogo, preço e textura da loja")
		quit()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	viewport.add_child(fruta)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202c38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e5ff")
	env.ambient_light_energy = 0.4
	ambiente.environment = env
	viewport.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	viewport.add_child(luz)
	luz.rotation_degrees = Vector3(-40, -35, 0)
	luz.light_color = Color("fff1d8")
	luz.light_energy = 0.85
	luz.shadow_enabled = true
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.65
	camera.position = Vector3(1.65, 1.05, 2.4)
	camera.look_at(Vector3(0, 0.10, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	await salvar(viewport, PASTA + "frente.png")
	camera.position = Vector3(-1.65, 0.95, -2.4)
	camera.look_at(Vector3(0, 0.10, 0))
	await salvar(viewport, PASTA + "costas.png")
	camera.position = Vector3(1.65, 1.05, 2.4)
	camera.look_at(Vector3(0, 0.10, 0))
	viewport.transparent_bg = true
	viewport.size = Vector2i(256, 256)
	await salvar(viewport, "res://assets/models/buda/buda_loja.png")
	print("BUDA_VOXEL_OK: integração e capturas frente/costas/loja")
	viewport.queue_free()
	await process_frame
	quit()

func salvar(viewport: SubViewport, caminho: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(caminho)) == OK)
