extends SceneTree
## Captura a Harpia do mapa real com progresso descartável; não edita o mapa.
var _saida := "res://art_src/validation/harpia_anime_2026-10-05/historia"
var _modo: GDScript
var _j: CharacterBody3D
var _boss: AnimalDaIlha
var _cam: Camera3D

func _init() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	seed(20261005)
	root.size = Vector2i(1280, 720)
	var ensaio := OS.get_environment("HARPIA_ENSAIO") == "1"
	if ensaio:
		_saida = _saida.get_base_dir().path_join("ensaio")
	DirAccess.make_dir_recursive_absolute(_saida)
	_modo = load("res://src/historia/ModoHistoria.gd")
	if ensaio:
		_modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	_modo.progresso_forcado = "user://harpia_captura_visual_descartavel.json"
	root.get_node("GameFlow").start_story()
	for i in 120: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_j = current_scene.jogador_local()
	if ensaio:
		var bib := MapaMontador.biblioteca_em_uso()
		var id := "harpia_-_animated_low_poly"
		_boss = load("res://src/historia/bosses/harpia/harpia_da_ilha.gd").new()
		_boss.montar(bib, id, bib.ficha_de_animal(id), {"id": "harpia_captura", "centro": Vector3.ZERO, "meio": Vector3(70, 40, 70), "base": Basis.IDENTITY})
		# Inserir já na posição de voo evita nascer sobre o jogador e fazer
		# a física tratá-lo como passageiro de uma plataforma teletransportada.
		_boss.position = Vector3(0, 6, -14)
		_boss.ponto_de_origem = _boss.position
		current_scene.add_child(_boss)
	for a: AnimalDaIlha in current_scene._animais.animais:
		if a.get("combate") != null:
			_boss = a
			break
	assert(_boss != null, "mapa real precisa conter Harpia")
	var centro := Vector3(0, 1, 0) if ensaio else _chao_livre()
	_j.global_position = centro
	_j.velocity = Vector3.ZERO
	_j.set_meta("damage_immune", true)
	var c: Node = _boss.get("combate")
	c.cancelar()
	c._intervalo = 999.0
	_boss.global_position = centro + Vector3(0, 5, -14)
	_boss.velocity = Vector3.ZERO
	_boss.visible = true
	_boss.set_physics_process(true)
	# Câmera normal do protagonista, com distância/rig de produção.
	_j._yaw = 0.0
	_j._pitch = -0.15
	_j._update_pivot()
	assert(c.iniciar_investida(_j))
	await _esperar(c, "preparar_investida", .4)
	await _foto("01_preparacao_camera_jogador")
	_cam = Camera3D.new()
	current_scene.add_child(_cam)
	_cam.fov = 58
	_cam.make_current()
	_enquadrar(centro + Vector3(0, 3, -6))
	await _esperar(c, "investida", .1)
	await _foto("02_investida")
	await _esperar(c, "recuperar", .30)
	await _foto("03_abertura_asas")
	c.cancelar()
	c._intervalo = 999
	_boss.global_position = centro + Vector3(0, 5, -14)
	_boss.velocity = Vector3.ZERO
	for i in 3: await physics_frame
	_j.global_position = centro
	_j.velocity = Vector3.ZERO
	assert(c.iniciar_vendaval(_j))
	await _esperar(c, "preparar_vendaval", .8)
	await _foto("04_preparo_vendaval")
	await _esperar(c, "vendaval", .18)
	_enquadrar(c.tornado.global_position + Vector3.UP * 3.0)
	await _foto("05_batida_e_tornado")
	await _esperar(c, "vendaval", 1.5)
	_enquadrar(c.tornado.global_position + Vector3.UP * 3.0)
	await _foto("06_tornado_ativo")
	await _esperar(c, "vendaval", 4.8)
	_enquadrar(c.tornado.global_position + Vector3.UP * 3.0)
	await _foto("07_dissipacao")
	c.cancelar()
	print("HARPIA_HISTORIA_CAPTURADA ", _saida)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_modo.progresso_forcado))
	_modo.progresso_forcado = ""
	_modo.mapa_forcado = ""
	quit()

func _chao_livre() -> Vector3:
	var espaco := _boss.get_world_3d().direct_space_state
	var origem := _boss.ponto_de_origem
	var forma := BoxShape3D.new()
	forma.size = Vector3(4, 6, 18)
	var melhor := origem
	var obstaculos := 1000
	for x in [-16, 0, 16, -28, 28]:
		for z in [16, 0, -16, 28, -28]:
			var p := origem + Vector3(x, 0, z)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 80, p + Vector3.DOWN * 120, 1)
			q.exclude = [_j.get_rid(), _boss.get_rid()]
			var h := espaco.intersect_ray(q)
			if h.is_empty() or not str(h.collider.get_meta("peca_id", "")).begins_with("relevo_"):
				continue
			var volume := PhysicsShapeQueryParameters3D.new()
			volume.shape = forma
			volume.collision_mask = 1
			volume.exclude = q.exclude
			volume.exclude = [q.exclude[0], q.exclude[1], h.collider.get_rid()]
			volume.transform.origin = h.position + Vector3(0, 3.3, -6)
			var total := espaco.intersect_shape(volume, 32).size()
			if total < obstaculos:
				obstaculos = total
				melhor = h.position + Vector3.UP
			if total == 0:
				print("HARPIA_CAPTURA_CHAO ", h.position)
				return h.position + Vector3.UP
	print("HARPIA_CAPTURA_CHAO ", melhor, " obstáculos próximos=", obstaculos)
	return melhor

func _enquadrar(foco: Vector3) -> void:
	var espaco := _boss.get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3(-13, 7, 10), Vector3(13, 7, 10), Vector3(0, 14, 12), Vector3(-13, 12, -8)]:
		var q := PhysicsRayQueryParameters3D.create(foco, foco + offset, 1)
		q.exclude = [_j.get_rid(), _boss.get_rid()]
		if espaco.intersect_ray(q).is_empty():
			_cam.global_position = foco + offset
			_cam.look_at(foco)
			return
	_cam.global_position = foco + Vector3.UP * 18 + Vector3.BACK * .1
	_cam.look_at(foco)

func _esperar(c: Node, fase: String, t: float) -> void:
	var anterior := ""
	for i in 500:
		if str(c.fase) != anterior:
			anterior = str(c.fase)
			print("FASE ", c.fase, " tempo=", c.tempo_fase, " boss=", _boss.global_position, " jogador=", _j.global_position)
		if c.fase == fase and c.tempo_fase >= t:
			return
		await physics_frame
	push_error("fase não alcançada: " + fase)
	quit(1)

func _foto(nome: String) -> void:
	# A leitura de GPU pode ser lenta na primeira compilação de shaders.
	# Congela a simulação para não perder a fase curta enquanto salva o PNG.
	paused = true
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_saida.path_join(nome + ".png"))
	paused = false
