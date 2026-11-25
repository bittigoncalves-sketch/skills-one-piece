extends SceneTree
## Captura os clipes no rig do Modo História, em quatro direções e três fases.
const SAIDA := "res://art_src/validation/dash_aereo/"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var cena := Node3D.new()
	root.add_child(cena)
	current_scene = cena
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.29, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.9
	ambiente.environment = env
	cena.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, -35, 0)
	cena.add_child(luz)
	var visual: Node3D = preload("res://src/player/corpo_historia.gd").construir("masculino")["node"]
	cena.add_child(visual)
	var anim := ProceduralAnimator.new()
	visual.add_child(anim)
	anim.setup(BodyScanner.scan(visual))
	var camera := Camera3D.new()
	cena.add_child(camera)
	camera.position = Vector3(2.6, 1.5, -3.4)
	camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.current = true
	for nome in ["frente", "tras", "esquerda", "direita"]:
		anim.acao_clipe = DashNoAr.CLIPES[nome]
		for fase in [["preparo", 0.045], ["chute", 0.095], ["recuperacao", 0.17]]:
			anim.acao_tempo = fase[1]
			for i in 8:
				anim.update(Vector3.ZERO, false, false, 1.0 / 60.0, 0.0)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA) + nome + "_" + fase[0] + ".png")
			if fase[0] == "chute":
				var anterior := camera.position
				camera.position = Vector3(4, 1.15, 0)
				camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA) + nome + "_chute_perfil.png")
				camera.position = anterior
				camera.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	print("CAPTURAS_DASH: 12 imagens em ", SAIDA)
	await _capturar_no_jogo()
	quit()

func _capturar_no_jogo() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_dash_codex.json")
	root.get_node("GameFlow").start_story()
	for i in 180: await physics_frame
	var jogador: CharacterBody3D
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			jogador = n
			break
	if jogador == null:
		push_error("Sem jogador para capturar dash no Modo História")
		return
	jogador.capacidades = CapacidadesDoJogador.completas()
	jogador.capacidades.recarga_dash_no_ar = 0.0
	for caso in [["frente", KEY_W], ["tras", KEY_S], ["esquerda", KEY_A], ["direita", KEY_D]]:
		for tecla in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q]: _tecla(tecla, false)
		jogador._dash_ar.cancelar()
		jogador.global_position = Vector3(0, 20, 0)
		jogador.velocity = Vector3.ZERO
		jogador._yaw = 0.0
		jogador._pitch = jogador.PITCH_DE_DESCANSO
		for i in 6: await physics_frame
		_tecla(caso[1], true)
		await physics_frame
		_tecla(KEY_Q, true)
		for i in 5: await physics_frame
		await process_frame
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA) + "jogo_" + caso[0] + ".png")
		_tecla(KEY_Q, false)
		_tecla(caso[1], false)
		for i in 20: await physics_frame
	print("CAPTURAS_DASH_JOGO: 4 imagens em ", SAIDA)

func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)
