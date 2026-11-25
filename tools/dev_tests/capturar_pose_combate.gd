extends SceneTree
# ============================================================================
#  CAPTURAR POSE DO COMBATE DIRECIONAL — fotos para avaliação VISUAL (com tela).
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (§8.3). Números certos não provam que a
#  animação lê bem na tela; isto grava o que o jogador veria. Para cada golpe do
#  estilo, com um boneco à frente, três instantes:
#    carga (fim do preparo) · contato (meio do ativo) · follow-through
#  em duas câmeras: a do JOGO (3ª pessoa, atrás do ombro) e uma LATERAL.
#  Depois, a defesa do JOGADOR: guarda erguida, tranco de um golpe bloqueado e quebra.
#
#  Rodar (precisa de tela; PNGs na pasta passada):
#    DISPLAY=:1 godot --path . --script tools/dev_tests/capturar_pose_combate.gd -- /pasta/de/saida
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://capturar_pose_combate.json"
## Altura do centro do corpo em pé na baseplate do mapa fixo (colisor de 1,6 m).
const CHAO := 0.8


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var saida := args[0] if args.size() > 0 else OS.get_user_data_dir() + "/capturas_combate"
	# O que capturar: "tudo" (padrão), "guarda", "golpes" ou "defesa" — iterar numa pose
	# não precisa refazer as outras.
	var parte := args[1] if args.size() > 1 else "tudo"
	DirAccess.make_dir_recursive_absolute(saida)
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	var jogador: Node = null
	for p in get_root().get_tree().get_nodes_in_group("player"):
		jogador = p
	jogador.capacidades = CapacidadesDoJogador.completas()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.vida_maxima = 100000.0
	# ⚠️ LONGE do jogador ao nascer. Nascendo na origem ele sobrepunha o jogador, a
	# física despenetrava o jogador PARA CIMA da caixa, e cada teletransporte do boneco
	# o carregava junto como plataforma (rastreado em 16/09).
	boneco.position = Vector3(0, CHAO, -4.0)
	current_scene.add_child(boneco)
	await _fisica(10)

	var lateral := Camera3D.new()
	lateral.fov = 50.0
	current_scene.add_child(lateral)
	var e: ExecutorCorpoACorpo = jogador.combate_direcional

	if parte in ["tudo", "guarda"]:
		await _guarda_e_maos(jogador, boneco, lateral, saida)
	for golpe in (e.estilo.golpes if parte in ["tudo", "golpes"] else []):
		# Mesmo enquadramento para todo golpe: jogador na origem olhando −Z, boneco a 1,1 m.
		for i in 150:
			if not e.ocupado():
				break
			await _fisica(1)
		# ⚠️ Os dois corpos NO CHÃO antes de posicionar. Posicionar com o jogador ainda
		# caindo do spawn o deixou em cima da caixa do boneco (visto em 16/09: y 2,40).
		boneco.global_position = Vector3(0, CHAO, -3.0)
		jogador.global_position = Vector3(0, CHAO, 0)
		jogador.velocity = Vector3.ZERO
		boneco.velocity = Vector3.ZERO
		for i in 120:
			await _fisica(1)
			if jogador.is_on_floor() and boneco.is_on_floor():
				break
		jogador.velocity = Vector3.ZERO
		jogador.global_position = Vector3(0, jogador.global_position.y, 0)
		jogador._yaw = 0.0
		jogador._pitch = -0.15
		jogador.modelo_visual().rotation.y = 0.0
		await _fisica(2)   # jogador antes do boneco (ver a nota no test_contato_historia)
		boneco.parar()
		boneco.global_position = Vector3(0, boneco.global_position.y, -1.1)
		boneco.encarar_yaw(PI)
		boneco.modelo_visual().rotation.y = PI
		await _fisica(30)
		print("   %s posicionado: distância %.2f m" % [golpe.id,
			Vector2(boneco.global_position.x - jogador.global_position.x, boneco.global_position.z - jogador.global_position.z).length()])
		var instantes := {
			"1_carga": golpe.preparo * 0.92,
			"2_contato": golpe.preparo + golpe.ativo * 0.5,
			"3_follow": golpe.preparo + golpe.ativo + golpe.recuperacao * 0.3,
		}
		e.pedir_ataque(golpe.direcao)
		for nome in instantes:
			while e.atacando() and e.tempo_da_acao() < instantes[nome]:
				await _fisica(1)
			# Congela o golpe no instante para as duas fotos mostrarem a mesma pose.
			e.pausar(1.0)
			var base: String = "%s/%s_%s" % [saida, golpe.id, nome]
			print("   %s %s: jogador %s  boneco %s  distância %.2f m" % [golpe.id, nome,
				jogador.global_position, boneco.global_position,
				Vector2(boneco.global_position.x - jogador.global_position.x, boneco.global_position.z - jogador.global_position.z).length()])
			await _foto(base + "_jogo.png")
			var centro: Vector3 = jogador.global_position + Vector3(0, 0.3, -0.55)
			lateral.global_position = centro + Vector3(3.2, 0.3, 0)
			lateral.look_at(centro)
			lateral.make_current()
			await _foto(base + "_lateral.png")
			lateral.clear_current(true)
			e.pausar(0.0)
			e._hitstop = 0.0
		print("capturado: ", golpe.id)
	if parte in ["tudo", "defesa"]:
		await _defesa(jogador, boneco, lateral, saida)
	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	print("PNGs em: ", saida)
	quit(0)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _foto(caminho: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(caminho)


## A base (pés, joelhos, quadril) na guarda parada e o punho fechado de perto. A guarda
## aparece no NEUTRO depois de uma ação (`guarda_apos_acao`): um jab no ar e espera.
func _guarda_e_maos(jogador: Node, boneco: Node, lateral: Camera3D, saida: String) -> void:
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	boneco.global_position = Vector3(0, CHAO, -3.0)
	for i in 120:
		await _fisica(1)
		if jogador.is_on_floor():
			break
	jogador.velocity = Vector3.ZERO
	jogador._yaw = 0.0
	jogador._pitch = -0.15
	jogador.modelo_visual().rotation.y = 0.0
	e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	for i in 120:
		await _fisica(1)
		if not e.ocupado():
			break
	await _fisica(40)
	print("   guarda: peso da pose %.2f" % e.peso_da_pose())
	await _duas_fotos(jogador, lateral, saida + "/guarda_base")
	var frente: Vector3 = jogador.global_position + Vector3(0, 0.45, -0.1)
	lateral.global_position = frente + Vector3(0.9, 0.35, -1.9)
	lateral.look_at(frente)
	lateral.make_current()
	await _foto(saida + "/guarda_base_frente34.png")
	for lado in ["R", "L"]:
		var mao := (jogador.modelo_visual().find_child("Hand_" + lado, true, false) as Node3D).global_position
		lateral.fov = 22.0
		lateral.global_position = mao + Vector3(0.35 if lado == "R" else -0.35, 0.12, -0.55)
		lateral.look_at(mao)
		await _foto(saida + "/guarda_mao_%s.png" % lado)
	lateral.fov = 50.0
	lateral.clear_current(true)


func _duas_fotos(jogador: Node, lateral: Camera3D, base: String) -> void:
	await _foto(base + "_jogo.png")
	var centro: Vector3 = jogador.global_position + Vector3(0, 0.3, -0.55)
	lateral.global_position = centro + Vector3(3.2, 0.3, 0)
	lateral.look_at(centro)
	lateral.make_current()
	await _foto(base + "_lateral.png")
	lateral.clear_current(true)


func _defesa(jogador: Node, boneco: Node, lateral: Camera3D, saida: String) -> void:
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	var b: ExecutorCorpoACorpo = boneco.combate_direcional
	for i in 150:
		if not e.ocupado() and not b.ocupado():
			break
		await _fisica(1)
	jogador.velocity = Vector3.ZERO
	jogador.global_position = Vector3(0, jogador.global_position.y, 0)
	jogador._yaw = 0.0
	jogador.modelo_visual().rotation.y = 0.0
	await _fisica(2)
	boneco.parar()
	boneco.global_position = Vector3(0, boneco.global_position.y, -1.1)
	boneco.encarar_yaw(PI)
	boneco.modelo_visual().rotation.y = PI
	e.erguer_guarda()
	await _fisica(30)
	await _duas_fotos(jogador, lateral, saida + "/defesa_1_guarda_erguida")

	var tocou := [false]
	var cb := func(_id, _alvo, _r, _l, _p, _g): tocou[0] = true
	b.contato.connect(cb)
	b.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	for i in 90:
		await _fisica(1)
		if tocou[0]:
			break
	await _fisica(4)
	e.pausar(1.0)
	await _duas_fotos(jogador, lateral, saida + "/defesa_2_tranco_na_guarda")
	e._hitstop = 0.0
	b.contato.disconnect(cb)
	for i in 90:
		if not b.atacando():
			break
		await _fisica(1)

	e.postura = 5.0
	tocou[0] = false
	b.contato.connect(cb)
	b.pedir_ataque(GolpeDirecional.Direcao.PARA_ESQUERDA)
	for i in 90:
		await _fisica(1)
		if tocou[0]:
			break
	await _fisica(20)
	e.pausar(1.0)
	await _duas_fotos(jogador, lateral, saida + "/defesa_3_quebra")
	e._hitstop = 0.0
	b.contato.disconnect(cb)
	e.baixar_guarda()
	print("capturado: defesa (estado final do jogador: %s)" % ExecutorCorpoACorpo.Estado.keys()[e.estado])

	# Aparo: o boneco soca, o jogador aperta a guarda 0,10 s antes do contato.
	for i in 150:
		if e.estado == ExecutorCorpoACorpo.Estado.NEUTRO and not b.ocupado():
			break
		await _fisica(1)
	await _fisica(45)
	e.postura = e.estilo.postura_maxima
	var jab := b.estilo.golpe_para(GolpeDirecional.Direcao.FRENTE)
	b.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	for i in 60:
		if b.tempo_da_acao() >= jab.preparo - 0.10:
			break
		await _fisica(1)
	e.erguer_guarda()
	for i in 60:
		await _fisica(1)
		if b.estado == ExecutorCorpoACorpo.Estado.REBATIDO:
			break
	await _fisica(4)
	e.pausar(1.0)
	b.pausar(1.0)
	await _duas_fotos(jogador, lateral, saida + "/defesa_4_aparo_e_rebote")
	e._hitstop = 0.0
	b._hitstop = 0.0
	e.baixar_guarda()
	print("capturado: aparo (boneco em %s)" % ExecutorCorpoACorpo.Estado.keys()[b.estado])
