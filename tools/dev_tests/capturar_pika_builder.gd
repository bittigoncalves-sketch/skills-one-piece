extends SceneTree
# ============================================================================
#  PIKA REFEITA NO BUILDER — fotos com GPU (06/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_pika_builder.gd -- <pasta>
#
#  Câmera do JOGO e uma lateral, nos instantes que contam:
#    z_raio          o feixe único saindo da mão até o boneco
#    x_1_sobe        o corpo virando luz depois do teleporte para o alto
#    x_2_ziguezague  o cometa no meio do zigue-zague
#    x_3_esfera      a esfera de luz caindo
#    x_4_explosao    a explosão no chão
#    c_barragem      a barragem do C travada no boneco
#  RODADA 2 (07/10/2026): z_estrela (segurando: a estrela de quatro pontas na mão),
#  z_raio (o raio saindo DA MÃO), x_inimigo (o X terminando em cima do boneco perto do
#  caminho, a esfera caindo), c_chuva (a chuva de bolinhas na área mirada). Imprime o
#  FPS nos instantes de cada foto (custo de GPU).
#  Mapa e progresso de TESTE; a Pika é a publicada no projeto.
# ============================================================================

const MAPA := "user://capturar_pika_builder_mapa.json"
const PROGRESSO := "user://capturar_pika_builder.json"

var saida := ""
var p: Node3D
var lateral: Camera3D
var cam_jogo: Camera3D


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	root.size = Vector2i(1600, 900)
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _quadros(150)
	p = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _quadros(30)
	cam_jogo = p.get("_cam")
	lateral = Camera3D.new()
	current_scene.add_child(lateral)
	lateral.fov = 60.0

	# Z: segura (a estrela cresce na mão) e solta (o raio sai da mão)
	var alvo := _boneco(Vector3(0.0, 1.0, -16.0))
	await _lugar(Vector3(0, 0.8, 0))
	await _mirar_em(alvo.global_position + Vector3.UP * 0.4)
	_olhar(Vector3(2.2, 1.9, -2.4), Vector3(0.3, 1.35, -0.4))
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge("Z")
	await _quadros(100)
	await _duas("z_estrela")
	_olhar(Vector3(9.0, 2.6, -6.0), Vector3(0.0, 1.3, -8.0))
	p.release_charge("Z")
	await _quadros(5)
	await _duas("z_raio")
	alvo.queue_free()
	await _quadros(60)

	# X (o fim do zigue-zague em (−5, −21))
	var fim := _boneco(Vector3(-5.0, 1.0, -21.0))
	await _lugar(Vector3(0, 0.8, 0))
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.1)
	p.call("_update_pivot")
	await _quadros(10)
	_olhar(Vector3(16.0, 6.0, -8.0), Vector3(0.0, 4.5, -11.0))
	_tecla("X")
	await _quadros(10)
	await _duas("x_1_sobe")
	await _quadros(14)
	await _duas("x_2_ziguezague")
	await _quadros(19)
	_olhar(Vector3(10.0, 5.0, -10.0), Vector3(-5.0, 2.5, -21.0))
	await _duas("x_3_esfera")
	await _quadros(8)
	await _duas("x_4_explosao")
	fim.queue_free()
	await _quadros(90)

	# X com um boneco perto do caminho: termina em cima dele
	var perto := _boneco(Vector3(4.0, 1.0, -10.0))
	await _lugar(Vector3(0, 0.8, 0))
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.1)
	p.call("_update_pivot")
	await _quadros(10)
	_tecla("X")
	await _quadros(42)
	_olhar(Vector3(14.0, 6.0, -2.0), Vector3(4.0, 3.0, -10.0))
	await _duas("x_inimigo")
	perto.queue_free()
	await _quadros(90)

	# C: chuva na área mirada (chão a 16 m)
	var c_alvo := _boneco(Vector3(1.0, 1.0, -16.0))
	await _lugar(Vector3(0, 0.8, 0))
	await _mirar_em(Vector3(0.0, 0.0, -16.0))
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["C"] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge("C")
	await _quadros(75)
	_olhar(Vector3(18.0, 10.0, 0.0), Vector3(0.0, 1.5, -15.0))
	await _duas("c_chuva")
	p.release_charge("C")
	c_alvo.queue_free()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("fotos em ", saida)
	quit(0)


func _tecla(slot: String) -> void:
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
	p.begin_charge(slot)
	p.release_charge(slot)


func _olhar(de: Vector3, para: Vector3) -> void:
	lateral.global_position = de
	lateral.look_at(para)


func _duas(nome: String) -> void:
	await _foto(cam_jogo, nome + "_jogo")
	await _foto(lateral, nome + "_lado")


func _foto(cam: Camera3D, nome: String) -> void:
	cam.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))
	print("   foto %-22s FPS %.0f | quadro %.2f ms" % [nome, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])


func _mirar_em(ponto: Vector3) -> void:
	for i in 30:
		var d := (ponto - cam_jogo.global_position).normalized()
		p.set("_yaw", atan2(-d.x, -d.z))
		p.set("_pitch", asin(clampf(d.y, -1.0, 1.0)))
		p.call("_update_pivot")
		await process_frame


func _boneco(pos: Vector3) -> Node3D:
	var b := BonecoDeDuelo.new()
	b.position = pos
	current_scene.add_child(b)
	return b


func _lugar(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _quadros(20)
	for b in get_nodes_in_group("enemy"):
		if b is BonecoDeDuelo:
			b.call("parar")


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
