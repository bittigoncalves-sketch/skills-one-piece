extends SceneTree
## Missões da Ilha dos Macacos só aparecem lá; aceitar a pesca entrega a vara na HOTBAR.
var total := 0
var falhas := 0
func ok(v: bool, t: String) -> void:
	total += 1
	if not v: falhas += 1
	print(("PASS " if v else "FALHA ") + t)
func _init() -> void:
	var M := preload("res://src/historia/missoes/missoes.gd")
	var Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
	var p := ProgressaoDoPersonagem.new()
	var da_ilha := ["cesto_de_bananas", "pesca_do_cais", "os_saqueadores", "os_quatro_totens"]
	p.ilha = Ilhas.INICIAL
	var longe := M.proximas(p)
	ok(da_ilha.all(func(id): return not longe.has(id)), "na ilha inicial nenhuma missão dos Macacos aparece como Próxima")
	ok(longe.has("treino"), "o treino da ilha inicial continua aparecendo")
	p.ilha = ""
	ok(da_ilha.all(func(id): return not M.proximas(p).has(id)), "no mar também não")
	p.ilha = Ilhas.MACACOS
	var la := M.proximas(p)
	ok(da_ilha.all(func(id): return la.has(id)), "na Ilha dos Macacos as quatro missões de NPC aparecem")
	ok(not p.equipamentos.has("vara_de_pesca"), "sem vara antes de aceitar a pesca")
	ok(p.aceitar_missao("pesca_do_cais"), "aceita a pesca do cais")
	ok(p.equipamentos.has("vara_de_pesca") and p.vara_equipada, "aceitar entrega a vara e a deixa equipável na barra")
	var barra: Array = p.itens_da_barra()
	ok(barra.has("vara"), "a vara aparece na hotbar (itens_da_barra: %s)" % [barra])
	var hotbar_ids := []
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_INI + 9):
		hotbar_ids.append(InventarioMinecraft.id_de(p.inventario.pilha(i)))
	ok(hotbar_ids.has("jogo:vara"), "o item da vara ocupa um slot da hotbar do inventário (%s)" % [hotbar_ids])
	var q := ProgressaoDoPersonagem.new()
	q.ganhar_equipamento("vara_de_pesca")
	ok(q.vara_equipada and q.itens_da_barra().has("vara"), "pegar a vara com o pescador também a põe na hotbar")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
