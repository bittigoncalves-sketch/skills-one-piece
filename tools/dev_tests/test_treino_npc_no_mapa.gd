extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_treino_npc_no_mapa.gd
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

func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_treino_npc.json"))
	modo.set("progresso_forcado", "user://test_treino_npc.json")
	root.get_node("GameFlow").start_story()
	for i in 1800:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get_node_or_null("TreinoDeSoco") != null:
			break
	await frames(60)
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	prog = current_scene.progressao
	treino = current_scene.get_node("TreinoDeSoco")
	p.global_position = Vector3(27.0, 6.0, -8.0)
	await frames(240)
	var npcs = current_scene.get_node_or_null("NpcsDaIlha")
	var instrutor: Node3D = null
	for n in current_scene.find_children("*", "NpcDaIlha", true, false):
		if n.tipo == "npc_treinador":
			instrutor = n
	ok("o instrutor existe no mapa real", instrutor != null)
	ok("ele nasceu junto do centro de treino (centro em 27, -14,2; fica na frente dele): a %.1f m" % (instrutor.global_position.distance_to(Vector3(27.0, 4.9, -14.155)) if instrutor != null else -1.0), instrutor != null and instrutor.global_position.distance_to(Vector3(27.0, 4.9, -14.155)) < 12.0)
	ok("nenhum NPC de missão antiga sobrou (só o instrutor tem missão)", current_scene.find_children("*", "NpcDaIlha", true, false).all(func(n): return n.missao().is_empty() or n.tipo == "npc_treinador"))
	ok("a missão da vez do instrutor é o treino", instrutor != null and instrutor.missao(prog) == "treino")
	var loja = instrutor.loja()
	loja.set("progressao", prog)
	var linhas: Array = loja.linhas(prog, null)
	ok("a janela oferece o treino com o botão Treinar ativo (nível %d)" % prog.nivel, linhas.size() == 2 and linhas[0].botoes.is_empty() and String(linhas[0].detalhe).contains("Acerte a tecla indicada") and linhas[1].botoes.size() == 1 and linhas[1].botoes[0].texto == "Treinar" and linhas[1].botoes[0].ativo)
	ok("a janela fecha ao treinar", loja.fecha_a_janela())
	ok("a fala do instrutor é a oferta (primeiro treino)", loja.fala().contains("Quer aprender a lutar"))
	var detalhe_txt := String(linhas[1].detalhe)
	ok("o detalhe não promete 500 XP garantidos: explica 500 / 250 / 0 (%s)" % detalhe_txt, detalhe_txt.contains("500") and detalhe_txt.contains("250") and detalhe_txt.contains("nenhum = 0") and not detalhe_txt.contains("+500"))
	ok("a oferta da missão diz 'até 500'", load("res://src/historia/missoes/missoes.gd").TABELA["treino"].oferta.contains("até 500"))
	p.global_position = Vector3(29.43, 5.5, -7.5)
	await frames(30)
	var r: String = loja.executar(prog, null, "treinar", "treino")
	ok("Treinar inicia o minigame (devolve '%s')" % r, r == "" and treino.ativo())
	await frames(30)
	treino.cancelar()
	await frames(5)
	prog.nivel = 3
	linhas = loja.linhas(prog, null)
	ok("no nível 3 o botão fica desligado e o detalhe é a recusa", not linhas[1].botoes[0].ativo and String(linhas[1].detalhe).contains("força excede"))
	ok("e a fala do instrutor é a recusa", loja.fala().contains("força excede"))
	r = loja.executar(prog, null, "treinar", "treino")
	ok("treinar no nível 3 devolve a recusa e não inicia", r.contains("força excede") and not treino.ativo())
	modo.set("progresso_forcado", "")
	print("TREINO_NPC %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
