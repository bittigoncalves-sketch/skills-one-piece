extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_treino_de_soco.gd
var p: Node3D
var boneco: Node3D
var treino
var prog
var passou := 0
var falhas := 0

func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func carregar_prog():
	return current_scene.progressao

func tecla_letra(letra: String) -> void:
	tecla(OS.find_keycode_from_string(letra), true)
	await frames(1)
	tecla(OS.find_keycode_from_string(letra), false)

func esperar_fase(f: int, max_frames := 200) -> bool:
	for i in max_frames:
		if treino.fase == f:
			return true
		await physics_frame
	return treino.fase == f

func sessao_completa(acertar := true) -> void:
	var guarda := 0
	while treino.fase != 5 and treino.fase != 0 and guarda < 2000:
		guarda += 1
		if treino.fase == 2:
			if acertar:
				await tecla_letra(treino.tecla_atual)
			else:
				await frames(80)
		else:
			await physics_frame

func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_treino_de_soco.json"))
	modo.set("progresso_forcado", "user://test_treino_de_soco.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	prog = current_scene.progressao
	treino = current_scene.get_node_or_null("TreinoDeSoco")
	ok("o nó do treino existe no Modo História", treino != null)
	# o boneco de treino (o do mapa de teste não tem; põe um com o nome que o treino procura)
	boneco = Node3D.new()
	boneco.name = "boneco_de_treino_t"
	var malha := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.8, 1.8, 0.8)
	malha.mesh = bm
	malha.position.y = 0.9
	boneco.add_child(malha)
	current_scene.add_child(boneco)
	boneco.global_position = Vector3(0, 0, -5)
	p.global_position = Vector3(0, 1, 0)
	await frames(10)

	print("\n-- tabela de missões --")
	var M = load("res://src/historia/missoes/missoes.gd")
	ok("só existe a missão 'treino'", M.TABELA.size() == 1 and M.existe("treino"))
	ok("as missões da cadeia da vara saíram", not M.existe("vara_inicial") and not M.existe("peixe_raro") and not M.existe("ferraria") and not M.existe("faccao_inicial") and not M.existe("bandidos"))
	ok("o jogador novo não começa com missão da vara", not prog.missoes.has("vara_inicial") and prog.estado_da_missao("treino") == "disponivel")
	var NPC = load("res://src/historia/npcs/npc_da_ilha.gd")
	ok("o instrutor tem a ficha e a missão do treino", NPC.FICHAS.has("npc_treinador") and NPC.FICHAS["npc_treinador"].missao == "treino")
	ok("pescador, ferreiro e guarda não dão mais missão", not NPC.FICHAS["npc_pescador"].has("missao") and not NPC.FICHAS["npc_ferreiro"].has("missao") and not NPC.FICHAS["npc_missao_bandidos"].has("missao"))

	print("\n-- regras (puras) --")
	var R = load("res://src/historia/treino/regras_do_treino.gd")
	ok("XP da sessão: 0 acertos = 0, 1 a 3 = 250, 4 a 6 = 500", R.xp_da_sessao(0) == 0 and R.xp_da_sessao(1) == 250 and R.xp_da_sessao(3) == 250 and R.xp_da_sessao(4) == 500 and R.xp_da_sessao(6) == 500)
	ok("nível 1 e 2 podem treinar, nível 3 é recusado", R.motivo_para_nao_treinar(prog) == "" and prog.nivel == 1)
	var nivel_salvo: int = prog.nivel
	prog.nivel = 3
	ok("ao ATINGIR o nível 3 o instrutor recusa com a fala da força excedida", R.motivo_para_nao_treinar(prog).contains("força excede"))
	prog.nivel = nivel_salvo

	print("\n-- sessão completa acertando tudo --")
	var xp0: int = prog.xp
	var niv0: int = prog.nivel
	ok("pode iniciar", treino.motivo_para_nao_iniciar() == "")
	var cam0 := root.get_viewport().get_camera_3d()
	var yaw_pos0: Vector3 = p.global_position
	ok("pedir_inicio começa (devolve vazio)", treino.pedir_inicio() == "")
	await frames(45)         # a câmera termina o movimento de entrada (0,7 s)
	ok("jogador congelado e câmera de treino ativa", bool(p.get_meta("is_frozen", false)) and root.get_viewport().get_camera_3d().name == "CameraDeTreino")
	ok("a câmera fica DO LADO do eixo jogador→boneco (perpendicular)", absf((root.get_viewport().get_camera_3d().global_position - p.global_position).normalized().dot((boneco.global_position - p.global_position).normalized())) < 0.5)
	var estourou := false
	var tremeu := false
	var boneco_mexeu := false
	var lascou := false
	var prompts_vistos := 0
	var antes_fase := -1
	var guarda := 0
	while treino.fase != 4 and treino.fase != 0 and guarda < 3000:
		guarda += 1
		if treino.fase == 2 and antes_fase != 2:
			prompts_vistos += 1
		antes_fase = treino.fase
		if treino.fase == 2:
			await tecla_letra(treino.tecla_atual)
		else:
			await physics_frame
		if treino.fase == 3:
			if treino.find_children("*", "MeshInstance3D", true, false).size() > 1:
				estourou = true
			if treino._tremor > 0.2:
				tremeu = true
			if not treino.find_children("Lasca", "MeshInstance3D", true, false).is_empty():
				lascou = true
			if not boneco.transform.is_equal_approx(treino._boneco_base):
				boneco_mexeu = true
	ok("viu %d prompts, os 6 aparecem" % prompts_vistos, prompts_vistos == 6)
	ok("cada soco criou partículas de impacto", estourou)
	ok("cada soco tremeu a tela", tremeu)
	ok("o boneco reagiu (balançou)", boneco_mexeu)
	ok("saltaram lascas de madeira no contato", lascou)
	ok("6 acertos", treino.acertos == 6)
	ok("XP pago: +500 e missão entregue", treino._resultado.get("xp", 0) == 500 and prog.estado_da_missao("treino") == "entregue" and treino._resultado.get("missao_entregue", false))
	var ganho: int = prog.xp - xp0
	for n in range(niv0, prog.nivel):
		ganho += int(prog.xp_para(n))
	ok("UMA fonte de XP: a primeira sessão pagou exatamente 500 (ganho medido %d)" % ganho, ganho == 500)
	var xp_pago_1: int = prog.xp
	treino._encerrar_sessao()           # sinal repetido: não paga de novo
	ok("encerrar a mesma sessão de novo não paga duas vezes", prog.xp == xp_pago_1 and R.treinos_feitos(prog) == 1)
	var d_save: Dictionary = prog.para_dict()
	var recarregado = ProgressaoDoPersonagem.de_dict(d_save)
	ok("o save guarda: missão entregue, 1 treino, mesmo nível e XP", recarregado.estado_da_missao("treino") == "entregue" and R.treinos_feitos(recarregado) == 1 and recarregado.nivel == prog.nivel and recarregado.xp == prog.xp)
	var xp_rec: int = recarregado.xp
	var niv_rec: int = recarregado.nivel
	var r2: Dictionary = R.concluir(recarregado, 6)
	var ganho2: int = recarregado.xp - xp_rec
	for n in range(niv_rec, recarregado.nivel):
		ganho2 += int(recarregado.xp_para(n))
	ok("depois de recarregar, a repetição paga 500 e NÃO reentrega a missão (ganho %d)" % ganho2, ganho2 == 500 and not r2.missao_entregue and R.treinos_feitos(recarregado) == 2)
	var r3: Dictionary = R.concluir(recarregado, 3)
	ok("1 a 3 acertos = 250 XP e 4+ = 500; 0 = nada e não conta", r3.xp == 250 and R.concluir(recarregado, 0).xp == 0 and R.treinos_feitos(recarregado) == 3)
	var antigo = ProgressaoDoPersonagem.new()
	antigo.nivel = 5
	antigo.xp = 7
	ok("save que já passou do limite sem fazer a missão: migra para 'entregue' sem pagar XP", R.migrar_save_acima_do_limite(antigo) and antigo.estado_da_missao("treino") == "entregue" and antigo.xp == 7 and not R.migrar_save_acima_do_limite(antigo))
	var novo_prog = ProgressaoDoPersonagem.new()
	ok("save abaixo do limite não migra (a missão continua disponível)", not R.migrar_save_acima_do_limite(novo_prog) and novo_prog.estado_da_missao("treino") == "disponivel")
	await frames(200)
	ok("terminou: fase parado, câmera de volta, jogador solto", treino.fase == 0 and root.get_viewport().get_camera_3d() != null and root.get_viewport().get_camera_3d().name != "CameraDeTreino" and not bool(p.get_meta("is_frozen", false)))
	ok("pose do soco removida e boneco de volta ao lugar", not p.has_meta("pose_de_skill") and boneco.transform.is_equal_approx(treino._boneco_base))
	ok("contou 1 treino", R.treinos_feitos(prog) == 1)

	print("\n-- erro, tempo e cancelar --")
	var xp1: int = prog.xp
	var niv1: int = prog.nivel
	ok("segunda sessão começa", treino.pedir_inicio() == "")
	await esperar_fase(2)
	var errada := "Z" if treino.tecla_atual != "Z" else "X"
	var indice0: int = treino.indice
	await tecla_letra(errada)
	ok("tecla errada: não soma acerto e passa ao próximo prompt", treino.acertos == 0 and treino.indice == indice0 + 1)
	await esperar_fase(2)
	var i1: int = treino.indice
	await frames(90)
	ok("estourar o tempo conta como erro e passa ao próximo", treino.indice > i1 and treino.acertos == 0)
	treino.cancelar()
	await frames(5)
	ok("cancelar não paga XP, solta o corpo e devolve a câmera", prog.xp == xp1 and prog.nivel == niv1 and treino.fase == 0 and not bool(p.get_meta("is_frozen", false)) and root.get_viewport().get_camera_3d().name != "CameraDeTreino")
	ok("Esc também cancela", treino.pedir_inicio() == "")
	await esperar_fase(2)
	tecla(KEY_ESCAPE, true)
	await frames(1)
	tecla(KEY_ESCAPE, false)
	await frames(5)
	ok("Esc: treino encerrado", treino.fase == 0 and not bool(p.get_meta("is_frozen", false)))

	print("\n-- sessão sem nenhum acerto não paga --")
	var feitos0: int = R.treinos_feitos(prog)
	ok("começa", treino.pedir_inicio() == "")
	await sessao_completa(false)
	await frames(200)
	ok("0 acertos = 0 XP e não conta como treino", R.treinos_feitos(prog) == feitos0 and prog.xp == xp1 and treino.fase == 0)

	print("\n-- repetir até o nível 3, depois recusa --")
	prog.nivel = 1
	prog.xp = 0
	var sessoes := 0
	while R.motivo_para_nao_treinar(prog) == "" and sessoes < 40:
		sessoes += 1
		ok("sessão %d (nível %d) começa" % [sessoes, prog.nivel], treino.pedir_inicio() == "")
		await sessao_completa(true)
		await frames(200)
	ok("depois de %d treinos o nível chegou a %d e o instrutor recusa" % [sessoes, prog.nivel], prog.nivel >= 3 and sessoes >= 2 and sessoes < 40)
	ok("pedir_inicio recusa com a fala de força excedida", treino.pedir_inicio().contains("força excede") and treino.fase == 0)
	ok("a missão continua entregue uma vez só e não reabre", prog.estado_da_missao("treino") == "entregue")

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("TREINO %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
