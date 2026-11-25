extends SceneTree
# ============================================================================
#  TESTE — água: jogador e animais (01/10/2026, docs/AGUA_PLANO.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_agua.gd
#
#  A1. serviço de água: rio (relevo), mar (fora das baseplates), seco;
#  A2. água rasa: o jogador DE VERDADE andando (tecla W) perde velocidade conforme a
#      profundidade; o animal também.
#  A5. fundo do mar: rente à praia na costa, 60–80 m no mar aberto (relevo de 14/10);
#  A3. nado: boia com a cabeça fora, Espaço sobe, Ctrl mergulha, nada mais devagar, fôlego
#      acaba e tira vida, sai andando pela praia; usuário de fruta afunda, anda no fundo
#      devagar e fica sem técnicas;
#  A4. animal na água funda boia e nada.
#  Mapa vivo (só leitura) e progresso de teste em user://.
# ============================================================================

const PROGRESSO := "user://test_agua_progresso.json"
const MAPA := "res://mapas/historia/baseplate.json"

var _falhas := 0
var _mapa: Dictionary


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== ÁGUA =====")
	_mapa = MapaArquivo.carregar(MAPA)["mapa"]
	var modo_script: Script = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo_script.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	_ok(jogador != null, "Modo História aberto")
	if jogador != null:
		await _servico()
		await _agua_rasa(jogador)
		await _fundo_do_mar()
		await _nado(jogador)
		await _usuario_de_fruta(jogador)
		await _fruta_desligada(jogador)
		await _animal_nadando(jogador)
	modo_script.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\nAGUA_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


# ----------------------------------------------------------- A1. serviço
func _servico() -> void:
	print("\n-- A1. onde há água --")
	var rio := _ponto_no_rio(0.3, 1.3)
	_ok(rio != Vector3.INF and not is_nan(AguaDoMundo.nivel_em(rio.x, rio.z)), "rio: o relevo tem água (%s)" % rio.snapped(Vector3.ONE * 0.1))
	var spawn: Vector3 = _mapa["spawn"]["posicao"]
	_ok(is_nan(AguaDoMundo.nivel_em(spawn.x, spawn.z)), "praça da vila: seco")
	var oceano: Node = current_scene.get_node_or_null("Oceano")
	var no_mar := AguaDoMundo.nivel_em(300.0, 0.0)
	_ok(oceano != null and is_equal_approx(no_mar, float(oceano.get("nivel"))), "mar (fora da baseplate): nível do oceano (%.2f)" % no_mar)
	_ok(AguaDoMundo.fator_de_andar(0.0) == 1.0 and absf(AguaDoMundo.fator_de_andar(0.3) - 0.727) < 0.01
		and AguaDoMundo.fator_de_andar(0.6) == 0.5, "curva da água rasa: seco 1,0 · joelho 0,73 · cintura 0,5")


# --------------------------------------------------------- A2. água rasa
func _agua_rasa(jogador: Node3D) -> void:
	print("\n-- A2. água rasa --")
	var seco := await _velocidade_andando(jogador, _mapa["spawn"]["posicao"] + Vector3(0, 0, -20))
	var cintura := _ponto_no_rio(0.45, 0.6)   # o rio tem no máximo 0,95 m (59 % do corpo)
	if cintura == Vector3.INF:
		_ok(false, "achar um ponto do rio com água pela cintura")
		return
	var molhado := await _velocidade_andando(jogador, cintura)
	var na_agua: JogadorNaAgua = current_scene.get_node("JogadorNaAgua")
	_ok(seco > 3.5, "no seco anda a %.2f m/s" % seco)
	_ok(molhado < seco * 0.7 and molhado > seco * 0.35,
		"com água pela cintura (%.0f%% do corpo) anda a %.2f m/s (%.0f%% do seco)" % [na_agua.submerso * 100.0, molhado, molhado / seco * 100.0])
	# Animal: o mesmo fator.
	var pop: PopulacaoDeAnimais = current_scene.get_node("Animais")
	var vaca: AnimalDaIlha = null
	for a in pop.animais:
		if a.especie == "cow" and a.vivo():
			vaca = a
	jogador.global_position = cintura + Vector3(30, 5, 0)
	vaca.global_position = cintura + Vector3.UP * 0.1
	vaca.set_physics_process(true)
	vaca.estado = AnimalDaIlha.Estado.PASSEANDO
	vaca.set("_destino", cintura + Vector3(0, 0, 8))
	vaca.set("_relogio", 30.0)
	pop.atualizar_detalhe()
	for i in 20:
		await physics_frame
	var v := Vector2(vaca.velocity.x, vaca.velocity.z).length()
	_ok(v < float(vaca.ficha["passeio"]) * 0.9, "vaca na água mais lenta: %.2f m/s (passeio %.2f)" % [v, float(vaca.ficha["passeio"])])


# ------------------------------------------------------- A5. fundo do mar
func _fundo_do_mar() -> void:
	print("\n-- A5. fundo do mar --")
	var fundo := current_scene.get_node_or_null("FundoDoMar")
	_ok(fundo != null, "o fundo do mar existe")
	var costa := _chao_em(258.0, 0.0)
	var perto := _chao_em(300.0, 0.0)
	var longe := _chao_em(700.0, 0.0)
	var praia := _chao_em(254.0, 0.0)
	_ok(absf(costa - praia) < 0.5, "costa sem degrau: praia %.2f m, fundo logo depois %.2f m" % [praia, costa])
	_ok(perto < -3.0 and perto > -12.0, "a 44 m da costa: %.1f m (dá para mergulhar)" % perto)
	# Relevo marinho (14/10/2026, docs/MAR_HISTORIA_PLANO.md): mar aberto a 60–80 m.
	_ok(longe < -56.0 and longe > RelevoMarinho.FOSSA - 4.0, "mar aberto: fundo a %.1f m" % longe)


# ------------------------------------------------------------- A3. nado
func _nado(jogador: Node3D) -> void:
	print("\n-- A3. nado --")
	var na_agua: JogadorNaAgua = current_scene.get_node("JogadorNaAgua")
	var nivel := AguaDoMundo.nivel_em(300.0, 0.0)
	jogador.global_position = Vector3(300.0, nivel - 0.3, 0.0)
	jogador.velocity = Vector3.ZERO
	for i in 120:
		await physics_frame
	var cabeca := jogador.global_position.y + JogadorNaAgua.CABECA_ACIMA_DO_CENTRO
	_ok(jogador.get("modo_na_agua") == "nadando" and cabeca > nivel and absf(jogador.velocity.y) < 0.3,
		"boia nadando com a cabeça fora (cabeça %.2f m acima d'água)" % (cabeca - nivel))
	var anim: Node = jogador.get("_proc_anim")
	_ok(anim != null and float(anim.get("_swim_w")) > 0.8, "pose de nado ligada (peso %.2f)" % (float(anim.get("_swim_w")) if anim else 0.0))
	# NADO LIVRE (14/10/2026): sem teclas o corpo fica onde está, em qualquer profundidade; o mouse
	# (inclinação) + W dão a direção em 3D.
	var rep: float = jogador.get("PITCH_DE_DESCANSO")
	jogador.global_position = Vector3(300.0, nivel - 3.0, 0.0)
	jogador.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
	_ok(absf(jogador.global_position.y - (nivel - 3.0)) < 0.3, "parado no fundo, não sobe sozinho (y %.2f, esperado %.2f)" % [jogador.global_position.y, nivel - 3.0])
	jogador.set("_pitch", rep + 0.7)     # olhando para cima
	jogador.call("_update_pivot")
	var ya: float = jogador.global_position.y
	_tecla(KEY_W, true)
	for i in 40:
		await physics_frame
	_tecla(KEY_W, false)
	_ok(jogador.global_position.y > ya + 0.8, "olhando para cima, W sobe (%.2f → %.2f)" % [ya, jogador.global_position.y])
	jogador.set("_pitch", rep - 0.7)     # olhando para baixo
	jogador.call("_update_pivot")
	ya = jogador.global_position.y
	_tecla(KEY_W, true)
	for i in 40:
		await physics_frame
	_tecla(KEY_W, false)
	_ok(jogador.global_position.y < ya - 0.4, "olhando para baixo, W mergulha (%.2f → %.2f)" % [ya, jogador.global_position.y])
	jogador.set("_pitch", rep + 0.7)
	jogador.call("_update_pivot")
	_tecla(KEY_W, true)
	for i in 240:
		await physics_frame
	_tecla(KEY_W, false)
	for i in 30:
		await physics_frame
	_ok(jogador.global_position.y + JogadorNaAgua.CABECA_ACIMA_DO_CENTRO < nivel + 1.0 and jogador.get("modo_na_agua") == "nadando",
		"subindo sempre, para na superfície (y %.2f, nível %.2f)" % [jogador.global_position.y, nivel])
	jogador.set("_pitch", rep)
	jogador.call("_update_pivot")
	jogador.global_position = Vector3(300.0, nivel - 0.3, 0.0)
	jogador.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	# Ctrl mergulha.
	var y0 := jogador.global_position.y
	_tecla(KEY_CTRL, true)
	for i in 90:
		await physics_frame
	_tecla(KEY_CTRL, false)
	_ok(jogador.global_position.y < y0 - 2.5 and na_agua.cabeca_submersa and na_agua.folego < JogadorNaAgua.FOLEGO_MAXIMO,
		"Ctrl mergulha (%.1f m) e o fôlego cai (%.1f s)" % [y0 - jogador.global_position.y, na_agua.folego])
	# Espaço sobe de volta a boiar.
	_tecla(KEY_SPACE, true)
	for i in 120:
		await physics_frame
	_tecla(KEY_SPACE, false)
	cabeca = jogador.global_position.y + JogadorNaAgua.CABECA_ACIMA_DO_CENTRO
	_ok(cabeca > nivel and jogador.global_position.y < nivel + 1.0, "Espaço sobe até boiar (sem sair voando da água)")
	# Nadar é mais lento que andar.
	var v := await _velocidade_andando(jogador, Vector3(300.0, nivel - 0.3 - 1.0, 0.0))
	_ok(v > 1.8 and v < 3.4, "nada a %.2f m/s (anda a 4,2)" % v)
	# Fôlego acabando tira vida.
	jogador.global_position = Vector3(300.0, nivel - 3.0, 0.0)
	na_agua.folego = 0.2
	var vida0: float = jogador.get("health")
	_tecla(KEY_CTRL, true)
	for i in 180:
		await physics_frame
	_tecla(KEY_CTRL, false)
	_ok(float(jogador.get("health")) < vida0, "sem fôlego perde vida (%.0f → %.0f)" % [vida0, float(jogador.get("health"))])
	jogador.set("health", jogador.get("max_health"))
	# Sai andando pela praia: nadando para oeste até a costa.
	jogador.global_position = Vector3(272.0, nivel - 0.3, 0.0)
	jogador.velocity = Vector3.ZERO
	jogador.set("_yaw", atan2(1.0, 0.0))       # olha para −X (convenção dos outros testes)
	jogador.call("_update_pivot")
	for i in 20:
		await physics_frame
	_tecla(KEY_W, true)
	for i in 420:
		await physics_frame
	_tecla(KEY_W, false)
	_ok(jogador.global_position.x < 256.0 and jogador.get("modo_na_agua") == "",
		"sai da água andando pela praia (x %.1f, %s)" % [jogador.global_position.x, "fora d'água" if jogador.get("modo_na_agua") == "" else "ainda nadando"])


func _usuario_de_fruta(jogador: Node3D) -> void:
	print("\n-- A3b. usuário de Akuma no Mi --")
	var modo := current_scene
	modo.call("dar_fruta", "rocket")
	for i in 5:
		await physics_frame
	var na_agua: JogadorNaAgua = current_scene.get_node("JogadorNaAgua")
	var nivel := AguaDoMundo.nivel_em(300.0, 0.0)
	jogador.global_position = Vector3(300.0, nivel - 0.2, 0.0)
	jogador.velocity = Vector3.ZERO
	for i in 15:
		await physics_frame
	_ok(jogador.get("modo_na_agua") != "nadando", "usuário de fruta não nada")
	for i in 360:
		await physics_frame
	var fundo := _chao_em(300.0, 0.0)
	var c: Object = jogador.get("capacidades")
	_ok(jogador.get("modo_na_agua") == "afundando" and jogador.global_position.y - 0.8 < fundo + 0.4,
		"submerso, afunda até o fundo (%.1f m; fundo %.1f m)" % [jogador.global_position.y - 0.8, fundo])
	_ok(c != null and not c.get("can_use_fruit") and not c.get("can_fly"), "submerso: sem técnicas de fruta")
	var v := await _velocidade_andando(jogador, Vector3(300.0, fundo + 0.9, 0.0))
	_ok(v > 0.4 and v < 2.0, "anda devagar no fundo (%.2f m/s)" % v)
	jogador.global_position = (_mapa["spawn"]["posicao"] as Vector3) + Vector3.UP
	jogador.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	_ok(jogador.get("modo_na_agua") == "" and c.get("can_use_fruit"), "fora d'água as técnicas voltam")
	modo.call("tirar_fruta")


## Interruptor da fruta na janela M (01/10/2026): desligada = sem técnicas E nada.
func _fruta_desligada(jogador: Node3D) -> void:
	print("\n-- A3c. fruta desligada no M --")
	var modo := current_scene
	modo.call("dar_fruta", "rocket")
	var prog: ProgressaoDoPersonagem = modo.get("progressao")
	var hud: Node = modo.get("_hud")
	hud.call("alternar_status")                      # abre a M (cria/atualiza a janela)
	var janela: Node = hud.get("_janela")
	var botao := janela.find_child("AlternarFruta", true, false) as Button
	_ok(botao != null and botao.visible and botao.text == "Desligar", "a janela M mostra o botão Desligar com a fruta comida")
	botao.emit_signal("pressed")
	for i in 3:
		await physics_frame
	var c: Object = jogador.get("capacidades")
	_ok(not prog.fruta_ativa and prog.tem_fruta() and not c.get("can_use_fruit") and jogador.get("perfil_de_frutas") == null
		and botao.text == "Ligar", "desligada: continua comida, sem técnicas nem perfil (botão vira Ligar)")
	var volta := ProgressaoDoPersonagem.de_dict(JSON.parse_string(JSON.stringify(prog.para_dict())))
	_ok(not volta.fruta_ativa and volta.fruta == "rocket", "o estado desligado é salvo no progresso")
	hud.call("alternar_status")
	var nivel := AguaDoMundo.nivel_em(300.0, 0.0)
	jogador.global_position = Vector3(300.0, nivel - 0.3, 0.0)
	jogador.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
	_ok(jogador.get("modo_na_agua") == "nadando", "desligada, nada normalmente (%s)" % jogador.get("modo_na_agua"))
	prog.definir_fruta_ativa(true)
	for i in 300:
		await physics_frame
	_ok(jogador.get("modo_na_agua") != "nadando" and c.get("can_use_fruit") == false,
		"ligada de novo: não nada mais (%s) e submerso fica sem técnicas" % jogador.get("modo_na_agua"))
	jogador.global_position = (_mapa["spawn"]["posicao"] as Vector3) + Vector3.UP
	jogador.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	_ok((jogador.get("capacidades") as Object).get("can_use_fruit") and jogador.get("perfil_de_frutas") != null,
		"ligada e fora d'água: técnicas e perfil de volta")
	modo.call("tirar_fruta")


# --------------------------------------------------- A4. animal nadando
func _animal_nadando(jogador: Node3D) -> void:
	print("\n-- A4. animal na água funda --")
	var pop: PopulacaoDeAnimais = current_scene.get_node("Animais")
	var vaca: AnimalDaIlha = null
	for a in pop.animais:
		if a.especie == "cow" and a.vivo():
			vaca = a
	var nivel := AguaDoMundo.nivel_em(300.0, 6.0)
	jogador.global_position = Vector3(300.0, 10.0, 30.0)
	pop.atualizar_detalhe()
	vaca.global_position = Vector3(300.0, nivel - 0.5, 6.0)
	vaca.velocity = Vector3.ZERO
	vaca.set_physics_process(true)
	vaca.estado = AnimalDaIlha.Estado.PASSEANDO
	vaca.set("_destino", Vector3(290.0, 0.0, 6.0))
	vaca.set("_relogio", 30.0)
	for i in 120:
		await physics_frame
	var linha := nivel - vaca.altura() * AnimalDaIlha.LINHA_DAGUA_NADANDO
	_ok(vaca.nadando and absf(vaca.global_position.y - linha) < 0.3,
		"vaca na água funda boia e nada (y %.2f, linha %.2f)" % [vaca.global_position.y, linha])


func _chao_em(x: float, z: float) -> float:
	var excluir: Array[RID] = []
	for p in get_nodes_in_group("player"):
		excluir.append((p as CollisionObject3D).get_rid())
	var h := root.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -100, z), 1, excluir))
	return (h["position"] as Vector3).y if not h.is_empty() else NAN


## Anda 0,6 s para a frente (W) e devolve a velocidade horizontal média.
func _velocidade_andando(jogador: Node3D, onde: Vector3) -> float:
	jogador.global_position = onde + Vector3.UP * 1.0
	jogador.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	var de := jogador.global_position
	_tecla(KEY_W, true)
	for i in 12:
		await physics_frame
	de = jogador.global_position
	for i in 24:
		await physics_frame
	_tecla(KEY_W, false)
	var andou := Vector2(jogador.global_position.x - de.x, jogador.global_position.z - de.z).length()
	return andou / (24.0 / 60.0)


## Um ponto do rio cuja água cobre de `de` a `ate` do corpo de 1,6 m (fração).
func _ponto_no_rio(de: float, ate: float) -> Vector3:
	for p: Dictionary in _mapa["pecas"]:
		if p["tipo"] != "terreno" or (p["relevo"].get("agua", PackedInt32Array()) as PackedInt32Array).is_empty():
			continue
		var pos: Vector3 = p["posicao"]
		var tam: Vector3 = p["tamanho"]
		for i in 64:
			for j in 64:
				var x := pos.x + (i / 63.0 - 0.5) * tam.x * 0.96
				var z := pos.z + (j / 63.0 - 0.5) * tam.z * 0.96
				var nivel := AguaDoMundo.nivel_em(x, z)
				if is_nan(nivel):
					continue
				var chao := pos.y + TerrenoDoMapa.altura_local(p["relevo"], tam, x - pos.x, z - pos.z)
				var fracao := (nivel - chao) / 1.6
				# Longe da borda do rio (para andar 0,6 s sem sair da água).
				var vizinhos := 0
				for d in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
					vizinhos += int(not is_nan(AguaDoMundo.nivel_em(x + d.x, z + d.y)))
				if fracao >= de and fracao <= ate and vizinhos == 4:
					return Vector3(x, chao, z)
	return Vector3.INF


func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)
