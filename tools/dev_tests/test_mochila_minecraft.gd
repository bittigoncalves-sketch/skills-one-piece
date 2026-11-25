extends SceneTree
## Janela da mochila estilo Minecraft: layout vanilla medido, clique/shift/número via eventos de mouse, item preso ao cursor, ícones, página MOCHILA no jogo,
## integração (biscoito entregue pelo mod entra no inventário e some ao gastar; salvar/carregar; equipamento empurrado à camada do mod).
##   godot --headless --path . --script tools/dev_tests/test_mochila_minecraft.gd
const MAPA := "user://test_mochila.json"
const SAVE := "user://test_mochila_p.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _botao(w: MochilaMinecraft, i: int, botao: int, shift := false) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = botao
	e.pressed = true
	e.shift_pressed = shift
	e.position = (MochilaMinecraft.posicao_do_slot(i) + Vector2(8, 8)) * w.escala
	w._gui_input(e)
func _mover(w: MochilaMinecraft, i: int) -> void:
	var e := InputEventMouseMotion.new()
	e.position = (MochilaMinecraft.posicao_do_slot(i) + Vector2(8, 8)) * w.escala
	w._gui_input(e)
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var M := MochilaMinecraft
	# ---- layout PRÓPRIO (19/11/2026: deixou de ser o do vanilla)
	ok(M.posicao_do_slot(0) == Vector2(124, 45) and M.posicao_do_slot(1) == Vector2(66, 36) and M.posicao_do_slot(4) == Vector2(84, 54), "resultado (124,45) e grade 2×2 (66/84, 36/54)")
	ok(M.posicao_do_slot(5) == Vector2(66, 8) and M.posicao_do_slot(8) == Vector2(120, 8) and M.posicao_do_slot(45) == Vector2(146, 8), "equipamento em tira horizontal (x 66…120, y=8) e mão secundária (146,8)")
	ok(M.posicao_do_slot(9) == Vector2(8, 78) and M.posicao_do_slot(35) == Vector2(152, 114) and M.posicao_do_slot(36) == Vector2(8, 138) and M.posicao_do_slot(44) == Vector2(152, 138), "mochila 3×9 (y 78/96/114) e hotbar (y 138)")
	var sem_sobreposicao := true
	for i in InventarioMinecraft.TOTAL:
		var ri := Rect2(M.posicao_do_slot(i), Vector2(16, 16))
		sem_sobreposicao = sem_sobreposicao and Rect2(Vector2.ZERO, Vector2(M.LARGURA, M.ALTURA)).encloses(ri) and not ri.intersects(M.PREVIA)
		for j in range(i + 1, InventarioMinecraft.TOTAL):
			sem_sobreposicao = sem_sobreposicao and not ri.intersects(Rect2(M.posicao_do_slot(j), Vector2(16, 16)))
	ok(sem_sobreposicao, "nenhum slot se sobrepõe, cai fora da mochila ou invade a prévia do personagem")
	# ---- janela solta
	var inv := InventarioMinecraft.new()
	var w := M.new()
	root.add_child(w)
	w.ligar(inv)
	await process_frame
	ok(w.find_child("Fundo", true, false) == null, "o fundo é desenhado em código (moldura própria), sem a textura inventory.png do Mojang")
	ok(w.slot_em((M.posicao_do_slot(20) + Vector2(8, 8)) * w.escala) == 20 and w.slot_em(Vector2(2, 2) * w.escala) == -1, "slot_em acha o slot sob o mouse")
	inv.inserir(InventarioMinecraft.nova("minecraft:stone", 20))
	inv.inserir(InventarioMinecraft.nova("minecraft:iron_helmet", 1))
	await process_frame
	var tex_pedra: Texture2D = w._icones[InventarioMinecraft.HOTBAR_INI].texture
	ok(tex_pedra != null and w._numeros[InventarioMinecraft.HOTBAR_INI].text == "20", "slot mostra o ícone (textura do jar) e a quantidade")
	_mover(w, InventarioMinecraft.HOTBAR_INI)
	ok(w._dica.visible and w._dica.text.begins_with("Stone"), "dica com o nome ao passar o mouse (%s)" % w._dica.text.get_slice("\n", 0))
	_botao(w, InventarioMinecraft.HOTBAR_INI, MOUSE_BUTTON_LEFT)
	ok(inv.cursor.quantidade == 20 and w._cursor.visible and w._cursor_icone.texture != null, "clique esquerdo pega a pilha: o item vai preso ao cursor")
	_botao(w, InventarioMinecraft.MOCHILA_INI + 4, MOUSE_BUTTON_LEFT)
	ok(inv.pilha(InventarioMinecraft.MOCHILA_INI + 4).quantidade == 20 and inv.cursor.isEmpty() and not w._cursor.visible, "clique esquerdo solta no slot")
	_botao(w, InventarioMinecraft.MOCHILA_INI + 4, MOUSE_BUTTON_RIGHT)
	ok(inv.cursor.quantidade == 10, "clique direito pega a metade")
	_botao(w, InventarioMinecraft.MOCHILA_INI + 4, MOUSE_BUTTON_LEFT)
	_botao(w, InventarioMinecraft.HOTBAR_INI + 1, MOUSE_BUTTON_LEFT, true)           # shift: hotbar → mochila (o capacete sai do 2º slot da hotbar)
	ok(inv.pilha(InventarioMinecraft.HOTBAR_INI + 1).isEmpty() and InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.ARMADURA_INI)) == "minecraft:iron_helmet",
		"shift no capacete o leva direto para o slot da cabeça")
	# número: troca com a hotbar
	inv.slots[InventarioMinecraft.MOCHILA_INI + 8] = InventarioMinecraft.nova("minecraft:apple", 3)
	_mover(w, InventarioMinecraft.MOCHILA_INI + 8)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_6
	k.pressed = true
	w._gui_input(k)
	ok(InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI + 5)) == "minecraft:apple", "tecla 6 troca o slot sob o mouse com o 6º da hotbar")
	# grade 2×2 + resultado pela janela
	inv.slots[1] = InventarioMinecraft.nova("minecraft:oak_log", 1)
	inv._avisar()
	_botao(w, 0, MOUSE_BUTTON_LEFT)
	ok(InventarioMinecraft.id_de(inv.cursor) == "minecraft:oak_planks" and inv.cursor.quantidade == 4, "pegar o resultado da grade: 4 tábuas no cursor")
	inv.cursor = InventarioMinecraft.vazia()
	# ---- no jogo: página MOCHILA e integração com o mod
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var prog: ProgressaoDoPersonagem = m.get("progressao")
	var j: Node3D = get_first_node_in_group("player")
	var hud = get_first_node_in_group("hud")
	ok(hud.mochila() != null and hud.central().find_child("Aba_mochila", true, false) != null, "a central tem a aba MOCHILA")
	var e := McEntidade.de(j)
	Mc.estatico(&"ItemHandlerHelper", &"giveItemToPlayer", [e, McItem.pilha(Mc.item(&"minepiece:biscuit"), 5)])
	ok(prog.inventario.contar("minepiece:biscuit") == 5 and prog.item_do_mod("minepiece:biscuit") == 5, "biscoito entregue pelo mod entra no inventário real")
	ok(prog.gastar_item_do_mod("minepiece:biscuit", 2) and prog.inventario.contar("minepiece:biscuit") == 3, "gastar tira do inventário")
	var h = e.getCapability(Mc.campo(&"ForgeCapabilities", &"ITEM_HANDLER"), null).orElse(null)
	var achou := false
	for i in h.getSlots():
		if InventarioMinecraft.id_de(h.getStackInSlot(i)) == "minepiece:biscuit":
			achou = true
	ok(achou, "o IItemHandler do jogador enxerga a mochila (ReturnHaveItem do mod acha o biscoito)")
	var jm = j.get_node_or_null("JogadorDoMod")
	prog.inventario.slots[InventarioMinecraft.HOTBAR_INI + 8] = InventarioMinecraft.nova("minecraft:iron_sword", 1)
	prog.inventario.selecionado = 8
	prog.inventario.slots[InventarioMinecraft.ARMADURA_INI + 1] = InventarioMinecraft.nova("minecraft:iron_chestplate", 1)
	prog.inventario.mudou.emit()
	ok(jm != null and str(e.getMainHandItem().item.id) == "minecraft:iron_sword" and str(e.getItemBySlot(&"CHEST").item.id) == "minecraft:iron_chestplate",
		"hotbar selecionada e armadura viram o equipamento da camada do mod")
	# E abre e fecha a mochila (sem NPC por perto); o E antigo (Observação) não dispara no Modo História
	var aim0: bool = j.get("aim_assist")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_E
	tecla.keycode = KEY_E
	tecla.pressed = true
	hud._unhandled_input(tecla)
	ok(hud.central_aberta() and hud.central().aba == "mochila", "E abre a central direto na aba MOCHILA")
	ok(j.get("aim_assist") == aim0, "o E antigo (Observação) não dispara junto no Modo História")
	ok(hud.is_menu_open(), "mochila aberta conta como menu aberto (o mouse é solto e a câmera não gira; o modo do mouse não existe em headless)")
	var e_pequena := MochilaMinecraft.escala_que_cabe(Vector2(300, 250))
	var e_grande := MochilaMinecraft.escala_que_cabe(Vector2(1000, 560))
	ok(e_pequena >= 1.0 and e_pequena * MochilaMinecraft.ALTURA <= 250.0 and e_grande > e_pequena and e_grande * MochilaMinecraft.ALTURA <= 560.0, "escala acompanha o espaço da página (%.2f em 300x250, %.2f em 1000x560)" % [e_pequena, e_grande])
	await quadros(3)
	var pag: ScrollContainer = hud.mochila()._pagina()
	ok(pag != null and hud.mochila().size.y <= pag.size.y + 1.0, "a mochila cabe na página da central (%.0f de %.0f)" % [hud.mochila().size.y, pag.size.y if pag else 0.0])
	hud._input(tecla)
	ok(not hud.central_aberta(), "E de novo fecha a mochila")
	var fantasma_cabeca: Texture2D = hud.mochila()._icones[InventarioMinecraft.ARMADURA_INI].texture
	ok(prog.inventario.pilha(InventarioMinecraft.ARMADURA_INI).isEmpty() and fantasma_cabeca != null, "slot de capacete vazio mostra o ícone-fantasma do capacete")
	ok(hud.mochila().find_child("Titulo_Fabricar", true, false) != null and hud.mochila().find_child("Titulo_Crafting", true, false) == null, "o título é o próprio (Fabricar), não o Crafting do vanilla")
	# salvar e recarregar o personagem
	var arq := "user://test_mochila_salvo.json"
	prog.salvar(arq)
	var carregado := ProgressaoDoPersonagem.carregar(arq)
	ok(carregado.inventario.contar("minepiece:biscuit") == 3 and InventarioMinecraft.id_de(carregado.inventario.pilha(InventarioMinecraft.ARMADURA_INI + 1)) == "minecraft:iron_chestplate",
		"o inventário é salvo e carregado com o personagem")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arq))
	print("test_mochila_minecraft: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
