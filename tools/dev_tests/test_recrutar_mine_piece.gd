extends SceneTree
# ============================================================================
#  CAPTURAR PERSONAGENS DO MINE PIECE COM A POKÉBOLA (30/10/2026; antes: recrutar com F, 18/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_recrutar_mine_piece.gd
#
#  Pedido do dono: a pokébola (item 4 da barra) captura inimigos de vida VERMELHA (abaixo de 25 %) e
#  substitui o F. Na cena real (mapa vivo, save de teste): marinheiro de vida cheia recusa; com a vida
#  vermelha, a bola arremessada o captura (vira membro da tripulação com o modelo dele e o corpo some pela
#  morte normal); o Buggy (chefe) nunca é capturável; derrotado de verdade morre direto, sem escolha de F.
# ============================================================================

const P := preload("res://src/historia/tripulantes/provisoes.gd")

var total := 0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_recrutar_mine_piece.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_recrutar_mine_piece.json"))
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var sistema := get_first_node_in_group("recrutamento_historia")
	ok(sistema != null, "sistema de recrutamento na campanha")
	var todos := get_nodes_in_group("personagens_east_blue")
	var comuns := todos.filter(func(p): return str(p.get_meta("modelo_recrutavel", "")) == "mp_marine" and not bool(p.ficha.get("chefe", false)))
	var chefe: Node3D = todos.filter(func(p): return str(p.get_meta("modelo_recrutavel", "")) == "mp_buggy")[0] if not todos.filter(func(p): return str(p.get_meta("modelo_recrutavel", "")) == "mp_buggy").is_empty() else null
	for m in comuns:
		m.capanga = false      # capanga: ver test_chefes_e_capangas
	ok(comuns.size() >= 2 and chefe != null, "marinheiros e o Buggy no mapa (%d marinheiros)" % comuns.size())
	if comuns.size() < 2 or chefe == null:
		quit(1)
		return

	print("\n-- a barra e o cubo na mão --")
	var itens: Array[String] = prog.itens_da_barra()
	var ip := itens.find("pokebola")
	ok(ip >= 0 and itens.find("comida") == ip - 1 and itens.find("bandeira") == ip + 1, "pokébola entra na barra entre a comida e a bandeira: %s" % str(itens))
	ok(itens.size() >= 4 and itens[3] == "pokebola", "com o kit inicial a pokébola é a tecla 4")
	var captura: Node = cena.get_node_or_null("CapturaDeInimigos")
	ok(captura != null, "CapturaDeInimigos existe na campanha")
	prog.ativar_item("pokebola")
	await quadros(10)
	var mao: Node3D = jogador.get("_rig").get("item_handle")
	ok(captura.segurando() and mao.find_child("PokebolaNaMao", false, false) != null, "ativa: aparece o cubo na mão do jogador")
	prog.ativar_item("pokebola")
	await quadros(10)
	ok(not captura.segurando() and mao.find_child("PokebolaNaMao", false, false) == null, "solta: o cubo some")
	ok(not jogador.has_meta("pokebola_na_mao"), "e a marca da mão sai")

	print("\n-- chance pela vida e pela raridade (08/11/2026) --")
	var a: Node3D = comuns[0]
	# O acampamento tem 19 marinheiros (e o Buggy): a bola acerta o PRIMEIRO no caminho. Isola o alvo para o teste.
	_isolar(a, jogador)
	jogador.global_position = a.global_position + Vector3(0, 0.5, 6.0)
	jogador.set("velocity", Vector3.ZERO)
	await quadros(30)
	var membros_antes: int = P.estado(prog).membros.size()
	var sempre_falha := 0.99999
	var sempre_passa := 0.0
	ok(sistema.avaliar(a) == sistema.Resultado.CAPTURADO, "qualquer vida pode ser alvo: não há mais o corte da vida vermelha")
	var cheia: Dictionary = _tentar_com(sistema, a, sempre_falha)
	ok(cheia["resultado"] == sistema.Resultado.ESCAPOU and P.estado(prog).membros.size() == membros_antes and a.health > 0.0, "sorteio ruim: escapou, nada muda")
	a.health = a.max_health * 0.10
	var baixa: Dictionary = _tentar_com(sistema, a, sempre_falha)
	ok(float(baixa["chance"]) > float(cheia["chance"]), "menos vida, mais chance (%.1f%% -> %.1f%%)" % [float(cheia["chance"]) * 100.0, float(baixa["chance"]) * 100.0])
	ok(sistema.mensagem(sistema.Resultado.NAO_CAPTURAVEL, a).contains("não pode"), "mensagem de alvo não capturável")
	a.health = a.max_health * 0.30
	ProbabilidadeDeCaptura.sorteio_fixo = sempre_falha

	print("\n-- vida vermelha: a bola captura --")
	a.health = a.max_health * 0.3                      # o tiro parcial acerta com o sorteio ruim e não captura
	a.process_mode = Node.PROCESS_MODE_DISABLED       # parado, para a bola não perseguir um alvo que anda
	var derrotado := [false]
	a.derrotado.connect(func(_p): derrotado[0] = true)
	# Giro e inclinação da câmera de frente para o alvo (yaw 0 olha para -Z).
	var d := a.global_position - jogador.global_position
	_mirar(jogador, a)
	await quadros(3)
	prog.ativar_item("pokebola")
	await quadros(5)
	var Capt: GDScript = load("res://src/historia/captura/captura_de_inimigos.gd")
	print("\n-- o arco: fórmula do BowItem (jar 1.20.1) --")
	ok(is_equal_approx(Capt.potencia_para(1.0), 1.0) and is_equal_approx(Capt.potencia_para(2.0), 1.0), "1 s puxando = potência cheia (e não passa de 1)")
	ok(absf(Capt.potencia_para(0.5) - 0.41667) < 0.001, "0,5 s = 0,417 ((0,25 + 1) / 3)")
	ok(Capt.potencia_para(0.10) < Capt.POTENCIA_MINIMA and Capt.potencia_para(0.15) >= Capt.POTENCIA_MINIMA, "o mínimo para atirar fica entre 0,10 s e 0,15 s")
	ok(absf(Capt.velocidade_para(1.0) - 52.8) < 0.01, "potência cheia = 3 blocos/tick = 52,8 m/s")

	print("\n-- puxar com o botão direito --")
	var cam_rig: Object = jogador.get("_camera")
	ok(captura.comecar_a_puxar() and captura.puxando(), "botão direito apertado começa a puxar")
	await quadros(3)
	ok(not captura.soltar() and not captura.puxando() and cena.get_node_or_null("PokebolaArremessada") == null, "soltar quase na hora só cancela (potência abaixo de 0,1)")
	ok(not jogador.has_meta("arco_fator_velocidade") and is_equal_approx(float(cam_rig.get("fator_fov")), 1.0), "e devolve velocidade e campo de visão")
	captura.comecar_a_puxar()
	await quadros(30)
	var braco_puxando: Vector3 = (jogador.get_meta("pose_de_skill", {}) as Dictionary).get("UpperArm_R", Vector3.ZERO)
	ok(jogador.has_meta("pose_da_captura") and absf(rad_to_deg(braco_puxando.x) - 180.0) < 2.0, "puxando, o braço direito sobe (UpperArm_R ≈ 180°: %.0f°)" % rad_to_deg(braco_puxando.x))
	ok(is_equal_approx(float(jogador.get_meta("arco_fator_velocidade", 1.0)), 0.2), "puxando, o movimento do jogador vai a 20 % (LocalPlayer × 0,2)")
	ok(absf(float(cam_rig.get("fator_fov")) - 0.925) < 0.012, "meio segundo puxando: o campo de visão fecha 7,5 %% (%.3f)" % float(cam_rig.get("fator_fov")))
	ok(absf(captura.potencia_atual() - 0.4167) < 0.04, "e a potência é ~0,42 (%.3f)" % captura.potencia_atual())
	ok(captura.soltar(), "soltar com potência suficiente atira")
	var bola_parcial: Node = cena.get_node_or_null("PokebolaArremessada")
	ok(bola_parcial != null and absf(bola_parcial.velocidade.length() - Capt.velocidade_para(0.4167)) < Capt.velocidade_para(0.4167) * 0.12 and not bola_parcial.critica,
		"a bola sai com velocidade proporcional à potência (%.1f m/s, sem crítico)" % (bola_parcial.velocidade.length() if bola_parcial != null else 0.0))
	await quadros(10)
	var braco_lancando: Vector3 = (jogador.get_meta("pose_de_skill", {}) as Dictionary).get("UpperArm_R", Vector3.ZERO)
	var cubo: Node = (jogador.get("_rig").get("item_handle") as Node3D).find_child("PokebolaNaMao", false, false)
	ok(absf(rad_to_deg(braco_lancando.x) - 90.0) < 2.0, "ao soltar, o braço vai à frente (UpperArm_R ≈ 90°: %.0f°)" % rad_to_deg(braco_lancando.x))
	ok(cubo != null and not cubo.visible, "e o cubo some da mão enquanto o braço está à frente")
	await quadros(50)
	ok(not captura.puxando() and not jogador.has_meta("arco_fator_velocidade") and is_equal_approx(float(cam_rig.get("fator_fov")), 1.0), "depois de atirar tudo volta ao normal")
	var cubo2: Node = (jogador.get("_rig").get("item_handle") as Node3D).find_child("PokebolaNaMao", false, false)
	ok(not jogador.has_meta("pose_da_captura") and not jogador.has_meta("pose_de_skill") and cubo2 != null and cubo2.visible, "o braço volta, a pose sai e o cubo reaparece na mão")
	P.estado(prog)   # a bola parcial acertou o marinheiro a 30 % com o sorteio ruim: escapou, nada muda
	ok(P.estado(prog).membros.size() == membros_antes and a.health > 0.0, "tiro com sorteio ruim (30 % de vida) não captura")

	print("\n-- cancelar puxando --")
	captura.comecar_a_puxar()
	await quadros(20)
	prog.ativar_item("luta")
	await quadros(3)
	ok(not captura.puxando() and not jogador.has_meta("arco_fator_velocidade"), "trocar de item enquanto puxa cancela, sem atirar")
	prog.ativar_item("pokebola")
	await quadros(3)

	print("\n-- tiro cheio com sorteio bom --")
	ProbabilidadeDeCaptura.sorteio_fixo = sempre_passa
	a.health = a.max_health * 0.2
	_isolar(a, jogador)
	_mirar(jogador, a)
	ok(captura.comecar_a_puxar(), "puxa de novo")
	await quadros(66)
	ok(captura.potencia_atual() >= 0.999 and absf(float(cam_rig.get("fator_fov")) - 0.85) < 0.01, "1 s puxando: potência cheia e campo de visão fechado em 15 %% (%.3f)" % float(cam_rig.get("fator_fov")))
	ok(captura.soltar(), "solta")
	var bola_cheia: Node = cena.get_node_or_null("PokebolaArremessada")
	ok(bola_cheia != null and bola_cheia.critica and absf(bola_cheia.velocidade.length() - 52.8) < 52.8 * 0.08,
		"tiro cheio = crítico a ~52,8 m/s (%.1f)" % (bola_cheia.velocidade.length() if bola_cheia != null else 0.0))
	await quadros(420)      # a animação de captura (bola cai, chacoalha, 3 estrelas) leva ~3 s antes de capturar
	var recrutas: Dictionary = prog.dados_de("recrutas")
	var novo := recrutas.values().filter(func(r): return r is Dictionary and str(r.get("modelo", "")) == "mp_marine")
	ok(not novo.is_empty() and P.estado(prog).membros.size() == membros_antes + 1,
		"capturado: virou membro com o modelo mp_marine (%d membros)" % P.estado(prog).membros.size())
	ok(derrotado[0] and not a.visible, "o corpo some pela morte normal (derrotado emitido)")

	print("\n-- chefe: não capturável --")
	chefe.health = chefe.max_health * 0.1
	ok(sistema.avaliar(chefe) == sistema.Resultado.NAO_CAPTURAVEL, "o Buggy (chefe) nunca é capturável, nem com vida vermelha")

	print("\n-- sem F: derrotado de verdade morre direto --")
	var b: Node3D = comuns[1]
	var morreu := [false]
	b.derrotado.connect(func(_p): morreu[0] = true)
	await _derrotar(jogador, b)
	ok(not b.get_meta("aguardando_recrutamento", false) and morreu[0], "marinheiro derrotado morre direto, sem esperar escolha")
	print("\n%d/%d" % [total - falhas, total])
	ProbabilidadeDeCaptura.sorteio_fixo = -1.0
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)


## A bola acerta o PRIMEIRO corpo no caminho e o acampamento está cheio: leva os outros inimigos para longe e os congela.
## Chamado de novo antes de cada tiro, porque alguns voltam ao posto sozinhos.
func _tentar_com(sistema: Node, alvo: Node3D, sorteio: float) -> Dictionary:
	ProbabilidadeDeCaptura.sorteio_fixo = sorteio
	var r: Dictionary = sistema.tentar(alvo, 1.0)
	ProbabilidadeDeCaptura.sorteio_fixo = -1.0
	return r


func _isolar(alvo: Node3D, jogador: Node3D) -> void:
	for outro in get_nodes_in_group("enemy"):
		if outro != alvo and outro != jogador and outro is Node3D:
			outro.process_mode = Node.PROCESS_MODE_DISABLED
			(outro as Node3D).global_position = Vector3(0, -800, 0)


## Aponta a câmera do jogador para o centro de `alvo` (giro e inclinação): a linha da mira tem de passar PELO alvo,
## como faria quem joga. O alvo pode estar mais baixo que o jogador; câmera na horizontal passaria por cima dele.
func _mirar(jogador: Node3D, alvo: Node3D) -> void:
	var cam: Camera3D = jogador.get("_cam")
	var d := AlvosDeGolpe.centro(alvo) - cam.global_position
	jogador.set("_yaw", atan2(-d.x, -d.z))
	var melhor := 0.0
	var melhor_cos := -2.0
	var passo := -0.8
	while passo <= 0.8:
		jogador.set("_pitch", passo)
		jogador.call("_update_pivot")
		var c := (-cam.global_basis.z).dot(d.normalized())
		if c > melhor_cos:
			melhor_cos = c
			melhor = passo
		passo += 0.01
	jogador.set("_pitch", melhor)
	jogador.call("_update_pivot")


## O jogador ao lado, e um golpe dele que zera a vida (a marca que o `CombatResolver` põe).
func _derrotar(jogador: Node3D, alvo: Node3D) -> void:
	jogador.global_position = alvo.global_position + Vector3(1.5, 0.5, 0)
	jogador.set("velocity", Vector3.ZERO)
	await quadros(30)
	alvo.set_meta("dano_do_jogador", true)
	alvo.call("take_damage", 99999.0, jogador.global_position)
	await quadros(3)
