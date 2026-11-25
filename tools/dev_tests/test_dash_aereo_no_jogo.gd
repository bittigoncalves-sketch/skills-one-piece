extends SceneTree
## Exercita teclas e Player reais no Modo História, sem depender do mapa completo.
var falhas := 0
var testes := 0
var jogador: CharacterBody3D

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_dash_direcional_codex.json")
	root.get_node("GameFlow").start_story()
	for i in 160:
		await physics_frame
	for no in get_nodes_in_group("player"):
		if no.is_multiplayer_authority():
			jogador = no
			break
	_checar("personagem real", jogador != null)
	if jogador == null:
		quit(1)
		return
	jogador.capacidades = CapacidadesDoJogador.completas()
	jogador.capacidades.recarga_dash_no_ar = 0.0
	var limites: Vector2 = jogador.limites_de_pitch()
	var ate_cima: float = limites.y - jogador.PITCH_DE_DESCANSO
	var ate_baixo: float = limites.x - jogador.PITCH_DE_DESCANSO
	# [teclas, pitch relativo à posição de repouso, direção esperada, clipe]
	var casos := [
		[[KEY_W], 0.0, Vector3.FORWARD, "frente"],
		[[KEY_S], 0.0, Vector3.BACK, "tras"],
		[[KEY_A], 0.0, Vector3.LEFT, "esquerda"],
		[[KEY_D], 0.0, Vector3.RIGHT, "direita"],
		[[KEY_W, KEY_A], 0.0, (Vector3.FORWARD + Vector3.LEFT).normalized(), "frente"],
		[[KEY_S, KEY_D], 0.0, (Vector3.BACK + Vector3.RIGHT).normalized(), "tras"],
		[[KEY_W], ate_cima * 0.5, Vector3(0, sin(PI / 4), -cos(PI / 4)), "frente"],
		[[KEY_W], ate_baixo * 0.5, Vector3(0, -sin(PI / 4), -cos(PI / 4)), "frente"],
		[[KEY_W, KEY_A], ate_cima * 0.5, (Vector3(0, sin(PI / 4), -cos(PI / 4)) + Vector3.LEFT).normalized(), "frente"],
		[[], ate_cima, Vector3.UP, "frente"],
		[[KEY_W], ate_baixo, Vector3.DOWN, "frente"],
	]
	for indice in casos.size():
		var caso: Array = casos[indice]
		for tecla in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q]: _tecla(tecla, false)
		jogador._dash_ar.cancelar()
		jogador.global_position = Vector3(0, 60, 0)
		jogador.velocity = Vector3.ZERO
		jogador._yaw = 0.0
		jogador._pitch = jogador.PITCH_DE_DESCANSO + caso[1]
		await physics_frame
		for tecla in caso[0]: _tecla(tecla, true)
		await physics_frame
		_tecla(KEY_Q, true)
		await physics_frame
		await physics_frame
		var ar: DashNoAr = jogador._dash_ar
		var nome := str(caso[0]) + " pitch=" + str(caso[1])
		_checar(nome + " direção", ar.ativo() and ar.direcao().distance_to(caso[2]) < 0.01)
		var esperado: String = DashNoAr.CLIPES[caso[3]] if indice % 2 == 0 else DashNoAr.CLIPES_ALTERNADOS[caso[3]]
		_checar(nome + " clipe e perna alternada", jogador._proc_anim.acao_clipe == esperado)
		_checar(nome + " velocidade", jogador.velocity.normalized().distance_to(caso[2]) < 0.05)
		_tecla(KEY_Q, false)
		for tecla in caso[0]: _tecla(tecla, false)
		for i in 20: await physics_frame
		_checar(nome + " terminou", not ar.ativo())
	print("DASH_NO_JOGO: %d verificações; %d falhas" % [testes, falhas])
	quit(1 if falhas else 0)

func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)

func _checar(nome: String, condicao: bool) -> void:
	testes += 1
	if not condicao:
		falhas += 1
		push_error("FALHOU " + nome)
