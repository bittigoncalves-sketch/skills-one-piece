extends SceneTree
## Prova visual dos clipes nas quatro malhas reais, com rig e blend do jogo.
## -- --mergulho captura a extensão de 07/10 separada da galeria anterior.
const SAIDA := "res://art_src/validation/bestas_mar/comportamento"
const TIPOS := ["bovina", "girafa", "javali", "serpente"]
const CLIPES := ["idle", "dormindo", "nadando_walk", "nadando_run", "irritado", "atacando", "recebendo_dano", "disparando_ataque", "comendo"]
var camera: Camera3D
var mundo: Node3D
var legenda: Label


func _init() -> void:
	rodar.call_deferred()


func rodar() -> void:
	await process_frame
	root.size = Vector2i(1280, 900)
	root.content_scale_size = root.size
	mundo = Node3D.new()
	root.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9bc9de")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e7ed")
	env.ambient_light_energy = .7
	ambiente.environment = env
	mundo.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, -35, 0)
	sol.shadow_enabled = true
	mundo.add_child(sol)
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(120, 120)
	piso.mesh = plano
	var areia := StandardMaterial3D.new()
	areia.albedo_color = Color("c8b893")
	areia.roughness = .95
	piso.material_override = areia
	mundo.add_child(piso)
	camera = Camera3D.new()
	camera.fov = 48
	mundo.add_child(camera)
	camera.make_current()
	var camada := CanvasLayer.new()
	root.add_child(camada)
	legenda = Label.new()
	legenda.position = Vector2(24, 24)
	legenda.add_theme_font_size_override("font_size", 26)
	legenda.add_theme_color_override("font_shadow_color", Color.BLACK)
	legenda.add_theme_constant_override("shadow_offset_x", 2)
	legenda.add_theme_constant_override("shadow_offset_y", 2)
	camada.add_child(legenda)
	var bib := BibliotecaDeModelos.padrao()
	var tabela := {}
	var mergulho := OS.get_cmdline_user_args().has("--mergulho")
	var saida := SAIDA.get_base_dir().path_join("mergulho/poses") if mergulho else SAIDA
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var clipes: Array = ["dormindo", "nadando_walk", "mergulhando", "nadando_submerso", "emergindo", "atacando", "disparando_ataque"] if mergulho else CLIPES
	for tipo in TIPOS:
		var modelo := bib.instanciar("besta_mar_" + tipo)
		mundo.add_child(modelo)
		var animador = load("res://src/historia/bestas_mar/animador.gd").new()
		if tipo == "serpente":
			animador.boca_local = Vector3(0, 7.16, -3.02)
		animador.montar(modelo)
		var info := bib.info("besta_mar_" + tipo)
		var altura: float = info.tamanho.y
		camera.position = Vector3(altura * 1.4, altura * .85, -altura * 1.9)
		camera.look_at(Vector3(0, altura * .4, 1))
		tabela[tipo] = {}
		for clip in clipes:
			animador.mudar(clip)
			var instante: float = animador.duracao() * (.52 if clip in ["atacando", "disparando_ataque", "irritado"] else .25)
			if clip in ["mergulhando", "emergindo"]: instante = animador.duracao() * .75
			for i in 30:
				animador.avancar(instante / 30)
				await process_frame
			legenda.text = "%s  ·  %s" % [tipo.to_upper(), clip.replace("_", " ")]
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida.path_join(tipo + "_" + clip + ".png"))
			tabela[tipo][clip] = {"boca": str(animador.boca()), "tempo": instante, "duracao": animador.duracao()}
		modelo.free()
	var f := FileAccess.open(saida.path_join("poses_medidas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(tabela, "\t"))
	print("PREVIEW_BESTAS_COMPORTAMENTO_OK")
	quit()
