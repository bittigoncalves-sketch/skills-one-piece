extends SceneTree
# ============================================================================
#  LOJA DE PROJÉTEIS — fotos com GPU (06/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_loja_de_projeteis.gd -- <pasta>
#
#  1_loja.png      o Builder aberto na seção Projéteis (grade com as miniaturas)
#  1b_modelos.png  a mesma seção rolada até os modelos da loja do editor
#  2_em_voo.png    os 10 prontos voando lado a lado, com rastro, na luz do jogo
#  3_previa.png    a prévia do Builder disparando a Bola de fogo
# ============================================================================

const Catalogo := preload("res://src/skills_builder/catalogo_de_projeteis.gd")

var saida := ""


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	root.size = Vector2i(1600, 900)

	# 1. A loja no editor (espera a fila de miniaturas: 2 quadros por foto).
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(10)
	var ed := current_scene
	ed.pasta_skills = "user://capturar_loja_rascunho"
	ed._mostrar_secao("projeteis")
	await _quadros(260)
	ed._construir_inspector()
	await _quadros(6)
	await _foto("1_loja")
	# 1b. Rolando até os modelos da loja do editor.
	var modelos := ed.find_child("Modelos", true, false) as Control
	var rolagem := ed._inspector.get_parent() as ScrollContainer
	if modelos != null and rolagem != null:
		rolagem.scroll_vertical = int(modelos.global_position.y - ed._inspector.global_position.y) - 120
		await _quadros(90)
		await _foto("1b_modelos")

	# 3. A prévia disparando a Bola de fogo.
	ed._usar_projetil(Catalogo.valores_do_pronto("Bola de fogo"))
	var novo: Dictionary = ed.skill.duplicate(true)
	novo.eventos.append({"id": "disparo", "tipo": "projetil", "inicio": 0.05, "duracao": 0.2, "habilitado": true, "parametros": {}})
	ed._aplicar_edicao(novo)
	await _quadros(4)
	ed.executar(true)
	await _quadros(28)
	await _foto("3_previa")

	# 2. Os dez em voo.
	var cena := Node3D.new()
	root.add_child(cena)
	current_scene.visible = false
	WorldEnv.apply(cena)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(80, 80)
	chao.mesh = plano
	var mchao := StandardMaterial3D.new()
	mchao.albedo_color = Color(0.36, 0.42, 0.33)
	chao.material_override = mchao
	cena.add_child(chao)
	var voando: Array[Node3D] = []
	var vel := Vector3(0, 0, -9.0)
	var i := 0
	for forma: String in Catalogo.PRONTOS:
		var no := Catalogo.criar(Catalogo.valores_do_pronto(forma), Color("#ff7ad9"))
		cena.add_child(no)
		no.position = Vector3((i - 4.5) * 1.6, 1.4, 2.0)
		voando.append(no)
		var nome := Label3D.new()
		nome.text = forma
		nome.font_size = 40
		nome.pixel_size = 0.004
		nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nome.outline_size = 10
		cena.add_child(nome)
		nome.position = Vector3((i - 4.5) * 1.6, 0.45, -0.6)
		i += 1
	var cam := Camera3D.new()
	cena.add_child(cam)
	cam.position = Vector3(0.0, 3.2, 6.5)
	cam.look_at(Vector3(0, 1.0, -0.8))
	cam.fov = 62.0
	cam.make_current()
	for q in 22:
		for no in voando:
			no.position += vel / 60.0
			Catalogo.animar(no, vel, 1.0 / 60.0)
		await process_frame
	await _foto("2_em_voo")
	print("fotos em ", saida)
	quit(0)


func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _quadros(n: int) -> void:
	for k in n:
		await process_frame
