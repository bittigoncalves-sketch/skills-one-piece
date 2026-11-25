extends SceneTree
# ============================================================================
#  CAPTURA DA ÁGUA — nado, mergulho, fundo do mar (01/10/2026, docs/AGUA_PLANO.md).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_agua.gd -- [--saida res://art_src/validation/agua]
#
#  Modo História de verdade (progresso de teste em user://): a costa com o fundo do mar,
#  o personagem nadando (crawl e boiando), mergulhado (tinta submersa), a vaca nadando e
#  o usuário de fruta andando no fundo. Só LÊ o mapa.
# ============================================================================

const PROGRESSO := "user://captura_agua_progresso.json"
var saida := "res://art_src/validation/agua"
var _camera: Camera3D


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.find("--saida") >= 0:
		saida = args[args.find("--saida") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = Vector2i(1280, 720)
	var modo_script: Script = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo_script.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 160:
		await process_frame
	var modo := current_scene
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	_camera = Camera3D.new()
	_camera.far = 3000.0
	modo.add_child(_camera)
	_camera.make_current()
	var nivel := AguaDoMundo.nivel_em(300.0, 0.0)

	await _foto("01_costa_e_fundo", Vector3(300, 25, 70), Vector3(262, -4, 0))
	# Boiando parado.
	jogador.global_position = Vector3(300.0, nivel - 0.3, 0.0)
	jogador.velocity = Vector3.ZERO
	for i in 120:
		await physics_frame
	var j := jogador.global_position
	await _foto("02_boiando", j + Vector3(2.6, 0.9, 2.6), j + Vector3(0, -0.2, 0))
	# Nadando (W segurado).
	_tecla(KEY_W, true)
	for i in 60:
		await physics_frame
	j = jogador.global_position
	var frente := -(jogador.get("_char_model") as Node3D).global_transform.basis.z.normalized() if jogador.get("_char_model") else Vector3.FORWARD
	var lado := frente.cross(Vector3.UP).normalized()
	await _foto("03_nadando_lado", j + lado * 3.2 + Vector3(0, 0.8, 0), j + Vector3(0, -0.2, 0))
	_tecla(KEY_W, false)
	# Mergulhado: câmera embaixo d'água olhando o personagem e o fundo.
	_tecla(KEY_CTRL, true)
	for i in 120:
		await physics_frame
	_tecla(KEY_CTRL, false)
	j = jogador.global_position
	await _foto("04_mergulhando", j + Vector3(3.0, 0.3, 3.0), j)
	# Vaca nadando ao lado.
	var pop: PopulacaoDeAnimais = modo.get_node("Animais")
	var vaca: AnimalDaIlha = null
	for a in pop.animais:
		if a.especie == "cow" and a.vivo():
			vaca = a
	jogador.global_position = Vector3(300.0, nivel - 0.3, 0.0)
	vaca.global_position = Vector3(303.0, nivel - 0.5, 0.0)
	vaca.set_physics_process(true)
	vaca.estado = AnimalDaIlha.Estado.PASSEANDO
	vaca.set("_destino", Vector3(303.0, 0.0, -12.0))
	vaca.set("_relogio", 30.0)
	pop.atualizar_detalhe()
	for i in 90:
		await physics_frame
	var v := vaca.global_position
	await _foto("05_vaca_nadando", v + Vector3(4.0, 1.5, 3.0), v)
	# Usuário de fruta no fundo.
	modo.call("dar_fruta", "rocket")
	jogador.global_position = Vector3(300.0, nivel - 0.2, 6.0)
	jogador.velocity = Vector3.ZERO
	for i in 360:
		await physics_frame
	j = jogador.global_position
	await _foto("06_fruta_no_fundo", j + Vector3(3.0, 1.0, 3.0), j)
	modo.call("tirar_fruta")
	modo_script.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("CAPTURA_AGUA fotos em %s" % saida)
	quit()


func _foto(nome: String, de: Vector3, para: Vector3) -> void:
	_camera.global_position = de
	_camera.look_at(para)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(nome + ".png")))
	print("FOTO ", nome)


func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)
