extends SceneTree
## Abre a arena real com a Goro Goro equipada. -- --capture salva a revisão da
## FASE 1 (arte e identidade): o modelo autoral no mundo e os ícones no HUD.
## Nenhum ajuste de dano, recarga ou render do jogo é aplicado na versão jogável.
##
## Os golpes (Sango/El Thor/Shunshin/Mamaragan) NÃO são disparados aqui: esta
## fase entregou arte, não coreografia. Ver docs/frutas/goro_goro.md.

const OUTPUT := "res://multimodal/cache/goro-validation/captures"
var _actor: Node3D
var _camera: Camera3D
var _fruta: Node3D

func _init() -> void:
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for node in get_nodes_in_group("player"):
			if node.is_multiplayer_authority():
				_actor = node
		if is_instance_valid(_actor) and _actor.get("_proc_anim") != null:
			break
	if not is_instance_valid(_actor):
		push_error("Goro: a arena não criou o jogador.")
		quit(1)
		return
	await create_timer(0.7).timeout
	_actor.equip_fruit("goro_goro")
	_actor.combat_mode = "fruit"
	var hud := get_first_node_in_group("hud")
	if hud:
		hud.update_combat_mode("fruit", _actor.estilo_atual(), "goro_goro")
	print("GORO GORO — Z Sango | X El Thor | C Shunshin | V Mamaragan")
	if not "--capture" in OS.get_cmdline_user_args():
		return
	create_timer(40.0).timeout.connect(func():
		push_error("Captura Goro excedeu 40 segundos.")
		quit(2))
	await _capture_sequence()

func _capture_sequence() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await create_timer(1.0).timeout
	var scoreboard := get_first_node_in_group("scoreboard")
	if scoreboard:
		scoreboard.time_left = 300.0
	_actor.velocity = Vector3.ZERO
	var start: Vector3 = _actor.global_position

	# A fruta coletável, montada pelo mesmo caminho do mundo: se a tabela
	# PICKUPS_AUTORAIS não reconhecer a Goro, o que nasce aqui é o corpo voxel
	# genérico — e a captura denuncia na hora.
	_fruta = TreeAndFruitGenerator.create_fruit_3d({"id": "goro_goro"})
	current_scene.add_child(_fruta)
	_fruta.global_position = start + Vector3.FORWARD * 3.0 + Vector3.UP * 1.2
	# Sem colisor ativo a fruta não é coletada no meio da revisão.
	var area := _fruta.get_node_or_null("PickupArea")
	if area:
		area.monitoring = false

	_camera = Camera3D.new()
	_camera.name = "CameraRevisaoGoro"
	_camera.fov = 46.0
	current_scene.add_child(_camera)
	_camera.make_current()

	var alvo: Vector3 = _fruta.global_position
	_view(alvo + Vector3(0.0, 0.35, 2.0), alvo)
	await _save("00_fruta_frente.png")
	_view(alvo + Vector3(1.7, 0.5, 1.2), alvo)
	await _save("01_fruta_tres_quartos.png")
	_view(alvo + Vector3(0.0, 2.0, 0.9), alvo)
	await _save("02_fruta_de_cima.png")
	# Uma volta completa registra que o relevo existe em toda a superfície,
	# não só na face que ficou virada para a câmera do primeiro quadro.
	_view(alvo + Vector3(-1.9, 0.3, -1.1), alvo)
	await _save("03_fruta_costas.png")

	# O HUD: os quatro ícones autorais nos slots, com a Goro equipada.
	_camera.queue_free()
	var cam_jogador := _actor.get("_cam") as Camera3D
	if cam_jogador:
		cam_jogador.make_current()
	await create_timer(0.4).timeout
	await _save("04_hud_icones.png")

	if is_instance_valid(_fruta):
		_fruta.queue_free()
	await _capturar_v(start)
	await _capturar_poses(start)
	print("Goro: capturas do jogo salvas em ", OUTPUT)
	quit(0)

## A COREOGRAFIA (fase 4). Câmera de perto e de lado, porque o que se julga aqui
## é o CORPO — braço, tronco, apoio — e não o efeito na tela.
func _capturar_poses(start: Vector3) -> void:
	_camera = Camera3D.new()
	_camera.name = "CameraPosesGoro"
	_camera.fov = 40.0
	current_scene.add_child(_camera)
	_camera.make_current()

	# ⚠️ ESPERAR O CORPO ASSENTAR ANTES DE FOTOGRAFAR POSE. A primeira versão
	# disparava logo depois da detonação do V e pegou o boneco ainda tombado pelo
	# knockdown — a captura mostrava a recuperação de dano, não a coreografia.
	_actor.global_position = start
	_actor.velocity = Vector3.ZERO
	if _actor.has_method("heal"):
		_actor.heal(_actor.max_health)
	_actor.set_meta("custom_pose", "")
	await create_timer(2.5).timeout

	# ⚠️ O INSTANTE DE CADA CAPTURA É ESCOLHIDO, não arbitrário. No Sango o feixe
	# é tão intenso no quadro do disparo (0,22 s) que APAGA o corpo na imagem —
	# só as pernas sobram. Aos 0,40 s o efeito já saiu de cena e a pose ainda está
	# em `SANGO_HOLD`, que é o que se quer julgar aqui.
	for caso in [["Z", "11_pose_sango", 0.40], ["X", "12_pose_el_thor", 0.50],
				 ["C", "13_pose_shunshin", 0.16]]:
		var slot: String = caso[0]
		_actor.global_position = start
		_actor.velocity = Vector3.ZERO
		_actor._skill_cooldowns[slot] = 0.0
		_actor.energy = _actor.max_energy
		await physics_frame
		await physics_frame
		_actor._do_server_cast(slot, Vector3.FORWARD,
			_actor.global_position + Vector3.UP, 0.0, 9100 + slot.hash() % 100,
			"fruit", "goro_goro")
		await create_timer(float(caso[2])).timeout
		# A câmera é posicionada DEPOIS do cast: o C teleporta o corpo 12 m, e
		# enquadrar antes deixaria o jogador fora do quadro justamente nele.
		# O foco fica ABAIXO do `global_position`: o pivô do CharacterBody3D está na
		# cintura, e mirar nele joga o boneco para a beirada de baixo do quadro.
		var foco: Vector3 = _actor.global_position + Vector3.UP * 0.15
		_view(foco + Vector3(3.2, 1.1, 3.2), foco)
		await _save(str(caso[1]) + ".png")
		await create_timer(2.4).timeout

## O V REMODELADO (2026-09-12): a tempestade se junta sobre o ponto de mira, a
## bola cresce lá em cima e CAI. Passa pelo caminho real do jogador
## (`begin_charge` / `release_charge`), não por um atalho: é a carga de verdade
## que desenha as nuvens, e o que não passar por ela não é o que o jogador vê.
func _capturar_v(start: Vector3) -> void:
	_camera = Camera3D.new()
	_camera.name = "CameraRevisaoGoroV"
	_camera.fov = 62.0
	current_scene.add_child(_camera)
	_camera.make_current()

	_actor.global_position = start
	_actor.velocity = Vector3.ZERO
	_actor._skill_cooldowns["V"] = 0.0
	_actor.energy = _actor.max_energy
	await physics_frame

	# De lado, para a ALTURA aparecer: o golpe agora se lê no eixo vertical.
	var lateral := start + Vector3(16.0, 7.0, 10.0)
	_view(lateral, start + Vector3.FORWARD * 12.0 + Vector3.UP * 5.0)

	_actor.begin_charge("V")
	await create_timer(0.55).timeout
	await _save("05_v_nuvens_sobre_o_alvo.png")
	await create_timer(1.15).timeout
	await _save("06_v_bola_crescendo.png")
	await create_timer(1.30).timeout
	await _save("07_v_carga_cheia.png")

	_actor.release_charge("V")
	await create_timer(0.18).timeout
	await _save("08_v_queda.png")
	await create_timer(0.34).timeout
	await _save("09_v_impacto.png")
	await create_timer(0.9).timeout
	await _save("10_v_depois.png")

func _view(position_value: Vector3, focus: Vector3) -> void:
	_camera.global_position = position_value
	_camera.look_at(focus)

func _save(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var snapshot := root.get_texture().get_image()
	var result := snapshot.save_png(OUTPUT.path_join(file))
	print("GORO CAPTURE ", file, " result=", result)
