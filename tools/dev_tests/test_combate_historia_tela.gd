extends SceneTree
# ============================================================================
#  COMBATE DIRECIONAL NO MODO HISTÓRIA — o que só se prova COM TELA.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 2. Headless não captura o mouse
#  (medido em 16/09/2026, item 64 da lista), e sem captura o clique cai no ramo de
#  recaptura do Player antes do combate. Aqui o mouse é capturado de verdade, o
#  movimento entra pelo pipeline de input (`Input.parse_input_event`, o mesmo que a
#  câmera recebe) e o clique vai ao Player.
#
#  Prova: as quatro direções saem do gesto do mouse; parado sai a frente; com a
#  janela de status aberta o clique não ataca; segurar o botão direito ergue a
#  guarda, soltar baixa, e abrir a janela segurando NÃO deixa a guarda presa. Cada
#  caso começa do neutro e com o gesto anterior já vencido.
#
#  Rodar (precisa de tela):
#    DISPLAY=:1 godot --path . --script tools/dev_tests/test_combate_historia_tela.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_combate_historia_tela_progresso.json"
const D := GolpeDirecional.Direcao

var _modo_historia: GDScript
var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== COMBATE DIRECIONAL — COM TELA =====")
	_modo_historia = load("res://src/historia/ModoHistoria.gd")
	_modo_historia.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	_modo_historia.set("progresso_forcado", PROGRESSO)

	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame

	var jogador := _jogador_local()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	var capturou := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_ok(jogador != null and capturou,
		"jogador montado e mouse capturado (sem tela este teste não mede nada)")
	if jogador != null and capturou:
		jogador.capacidades = CapacidadesDoJogador.completas()
		await _sequencia(jogador)
		await _direcoes(jogador)
		await _status_aberto(jogador)
		await _guarda_pelo_botao(jogador)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_modo_historia.set("mapa_forcado", "")
	_modo_historia.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _jogador_local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


## Espera o neutro e deixa o gesto anterior vencer a janela de leitura.
func _preparar(jogador: Node) -> void:
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	for i in 180:
		if not e.ocupado():
			break
		await physics_frame
	await _quadros(int(ceil(jogador.entrada_combate_direcional.janela * 60.0)) + 6)


func _gesto(px: Vector2, quadros: int) -> void:
	for i in quadros:
		var m := InputEventMouseMotion.new()
		m.relative = px
		Input.parse_input_event(m)
		await process_frame


func _clique(jogador: Node) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	jogador._unhandled_input(ev)


func _direcoes(jogador: Node) -> void:
	print("\n-- 1. o gesto do mouse escolhe o golpe --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	# 3 quadros de 20 px = 60 px ≈ 0,21 rad, bem acima da zona morta (0,035).
	var casos := [
		[Vector2(-20, 0), D.PARA_ESQUERDA, "mouse para a esquerda"],
		[Vector2(20, 0), D.PARA_DIREITA, "mouse para a direita"],
		[Vector2(0, -20), D.DE_CIMA, "mouse para cima"],
		[Vector2.ZERO, D.FRENTE, "mouse parado"],
	]
	for c in casos:
		await _preparar(jogador)
		var yaw_antes: float = jogador._yaw
		if c[0] != Vector2.ZERO:
			await _gesto(c[0], 3)
		_clique(jogador)
		var obtido := e.golpe_atual.direcao if e.golpe_atual != null else -1
		_ok(obtido == c[1], "%s → %s (obteve %s, golpe %s)"
			% [c[2], D.keys()[c[1]], D.keys()[obtido] if obtido >= 0 else "nenhum",
			e.golpe_atual.id if e.golpe_atual else "-"])
		# Coerência com a câmera: o mesmo gesto que escolheu "para a esquerda" girou a
		# mira para a esquerda (yaw cresce). Se um dos dois estivesse invertido, o
		# jogador veria o golpe ir para um lado e a câmera para o outro.
		if c[1] == D.PARA_ESQUERDA:
			_ok(jogador._yaw > yaw_antes, "o mesmo gesto girou a câmera para a esquerda (yaw %.3f → %.3f)" % [yaw_antes, jogador._yaw])
		elif c[1] == D.PARA_DIREITA:
			_ok(jogador._yaw < yaw_antes, "o mesmo gesto girou a câmera para a direita (yaw %.3f → %.3f)" % [yaw_antes, jogador._yaw])


func _status_aberto(jogador: Node) -> void:
	print("\n-- 2. janela de status (M) aberta --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	await _preparar(jogador)
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	hud.alternar_status()
	await _quadros(2)
	_clique(jogador)
	_ok(hud.is_menu_open() and not e.ocupado(), "com a janela de status aberta o clique não ataca")
	hud.alternar_status()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _quadros(2)
	_clique(jogador)
	_ok(e.ocupado(), "controle: janela fechada e mouse capturado, o mesmo clique ataca")
	await _preparar(jogador)


func _rmb(apertado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = apertado
	Input.parse_input_event(ev)


func _guarda_pelo_botao(jogador: Node) -> void:
	print("\n-- 3. botão direito: guarda --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	await _preparar(jogador)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_rmb(true)
	await _quadros(4)
	_ok(e.em_guarda(), "segurar o botão direito ergue a guarda (%s)" % ExecutorCorpoACorpo.Estado.keys()[e.estado])
	_rmb(false)
	await _quadros(2)
	_ok(e.estado == ExecutorCorpoACorpo.Estado.BAIXANDO or e.estado == ExecutorCorpoACorpo.Estado.NEUTRO,
		"soltar baixa a guarda (%s)" % ExecutorCorpoACorpo.Estado.keys()[e.estado])
	await _quadros(30)

	# Segurando, abre a janela de status (o mouse fica solto e a UI pode engolir o
	# soltar). A guarda precisa cair — lida pelo estado do botão, não pelo evento.
	_rmb(true)
	await _quadros(4)
	_ok(e.em_guarda(), "(preparação) guarda erguida de novo")
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	hud.alternar_status()
	await _quadros(4)
	_ok(not e.em_guarda(), "com a janela aberta a guarda cai mesmo com o botão ainda segurado (%s)"
		% ExecutorCorpoACorpo.Estado.keys()[e.estado])
	_rmb(false)
	hud.alternar_status()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _quadros(30)
	_ok(not e.guarda_pedida(), "fechada a janela, sem botão, a guarda não volta sozinha")


func _sequencia(jogador: Node) -> void:
	print("\n-- sequência de socos pelo clique no Player --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	var entrada: EntradaCorpoACorpo = jogador.entrada_combate_direcional
	var inicios: Array[StringName] = []
	var gravar := func(g, _id): inicios.append(g.id)
	e.golpe_iniciado.connect(gravar)
	var esperados := [&"boxe_jab", &"boxe_hook_direita", &"boxe_hook_esquerda", &"boxe_overhand"]
	var detalhe := SubViewport.new()
	detalhe.size = Vector2i(800, 800)
	detalhe.world_3d = get_root().world_3d
	detalhe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(detalhe)
	var camera := Camera3D.new()
	detalhe.add_child(camera)
	camera.current = true
	camera.fov = 42
	var pasta := "res://art_src/validation/sequencia_socos_2026-10-07"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	for esperado in esperados:
		await _preparar(jogador)
		entrada.esquecer_gesto()
		_clique(jogador)
		_ok(e.golpe_atual != null and e.golpe_atual.id == esperado,
			"clique sem gesto → %s (obteve %s)" % [esperado, e.golpe_atual.id if e.golpe_atual else &"nenhum"])
		if e.golpe_atual != null:
			var centro: Vector3 = jogador.global_position + Vector3.UP
			var base: Basis = jogador._char_model.global_basis.orthonormalized()
			camera.global_position = centro + base * Vector3(3, 1.0, -3.8)
			camera.look_at(centro)
			var momento := e.golpe_atual.preparo + e.golpe_atual.ativo * .5
			for i in 180:
				await process_frame
				if e.tempo_da_acao() >= momento:
					break
			_ok(e.estado == ExecutorCorpoACorpo.Estado.ATIVO, "captura no contato de %s" % esperado)
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(pasta + "/" + str(esperado) + ".png")
			detalhe.get_texture().get_image().save_png(pasta + "/" + str(esperado) + "_detalhe.png")
	await _preparar(jogador)
	await _quadros(90)
	_ok(inicios.size() == 4, "quatro cliques dão quatro golpes; esperar não gera socos")
	_clique(jogador)
	_ok(e.golpe_atual != null and e.golpe_atual.id == &"boxe_jab", "após pausa a sequência recomeça no jab")
	await _preparar(jogador)
	await _quadros(90)
	e.golpe_iniciado.disconnect(gravar)
	detalhe.queue_free()
