extends SceneTree
## Integração real: inventário → barra → executor → lâmina → alvo. Save isolado.
const PROGRESSO := "user://test_espada_historia.json"
var falhas := 0
var total := 0
var jogador: Node
var boneco: Node
var prog: RefCounted
var ex: Node
var tela := false
var capturas := "/tmp/sop-espada-20261006/capturas"

func _init() -> void:
	_executar.call_deferred()

func verificar(sim: bool, msg: String) -> void:
	total += 1
	print(("OK " if sim else "FALHA ") + msg)
	if not sim:
		falhas += 1

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _executar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):
			capturas = argumento.trim_prefix("--capturas=")
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", PROGRESSO)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	# Este teste começa com personagem já escolhido; seleção tem teste próprio.
	var personagem = ProgressaoDoPersonagem.carregar(PROGRESSO)
	personagem.corpo = "masculino"
	personagem.salvar(PROGRESSO)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	jogador = get_first_node_in_group("player")
	if jogador == null:
		verificar(false, "jogador nasceu")
		quit(1)
		return
	prog = current_scene.progressao
	ex = jogador.combate_direcional
	var inventario: Node = current_scene._hud.inventario()
	var arma: Node = jogador.get_node("EspadaDaHistoria")
	prog.ganhar_equipamento("espada")        # o personagem novo começa só com as lâminas do Epic Fight (10/11/2026): a espada da história entra como achado
	verificar(prog.equipamentos.has("espada") and not prog.espada_equipada, "item inicial guardado")
	verificar(not prog.itens_da_barra().has("espada") and not prog.espada_equipada, "começa com mãos livres")
	inventario.mostrar_aba("armas")
	if tela:
		DirAccess.make_dir_recursive_absolute(capturas)
		await foto("antes_maos_livres")
		current_scene._hud.alternar_inventario()
		await foto("inventario_armas")
		current_scene._hud.alternar_inventario()
	var botao_equipar = inventario.find_child("EquiparEspada", true, false)
	if botao_equipar != null:
		botao_equipar.pressed.emit()
	else:
		prog.equipar_espada(true)      # o inventário estilo Minecraft não tem mais o botão "EquiparEspada": o mesmo caminho da aba ARMAS
	await quadros(5)
	verificar(prog.item_em_uso() == "espada" and prog.espada_equipada, "botão equipa e ativa")
	verificar(prog.itens_da_barra().has("espada") and jogador.capacidades.can_attack, "barra e capacidade de atacar")
	verificar(ex.estilo.id == &"espada" and ex.estilo.validar().is_empty(), "ficha de espada válida: " + str(ex.estilo.validar()))
	verificar(not jogador.capacidades.can_use_skills, "não libera técnicas da arena")
	if tela:
		await quadros(20)
		await foto("equipada")
	verificar(jogador.modelo_visual().find_children("EspadaInicial", "", true, false).size() == 1, "uma espada na mão")
	prog.salvar(PROGRESSO)        # o autosave é espaçado: grava na hora e confere a ida e volta
	var salvo = load("res://src/historia/progressao.gd").carregar(PROGRESSO)
	# a espada da história sem lâmina do Epic Fight não é restaurada ao carregar (serializacao_do_progresso.gd: item ativo "espada" volta a "luta"): a posse persiste, a mão não
	verificar(not salvo.espada_equipada and salvo.item_em_uso() != "espada", "carregar o save larga a espada da mão (volta às mãos livres)")
	var antigo: Dictionary = prog.para_dict()
	antigo.erase("espada_equipada")
	antigo["equipamentos"] = {}
	var migrado = load("res://src/historia/progressao.gd").de_dict(antigo)
	verificar(not migrado.espada_equipada and migrado.equipamentos.has(LaminasEpicFight.ids()[0]), "save antigo recebe as lâminas do Epic Fight e nada na mão")
	boneco = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.vida_maxima = 100000.0
	boneco.position = Vector3(0, 0.8, -5)
	current_scene.add_child(boneco)
	await quadros(20)
	if tela:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		verificar(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse capturado para clique real")
	for direcao in 4:
		await posicionar(1.35)
		var antes: float = boneco.health
		var golpe = ex.estilo.golpe_para(direcao)
		if tela:
			var entrada: Node = jogador.entrada_combate_direcional
			entrada.esquecer_gesto()
			var gestos := [Vector2.ZERO, Vector2(-30, 0), Vector2(30, 0), Vector2(0, -30)]
			entrada.registrar_movimento(gestos[direcao], Time.get_ticks_msec())
			var clique := InputEventMouseButton.new()
			clique.button_index = MOUSE_BUTTON_LEFT
			clique.pressed = true
			jogador._unhandled_input(clique)
			verificar(ex.atacando() and ex.golpe_atual.direcao == direcao, "clique escolhe direção %d" % direcao)
		else:
			verificar(ex.pedir_ataque(direcao), "aceitou golpe %d" % direcao)
		if tela:
			while ex.atacando() and ex.tempo_da_acao() < golpe.preparo + golpe.ativo * 0.5:
				await quadros(1)
			ex.pausar(0.3)
			await foto("golpe_%d" % direcao)
		await quadros(100)
		var bonus := float(jogador.get_meta("bonus_fisico_historia", 0.0))        # a Força do nível soma ao dano físico (7/11/2026)
		verificar(is_equal_approx(antes - boneco.health, golpe.dano + bonus), "direção %d: dano uma vez = %.1f (esperado %.1f)" % [direcao, antes - boneco.health, golpe.dano + bonus])
	# Troca de aparência recria a mão. A arma deve acompanhar sem duplicar nem perder dano.
	jogador._setup_character_model("base")
	await quadros(5)
	verificar(jogador.modelo_visual().find_children("EspadaInicial", "", true, false).size() == 1 and arma.ponto(&"EspadaPonta") != Vector3.INF,
		"troca de modelo remonta arma e efetor")
	await posicionar(1.35)
	var parede := StaticBody3D.new()
	var colisao := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(3, 3, 0.12)
	colisao.shape = caixa
	parede.add_child(colisao)
	current_scene.add_child(parede)
	parede.global_position = Vector3(0, 1.5, -0.65)
	await quadros(3)
	var vida_parede: float = boneco.health
	ex.pedir_ataque(0)
	await quadros(80)
	verificar(is_equal_approx(vida_parede, boneco.health), "controle: parede entre lâmina e alvo bloqueia dano")
	parede.queue_free()
	await quadros(2)
	await posicionar(4.0)
	var antes: float = boneco.health
	ex.pedir_ataque(0)
	await quadros(80)
	verificar(is_equal_approx(antes, boneco.health), "controle: longe não acerta")
	await posicionar(1.35)
	antes = boneco.health
	ex.pedir_ataque(0)
	await quadros(3)
	prog.ativar_item("luta")
	verificar(not ex.pedir_ataque(0), "trocar de item não burla recuperação do ataque")
	await quadros(80)
	verificar(is_equal_approx(antes, boneco.health) and ex.estilo.id == &"boxe", "troca no preparo cancela dano e volta ao boxe")
	verificar(arma.ponto(&"EspadaPonta") == Vector3.INF and jogador.modelo_visual().find_children("EspadaInicial", "", true, false).is_empty(), "guardar retira visual e contato")
	prog.ativar_item("espada")
	await posicionar(1.35)
	boneco.combate_direcional.erguer_guarda()
	await quadros(20) # passou janela de aparo
	antes = boneco.health
	var postura: float = boneco.combate_direcional.postura
	ex.pedir_ataque(0)
	await quadros(65)
	verificar(is_equal_approx(antes, boneco.health) and boneco.combate_direcional.postura < postura, "defesa bloqueia espada e perde postura")
	boneco.combate_direcional.baixar_guarda()
	await quadros(30)
	await posicionar(1.35)
	antes = boneco.health
	ex.pedir_ataque(0)
	while ex.tempo_da_acao() < 0.20:
		await quadros(1)
	boneco.combate_direcional.erguer_guarda()
	await quadros(60)
	verificar(is_equal_approx(antes, boneco.health), "aparo no tempo certo impede dano de espada")
	# Um mesmo botão seleciona o item da barra, e o segundo aperto volta às mãos livres.
	if tela:
		var tecla := InputEventKey.new()
		tecla.keycode = KEY_2
		tecla.physical_keycode = KEY_2
		tecla.pressed = true
		Input.parse_input_event(tecla)
		await quadros(3)
		tecla = InputEventKey.new()
		tecla.keycode = KEY_2
		tecla.physical_keycode = KEY_2
		tecla.pressed = false
		Input.parse_input_event(tecla)
		verificar(prog.item_em_uso() == "luta", "tecla da espada ativa guarda a arma")
	for i in 5:
		inventario.equipar_espada(false)
		inventario.equipar_espada(true)
	await quadros(5)
	verificar(jogador.modelo_visual().find_children("EspadaInicial", "", true, false).size() == 1, "reequipar 5 vezes não duplica arma")
	ex.quebrar_guarda(ex.estilo.golpes[0])
	prog.ativar_item("luta")
	verificar(ex.estado == ex.Estado.QUEBRA and not ex.pedir_ataque(0), "troca de arma preserva quebra de guarda")
	inventario.equipar_espada(false)
	verificar(not prog.itens_da_barra().has("espada") and prog.item_em_uso() == "luta", "desequipar retira da barra")
	inventario.equipar_espada(true)
	prog.reiniciar()
	verificar(not prog.espada_equipada and ex.estilo.id == &"boxe", "nova campanha volta às mãos livres (o personagem novo só tem as lâminas do Epic Fight)")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("ESPADA HISTÓRIA: %d/%d verificações passaram" % [total - falhas, total])
	quit(1 if falhas else 0)

func posicionar(distancia: float) -> void:
	ex.cancelar(&"teste")
	boneco.combate_direcional.cancelar(&"teste")
	boneco.combate_direcional.baixar_guarda()
	boneco.global_position = Vector3(0, 0.8, -5)
	jogador.global_position = Vector3(0, 0.8, 0)
	jogador.velocity = Vector3.ZERO
	jogador._yaw = 0.0
	jogador._pitch = -0.15
	jogador.modelo_visual().rotation.y = 0.0
	await quadros(10)
	boneco.parar()
	boneco.global_position = Vector3(0, jogador.global_position.y, -distancia)
	boneco.encarar_yaw(PI)
	boneco.modelo_visual().rotation.y = PI
	await quadros(15)

func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capturas.path_join(nome + ".png"))
	# Vista complementar: avalia a pega/trajectória sem o corpo encobrir a lâmina.
	if nome.begins_with("golpe"):
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.global_position = jogador.global_position + Vector3(3, 1.0, -2.8)
		camera.look_at(jogador.global_position + Vector3(0, 0.35, -0.5))
		camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capturas.path_join(nome + "_lateral.png"))
		camera.clear_current(true)
		camera.queue_free()
