extends SceneTree
## Captura os GLBs reais, o esqueleto importado e a loja real em mapa temporário.
## Não inicia jogabilidade, captura o mouse ou grava mapa/catálogo do usuário.
const SAIDA := "res://art_src/validation/bestas_mar"
const TIPOS := ["bovina", "girafa", "javali", "serpente"]
var mundo: Node3D
var camera: Camera3D
var biblioteca: BibliotecaDeModelos
var piso: MeshInstance3D
var legenda: Label
var falhou := false


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Preview exige renderer real e display GPU.")
		quit(1)
		return
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	biblioteca = BibliotecaDeModelos.new(BibliotecaDeModelos.RAIZ_PADRAO)
	for tipo: String in TIPOS:
		if not biblioteca.tem("besta_mar_" + tipo):
			push_error("Cadastre os quatro GLBs antes da captura: " + tipo)
			quit(1)
			return
	_montar_palco()
	for tipo: String in TIPOS:
		var modelo := biblioteca.instanciar("besta_mar_" + tipo)
		if modelo == null:
			push_error("Falha ao instanciar " + tipo)
			quit(1)
			return
		mundo.add_child(modelo)
		var caixa: AABB = BibliotecaDeModelos.medir(modelo)["aabb"]
		piso.position.y = caixa.position.y - 0.06
		_enquadrar(caixa)
		legenda.text = "BESTAS DO MAR  /  " + tipo.to_upper() + "  /  MODELO COMPLETO"
		await _foto(tipo + "_corpo.png")
		var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
		if esqueletos.is_empty():
			push_error("Modelo sem Skeleton3D: " + tipo)
			quit(1)
			return
		var rig := esqueletos[0] as Skeleton3D
		var cabeca := rig.find_bone("cabeca")
		var alvo := rig.global_transform * rig.get_bone_global_pose(cabeca).origin if cabeca >= 0 else Vector3(0, caixa.end.y - 3, -1)
		alvo += Vector3(0, 0.25, -0.65)
		camera.position = alvo + Vector3(5.8, 2.2, -12.0)
		camera.look_at(alvo)
		legenda.text = "BESTAS DO MAR  /  " + tipo.to_upper() + "  /  ROSTO"
		await _foto(tipo + "_rosto.png")
		if tipo == "serpente":
			await _poses_serpente(modelo)
		if tipo == "bovina":
			_enquadrar(caixa)
			var overlay := _desenhar_rig(rig)
			legenda.text = "BOVINA  /  %d OSSOS IMPORTADOS  /  SOBREPOSIÇÃO DO ESQUELETO INTERNO" % rig.get_bone_count()
			await _foto("bovina_esqueleto.png")
			overlay.free()
		modelo.free()
	piso.visible = false
	await _galeria()
	mundo.free()
	legenda.get_parent().free()
	await _editor()
	print("BESTAS_MAR_PREVIEW_OK" if not falhou else "FAIL BESTAS_MAR_PREVIEW")
	quit(1 if falhou else 0)


func _montar_palco() -> void:
	mundo = Node3D.new()
	root.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color("4c9bd0")
	ceu.sky_horizon_color = Color("bee6f5")
	ceu.ground_horizon_color = Color("bee6f5")
	ceu.ground_bottom_color = Color("7193a1")
	env.sky = Sky.new()
	env.sky.sky_material = ceu
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8e9f3")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambiente.environment = env
	mundo.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-42, -30, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 150.0
	mundo.add_child(sol)
	var preenchimento := DirectionalLight3D.new()
	preenchimento.rotation_degrees = Vector3(-15, 145, 0)
	preenchimento.light_color = Color("b4d9f4")
	preenchimento.light_energy = 0.5
	mundo.add_child(preenchimento)
	piso = MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(200, 200)
	piso.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("80b6c8")
	mat.roughness = 1.0
	piso.material_override = mat
	mundo.add_child(piso)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.far = 2000.0
	mundo.add_child(camera)
	camera.make_current()
	var ui := CanvasLayer.new()
	root.add_child(ui)
	legenda = Label.new()
	legenda.position = Vector2(28, 26)
	legenda.add_theme_font_size_override("font_size", 19)
	legenda.add_theme_color_override("font_color", Color("173e56"))
	ui.add_child(legenda)


func _enquadrar(caixa: AABB) -> void:
	var centro := caixa.get_center()
	var raio := caixa.size.length() * 0.5
	camera.position = centro + Vector3(0.62, 0.27, -1.0).normalized() * raio / sin(deg_to_rad(camera.fov * 0.5)) * 1.08
	camera.look_at(centro)


func _desenhar_rig(rig: Skeleton3D) -> Node3D:
	var overlay := Node3D.new()
	mundo.add_child(overlay)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffcf40")
	mat.no_depth_test = true
	mat.render_priority = 10
	for i in rig.get_bone_count():
		var ponto := rig.global_transform * rig.get_bone_global_pose(i).origin
		var junta := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.105
		esfera.height = 0.21
		esfera.radial_segments = 12
		esfera.rings = 6
		junta.mesh = esfera
		junta.material_override = mat
		overlay.add_child(junta)
		junta.position = ponto
		var pai := rig.get_bone_parent(i)
		if pai < 0:
			continue
		var origem := rig.global_transform * rig.get_bone_global_pose(pai).origin
		var direcao := ponto - origem
		if direcao.length() < 0.01:
			continue
		var osso := MeshInstance3D.new()
		var cilindro := CylinderMesh.new()
		cilindro.top_radius = 0.045
		cilindro.bottom_radius = 0.07
		cilindro.height = direcao.length()
		cilindro.radial_segments = 8
		osso.mesh = cilindro
		osso.material_override = mat
		overlay.add_child(osso)
		osso.position = (ponto + origem) * 0.5
		osso.quaternion = Quaternion(Vector3.UP, direcao.normalized())
	return overlay


func _poses_serpente(modelo: Node3D) -> void:
	var animadores := modelo.find_children("*", "AnimationPlayer", true, false)
	if animadores.is_empty():
		push_error("Serpente sem AnimationPlayer importado.")
		falhou = true
		return
	var animador := animadores[0] as AnimationPlayer
	for pose: String in ["repouso", "ameaca"]:
		var clip := ""
		for nome: String in animador.get_animation_list():
			if nome.to_lower().contains(pose):
				clip = nome
		if clip.is_empty():
			push_error("Animação ausente: " + pose)
			falhou = true
			continue
		animador.play(clip)
		animador.seek(0.9, true)
		animador.pause()
		legenda.text = "SERPENTE  /  " + pose.to_upper() + "  /  ANIMAÇÃO IMPORTADA EM 0,9 s"
		await _foto("serpente_" + pose + ".png")


func _galeria() -> void:
	var oceano := preload("res://src/world/oceano_historia.gd").new()
	oceano.nivel_relativo = 2.2
	oceano.altura_ondas = 0.23
	mundo.add_child(oceano)
	# Base somente como referência do shader, longe da câmera; nenhum mapa montado.
	oceano.configurar({"pecas": [{"id": "baseplate", "tipo": "caixa",
		"posicao": Vector3(1000, 0, 1000), "tamanho": Vector3(2, 2, 2), "rotacao_graus": Vector3.ZERO}]})
	oceano.material.set_shader_parameter("tempo_fixo", 0.0)
	for i in TIPOS.size():
		var modelo := biblioteca.instanciar("besta_mar_" + TIPOS[i])
		mundo.add_child(modelo)
		modelo.position = Vector3((1.5 - i) * 10.0, 0, 0)
		modelo.rotation_degrees.y = -20.0
	camera.position = Vector3(5, 13, -54)
	camera.look_at(Vector3(0, 9.2, 0))
	legenda.text = "BESTAS DO MAR  /  BOVINA · GIRAFA · JAVALI · SERPENTE"
	await _foto("galeria_mar.png")


func _editor() -> void:
	var caminho := "user://bestas_mar_preview_mapa.json"
	var erro := DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tools/dev_tests/fixtures/mapa_baseplate.json"), ProjectSettings.globalize_path(caminho))
	if erro != OK:
		push_error("Não foi possível copiar fixture do editor: %d" % erro)
		falhou = true
		return
	var editor: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	editor.caminho_do_mapa = caminho
	editor.biblioteca = biblioteca
	root.add_child(editor)
	current_scene = editor
	# Limita a fila transitória às quatro miniaturas de interesse; catálogo intacto.
	editor._miniaturas._fila.clear()
	var categoria := ""
	for item: Dictionary in biblioteca.categorias():
		if str(item["nome"]).to_lower() == "bestas do mar":
			categoria = item["id"]
	editor._loja.filtrar(categoria)
	if editor._loja.quantidade_visivel() != 4:
		push_error("Filtro da loja não mostra exatamente quatro bestas.")
		falhou = true
	var id: String = editor.inserir_modelo("besta_mar_bovina")
	var peca: Dictionary = editor.doc.peca(id)
	peca["posicao"] = biblioteca.info("besta_mar_bovina")["centro"]
	editor.doc.definir_peca(id, peca)
	editor._camera.fov = 40.0
	editor._camera.posicionar(Vector3(18, 14, -32), Vector3(0, 7, 1))
	editor._camera.ativa = false
	editor.set_process_input(false)
	editor.set_process_unhandled_input(false)
	for quadro in 300:
		await process_frame
		var completas := true
		for tipo: String in TIPOS:
			if editor._miniaturas.em_cache("besta_mar_" + tipo) == null:
				completas = false
		if completas:
			break
	await _foto("editor_loja.png")
	editor.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	await process_frame


func _foto(nome: String) -> void:
	for quadro in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var imagem := root.get_texture().get_image()
	var erro := imagem.save_png(SAIDA.path_join(nome))
	if erro != OK:
		push_error("Falha ao salvar " + nome)
		falhou = true
	print("FOTO ", nome, " erro=", erro)
