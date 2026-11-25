extends SceneTree
## Entrada real, save isolado, rig/itens/animação e capturas opcionais na campanha.
const SAVE := "user://test_corpo_historia.json"
const PASTA := "res://art_src/validation/entrada_historia/"
var falhas := 0
var checks := 0
var modo: GDScript
var capturar := false


func _init() -> void:
	executar.call_deferred()


func executar() -> void:
	capturar = "--capturar" in OS.get_cmdline_user_args()
	modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	# Este teste exercita a TELA REAL de escolha. Em teste automatizado o jogo a pula sozinho (senão 263 testes travavam nela); aqui liga-se a interface de verdade.
	modo.exigir_escolha_de_corpo = true
	# Migração conserva o progresso; tipo inválido precisa de escolha explícita.
	var antigo := ProgressaoDoPersonagem.new().para_dict()
	antigo.erase("corpo")
	antigo["nivel"] = 17
	var migrado := ProgressaoDoPersonagem.de_dict(antigo)
	ok(migrado.corpo == "" and migrado.nivel == 17, "save antigo conserva nível e pede escolha")
	for invalido: Variant in ["outro", 2, null, {}, []]:
		antigo["corpo"] = invalido
		ok(ProgressaoDoPersonagem.de_dict(antigo).corpo == "", "tipo inválido não vira escolha silenciosa")
	ok(not migrado.definir_corpo("outro"), "setter rejeita opção inválida")
	ok(migrado.definir_corpo("feminino"), "setter aceita feminino")
	migrado.reiniciar()
	ok(migrado.corpo == "", "reinício limpa a escolha")
	for tipo: String in ["masculino", "feminino"]:
		var progresso := ProgressaoDoPersonagem.new()
		progresso.nivel = 17
		ok(progresso.salvar(SAVE) == OK, "prepara save isolado sem corpo")
		root.get_node("GameFlow").start_story()
		var tela := await esperar_tela()
		if tela == null:
			ok(false, "tela de escolha apareceu")
			quit(1)
			return
		ok(get_first_node_in_group("player") == null, "não nasce nem recebe input antes da escolha")
		ok((tela.find_child("Entrar", true, false) as Button).disabled, "entrada exige escolha explícita")
		await foto("01_selecao")
		(tela.find_child(tipo.capitalize(), true, false) as Button).pressed.emit()
		var tom := "muito_escuro" if tipo == "feminino" else "claro"
		(tela.find_child("Tom_" + tom, true, false) as Button).pressed.emit()
		(tela.find_child("Entrar", true, false) as Button).pressed.emit()
		ok(get_first_node_in_group("player") == null, "concluir personalização ainda espera Jogar")
		(current_scene.get_node("EntradaHistoria").find_child("Jogar", true, false) as Button).pressed.emit()
		var j := await esperar_jogador()
		if j == null:
			ok(false, "jogador nasceu")
			quit(1)
			return
		await quadros(80)
		var salvo := ProgressaoDoPersonagem.carregar(SAVE)
		ok(salvo.corpo == tipo and salvo.nivel == 17, tipo + ": escolha salva sem perder nível")
		ok(salvo.tom_de_pele == tom, tipo + ": tom escolhido persistiu no disco")
		ok(j.modelo_visual().get_meta("tom_de_pele", "") == tom, tipo + ": jogador nasceu com o tom escolhido")
		await validar_corpo(j, tipo)
		# Reentrada exibe a aparência salva e espera Jogar, sem exigir customizar de novo.
		root.get_node("GameFlow").back_to_menu()
		await quadros(4)
		root.get_node("GameFlow").start_story()
		var entrada := await esperar_entrada()
		ok(entrada != null and entrada.corpo == tipo and entrada.tom_de_pele == tom, "entrada recupera a aparência salva")
		if entrada:
			(entrada.find_child("Jogar", true, false) as Button).pressed.emit()
		j = await esperar_jogador()
		ok(j != null, tipo + ": reentrada pelo botão Jogar")
		if j:
			ok(j.modelo_visual().get_meta("corpo_historia", "") == tipo, tipo + ": corpo recuperado do disco")
			ok(j.modelo_visual().get_meta("tom_de_pele", "") == tom, tipo + ": tom recuperado na reentrada")
			ok(current_scene.get_node_or_null("EntradaHistoria") == null, "tela removida ao continuar campanha")
			if tipo == "feminino":
				current_scene.reiniciar_campanha()
				var nova_escolha := await esperar_tela()
				ok(nova_escolha != null, "reiniciar campanha reabre escolha")
				ok(current_scene.progressao.nivel == 1 and current_scene.progressao.corpo.is_empty(), "nova campanha limpa corpo e nível juntos")
				ok(current_scene.progressao.tom_de_pele == "medio", "nova campanha reinicia o tom de pele")
				if nova_escolha:
					(nova_escolha.find_child("Feminino", true, false) as Button).pressed.emit()
					(nova_escolha.find_child("Entrar", true, false) as Button).pressed.emit()
					(current_scene.get_node("EntradaHistoria").find_child("Jogar", true, false) as Button).pressed.emit()
					j = await esperar_jogador()
					ok(j != null and j.modelo_visual().get_meta("corpo_historia", "") == "feminino", "nova campanha nasce com a nova escolha")
		root.get_node("GameFlow").back_to_menu()
		await quadros(4)
	# Cancelar não escolhe nem sobrescreve um save antigo.
	var sem_corpo := ProgressaoDoPersonagem.new()
	sem_corpo.nivel = 9
	sem_corpo.salvar(SAVE)
	root.get_node("GameFlow").start_story()
	var cancelar := await esperar_tela()
	if cancelar:
		(cancelar.find_child("Tom_escuro", true, false) as Button).pressed.emit()
		(cancelar.find_child("Voltar", true, false) as Button).pressed.emit()
		(current_scene.get_node("EntradaHistoria").find_child("Voltar", true, false) as Button).pressed.emit()
		await quadros(10)
		ok(get_first_node_in_group("modo_historia") == null, "voltar fecha campanha sem spawn")
		var salvo := ProgressaoDoPersonagem.carregar(SAVE)
		ok(salvo.corpo.is_empty() and salvo.nivel == 9, "voltar preserva save e não assume masculino")
		ok(salvo.tom_de_pele == "medio", "cancelar não grava a prévia do tom")
	modo.mapa_forcado = ""
	modo.progresso_forcado = ""
	print("CORPO HISTORIA: %d/%d verificações passaram" % [checks - falhas, checks])
	quit(1 if falhas else 0)


func validar_corpo(j: Node3D, tipo: String) -> void:
	var rig: Node = j.get_node("PlayerRig")
	var modelo: Node3D = j.modelo_visual()
	var tom: String = current_scene.progressao.tom_de_pele
	ok(modelo.get_meta("corpo_historia", "") == tipo, tipo + ": PlayerRig usa o corpo selecionado")
	var braco := modelo.find_child("Braco", true, false) as MeshInstance3D
	ok(is_equal_approx(braco.mesh.get_aabb().size.x, .18 if tipo == "feminino" else .24), tipo + ": braço com largura de 3/4 pixels")
	var cabeca := modelo.find_child("Cabeca", true, false) as MeshInstance3D
	ok(cabeca.mesh.get_aabb().size.is_equal_approx(Vector3.ONE * .48), tipo + ": cabeça cúbica de 8 pixels")
	ok(modelo.find_child("Biceps", true, false) == null and modelo.find_child("Peitoral", true, false) == null, tipo + ": sem volumes musculares extras")
	ok(modelo.find_child("BustoR", true, false) != null if tipo == "feminino" else modelo.find_child("Abdominal", true, false) == null, tipo + ": busto preservado e abdômen agora na textura")
	ok(cabeca.material_override.albedo_texture != null, tipo + ": rosto integrado na textura")
	ok((modelo.find_child("CabeloLongo", true, false) != null) == (tipo == "feminino"), tipo + ": cabelo longo somente no feminino")
	var perfil := BodyScanner.scan(modelo)
	for papel: String in BodyScanner.ROLES:
		ok(perfil.nodes.has(papel), tipo + ": animação resolve " + papel)
	ok(RigDetalhado.tem_cadeia(perfil.nodes), tipo + ": cadeia detalhada disponível")
	for lado: String in ["L", "R"]:
		for dedo: String in ["Index", "Middle", "Ring", "Little", "Thumb"]:
			for falange in 3:
				ok(perfil.nodes.has("%s%d_%s" % [dedo, falange + 1, lado]), tipo + ": dedo articulado " + dedo + str(falange + 1) + lado)
		var encaixe: Node3D = rig.item_handle if lado == "R" else rig.item_handle_l
		var grip := modelo.find_child("Grip_" + lado, true, false) as Node3D
		ok(encaixe.global_position.distance_to(grip.global_position) < .0001, tipo + ": item na pega " + lado)
		var punho := modelo.find_child("Wrist_" + lado, true, false) as Node3D
		punho.rotation.x += .5
		ok(encaixe.global_position.distance_to(grip.global_position) < .0001, tipo + ": item acompanha o punho " + lado)
	var anterior := modelo.get_instance_id()
	j._setup_character_model("base")
	await quadros(3)
	modelo = j.modelo_visual()
	ok(modelo.get_instance_id() != anterior and modelo.get_meta("corpo_historia", "") == tipo, tipo + ": remontagem mantém aparência")
	ok(modelo.get_meta("tom_de_pele", "") == tom, tipo + ": remontagem mantém o tom")
	var hud: Node = current_scene.find_child("HistoriaHud", true, false)
	if hud:
		var mochila: Node = hud.mochila()
		mochila._previa.remontar()
		ok(mochila._previa.modelo.get_meta("tom_de_pele", "") == tom, tipo + ": mochila usa o tom salvo")
		var status: Node = hud.janela_de_status()
		status.abrir(j)
		ok(status._previa.modelo.get_meta("tom_de_pele", "") == tom, tipo + ": status usa o tom salvo")
	else:
		ok(false, "HUD disponível para validar as prévias")
	j._char_model.rotation.y = 0
	var camera: Camera3D
	if capturar:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		camera = Camera3D.new()
		current_scene.add_child(camera)
		camera.global_position = j.global_position + Vector3(1.7, .7, -3)
		camera.look_at(j.global_position + Vector3(0, -.02, 0))
		camera.fov = 38
		camera.make_current()
	await foto("02_" + tipo + "_campanha")
	var inicial := j.global_position
	Input.parse_input_event(tecla(KEY_W, true))
	await quadros(30)
	Input.parse_input_event(tecla(KEY_W, false))
	ok(j.global_position.distance_to(inicial) > .2, tipo + ": deslocamento real por W")
	await quadros(10)
	Input.parse_input_event(tecla(KEY_CTRL, true))
	await quadros(25)
	ok(j._agachar.ativo, tipo + ": agachamento integrado")
	if camera:
		camera.global_position = j.global_position + Vector3(1.7, .7, -3)
		camera.look_at(j.global_position + Vector3(0, -.02, 0))
	await foto("03_" + tipo + "_agachar")
	Input.parse_input_event(tecla(KEY_CTRL, false))
	await quadros(25)
	ok(not j._agachar.ativo, tipo + ": volta à postura em pé")
	j.net_force_respawn()
	await quadros(20)
	ok(j.modelo_visual().get_meta("corpo_historia", "") == tipo, tipo + ": respawn mantém escolha")
	ok(j.modelo_visual().get_meta("tom_de_pele", "") == tom, tipo + ": respawn mantém tom")
	if camera: camera.queue_free()


func tecla(codigo: Key, pressionado: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionado
	return ev


func esperar_tela() -> Node:
	var entrada := await esperar_entrada()
	if entrada:
		(entrada.find_child("Customizar", true, false) as Button).pressed.emit()
	for i in 600:
		await process_frame
		if current_scene:
			var tela := current_scene.find_child("EscolhaCorpoHistoria", true, false)
			if tela: return tela
	return null


func esperar_entrada() -> Node:
	for i in 600:
		await process_frame
		if current_scene:
			var tela := current_scene.get_node_or_null("EntradaHistoria")
			if tela: return tela
	return null


func esperar_jogador() -> Node3D:
	for i in 600:
		await process_frame
		var j := get_first_node_in_group("player") as Node3D
		if j: return j
	return null


func quadros(n: int) -> void:
	for i in n: await physics_frame


func foto(nome: String) -> void:
	if not capturar: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA + nome + ".png")


func ok(sim: bool, texto: String) -> void:
	checks += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + texto)
