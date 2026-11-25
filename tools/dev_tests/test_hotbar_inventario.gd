extends SceneTree
## Hotbar do inventário (10/11/2026): os itens numerados do jogo são itens do inventário; a tecla 1–9 é o SLOT; arrastar muda o número; os 9 números aparecem; a
## mochila (E, com o painel de itens ao lado) fica centralizada. Rodar: godot --headless --path . --script tools/dev_tests/test_hotbar_inventario.gd
const MAPA := "user://test_hotbar.json"
const SAVE := "user://test_hotbar_p.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
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
	var barra: BarraDeItensHud = hud.find_child("BarraDeItens", true, false)
	ok(barra != null, "a HUD tem a hotbar (BarraDeItensHud)")
	# ---- os 9 números e o inventário como dono da barra
	var numeros := []
	for i in 9:
		var n := barra.find_child("Numero%d" % i, true, false) as Label
		numeros.append(n.text if n != null else "?")
	ok(numeros == ["1", "2", "3", "4", "5", "6", "7", "8", "9"], "os nove números 1–9 aparecem na hotbar (%s)" % str(numeros))
	var inv := prog.inventario
	ok(InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI)) == "jogo:luta", "o combate (luta) é um item do inventário no slot 1")
	ok(InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI + 5)) == "jogo:agua" and InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI + 8)) == "jogo:bandeira", "água no slot 6 e bandeira no 9 (slots padrão fixos)")
	ok(barra._icones[0].texture != null and barra._icones[5].texture != null, "os itens do jogo têm ícone na hotbar")
	# ---- tecla 1–9 = slot
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	ok(barra.escolher(0) and prog.item_em_uso() == "luta", "tecla 1 ativa o combate")
	ok(barra.escolher(0) and prog.item_em_uso() == "luta", "apertar o mesmo número de novo NÃO desativa o estilo de luta (19/11/2026)")
	ok(barra.escolher(0) and barra.escolher(0) and prog.item_em_uso() == "luta", "e continua ativo mesmo apertando várias vezes")
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	ok(not barra.escolher(3), "slot vazio não escolhe nada")
	# fruta entra no slot 2 ao ser obtida
	prog.comer_fruta("rocket")
	ok(InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI + 1)) == "jogo:fruta" and prog.slot_da_barra("fruta") == 1, "fruta obtida vai para o slot 2")
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	ok(barra.escolher(1) and prog.item_em_uso() == "fruta", "tecla 2 ativa a fruta")
	# ---- item comum do inventário na hotbar vai para a mão
	inv.slots[InventarioMinecraft.HOTBAR_INI + 3] = InventarioMinecraft.nova("minecraft:iron_sword", 1)
	inv.mudou.emit()
	ok(barra.escolher(3) and prog.item_em_uso() == "" and inv.selecionado == 3, "tecla 4 escolhe o item comum e solta o item do jogo")
	var e := McEntidade.de(j)
	ok(str(e.getMainHandItem().item.id) == "minecraft:iron_sword" if not e.getMainHandItem().isEmpty() else false, "o item comum vira o item da mão da camada Minecraft")
	# ---- arrastar muda o número: água do slot 6 para o slot 1
	var antes_ordem := prog.itens_da_barra()
	inv.clique(InventarioMinecraft.HOTBAR_INI + 5, 0)                 # pega a água
	inv.clique(InventarioMinecraft.HOTBAR_INI, 0)                     # solta no slot 1 (troca com a luta)
	inv.clique(InventarioMinecraft.HOTBAR_INI + 5, 0)                 # a luta que veio para o cursor vai para o slot 6
	ok(prog.slot_da_barra("agua") == 0 and prog.slot_da_barra("luta") == 5, "arrastar troca os números (água = 1, luta = 6)")
	ok(barra.escolher(0) and prog.item_em_uso() == "agua", "a tecla 1 agora ativa a água")
	ok(prog.itens_da_barra() != antes_ordem, "a ordem da barra acompanha o inventário")
	# ---- salvar e carregar mantém o arranjo
	var arq := "user://test_hotbar_salvo.json"
	prog.salvar(arq)
	var carregado := ProgressaoDoPersonagem.carregar(arq)
	ok(carregado.slot_da_barra("agua") == 0 and carregado.slot_da_barra("fruta") == 1, "o arranjo da hotbar é salvo com o personagem")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arq))
	# ---- a mochila abre centralizada
	hud.abrir_mochila()
	await quadros(5)
	var central: Control = hud.central()
	var moch: Control = hud.mochila()
	var c_central := central.get_global_rect().get_center()
	# 19/11/2026: a página tem a grade e, à direita, o painel de itens; o CONJUNTO é que fica centralizado na janela
	var conjunto := moch.get_global_rect().merge(hud.inventario().get_global_rect())
	var c_moch := conjunto.get_center()
	ok(central.aberta() and absf(c_central.x - c_moch.x) < 60.0, "a mochila (grade + painel de itens) fica centralizada na janela (Δx %.0f px)" % absf(c_central.x - c_moch.x))
	# ---- item do jogo na mochila: arrastar para a mochila tira da hotbar (e o número some)
	inv.clique(InventarioMinecraft.HOTBAR_INI + 8, 0)
	inv.clique(InventarioMinecraft.MOCHILA_INI, 0)
	ok(prog.slot_da_barra("bandeira") == -1 and not prog.itens_da_barra().has("bandeira"), "item do jogo guardado na mochila deixa de estar na hotbar")
	# ---- 19/11/2026: Shift SEGURADO + número (corrida): escolhe o slot, não desliga o item e não solta o Shift
	hud.central().fechar()
	await quadros(3)
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	shift.shift_pressed = true
	Input.parse_input_event(shift)
	await quadros(2)
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	for par in [[KEY_1, KEY_EXCLAM, 0], [KEY_1, KEY_EXCLAM, 0], [KEY_2, KEY_AT, 1]]:
		var tecla := InputEventKey.new()
		tecla.physical_keycode = par[0]
		tecla.keycode = par[1]            # com Shift o `keycode` é o símbolo; o físico continua o do número
		tecla.shift_pressed = true
		tecla.pressed = true
		hud._input(tecla)
		await quadros(2)
	ok(inv.selecionado == 1 and prog.item_em_uso() == "fruta", "Shift+1, Shift+1, Shift+2: o slot da hitbox/seleção acompanha (slot %d, item '%s')" % [inv.selecionado, prog.item_em_uso()])
	var um := InputEventKey.new()
	um.physical_keycode = KEY_1
	um.keycode = KEY_EXCLAM
	um.shift_pressed = true
	um.pressed = true
	hud._input(um)
	hud._input(um)
	var do_slot_1 := ItensDoJogo.id_de(InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI)))      # o arranjo da hotbar foi trocado acima: o slot 1 pode não ser a luta
	ok(prog.item_em_uso() == do_slot_1 and inv.selecionado == 0, "Shift+1 duas vezes: o item do slot 1 ('%s') fica ATIVO, não alterna (slot %d, '%s')" % [do_slot_1, inv.selecionado, prog.item_em_uso()])
	ok(Input.is_key_pressed(KEY_SHIFT), "a tecla número não solta o Shift (a corrida continua pedida)")
	shift.pressed = false
	Input.parse_input_event(shift)
	print("test_hotbar_inventario: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
