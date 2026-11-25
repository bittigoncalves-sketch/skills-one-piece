extends SceneTree
## Caminho real de história: transformação, articulações, perspectiva e limpeza.
const PASTA := "res://art_src/validation/buda_transformacao/"
var falhas := 0
var total := 0

func _init() -> void:
	executar.call_deferred()

func verificar(condicao: bool, descricao: String) -> void:
	total += 1
	if not condicao: falhas += 1
	print(("PASS " if condicao else "FALHA ") + descricao)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func executar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://teste_buda_transformacao.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	modo.equipar_fruta(j, "hito_hito_daibutsu")
	await quadros(8)
	var c = j.get_node("FrutaMinePiece")
	c.transformar(false)
	await quadros(12)
	var f := j.get_node_or_null("FormaZoan") as FormaZoan
	verificar(f != null and f._buda_autoral, "J monta o modelo autoral no Modo História")
	if f == null:
		quit(1)
		return
	verificar(not j._char_model.visible, "corpo original escondido")
	verificar(f.find_children("Head", "Node3D", true, false).size() == 1, "somente uma cabeça sólida")
	verificar(f.find_children("*", "MeshInstance3D", true, false).size() == 12, "12 peças articuladas")
	verificar(is_equal_approx(float(McEntidade.de(j).escala(&"height")), 3.5), "escala gigante original preservada")
	await foto(j, f, "historia_parado")
	j._camera.alternar_perspectiva()
	f._seguir()
	verificar(not f.visible, "primeira pessoa esconde a forma")
	j._camera.alternar_perspectiva()
	f._seguir()
	verificar(f.visible, "terceira pessoa restaura a forma")
	var inicio: Vector3 = j.global_position
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_W
	tecla.keycode = KEY_W
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await quadros(24)
	verificar(j.global_position.distance_to(inicio) > 0.1, "transformado anda pelo controle real")
	await foto(j, f, "historia_andando")
	tecla = InputEventKey.new()
	tecla.physical_keycode = KEY_W
	tecla.keycode = KEY_W
	tecla.pressed = false
	Input.parse_input_event(tecla)
	await quadros(20)
	# Congela a atualização do ator enquanto injeta rotações conhecidas no rig real.
	j.set_physics_process(false)
	var guardadas := {}
	for nome: String in f._juntas:
		var junta := f._juntas[nome] as Node3D
		if junta != null: guardadas[junta] = junta.transform
	for nome: String in FormaZoan.BUDA_JUNTAS:
		var junta := f._juntas[nome] as Node3D
		verificar(junta != null, nome + " possui junta no jogador")
		if junta == null: continue
		var peca := f._topo[nome] as Node3D
		var antes := peca.global_basis
		junta.rotate_x(0.65)
		f._seguir()
		verificar(not peca.global_basis.is_equal_approx(antes), nome + " acompanha rotação")
		var giro: Basis = j._char_model.global_basis.orthonormalized()
		var meia := Basis(Vector3.UP, PI)
		var esperado := meia * (giro.inverse()*junta.global_basis).orthonormalized() * meia.inverse()
		var medido := f.global_basis.orthonormalized().inverse()*peca.global_basis.orthonormalized()
		verificar(medido.is_equal_approx(esperado), nome + " não duplica rotação do pai")
		junta.transform = guardadas[junta]
		f._seguir()
	# Pose de guarda para inspecionar costuras dos ombros/cotovelos e rosto.
	(f._juntas["RightArm"] as Node3D).rotate_x(0.65)
	(f._juntas["RightForeArm"] as Node3D).rotate_x(1.0)
	(f._juntas["LeftArm"] as Node3D).rotate_x(0.45)
	(f._juntas["LeftForeArm"] as Node3D).rotate_x(1.1)
	f._seguir()
	await foto(j, f, "historia_articulado")
	for junta: Node3D in guardadas:
		junta.transform = guardadas[junta]
	f._seguir()
	j.set_physics_process(true)
	c.transformar(false)
	await quadros(8)
	verificar(j.get_node_or_null("FormaZoan") == null and j._char_model.visible, "J desfaz e devolve o corpo")
	verificar(is_equal_approx(float(McEntidade.de(j).escala(&"height")), 1.0), "J restaura escala")
	c.transformar(false)
	await quadros(8)
	modo.equipar_fruta(j, "gomu_gomu")
	await quadros(8)
	verificar(j.get_node_or_null("FormaZoan") == null and j._char_model.visible, "trocar fruta transformado limpa o modelo")
	verificar(j.find_children("FormaZoanRetirada*", "Node3D", false, false).is_empty(), "nenhuma forma antiga sobra no ator")
	print("BUDA_TRANSFORMACAO: %d verificações, %d falhas" % [total, falhas])
	# Libera a cena antes de sair para não confundir recursos vivos com vazamento.
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if falhas else 0)

func foto(j: Node3D, f: Node3D, nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var vp := SubViewport.new()
	vp.size = Vector2i(1200, 1000)
	vp.world_3d = j.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	var centro := f.global_position + Vector3.DOWN*1.3
	camera.global_position = centro + f.global_basis.z.normalized()*12 + f.global_basis.x.normalized()*5 + Vector3.UP*2
	camera.look_at(centro)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA+nome+".png"))
	vp.queue_free()
	await process_frame
