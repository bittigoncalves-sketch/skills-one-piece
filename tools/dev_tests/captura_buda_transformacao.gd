extends SceneTree
const PASTA := "res://art_src/validation/buda_transformacao/"

func _init() -> void:
	executar.call_deferred()

func referencia() -> Node3D:
	var raiz := Node3D.new()
	var forma := FormaZoan.new()
	forma._k = MundoMinePiece.METROS_POR_BLOCO / 16.0 * FormaZoan.ESCALA_DO_MOD
	for camada: Dictionary in FormaZoan.dados()["hito_hito_daibutsu"]:
		for parte: Dictionary in camada.partes:
			var p := Node3D.new()
			p.transform = forma._pose(parte.pos, parte.rot)
			raiz.add_child(p)
			if parte.caixas.is_empty():
				continue
			var vs := PackedVector3Array()
			var uvs := PackedVector2Array()
			var idx := PackedInt32Array()
			for caixa: Array in parte.caixas:
				McVisual._caixa_mc(vs, uvs, idx, caixa, Vector3.ZERO, Basis.IDENTITY, forma._k, Vector2(camada.tex_w, camada.tex_h))
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = vs
			arr[Mesh.ARRAY_TEX_UV] = uvs
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.material_override = forma._material(camada.textura)
			p.add_child(m)
	forma.free()
	return raiz

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 1000)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var modelo: Node3D
	var antigo := OS.get_cmdline_user_args().has("referencia")
	if antigo:
		modelo = referencia()
	else:
		modelo = load("res://assets/models/buda/buda_transformacao.tscn").instantiate()
	viewport.add_child(modelo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("202a36")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e4ff")
	env.ambient_light_energy = 0.55
	ambiente.environment = env
	viewport.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	viewport.add_child(luz)
	luz.rotation_degrees = Vector3(-30, -30, 0)
	luz.light_energy = 0.8
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	var centro := Vector3(0, -0.42, 0)
	for vista in ["frente", "tres_quartos", "costas"]:
		camera.position = centro + {"frente": Vector3(0,0.1,4), "tres_quartos": Vector3(2,0.5,4), "costas": Vector3(-2,0.4,-4)}[vista]
		camera.look_at(centro)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA + ("antes_" if antigo else "depois_") + vista + ".png"))
	viewport.queue_free()
	await process_frame
	quit()
