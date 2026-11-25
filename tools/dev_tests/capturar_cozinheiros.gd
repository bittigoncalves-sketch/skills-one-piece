extends SceneTree
## Prévia na engine, sem Player/captura de mouse. -- cidade usa o mapa real (somente leitura).
const APRESENTACAO = preload("res://src/historia/npcs/exposicao_cozinheiros.gd")
const SAIDA := "res://art_src/validation/cozinheiros/"

func _initialize() -> void:
	_executar.call_deferred()

func _executar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var cidade := OS.get_cmdline_user_args().has("cidade")
	var mapa := {"pecas": []}
	var bib := BibliotecaDeModelos.padrao()
	var raiz: Node3D
	var foco := Vector3(0, 1.1, 0)
	if cidade:
		var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
		mapa = lido["mapa"]
		# Recorte espacial do mapa real para avaliar terreno/obstáculos locais.
		mapa["pecas"] = mapa["pecas"].filter(func(p: Dictionary):
			var pos: Vector3 = p["posicao"]
			return Vector2(pos.x - 154, pos.z - 26).length() < (65.0 if p["tipo"] == "terreno" else 27.0))
		raiz = MapaMontador.montar(mundo, mapa)
		# PopulacaoDeAnimais oculta estes volumes no jogo; aqui não criamos a fauna.
		for p: Dictionary in mapa["pecas"]:
			if p["tipo"] == "area_animais":
				(raiz.get_node(NodePath(str(p["id"]))) as Node3D).visible = false
		foco = Vector3(154.2, 4.05, 26.5)
	else:
		raiz = Node3D.new()
		mundo.add_child(raiz)
		var i := 0
		for id: String in APRESENTACAO.NOMES:
			var tam := bib.tamanho_padrao(id)
			var p := {"id": id, "modelo": id, "tipo": "modelo", "tamanho": tam,
				"posicao": Vector3((i-2)*1.65, tam.y/2, 0), "rotacao_graus": Vector3.ZERO}
			mapa["pecas"].append(p)
			var peca := Node3D.new()
			peca.name = id
			peca.position = p["posicao"]
			raiz.add_child(peca)
			bib.aplicar_em(peca, p)
			i += 1
		var piso := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(200, 200)
		piso.mesh = plano
		mundo.add_child(piso)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.23, 0.28)
		piso.material_override = mat
	var npcs := NpcsDaIlha.new()
	mundo.add_child(npcs)
	npcs.ligar_no_mapa(raiz, mapa, bib)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.20, 0.25, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.90, 1)
	env.environment.ambient_light_energy = 0.65
	mundo.add_child(env)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, -25, 0)
	luz.light_energy = 1.15
	luz.shadow_enabled = true
	mundo.add_child(luz)
	if cidade:
		mundo.remove_child(env)
		env.free()
		mundo.remove_child(luz)
		luz.free()
		WorldEnv.apply(mundo)
	else:
		Contorno.criar(mundo)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.position = foco + Vector3(-0.4, 1.3, -9.2)
	cam.look_at(foco)
	# O contorno do jogo usa profundidade de câmera perspectiva.
	cam.fov = 36.0 if cidade else 29.0
	for clipe in ["descanso", "saudacao", "cozinhar", "caminhada"]:
		for peca in get_nodes_in_group("cozinheiros_exposicao"):
			var c: Node = peca.get_node("ApresentacaoCozinheiro")
			c.set_process(false)
			c.mostrar(clipe)
			c.animador.play(clipe, 0.0)
			c.animador.seek(1.5 if clipe != "caminhada" else 0.3, true)
			c.animador.advance(0.0)
			c.animador.pause()
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(SAIDA + ("cidade_" if cidade else "grupo_") + clipe + ".png")
	var sanji := raiz.get_node("cidade_cozinheiro_sanji" if cidade else "cozinheiro_sanji") as Node3D
	var alvo := sanji.global_position
	cam.fov = 32.0
	cam.position = alvo + Vector3(0.9, 0.35, -4.5)
	cam.look_at(alvo)
	for clipe in ["descanso", "cozinhar"]:
		var c: Node = sanji.get_node("ApresentacaoCozinheiro")
		c.mostrar(clipe)
		c.animador.play(clipe, 0.0)
		c.animador.seek(0.8, true)
		c.animador.advance(0.0)
		c.animador.pause()
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(SAIDA + ("cidade_" if cidade else "") + "sanji_" + clipe + ".png")
	quit()
