extends SceneTree
# ============================================================================
#  ROLETA DO BARBA NEGRA + A LOJA REFEITA (15/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_roleta.gd
#
#  Pedido do dono: tripulantes humanos vêm da roleta do Barba Negra — 100 moedas por giro,
#  Nami comum, Crocodile incomum, Barba Negra lendário; a UI da loja maior, com cores,
#  símbolos, preço em cada opção e ordenada por preço; retirar fruta continua grátis.
# ============================================================================

const Loja := preload("res://src/historia/npcs/loja_do_barba_negra.gd")
var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_dados()
	_loja()
	await _janela()
	await _viagem()
	print("\nROLETA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _rng(semente: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	return r


func _dados() -> void:
	_ok("Nami é comum, Crocodile incomum, Barba Negra lendário",
		CatalogoDeTripulantes.raridade("nami") == CatalogoDeTripulantes.COMUM
		and CatalogoDeTripulantes.raridade("crocodile") == CatalogoDeTripulantes.INCOMUM
		and CatalogoDeTripulantes.raridade("barba_negra") == CatalogoDeTripulantes.LENDARIO)
	_ok("a roleta custa 100 moedas", CatalogoDeTripulantes.PRECO_DA_ROLETA == 100)
	var comuns := CatalogoDeTripulantes.ids().filter(func(i): return CatalogoDeTripulantes.raridade(i) == CatalogoDeTripulantes.COMUM)
	_ok("Sanji e os quatro cozinheiros são COMUNS, junto com a Nami (%s)" % str(comuns),
		comuns.size() == 6 and ["sanji", "beto", "iara", "ravi", "otto", "nami"].all(func(i): return comuns.has(i)))
	var por_raridade := {CatalogoDeTripulantes.COMUM: 0, CatalogoDeTripulantes.INCOMUM: 0, CatalogoDeTripulantes.LENDARIO: 0}
	var r := _rng(7)
	for i in 4000:
		por_raridade[CatalogoDeTripulantes.raridade(CatalogoDeTripulantes.sortear({}, r))] += 1
	_ok("o sorteio respeita as raridades (comum %d · incomum %d · lendário %d de 4000)" % [por_raridade[CatalogoDeTripulantes.COMUM], por_raridade[CatalogoDeTripulantes.INCOMUM], por_raridade[CatalogoDeTripulantes.LENDARIO]],
		por_raridade[CatalogoDeTripulantes.COMUM] > por_raridade[CatalogoDeTripulantes.INCOMUM] and por_raridade[CatalogoDeTripulantes.INCOMUM] > por_raridade[CatalogoDeTripulantes.LENDARIO] and por_raridade[CatalogoDeTripulantes.LENDARIO] > 100)
	var sem_nami := CatalogoDeTripulantes.sortear({"nami": true}, _rng(1))
	_ok("quem já foi recrutado não sai de novo (%s)" % sem_nami, sem_nami != "nami" and sem_nami != "")
	var todos := {}
	for id in CatalogoDeTripulantes.ids():
		todos[id] = true
	_ok("com todos recrutados o sorteio devolve vazio", CatalogoDeTripulantes.sortear(todos, _rng(1)) == "")
	var visto := {}
	var rr := _rng(5)
	var recrutados := {}
	for i in CatalogoDeTripulantes.ids().size():
		var id := CatalogoDeTripulantes.sortear(recrutados, rr)
		visto[id] = true
		recrutados[id] = true
	_ok("giros seguidos esgotam os 9 sem repetir (%d)" % visto.size(), visto.size() == CatalogoDeTripulantes.ids().size())


func _loja() -> void:
	var prog := ProgressaoDoPersonagem.new()
	prog.ouro = 250
	var loja = Loja.new()
	loja.rng = _rng(3)
	var l := loja.linhas(prog, null)
	var precos: Array = l.map(func(x): return x["preco"])
	_ok("as opções vêm ordenadas por preço (%s)" % str(precos), precos == [0, 100, 1000, 1000])
	_ok("retirar fruta é grátis e a primeira", l[0]["id"] == "retirar_fruta" and l[0]["preco"] == 0)
	_ok("cada opção tem cor, símbolo e preço", l.all(func(x): return (x["cor"] as Color).a > 0.0 and str(x["simbolo"]) != "" and int(x["preco"]) >= 0))
	_ok("a loja é menor que a padrão (escala %.1f)" % loja.escala_da_ui(), loja.escala_da_ui() < 1.0)
	var antes := prog.ouro
	var msg: String = loja.executar(prog, null, "girar", "roleta")
	_ok("girar cobra 100 e recruta um (%s)" % msg, prog.ouro == antes - 100 and prog.recrutados.size() == 1)
	var giro: Dictionary = loja.consumir_giro()
	_ok("o giro entrega id, nome e raridade e só uma vez", giro.has("id") and giro.has("raridade") and loja.consumir_giro().is_empty())
	prog.ouro = 99
	var n := prog.recrutados.size()
	loja.executar(prog, null, "girar", "roleta")
	_ok("com 99 moedas não gira nem cobra", prog.ouro == 99 and prog.recrutados.size() == n)
	prog.ouro = 1000
	var total := CatalogoDeTripulantes.ids().size()
	for i in total + 3:
		loja.executar(prog, null, "girar", "roleta")
	_ok("todos saem sem repetir e depois a roleta não cobra mais (%d/%d)" % [prog.recrutados.size(), total],
		prog.recrutados.size() == total and prog.ouro == 1000 - 100 * (total - n))
	var tela := ProgressaoDoPersonagem.new()
	tela.ouro = 100
	tela.fruta = ""
	_ok("sem fruta, retirar fica desligado mas continua grátis", not loja.linhas(tela, null)[0]["botoes"][0]["ativo"] and loja.linhas(tela, null)[0]["preco"] == 0)
	var caminho := "user://test_roleta.json"
	prog.salvar(caminho)
	var lido := ProgressaoDoPersonagem.carregar(caminho)
	_ok("os recrutados persistem no save", lido.recrutados.size() == CatalogoDeTripulantes.ids().size() and lido.tem_recrutado("barba_negra"))


func _janela() -> void:
	var prog := ProgressaoDoPersonagem.new()
	prog.ouro = 500
	var j := JanelaDeLoja.new()
	root.add_child(j)
	j.ligar(prog, null)
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_barba_negra"
	root.add_child(npc)
	j.abrir(npc)
	await process_frame
	await process_frame
	var lista: Node = j.find_child("Lista", true, false)
	var linhas := lista.get_children()
	_ok("a janela mostra 4 linhas, cada uma com símbolo e etiqueta de preço (%d)" % linhas.size(),
		linhas.size() == 4 and linhas.all(func(x): return x.find_child("Simbolo", true, false) != null and x.find_child("Preco", true, false) != null))
	_ok("a primeira é grátis (verde) e a ordem dos preços é crescente",
		(linhas[0].find_child("Valor", true, false) as Label).text == "Grátis"
		and (linhas[1].find_child("Valor", true, false) as Label).text == "100 moedas")
	_ok("a janela está menor que a padrão (%.0f < %.0f; era 1,3× em 15/10, reduzida em 19/11)" % [j.custom_minimum_size.x, JanelaDeLoja.LARGURA], j.custom_minimum_size.x < JanelaDeLoja.LARGURA)
	j._roleta = null
	(npc.loja() as LojaDeNpc).set("rng", _rng(11))
	j.executar("girar", "roleta")
	var roleta: RoletaHud = j.find_child("Roleta", true, false)
	_ok("girar abre a roleta girando, em cima de tudo", roleta != null and roleta.visible and roleta.esta_girando() and roleta.top_level)
	await process_frame
	await process_frame
	var tela := Vector2(roleta.get_viewport_rect().size)
	var painel := roleta.find_child("PainelDaRoda", true, false) as Control
	_ok("a roleta fica no CENTRO da tela (%s vs %s)" % [str(painel.get_global_rect().get_center()), str(tela * 0.5)],
		painel.get_global_rect().get_center().distance_to(tela * 0.5) < 2.0)
	roleta.duracao = 0.05
	roleta.exibicao = 0.4
	var giro := {"id": "nami", "nome": "Nami", "raridade": &"comum"}
	roleta.girar(giro)
	var sinais: Array = []
	roleta.terminou.connect(func(id): sinais.append("terminou:" + id))
	roleta.encerrou.connect(func(id): sinais.append("encerrou:" + id))
	for i in 10:
		await process_frame
	var sorteado := roleta.find_child("Sorteado", true, false) as Control
	_ok("a roda para: some, e o sorteado aparece (%s)" % str(sinais),
		sinais == ["terminou:nami"] and not painel.visible and roleta.sorteado_na_tela() and sorteado.visible)
	_ok("o sorteado é o personagem em 3D com nome e raridade",
		sorteado.find_child("Vitrine", true, false) != null and (sorteado.find_child("Resultado", true, false) as Label).text == "Nami"
		and (sorteado.find_child("Raridade", true, false) as Label).text == "COMUM")
	var centro_do_sorteado := sorteado.get_global_rect().get_center()
	_ok("e também no centro da tela (%s)" % str(centro_do_sorteado), centro_do_sorteado.distance_to(tela * 0.5) < 2.0)
	await create_timer(0.7).timeout
	_ok("passado o tempo tudo some sozinho (%s)" % str(sinais), sinais == ["terminou:nami", "encerrou:nami"] and not roleta.visible)
	# O tempo padrão é 1 s, como pediu o dono.
	var padrao := RoletaHud.new()
	_ok("o sorteado fica 1 s na tela por padrão", is_equal_approx(padrao.exibicao, 1.0))
	padrao.free()
	roleta.duracao = 3.6
	roleta.girar(giro)
	j.fechar()
	_ok("fechar a loja fecha a roleta", not roleta.visible)
	j.queue_free()
	npc.queue_free()


func _viagem() -> void:
	var prog := ProgressaoDoPersonagem.new()
	prog.recrutados = {"nami": true, "crocodile": true}
	prog.pets = {"gaivota": {"especie": "gaivota", "nome": "G", "modo": &"livre"}}
	var ds := Tripulacao.disponiveis(prog, null)
	_ok("os recrutados entram na lista de aliados como tripulantes (%d)" % ds.size(),
		ds.size() == 3 and Tripulacao.aliado(prog, null, "humano_nami")["categoria"] == Tripulacao.Categoria.HUMANO)
	_ok("humano não recrutado não embarca", Tripulacao.validos(["humano_nami", "humano_barba_negra", "gaivota"], prog) == (["humano_nami", "gaivota"] as Array[String]))
	var caixas := {"ilha_inicial": Rect2(-50, -50, 100, 100), "ilha_dos_macacos": Rect2(400, -50, 100, 100)}
	var perto := Tripulacao.ilha_mais_proxima(caixas, Vector3(300, 0, -20))
	_ok("a Nami acha a ilha mais próxima (%s a %d m, rumo %s)" % [perto["nome"], roundi(perto["distancia"]), perto["rumo"]],
		perto["ilha"] == "ilha_dos_macacos" and perto["rumo"] == "L" and roundi(perto["distancia"]) == 100)
	_ok("rumos: −Z é norte, +X leste, +Z sul",
		Tripulacao.rumo_para(Vector2(0, -5)) == "N" and Tripulacao.rumo_para(Vector2(5, 0)) == "L" and Tripulacao.rumo_para(Vector2(0, 5)) == "S"
		and Tripulacao.rumo_para(Vector2(5, -5)) == "NE")
	var vitrine := Tripulacao.modelo_de_vitrine("nami", null)
	_ok("a vitrine 3D dos humanos monta o rig do elenco", vitrine != null)
	if vitrine != null:
		vitrine.free()
	var bib := MapaMontador.biblioteca_em_uso()
	for id in ["sanji", "beto", "iara", "ravi", "otto"]:
		var v := Tripulacao.modelo_de_vitrine(id, bib)
		_ok("a vitrine do %s usa o modelo do cozinheiro da biblioteca" % id, v != null and v.find_children("*", "MeshInstance3D", true, false).size() > 0)
		if v != null:
			v.free()


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
