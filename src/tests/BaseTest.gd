extends SceneTree
# ============================================================================
#  BASE DOS TESTES DE CENA (src/tests/*.gd)
#
#  Monta uma arena mínima (TestArena.tscn) com um Player de verdade e o boneco
#  de treino, e chama `test_step(f, delta)` uma vez por QUADRO DE FÍSICA.
#
#  Rodar:
#    godot --headless --path . --script src/tests/test_fsm.gd
#
#  --------------------------------------------------------------- 2026-08-21
#  ⚠️ POR QUE O `await process_frame` NA PRIMEIRA LINHA É OBRIGATÓRIO
#
#  Este arquivo montava a cena de forma SÍNCRONA dentro do `_init()`. Num script
#  `-s`/`--script` o `_init()` da SceneTree roda ANTES de os autoloads entrarem
#  na árvore — e o `Player.gd` cita `FruitNet` (autoload) como identificador. Sem
#  os autoloads registrados o `Player.gd` NÃO COMPILA, e então:
#
#      Compile Error: Identifier not found: FruitNet
#      Invalid call. Nonexistent function 'new' in base 'GDScript'
#
#  `load("res://Player.gd").new()` devolvia `null` em silêncio. O teste seguia
#  rodando com `player == null`, cada passo estourava "Invalid access ... on a
#  base object of type 'Nil'", e no fim ainda imprimia ">>> TEST DONE" com
#  código 0. Um teste verde que não exercitou NADA — pior que um teste vermelho.
#
#  Um único `await process_frame` antes de qualquer `load()` resolve: os
#  autoloads já estão em /root e o `Player.gd` compila. É o mesmo caminho que os
#  testes que funcionam já usavam (ver `tools/dev_tests/test_arena.gd` e
#  `test_charge_up.gd`) — aqui só se copiou o padrão da casa.
#
#  ⚠️ SEGUNDA ARMADILHA, do mesmo defeito: montar a cena SEM CONFERIR. Agora
#  todo pré-requisito (cena, script, jogador, boneco) é checado, e o que falta
#  derruba o teste com `quit(1)` e mensagem explícita. Falha de CENÁRIO nunca
#  mais pode passar por sucesso.
#
#  ⚠️ TERCEIRA: o `_ready()` do Player NÃO é chamado na mão. Ele já roda sozinho
#  no `add_child()` (a arena está na árvore); chamar de novo montava rig, FSM e
#  controladores EM DOBRO.
#
#  ⚠️ QUARTA: o `_physics_process` do Player também NÃO é chamado na mão. Os nós
#  estão na árvore de verdade, então a engine já os processa; a chamada manual
#  rodava o quadro duas vezes. O laço abaixo espera `physics_frame`, de modo que
#  `f` conta QUADRO DE FÍSICA — o mesmo relógio do jogo. (O `_process` da
#  SceneTree não serve: em headless o quadro ocioso é ilimitado e `f == 10`
#  chegava antes de existir um único quadro de física.)
# ============================================================================

var arena: Node3D
var player: CharacterBody3D
var dummy: CharacterBody3D
var frames := 0
var max_frames := 600

var falhas := 0            # asserções que falharam (define o código de saída)
var _asseracoes := 0       # quantas foram feitas (zero = teste que não testa nada)

func _init() -> void:
	# ⚠️ NÃO MEXA: sem este await os autoloads não existem e o Player.gd não
	# compila. Ver o cabeçalho.
	await process_frame

	for action in ["jump", "sprint", "dash", "aim", "fire"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	var cena: PackedScene = load("res://TestArena.tscn")
	if cena == null:
		_abortar("res://TestArena.tscn não carregou")
		return
	arena = cena.instantiate()
	if arena == null:
		_abortar("TestArena.tscn não instanciou")
		return
	root.add_child(arena)
	# Vários efeitos (FxUtil.dash_effect, por ex.) penduram nós em
	# `get_tree().current_scene`. Num script `-s` isso é nulo e o efeito some sem
	# avisar — apontar para a arena deixa o teste mais perto do jogo real.
	current_scene = arena

	dummy = arena.get_node_or_null("TrainingDummy")
	var spawn: Node3D = arena.get_node_or_null("SpawnPoint")
	if dummy == null:
		_abortar("TrainingDummy não encontrado em TestArena.tscn")
		return
	if spawn == null:
		_abortar("SpawnPoint não encontrado em TestArena.tscn")
		return

	var script_player: GDScript = load("res://Player.gd")
	if script_player == null or not script_player.can_instantiate():
		_abortar("res://Player.gd não compilou (autoloads registrados? veja o cabeçalho)")
		return
	player = script_player.new()
	if player == null:
		_abortar("Player.gd compilou mas `.new()` devolveu null")
		return
	player.name = "Player"
	# ⚠️ `_ready()` roda AQUI, sozinho. Não chame de novo.
	arena.add_child(player)
	player.global_position = spawn.global_position
	player.equipped_weapon = "sword"

	# Cenário montado — só a partir daqui o teste pode falar em sucesso.
	if not is_instance_valid(player) or player._fsm == null:
		_abortar("Player entrou na árvore mas o `_ready()` não montou a FSM")
		return

	await preparar()

	var delta := 1.0 / float(Engine.physics_ticks_per_second)
	while true:
		await physics_frame
		frames += 1
		test_step(frames, delta)
		if is_test_done():
			break
		if frames >= max_frames:
			print(">>> TEST TIMEOUT: %d quadros sem o teste terminar" % max_frames)
			falhas += 1
			break

	await concluir()

	# ⚠️ ZERO ASSERÇÕES É FALHA, e não sucesso. Foi exatamente assim que este
	# arquivo deixou o `test_fsm` verde por meses sem exercitar nada: sem
	# `ok(...)` não há teste, há só um script que rodou até o fim.
	if _asseracoes == 0:
		print("\n>>> TEST FAIL: nenhuma asserção foi executada — use `ok(cond, msg)`")
		quit(1)
		return

	if falhas == 0:
		print("\n>>> TEST DONE: %d asserção(ões), tudo OK" % _asseracoes)
		quit(0)
	else:
		print("\n>>> TEST FAIL: %d de %d asserção(ões) falharam" % [falhas, _asseracoes])
		quit(1)

# Falha de CENÁRIO: não dá para testar nada, então grita e sai com erro.
func _abortar(motivo: String) -> void:
	print("\n>>> TEST FAIL (cenário não montou): %s" % motivo)
	quit(1)

# ---------------------------------------------------------------- asserções
# Mesmo formato dos testes de `tools/dev_tests/` — uma linha ✅/❌ por checagem.
func ok(cond: bool, msg: String) -> void:
	_asseracoes += 1
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		falhas += 1

# ------------------------------------------------------------------ teclado
# O movimento e a esquiva leem TECLA FÍSICA (`Input.is_physical_key_pressed`),
# não ação do InputMap — ver `src/player/move_frame.gd`. `Input.action_press()`
# não move nada; é preciso injetar o evento de teclado de verdade.
func tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)

# ----------------------------------------------- ganchos para as subclasses
# Preparação assíncrona antes do laço (opcional).
func preparar() -> void:
	pass

# Um quadro de física. `f` começa em 1.
func test_step(f: int, delta: float) -> void:
	pass

# Verificações finais depois do laço (opcional).
func concluir() -> void:
	pass

func is_test_done() -> bool:
	return frames >= 100
