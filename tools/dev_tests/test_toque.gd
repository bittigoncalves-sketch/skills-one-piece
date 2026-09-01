extends SceneTree
# ============================================================================
#  CONTROLES DE TOQUE — o dedo faz o mesmo que o teclado?
#
#  ⚠️ O QUE IMPORTA MEDIR É O EFEITO NO JOGADOR, não o estado do HUD. Um teste
#  que só confere "o joystick registrou o toque" passa com o boneco parado: o
#  HUD injeta eventos, e entre a injeção e o personagem andar existem o
#  `MoveFrame`, a FSM e a física. Por isso aqui se mede DESLOCAMENTO.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_toque.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)

	var hud := get_root().get_tree().get_first_node_in_group("hud")
	var toque: ToqueHud = hud.get_node_or_null("ToqueHud") if hud else null
	_ok("o HUD de toque existe na interface", toque != null)
	if toque == null:
		print("\n%d conferem | %d divergem" % [_ok_n, _falhas]); quit(1); return

	# ⚠️ ESCONDIDO NO PC. Se aparecesse sempre, o jogo de teclado ganharia
	# botões por cima da tela sem ninguém pedir.
	_ok("fora de celular ele começa ESCONDIDO", not toque.visible)

	ToqueHud.forcar = true
	toque.visible = true
	toque.set_process_input(true)
	await _quadros(5)
	_ok("forçado, ele aparece", toque.visible)

	await _o_joystick(p, toque)
	await _os_botoes(p, toque)
	await _a_camera(p, toque)

	ToqueHud.forcar = false
	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## O JOYSTICK faz o boneco ANDAR — é isso que precisa ser verdade.
func _o_joystick(p: Node3D, toque: ToqueHud) -> void:
	print("\n=== 1. o joystick move o jogador ===")
	await _assentar(p)
	var tela: Vector2 = toque.size
	var base := Vector2(tela.x * 0.2, tela.y * 0.7)

	var antes: Vector3 = p.global_position
	_tocar(0, base, true)
	await _quadros(3)
	_ok("tocar na metade esquerda arma o joystick", toque._dedo_mov == 0)

	# arrasta para cima = frente
	_arrastar(0, base + Vector2(0, -95))
	await _quadros(30)
	var andou: float = Vector2(p.global_position.x - antes.x, p.global_position.z - antes.z).length()
	print("   arrastando o joystick para cima: andou %.2f m" % andou)
	_ok("o jogador ANDA com o joystick", andou > 0.5)

	_tocar(0, base, false)
	await _quadros(10)
	var parou_em: Vector3 = p.global_position
	await _quadros(20)
	var depois: float = Vector2(p.global_position.x - parou_em.x, p.global_position.z - parou_em.z).length()
	print("   depois de soltar: andou mais %.2f m" % depois)
	_ok("soltar o dedo PARA o jogador", depois < 0.35)


## OS BOTÕES disparam as ações.
func _os_botoes(p: Node3D, toque: ToqueHud) -> void:
	print("\n=== 2. os botões disparam ações ===")
	await _assentar(p)
	var i_pulo := -1
	for i in ToqueHud.BOTOES.size():
		if String(ToqueHud.BOTOES[i]["nome"]) == "PULO":
			i_pulo = i
	_ok("existe botão de pulo", i_pulo >= 0)
	if i_pulo < 0:
		return

	# ⚠️ ESPERAR O CHÃO, não contar quadros. O teste do joystick antes deste move
	# o jogador, e testar o pulo enquanto ele ainda está no ar reprova um botão
	# que funciona — aconteceu uma vez em três execuções. Esperar a CONDIÇÃO
	# elimina a instabilidade em vez de mascará-la com mais quadros.
	var espera := 0
	while not p.is_on_floor() and espera < 180:
		await process_frame
		espera += 1
	_ok("o jogador está no chão antes de testar o pulo", p.is_on_floor())

	var chao: float = p.global_position.y
	# ⚠️ SEGURAR O DEDO ALGUNS QUADROS. A borda do Espaço é amostrada no quadro
	# de FÍSICA: apertar e soltar dentro de poucos quadros de PROCESSO pode não
	# ser vista nenhuma vez, e o pulo simplesmente não sai. Medido: com 4 quadros
	# o pulo saiu em duas de três execuções (0,26 m na que falhou, contra 2,9 m
	# nas outras). É a mesma armadilha que o `medir_camera_e_parede` já
	# registrava para o teclado — vale igual para o dedo.
	var c := toque._centro_do_botao(i_pulo)
	_tocar(1, c, true)
	await _quadros(2)
	print("   [diag] Input ve o espaco? %s" % str(Input.is_key_pressed(KEY_SPACE)))
	await _quadros(10)
	_tocar(1, c, false)
	var subiu := 0.0
	for i in 30:
		await process_frame
		subiu = maxf(subiu, p.global_position.y - chao)
	print("   botão de pulo: subiu %.2f m" % subiu)
	_ok("o botão de PULO tira os pés do chão", subiu > 0.4)

	# ⚠️ CONTROLE: um toque LONGE de qualquer botão não pode disparar nada.
	var longe := Vector2(toque.size.x * 0.55, toque.size.y * 0.5)
	_ok("toque fora dos botões não acerta nenhum", toque._botao_em(longe) < 0)


## A CÂMERA gira com o arrasto da direita.
func _a_camera(p: Node3D, toque: ToqueHud) -> void:
	print("\n=== 3. a câmera gira com o arrasto ===")
	await _assentar(p)
	var yaw0: float = p._yaw
	var inicio := Vector2(toque.size.x * 0.8, toque.size.y * 0.5)
	_tocar(2, inicio, true)
	await _quadros(3)
	_ok("tocar na metade direita arma a câmera", toque._dedo_cam == 2)
	_arrastar(2, inicio + Vector2(-160, 0))
	await _quadros(6)
	var girou: float = absf(p._yaw - yaw0)
	print("   arrastando 160 px: o yaw mudou %.3f rad" % girou)
	_ok("o arrasto GIRA a câmera", girou > 0.05)
	_tocar(2, inicio, false)
	await _quadros(3)


## ⚠️ CADA BLOCO COMEÇA LIMPO. Sem isto os blocos interferem entre si e a falha
## MIGRA: com o joystick antes, o pulo falhava em 1 de 3; invertendo a ordem, o
## pulo passou a funcionar sempre e quem falhava era o joystick. O problema
## nunca foi a ordem — era um bloco herdar o corpo em movimento do anterior.
## Assentar é esperar a CONDIÇÃO (parado, no chão), não contar quadros.
func _assentar(p: Node3D) -> void:
	var espera := 0
	while espera < 240:
		await process_frame
		espera += 1
		var plano := Vector2(p.velocity.x, p.velocity.z).length()
		if p.is_on_floor() and plano < 0.5 and absf(p.velocity.y) < 1.0:
			break
	# mais alguns quadros para a FSM sair de qualquer estado de transição
	await _quadros(10)


func _tocar(indice: int, pos: Vector2, pressionado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = indice
	e.position = pos
	e.pressed = pressionado
	Input.parse_input_event(e)


func _arrastar(indice: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = indice
	e.position = pos
	e.relative = Vector2(-160, 0) if indice == 2 else Vector2.ZERO
	Input.parse_input_event(e)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
