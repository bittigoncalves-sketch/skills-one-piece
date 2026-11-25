extends SceneTree
## --headless: integração nos NPCs reais; -- --capturar: comparação visual antes/depois.
const Uniformes := preload("res://src/historia/east_blue/uniformes_faccoes.gd")
var falhas := 0
var passou := 0
var mundo: Node3D
var personagens: Array[PersonagemMinePiece] = []


func _init() -> void:
	_rodar.call_deferred()


func verificar(condicao: bool, descricao: String) -> void:
	if condicao:
		passou += 1
	else:
		falhas += 1
	print("%s %s" % ["OK" if condicao else "FALHA", descricao])


func criar(modelo_id: String) -> PersonagemMinePiece:
	var p := PersonagemMinePiece.new()
	p.montar(DadosEastBlue.ficha_do_modelo(modelo_id), modelo_id)
	mundo.add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	return p


func conferir(p: PersonagemMinePiece, modelo_id: String) -> void:
	var grupo := Uniformes.grupo_do_modelo(modelo_id)
	var corpos := 0
	var preservou_itens := true
	var roupa_certa := true
	var rosto_igual := true
	for no: Node in p._modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var aplicado := mi.get_surface_override_material(i) as StandardMaterial3D
			if base.resource_name == "corpo" and not grupo.is_empty():
				corpos += 1
				roupa_certa = roupa_certa and aplicado != null and aplicado.resource_name == "uniforme_" + grupo
				if aplicado != null:
					var original := base.albedo_texture.get_image()
					var nova := aplicado.albedo_texture.get_image()
					if original.is_compressed(): original.decompress()
					# Centro de cada texel do rosto, que não recebe pintura de uniforme.
					for y in range(8, 16):
						for x in range(8, 16):
							rosto_igual = rosto_igual and original.get_pixel(x, y).is_equal_approx(nova.get_pixel(x * 8 + 4, y * 8 + 4))
			elif grupo == "marinheiro" and base.resource_name == "uniform_marine_1_helmet":
				roupa_certa = roupa_certa and aplicado != null and aplicado.resource_name == "uniforme_marinheiro"
			else:
				preservou_itens = preservou_itens and aplicado == null
	verificar((corpos > 0 if not grupo.is_empty() else corpos == 0) and roupa_certa, modelo_id + ": roupa aplicada apenas aos genéricos")
	verificar(preservou_itens and rosto_igual, modelo_id + ": rosto e equipamentos preservados")
	verificar(p._anim != null and p._anim.get_animation_list().size() > 0, modelo_id + ": animações disponíveis")


func _rodar() -> void:
	await process_frame
	mundo = Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var modelos := ["mp_marine", "mp_pirate"]
	for i in range(1, 9): modelos.append("mp_pirate_pirate%d" % i)
	for i in range(1, 5): modelos.append("mp_pirate_fishman%d" % i)
	modelos.append("mp_morgan")
	for modelo: String in modelos:
		var p := criar(modelo)
		conferir(p, modelo)
		personagens.append(p)
	# O evento de nascimento pode sortear equipamento/textura. Exercita a procedure real.
	for indice in [0, 2]:
		var p := personagens[indice]
		p.ia_do_mod._physics_process(0.1)
		p._renascer()
		conferir(p, modelos[indice])
	var outro := criar("mp_marine")
	var a := personagens[0]._modelo.find_child("torso", true, false) as MeshInstance3D
	var b := outro._modelo.find_child("torso", true, false) as MeshInstance3D
	verificar(a != null and b != null and a.get_surface_override_material(0) == b.get_surface_override_material(0), "NPCs compartilham o material composto em cache")
	outro.queue_free()
	if "--capturar" in OS.get_cmdline_user_args():
		await capturar()
	print("UNIFORMES: %d verificações passaram; %d falhas" % [passou, falhas])
	quit(1 if falhas > 0 else 0)


func capturar() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202b3a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	mundo.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -35, 0)
	sol.light_energy = 1.2
	mundo.add_child(sol)
	var camera := Camera3D.new()
	mundo.add_child(camera)
	camera.position = Vector3(0, 2.5, -9)
	camera.look_at(Vector3(0, 1, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.7
	camera.current = true
	for p in personagens: p.visible = false
	var exibidos: Array[PersonagemMinePiece] = [personagens[0], criar("mp_marine"), personagens[2], criar("mp_pirate_pirate1")]
	for i in exibidos.size():
		var p := exibidos[i]
		p.visible = true
		p._rotulo.visible = false
		p.position = Vector3((1.5 - i) * 1.55, 0, 0)
		p.rotation.y = PI if i % 2 == 1 else 0.0
		p._anim.stop()
	var titulo := Label.new()
	titulo.position = Vector2(45, 35)
	titulo.add_theme_font_size_override("font_size", 28)
	root.add_child(titulo)
	var legenda := Label.new()
	legenda.text = "MARINHEIRO • FRENTE / COSTAS                         PIRATA • FRENTE / COSTAS"
	legenda.position = Vector2(190, 800)
	legenda.add_theme_font_size_override("font_size", 21)
	root.add_child(legenda)
	var pasta := "res://art_src/uniformes_faccoes/validacao"
	DirAccess.make_dir_recursive_absolute(pasta)
	for etapa in ["antes", "depois"]:
		for p in exibidos:
			if etapa == "antes":
				for no: Node in p._modelo.find_children("*", "MeshInstance3D", true, false):
					var mi := no as MeshInstance3D
					for i in mi.mesh.get_surface_count(): mi.set_surface_override_material(i, null)
			else:
				Uniformes.aplicar(p._modelo, str(p.get_meta("modelo_recrutavel")))
		titulo.text = "UNIFORMES DAS FACÇÕES / " + etapa.to_upper()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		verificar(root.get_texture().get_image().save_png(pasta + "/" + etapa + ".png") == OK, "captura " + etapa)
