extends SceneTree
## Frutas como itens do inventário (25/11/2026): Akuma `akuma:<id>` e pomar `pomar:<id>` empilham na hotbar/mochila, a aba FRUTAS acabou,
## comer pelo botão direito (mão e mochila), excedente, migração de save antigo e persistência.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_frutas_no_inventario.gd
const SAVE := "user://teste_frutas_no_inventario.json"
var falhas := 0
var total := 0


func ok(c: bool, m: String) -> void:
	total += 1
	if not c:
		falhas += 1
		print("FALHA ", m)


func _init() -> void:
	var p := ProgressaoDoPersonagem.new()
	# --- regras do item
	ok(RegrasDeItens.limite("akuma:mera_mera") == 64 and RegrasDeItens.limite("pomar:fruta_maca") == 64, "frutas empilham até 64")
	ok(RegrasDeItens.nome("akuma:mera_mera") == PerfilDeFrutas.nome_da_fruta("mera_mera"), "nome da Akuma no slot")
	ok(RegrasDeItens.icone("akuma:mera_mera") != null, "Akuma tem ícone")
	# --- receber / comprar vão para o inventário, hotbar primeiro
	ok(p.receber_fruta("mera_mera"), "receber_fruta")
	var i0 := -1
	for i in range(InventarioMinecraft.MOCHILA_INI, InventarioMinecraft.TOTAL):
		if InventarioMinecraft.id_de(p.inventario.pilha(i)) == "akuma:mera_mera":
			i0 = i
	ok(i0 >= InventarioMinecraft.HOTBAR_INI and i0 < InventarioMinecraft.HOTBAR_FIM, "a Akuma entra na hotbar primeiro (slot %d)" % i0)
	ok(p.frutas_compradas.is_empty() and p.quantas_akuma("mera_mera") == 1, "o dicionário antigo não guarda nada (só excedente)")
	p.ouro = 1000000
	ok(p.comprar_fruta("gomu_gomu", 10) and p.quantas_akuma("gomu_gomu") == 1 and p.ouro == 999990, "comprar cobra e guarda como item")
	ok(p.dar_fruta_de_teste("mera_mera", 5) and p.quantas_akuma("mera_mera") == 5 and p.dar_fruta_de_teste("mera_mera", 5) and p.quantas_akuma("mera_mera") == 5, "dar_fruta_de_teste idempotente")
	ok(p.akumas_guardadas().get("mera_mera", 0) == 5, "akumas_guardadas conta as pilhas")
	# --- pomar
	p.ganhar_fruta_do_pomar("fruta_maca", 30)
	ok(p.quantas_frutas_do_pomar("fruta_maca") == 30 and p.inventario.contar("pomar:fruta_maca") == 30, "fruta do pomar é pilha no inventário")
	ok(p.gastar_fruta_do_pomar("fruta_maca") and p.quantas_frutas_do_pomar("fruta_maca") == 29, "gastar uma na doma")
	# --- comer
	var r := ItensDeFruta.comer(p, "akuma:mera_mera", false)
	ok(r.estado == "comeu" and p.fruta == "mera_mera" and p.quantas_akuma("mera_mera") == 4, "comer sem fruta no corpo: come e gasta 1")
	ok(ItensDeFruta.comer(p, "akuma:mera_mera", false).estado == "igual" and p.quantas_akuma("mera_mera") == 4, "mesma fruta: recusa sem gastar")
	r = ItensDeFruta.comer(p, "akuma:gomu_gomu", false)
	ok(r.estado == "confirmar" and p.fruta == "mera_mera" and p.quantas_akuma("gomu_gomu") == 1, "com fruta no corpo: pede confirmação, nada muda")
	r = ItensDeFruta.comer(p, "akuma:gomu_gomu", true)
	ok(r.estado == "comeu" and p.fruta == "gomu_gomu" and p.quantas_akuma("gomu_gomu") == 0, "confirmado: troca")
	# --- botão direito com a Akuma na mão (CliqueDeBlocos)
	var jogador := Node3D.new()
	root.add_child(jogador)
	var clique := CliqueDeBlocos.new()
	clique.montar(jogador, p)
	clique.mira_ativa = func() -> bool: return true
	p.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	var avisos: Array[String] = []
	clique.avisou.connect(func(t): avisos.append(t))
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		if InventarioMinecraft.id_de(p.inventario.pilha(i)) == "akuma:mera_mera":
			p.inventario.selecionado = i - InventarioMinecraft.HOTBAR_INI
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	ok(clique.tratar(ev) and avisos.size() == 1 and p.fruta == "gomu_gomu", "botão direito: 1º clique avisa a troca")
	ok(clique.tratar(ev) and p.fruta == "mera_mera" and p.quantas_akuma("mera_mera") == 3, "botão direito: 2º clique confirma e come (%s)" % str(avisos))
	# --- inventário cheio: compra não cobra; excedente espera vaga
	var cheio := ProgressaoDoPersonagem.new()
	cheio.ouro = 500
	for i in range(InventarioMinecraft.MOCHILA_INI, InventarioMinecraft.HOTBAR_FIM):
		cheio.inventario.slots[i] = InventarioMinecraft.nova("minecraft:stone", 64)
	ok(not cheio.comprar_fruta("mera_mera", 50) and cheio.ouro == 500, "mochila cheia: compra recusada sem cobrar")
	ok(cheio.receber_fruta("mera_mera") and cheio.frutas_compradas.get("mera_mera", 0) == 1 and cheio.quantas_akuma("mera_mera") == 1, "mochila cheia: fruta de baú vira excedente (não se perde)")
	cheio.inventario.slots[InventarioMinecraft.HOTBAR_INI] = InventarioMinecraft.vazia()
	cheio.recolher_frutas_para_o_inventario()
	ok(cheio.frutas_compradas.is_empty() and cheio.inventario.contar("akuma:mera_mera") == 1, "com vaga, o excedente entra no inventário")
	# --- save antigo (dicionários) migra
	var velho := ProgressaoDoPersonagem.new()
	velho.frutas_compradas["hie_hie"] = 3
	velho.frutas_do_pomar["fruta_maca"] = 7
	velho.recolher_frutas_para_o_inventario()
	ok(velho.frutas_compradas.is_empty() and velho.frutas_do_pomar.is_empty() and velho.inventario.contar("akuma:hie_hie") == 3 and velho.inventario.contar("pomar:fruta_maca") == 7, "save antigo: listas viram itens")
	# --- persistência
	ok(p.salvar(SAVE) == OK, "salvar")
	var lido := ProgressaoDoPersonagem.carregar(SAVE)
	ok(lido != null and lido.quantas_akuma("mera_mera") == 3 and lido.quantas_frutas_do_pomar("fruta_maca") == 29, "o save guarda as pilhas de fruta")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("FRUTAS_NO_INVENTARIO %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
