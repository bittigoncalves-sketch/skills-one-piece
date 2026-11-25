extends SceneTree
## Fluxo real com save existente, cancelamento, falha de gravação e avaliação do layout.
const SAVE := "user://test_entrada_historia.json"
const PASTA := "res://art_src/validation/entrada_historia/"
var falhas := 0
var checks := 0
var modo: GDScript


func _init() -> void:
	executar.call_deferred()


func executar() -> void:
	modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	modo.exigir_escolha_de_corpo = true
	var prog := ProgressaoDoPersonagem.new()
	prog.corpo = "masculino"
	prog.tom_de_pele = "moreno"
	prog.nivel = 17
	ok(prog.salvar(SAVE) == OK, "prepara campanha já existente")
	root.get_node("GameFlow").start_story()
	var entrada := await esperar_entrada()
	if entrada == null:
		ok(false, "entrada apareceu")
		quit(1)
		return
	await quadros(8)
	ok(get_first_node_in_group("player") == null, "mundo aguarda Jogar também com save existente")
	ok(entrada.corpo == "masculino" and entrada.tom_de_pele == "moreno", "entrada carrega aparência salva")
	var previa: Control = entrada._previa
	var jogar := entrada.find_child("Jogar", true, false) as Button
	var customizar := entrada.find_child("Customizar", true, false) as Button
	ok(jogar.get_global_rect().end.x < previa.global_position.x, "Jogar à esquerda do personagem")
	ok(customizar.get_global_rect().end.x < previa.global_position.x, "Customizar à esquerda do personagem")
	var largura := root.get_visible_rect().size.x
	ok(previa.get_global_rect().get_center().x > largura * .5, "personagem na metade direita")
	ok(jogar.get_global_rect().get_center().x < largura * .5, "ações na metade esquerda")
	var verde := jogar.get_theme_stylebox("normal") as StyleBoxTexture
	var vermelho := customizar.get_theme_stylebox("normal") as StyleBoxTexture
	ok(verde != null and verde.modulate_color.g > verde.modulate_color.r * 1.5, "Jogar continua verde após normalização")
	ok(vermelho != null and vermelho.modulate_color.r > vermelho.modulate_color.g * 1.5, "Customizar continua vermelho após normalização")
	ok(is_zero_approx(entrada._previa.modelo.rotation.y) and entrada._previa.camera.position.z < 0.0, "modelo frontal e câmera na frente")
	ok(entrada._previa.mouse_filter == Control.MOUSE_FILTER_IGNORE, "entrada mantém visão frontal fixa")
	await foto("01_entrada_masculino")
	customizar.pressed.emit()
	var editor: Node = entrada._editor
	ok(editor.corpo_inicial == "masculino" and editor.tom_de_pele == "moreno", "customização começa na aparência salva")
	ok(not entrada._conteudo.visible, "entrada fica oculta durante edição")
	(editor.find_child("Feminino", true, false) as Button).pressed.emit()
	(editor.find_child("Tom_muito_escuro", true, false) as Button).pressed.emit()
	await quadros(5)
	await foto("02_customizar")
	(editor.find_child("Voltar", true, false) as Button).pressed.emit()
	await quadros(2)
	ok(entrada.corpo == "masculino" and entrada.tom_de_pele == "moreno", "cancelar descarta rascunho")
	ok(entrada._conteudo.visible and entrada._editor == null, "cancelar retorna à entrada")
	customizar.pressed.emit()
	editor = entrada._editor
	(editor.find_child("Feminino", true, false) as Button).pressed.emit()
	(editor.find_child("Tom_muito_escuro", true, false) as Button).pressed.emit()
	(editor.find_child("Entrar", true, false) as Button).pressed.emit()
	await quadros(4)
	ok(get_first_node_in_group("player") == null, "concluir não inicia a campanha")
	ok(entrada._previa.modelo.get_meta("corpo_historia") == "feminino" and entrada._previa.modelo.get_meta("tom_de_pele") == "muito_escuro", "prévia frontal recebe a edição")
	ok(ProgressaoDoPersonagem.carregar(SAVE).corpo == "masculino", "edição aguarda Jogar para gravar")
	await foto("03_entrada_feminino")
	(entrada.find_child("Voltar", true, false) as Button).pressed.emit()
	await quadros(6)
	ok(ProgressaoDoPersonagem.carregar(SAVE).corpo == "masculino", "voltar ao menu preserva save mesmo após concluir edição")
	root.get_node("GameFlow").start_story()
	entrada = await esperar_entrada()
	if entrada == null:
		ok(false, "entrada reaparece")
		quit(1)
		return
	(entrada.find_child("Customizar", true, false) as Button).pressed.emit()
	editor = entrada._editor
	(editor.find_child("Feminino", true, false) as Button).pressed.emit()
	(editor.find_child("Tom_muito_escuro", true, false) as Button).pressed.emit()
	(editor.find_child("Entrar", true, false) as Button).pressed.emit()
	# Força falha de gravação num diretório, sem tocar no save do jogador.
	modo.progresso_forcado = "user://"
	(entrada.find_child("Jogar", true, false) as Button).pressed.emit()
	ok(current_scene.progressao.corpo == "masculino" and current_scene.progressao.tom_de_pele == "moreno", "falha de save restaura ambos os campos em memória")
	ok(not entrada._jogar.disabled and not entrada._customizar.disabled, "falha permite tentar novamente ou editar")
	ok(get_first_node_in_group("player") == null, "falha de save não inicia partida")
	modo.progresso_forcado = SAVE
	(entrada.find_child("Jogar", true, false) as Button).pressed.emit()
	var jogador: Node
	for i in 700:
		await process_frame
		jogador = get_first_node_in_group("player")
		if jogador: break
	ok(jogador != null, "Jogar inicia campanha")
	if jogador:
		ok(jogador.modelo_visual().get_meta("corpo_historia") == "feminino" and jogador.modelo_visual().get_meta("tom_de_pele") == "muito_escuro", "jogador usa a nova aparência")
		var inventario: Node = current_scene.find_child("Inventario", true, false)
		ok(inventario != null and inventario.embutido and not inventario._cabeca.visible, "painel da mochila termina de inicializar antes de aplicar modo embutido")
	var salvo := ProgressaoDoPersonagem.carregar(SAVE)
	ok(salvo.nivel == 17 and salvo.corpo == "feminino" and salvo.tom_de_pele == "muito_escuro", "customização salva sem reiniciar progresso")
	ok(current_scene.get_node_or_null("EntradaHistoria") == null, "entrada é removida ao jogar")
	root.get_node("GameFlow").back_to_menu()
	await quadros(5)
	modo.mapa_forcado = ""
	modo.progresso_forcado = ""
	modo.exigir_escolha_de_corpo = false
	print("ENTRADA HISTORIA: %d/%d verificações passaram" % [checks - falhas, checks])
	quit(1 if falhas else 0)


func esperar_entrada() -> Node:
	for i in 600:
		await process_frame
		if current_scene:
			var tela := current_scene.get_node_or_null("EntradaHistoria")
			if tela: return tela
	return null


func quadros(n: int) -> void:
	for i in n: await process_frame


func foto(nome: String) -> void:
	if "--capturar" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	ok(root.get_texture().get_image().save_png(PASTA + nome + ".png") == OK, "captura " + nome)


func ok(sim: bool, texto: String) -> void:
	checks += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + texto)
