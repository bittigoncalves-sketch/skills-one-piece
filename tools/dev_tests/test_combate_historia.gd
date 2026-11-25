extends SceneTree
# ============================================================================
#  TESTE DO COMBATE DIRECIONAL NO MODO HISTÓRIA — o jogo de verdade.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md. Complementa o teste do executor (que
#  roda sem Player): aqui o executor está pendurado no jogador real, montado por
#  `ModoHistoria.colocar_civil`, e o que se prova é a PONTE com o Player.
#
#  Fase 1: instalação, porta do clique, capacidade, menu, cancelamento por
#  atordoamento, dash travado durante o golpe, e que o caminho da arena NÃO roda.
#  Fase 2: entrada instalada, teto de giro do corpo por fase, mobilidade reduzida
#  (sem congelar). A direção pelo mouse real está em `test_combate_historia_tela`.
#  Fase 7a: o boneco de duelo invocado pelos botões da seção TESTE da janela M.
#
#  ⚠️ Toda trava tem CONTROLE POSITIVO (ver o cabeçalho do test_modo_historia).
#  ⚠️ Mapa e progresso FIXOS: o mapa vivo do dono nunca é lido nem gravado.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_combate_historia.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_combate_historia_progresso.json"
# `load` em tempo de execução, nunca `preload` (ver test_modo_historia: o preload
# compila o Player antes de os autoloads existirem e o envenena no cache).
var _modo_historia: GDScript
var _falhas := 0


class MenuSubstituto extends Control:
	var aberto := false
	func is_open() -> bool:
		return aberto
	func toggle() -> void:
		aberto = not aberto
	func open_menu() -> void:
		aberto = true


func _init() -> void:
	await process_frame
	print("\n===== COMBATE DIRECIONAL NO MODO HISTÓRIA =====")
	# Este teste é do SOCO direcional: o clique do Minecraft (V5) fica desligado (mesma chave do `SOCO_ANTIGO=1`).
	CliqueDeBlocos.ligado = false
	_modo_historia = load("res://src/historia/ModoHistoria.gd")
	_modo_historia.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	_modo_historia.set("progresso_forcado", PROGRESSO)

	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame

	var jogador := _jogador_local()
	_ok(jogador != null, "o Modo História montou o jogador local")
	if jogador != null:
		_instalacao(jogador)
		await _porta_do_clique(jogador)
		await _menu(jogador)
		await _atordoado(jogador)
		await _dash_durante_o_golpe(jogador)
		await _giro_com_teto(jogador)
		await _mobilidade(jogador)
		await _boneco_pela_janela(jogador)

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


func _executor(jogador: Node) -> ExecutorCorpoACorpo:
	return jogador.combate_direcional


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _esperar_neutro(jogador: Node) -> void:
	for i in 180:
		if not _executor(jogador).ocupado():
			return
		await physics_frame


func _clique(jogador: Node) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	jogador._unhandled_input(ev)


func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)


# ------------------------------------------------------------------- 1
func _instalacao(jogador: Node) -> void:
	print("\n-- 1. instalação num ponto só --")
	var e := _executor(jogador)
	_ok(e is ExecutorCorpoACorpo, "colocar_civil pendurou o executor no jogador")
	_ok(e != null and e.get_parent() == jogador, "o executor é filho do corpo")
	_ok(e != null and e.estilo != null and e.estilo.id == &"boxe", "o estilo inicial é o boxe")
	# ⚠️ Sem citar `AtorJogador` pelo nome: ele depende do Player, e citá-lo aqui
	# compilaria o Player antes dos autoloads (a armadilha do cabeçalho).
	_ok(e != null and e.ator != null and e.ator.get_script().get_global_name() == &"AtorJogador"
		and e.ator.corpo() == jogador, "o corpo chega ao executor pelo adaptador do jogador")
	var entrada = jogador.get("entrada_combate_direcional")
	_ok(entrada != null and entrada.get_script().get_global_name() == &"EntradaCorpoACorpo"
		and entrada.get_parent() == e, "a entrada do jogador foi instalada junto, pendurada no executor")
	var arena_player: Node = load("res://Player.gd").new()
	_ok(arena_player.get("combate_direcional") == null, "controle: um Player fora do Modo História nasce SEM executor")
	arena_player.free()


# ------------------------------------------------------------------- 2
func _porta_do_clique(jogador: Node) -> void:
	print("\n-- 2. a porta do clique --")
	var e := _executor(jogador)
	# Desde 30/09/2026 a campanha começa com Combate 1: o corpo do jogo já bate. A TRAVA
	# (a porta do clique) se mede pondo o Civil à mão.
	_ok(jogador.capacidades.can_attack, "o jogador do Modo História já nasce podendo bater (Combate 1)")
	jogador.capacidades = CapacidadesDoJogador.civil()
	jogador._request_melee()
	await _quadros(5)
	_ok(not e.ocupado(), "Civil: pedir corpo a corpo não começa golpe")
	_clique(jogador)
	await _quadros(5)
	_ok(not e.ocupado(), "Civil: clique esquerdo não começa golpe")

	jogador.capacidades = CapacidadesDoJogador.completas()
	jogador._request_melee()
	_ok(e.em_preparo(), "controle: com combate liberado o mesmo pedido começa o golpe")
	_ok(jogador.esta_atacando() and jogador.em_startup_de_ataque(), "as consultas públicas do Player respondem pelo executor")
	await _quadros(3)
	_ok(jogador._fsm.state.name == "Idle", "o caminho da arena não rodou: a FSM continua em Idle")
	await _esperar_neutro(jogador)
	_ok(not e.ocupado() and not jogador.esta_atacando(), "o golpe termina sozinho e o Player volta a não estar atacando")

	# ⚠️ HEADLESS NÃO CAPTURA O MOUSE (medido em 16/09/2026: `mouse_mode` continua
	# VISIBLE depois de atribuir CAPTURED). Sem captura o clique cai no ramo de
	# recaptura do Player e sai sem atacar — um "não atacou" aqui não provaria nada.
	# Por isso este trecho só julga com mouse capturado de verdade (rodar com tela).
	_clique(jogador)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_ok(e.em_preparo(), "o clique esquerdo de verdade (_unhandled_input) também começa o golpe")
	else:
		print("  ⏭️  pulado: clique real exige mouse capturado (rode com tela)")
	await _esperar_neutro(jogador)
	jogador.capacidades = CapacidadesDoJogador.civil()


# ------------------------------------------------------------------- 3
func _menu(jogador: Node) -> void:
	print("\n-- 3. menu aberto --")
	var e := _executor(jogador)
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	var substituto := MenuSubstituto.new()
	hud.add_child(substituto)
	hud._menu = substituto
	jogador.capacidades = CapacidadesDoJogador.completas()

	hud.toggle_main_menu()
	jogador._request_melee()
	_ok(hud.is_menu_open() and not e.ocupado(), "com o menu aberto o pedido não começa golpe")
	hud.toggle_main_menu()
	jogador._request_melee()
	_ok(e.em_preparo(), "controle: menu fechado, o mesmo pedido começa")

	hud.toggle_main_menu()   # abrir NO MEIO do golpe
	await _quadros(int(ceil(e.golpe_atual.preparo * 60.0)) + 2)
	_ok(e.estado == ExecutorCorpoACorpo.Estado.ATIVO or e.estado == ExecutorCorpoACorpo.Estado.RECUPERACAO,
		"menu aberto no meio do golpe não o cancela (%s)" % ExecutorCorpoACorpo.Estado.keys()[e.estado])
	hud.toggle_main_menu()
	await _esperar_neutro(jogador)
	hud._menu = null
	substituto.queue_free()
	jogador.capacidades = CapacidadesDoJogador.civil()


# ------------------------------------------------------------------- 4
func _atordoado(jogador: Node) -> void:
	print("\n-- 4. apanhar no preparo cancela --")
	var e := _executor(jogador)
	jogador.capacidades = CapacidadesDoJogador.completas()
	var motivos: Array = []
	var ao_encerrar := func(_id, motivo): motivos.append(motivo)
	e.golpe_encerrado.connect(ao_encerrar)

	jogador._request_melee()
	var id := e.id_acao
	jogador.take_damage(1.0, jogador.global_position + Vector3.FORWARD, Vector3.ZERO, 0.5)
	await _quadros(3)
	_ok(not e.golpe_valido(id) and motivos.has(&"impedido"),
		"dano com hitstun no preparo cancela o golpe (motivos: %s)" % str(motivos))
	jogador._request_melee()
	_ok(not e.ocupado(), "atordoado, o pedido é recusado")

	for i in 90:
		await physics_frame
	jogador._request_melee()
	_ok(e.em_preparo(), "controle: passado o hitstun, o mesmo pedido começa")
	await _esperar_neutro(jogador)
	e.golpe_encerrado.disconnect(ao_encerrar)
	jogador.health = jogador.max_health
	jogador.capacidades = CapacidadesDoJogador.civil()


# ------------------------------------------------------------------- 5
func _dash_durante_o_golpe(jogador: Node) -> void:
	print("\n-- 5. esquiva não corta o golpe --")
	var e := _executor(jogador)
	jogador.capacidades = CapacidadesDoJogador.completas()
	jogador._request_melee()
	_tecla(KEY_Q, true)
	await _quadros(6)
	_tecla(KEY_Q, false)
	var saiu := false
	for i in 4:
		await physics_frame
		saiu = saiu or jogador._dash.ativo()
	_ok(not saiu, "com golpe em curso o Q não dispara a esquiva")
	await _esperar_neutro(jogador)
	await _quadros(30)
	_tecla(KEY_Q, true)
	await _quadros(6)
	_tecla(KEY_Q, false)
	saiu = false
	for i in 4:
		await physics_frame
		saiu = saiu or jogador._dash.ativo()
	_ok(saiu, "controle: sem golpe, o mesmo Q dispara")
	await _quadros(60)
	jogador.capacidades = CapacidadesDoJogador.civil()


# ------------------------------------------------------------------- 6
func _giro_com_teto(jogador: Node) -> void:
	print("\n-- 6. o corpo segue a mira com teto de giro durante o golpe --")
	var e := _executor(jogador)
	jogador.capacidades = CapacidadesDoJogador.completas()
	var dt := 1.0 / Engine.physics_ticks_per_second

	# Controle: em combate mas fora de golpe, meia volta da mira gira o corpo
	# rápido. Desde 02/10 o corpo LIVRE segue o movimento, não a mira — o
	# controle precisa estar na janela de combate (logo depois de um golpe).
	await _quadros(10)
	var antes: float = jogador._char_model.rotation.y
	jogador._combate_t = jogador.COMBATE_SEGURA
	jogador._yaw = antes + PI * 0.9
	await _quadros(1)
	var livre := absf(wrapf(jogador._char_model.rotation.y - antes, -PI, PI))
	_ok(livre > 0.5, "controle: sem golpe, o corpo vira %.3f rad num quadro" % livre)
	await _quadros(40)

	jogador._request_melee()
	for i in 60:
		if e.estado == ExecutorCorpoACorpo.Estado.ATIVO:
			break
		await physics_frame
	_ok(e.estado == ExecutorCorpoACorpo.Estado.ATIVO, "(preparação) o golpe chegou ao ATIVO")
	var teto: float = e.giro_maximo() * dt
	antes = jogador._char_model.rotation.y
	jogador._yaw = antes + PI * 0.9
	await _quadros(1)
	var no_golpe := absf(wrapf(jogador._char_model.rotation.y - antes, -PI, PI))
	_ok(no_golpe <= teto + 0.0005 and no_golpe > 0.0,
		"no ATIVO o corpo vira só %.4f rad (teto da ficha %.4f rad/quadro)" % [no_golpe, teto])
	await _esperar_neutro(jogador)
	await _quadros(40)
	jogador.capacidades = CapacidadesDoJogador.civil()


# ------------------------------------------------------------------- 7
## Mede JÁ ANDANDO: desde 02/10 a corrida tem arrancada (0→4,2 m/s em ~0,33 s) e
## o combate acelera mais firme, então partir do repouso media a arrancada, não o
## fator da ficha.
func _andar_w(jogador: Node, quadros: int, atacar: bool) -> float:
	_tecla(KEY_W, true)
	await _quadros(45)
	var antes: Vector3 = jogador.global_position
	if atacar:
		jogador._request_melee()
	for i in quadros:
		await physics_frame
	_tecla(KEY_W, false)
	var d: Vector3 = jogador.global_position - antes
	d.y = 0.0
	return d.length()


func _mobilidade(jogador: Node) -> void:
	print("\n-- 7. atacar andando: menos mobilidade, nunca congelado --")
	var e := _executor(jogador)
	jogador.capacidades = CapacidadesDoJogador.completas()
	await _quadros(30)
	var golpe := e.estilo.golpe_para(GolpeDirecional.Direcao.FRENTE)
	# Mede só dentro do PREPARO, onde o fator é um número só.
	var quadros := int(floor(golpe.preparo * Engine.physics_ticks_per_second)) - 2
	var controle := await _andar_w(jogador, quadros, false)
	await _quadros(30)
	var com_golpe := await _andar_w(jogador, quadros, true)
	await _esperar_neutro(jogador)
	await _quadros(30)
	if controle < 0.2:
		print("  ⏭️  pulado: o W não moveu o corpo neste ambiente (%.2f m) — rode com tela" % controle)
	else:
		var razao := com_golpe / controle
		_ok(com_golpe > 0.0, "atacando, o corpo ainda anda (%.2f m)" % com_golpe)
		# A ficha dá a velocidade ALVO do preparo (×0,60); o corpo tem inércia (aceleração firme desde 02/10) e o preparo dura só ~0,3 s,
		# então a distância média fica entre a ficha e o controle (medido ×0,84). Vale: mais lento que o controle e nunca abaixo da ficha.
		_ok(razao < 0.95 and razao >= golpe.fator_movimento_preparo - 0.15,
			"no preparo anda ×%.2f do controle (%.2f m contra %.2f m; ficha ×%.2f)"
			% [razao, com_golpe, controle, golpe.fator_movimento_preparo])
	jogador.capacidades = CapacidadesDoJogador.civil()


# ------------------------------------------------------------------- 8
## Os bonecos de duelo na cena (grupo "enemy" com executor; os inimigos do mapa não têm).
func _bonecos() -> Array:
	return get_root().get_tree().get_nodes_in_group("enemy").filter(
		func(n): return n.get("combate_direcional") != null and not n.is_queued_for_deletion())


func _botao_do_boneco(texto: String) -> Button:
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	# Desde 30/09/2026 os botões de teste moram no painel F8 (`FerramentasDeTeste`),
	# e não mais na janela de Status.
	var painel: Node = hud.ferramentas_de_teste() if hud != null else null
	var fila: Node = painel.find_child("Bonecos", true, false) if painel != null else null
	if fila == null:
		return null
	for b in fila.get_children():
		if b is Button and b.text == texto:
			return b
	return null


func _boneco_pela_janela(jogador: Node) -> void:
	print("\n-- 8. ferramentas de teste (F8): o boneco de duelo --")
	await _esperar_neutro(jogador)
	_ok(_bonecos().is_empty(), "(pré-condição) nenhum boneco na cena antes do pedido")
	var parado := _botao_do_boneco("Parado")
	var ataca := _botao_do_boneco("Ataca")
	var guarda := _botao_do_boneco("Só guarda")
	var remover := _botao_do_boneco("Remover boneco")
	_ok(parado != null and ataca != null and guarda != null and remover != null,
		"a seção TESTE tem os botões do boneco (Parado, Ataca, Só guarda, Remover)")
	if parado == null or ataca == null or guarda == null or remover == null:
		return

	parado.pressed.emit()
	await _quadros(30)
	var lista := _bonecos()
	_ok(lista.size() == 1, "\"Parado\" invoca UM boneco (%d)" % lista.size())
	if lista.size() != 1:
		return
	var boneco: Node = lista[0]
	var eb: ExecutorCorpoACorpo = boneco.combate_direcional
	var plano := Vector2(boneco.global_position.x - jogador.global_position.x,
		boneco.global_position.z - jogador.global_position.z).length()
	_ok(absf(plano - 1.8) < 0.15 and absf(boneco.global_position.y - jogador.global_position.y) < 0.1,
		"ele aparece no chão, à frente do jogador, a 1,8 m (%.2f m; Δy %.2f)" % [plano, boneco.global_position.y - jogador.global_position.y])
	_ok(eb.estilo.resource_path == _executor(jogador).estilo.resource_path,
		"usa o MESMO estilo do jogador (%s)" % eb.estilo.resource_path.get_file())

	var golpes := [0]
	var ao_golpe := func(_g, _id): golpes[0] += 1
	eb.golpe_iniciado.connect(ao_golpe)
	await _quadros(150)
	_ok(golpes[0] == 0, "controle: \"Parado\" não ataca em 2,5 s (%d golpe(s))" % golpes[0])
	ataca.pressed.emit()
	await _quadros(150)
	_ok(golpes[0] >= 1, "\"Ataca\" solta golpe sozinho em 2,5 s (%d golpe(s))" % golpes[0])
	_ok(_bonecos().size() == 1 and _bonecos()[0] == boneco, "trocar o modo mantém o MESMO boneco (um por vez)")
	eb.golpe_iniciado.disconnect(ao_golpe)

	guarda.pressed.emit()
	await _quadros(20)
	_ok(eb.em_guarda(), "\"Só guarda\" deixa o boneco em guarda (%s)" % ExecutorCorpoACorpo.Estado.keys()[eb.estado])

	remover.pressed.emit()
	await _quadros(2)
	_ok(_bonecos().is_empty(), "\"Remover boneco\" tira o boneco da cena")
