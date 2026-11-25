extends SceneTree
const Bau := preload("res://src/inventario/bau_de_tesouros.gd")
const Naufragios := preload("res://src/historia/mar/naufragios.gd")
const SAVE := "user://test_bau_tesouros.json"
var checks := 0
var falhas := 0

func _init() -> void:
	executar.call_deferred()

func ok(cond: bool, texto: String) -> void:
	checks += 1
	if not cond: falhas += 1
	print(("OK: " if cond else "FALHOU: ") + texto)

func executar() -> void:
	var p := ProgressaoDoPersonagem.new()
	var n := Naufragios.new()
	n.progressao = p
	n.naufragios = {"teste": {"modelo": "naufragio_bote"}, "segundo": {"modelo": "naufragio_galeao"}}
	var inicial := p.ouro
	for slot in range(InventarioMinecraft.MOCHILA_INI, InventarioMinecraft.TOTAL):
		p.inventario.slots[slot] = InventarioMinecraft.nova("minecraft:diamond_sword")
	ok(not n.abrir("teste"), "mochila cheia recusa sem consumir o baú")
	ok(p.ouro == inicial and n._abertos().is_empty(), "falha não paga ouro nem marca aberto")
	p.inventario.slots[InventarioMinecraft.MOCHILA_INI] = InventarioMinecraft.vazia()
	ok(n.abrir("teste"), "espaço liberado permite recolher")
	ok(p.inventario.contar(Bau.ID) == 1 and p.ouro == inicial + 15, "recebe item e preserva recompensa original")
	ok(not n.abrir("teste") and p.inventario.contar(Bau.ID) == 1, "não duplica baú nem ouro")
	ok(n.abrir("segundo") and p.inventario.contar(Bau.ID) == 2, "segundo naufrágio empilha no mesmo espaço")
	ok(RegrasDeItens.limite(Bau.ID) == 16 and RegrasDeItens.peca_de_armadura(Bau.ID) == -1, "baú empilhável sem virar armadura")
	ok(RegrasDeItens.icone(Bau.ID) != null, "ícone importado e resolvido pelo inventário")
	var imagem := RegrasDeItens.icone(Bau.ID).get_image()
	ok(imagem.get_width() == 256 and imagem.get_pixel(0,0).a == 0, "ícone 256px com fundo transparente")
	ok(p.salvar(SAVE) == OK, "salva item no mesmo progresso da campanha")
	var salvo := ProgressaoDoPersonagem.carregar(SAVE)
	ok(salvo.inventario.contar(Bau.ID) == 2 and salvo.dados_de("mar").get("baus", []).size() == 2, "carrega inventário e baús abertos juntos")
	n.progressao = salvo
	ok(not n.abrir("teste"), "recarregar não permite segunda recompensa")
	var inv := InventarioMinecraft.new()
	inv.inserir(InventarioMinecraft.nova(Bau.ID, 17))
	ok(inv.pilha(36).quantidade == 16 and inv.pilha(37).quantidade == 1, "17 unidades separam em pilhas 16+1")
	inv.clique(36, 1)
	ok(inv.cursor.quantidade == 8 and inv.pilha(36).quantidade == 8, "clique direito divide a pilha")
	inv.clique(9)
	ok(inv.cursor.isEmpty() and inv.pilha(9).quantidade == 8, "arrastar move baús para a mochila")
	inv.clique(9, 0, true)
	ok(inv.contar(Bau.ID) == 17, "shift preserva a quantidade")
	n.free()
	var catalogo := CatalogoDeBlocos.new()
	root.add_child(catalogo)
	var p_catalogo := ProgressaoDoPersonagem.new()
	catalogo.ligar(p_catalogo)
	var botao := catalogo.find_child("Item_BauTesouros", true, false) as Button
	ok(botao != null and botao.icon != null, "baú disponível no catálogo com ícone")
	if botao:
		var clique := InputEventMouseButton.new()
		clique.button_index = MOUSE_BUTTON_RIGHT
		clique.pressed = true
		botao.gui_input.emit(clique)
		ok(p_catalogo.inventario.contar(Bau.ID) == 1, "botão direito do catálogo entrega um baú")
		clique.button_index = MOUSE_BUTTON_LEFT
		botao.gui_input.emit(clique)
		ok(p_catalogo.inventario.contar(Bau.ID) == 17, "clique esquerdo do catálogo entrega uma pilha de 16")
	catalogo.queue_free()
	if "--capturar" in OS.get_cmdline_user_args():
		await capturar_campanha()
	print("BAU_TESOUROS: %d/%d passaram" % [checks - falhas, checks])
	quit(1 if falhas else 0)

func capturar_campanha() -> void:
	var modo := load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	var p := ProgressaoDoPersonagem.new()
	p.corpo = "feminino"
	Bau.receber(p.inventario)
	p.salvar(SAVE)
	root.get_node("GameFlow").start_story()
	var jogador: Node3D
	for i in 600:
		await process_frame
		jogador = get_first_node_in_group("player") as Node3D
		if jogador: break
	ok(jogador != null, "campanha real com save isolado")
	if not jogador: return
	for i in 90: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	jogador._char_model.rotation.y = 0
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.global_position = jogador.global_position + Vector3(-1.7,.7,3)
	camera.look_at(jogador.global_position + Vector3(0,-.02,0))
	camera.fov = 38
	camera.make_current()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/bau_skins/05_cabelo_costas.png")
	var agachar := InputEventKey.new()
	agachar.physical_keycode = KEY_CTRL
	agachar.keycode = KEY_CTRL
	agachar.pressed = true
	Input.parse_input_event(agachar)
	for i in 25: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/bau_skins/06_cabelo_agachar.png")
	agachar.pressed = false
	Input.parse_input_event(agachar)
	for i in 25: await physics_frame
	var camada := CanvasLayer.new()
	camada.layer = 200
	current_scene.add_child(camada)
	var fundo := ColorRect.new()
	fundo.color = Color("182831")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(fundo)
	var titulo := Label.new()
	titulo.text = "Baú de tesouros — mochila do Modo História"
	titulo.position = Vector2(360,35)
	titulo.add_theme_font_size_override("font_size", 24)
	camada.add_child(titulo)
	var mochila := MochilaMinecraft.new()
	mochila.position = Vector2(350,100)
	camada.add_child(mochila)
	mochila.ligar(current_scene.progressao.inventario, current_scene.progressao)
	ok(mochila._icones[36].texture == Bau.icone(), "slot real da mochila mostra o ícone do baú")
	for i in 8: await process_frame
	ok(mochila._previa.modelo.get_meta("corpo_historia", "") == "feminino", "prévia da mochila usa a skin feminina da campanha")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/bau_skins/04_bau_inventario.png")
	camada.queue_free()
	modo.mapa_forcado = ""
	modo.progresso_forcado = ""
