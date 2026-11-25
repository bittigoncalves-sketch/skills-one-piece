extends SceneTree
## Construções em blocos (08/11/2026): golpe quebra cubos e abre buraco PASSÁVEL; só vale ao redor do jogador (40 m); quem fica
## longe volta inteira. Peça real do mapa (modelo voxel "hut"), colisão real. Não depende do Modo História.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_destruicao_de_estruturas.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _raio_para_baixo(corpo: Node3D, x: float, z: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -5, z), 1)
	return corpo.get_world_3d().direct_space_state.intersect_ray(q)

func rodar() -> void:
	await process_frame
	var raiz := Node3D.new()
	root.add_child(raiz)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(400, 1, 400)
	cs.shape = caixa
	chao.add_child(cs)
	chao.position.y = -0.5
	raiz.add_child(chao)
	var bib := BibliotecaDeModelos.padrao()
	var t := bib.tamanho_padrao("hut")
	var peca := {"id": "hut_t", "tipo": "modelo", "modelo": "hut", "posicao": Vector3(0, t.y * 0.5, 0), "rotacao_graus": Vector3.ZERO,
		"tamanho": t, "cor": "#ffffff", "material": "liso", "colisao": true}
	var corpo := MapaMontador.montar_peca(raiz, peca)
	var jogador := Node3D.new()
	raiz.add_child(jogador)
	jogador.global_position = Vector3(12, 0, 0)
	var g := DestruicaoDeEstruturas.new()
	g.jogador_de = func() -> Node3D: return jogador
	raiz.add_child(g)
	await quadros(5)

	print("\n-- catálogo --")
	ok(CatalogoDeConstrucoes.e_construcao("hut", bib.categorias_do_modelo("hut")), "hut é construção")
	ok(not CatalogoDeConstrucoes.e_construcao("palm_tree", []) and not CatalogoDeConstrucoes.e_construcao("rock", [])
		and not CatalogoDeConstrucoes.e_construcao("mpe_village_foosha_road_street", ["estruturas_mine_piece"]), "árvore, rocha e estrada não são")

	print("\n-- golpe quebra cubos e abre buraco --")
	var topo := _raio_para_baixo(corpo, 0.0, 0.0)
	ok(not topo.is_empty(), "o raio acha o telhado/chão da cabana (y %.2f)" % (topo["position"].y if not topo.is_empty() else -1.0))
	var ponto: Vector3 = topo["position"]
	var antes_y := ponto.y
	ok(g.abertas() == 0, "nada aberto antes do golpe")
	var n := g._golpe(ponto, 1.2)
	await quadros(3)
	ok(n > 0, "o golpe quebrou %d cubos" % n)
	ok(g.abertas() == 1, "só a cabana atingida foi aberta (%d)" % g.abertas())
	var e: EstruturaDestrutivel = corpo.get_node("Destrutivel")
	e.reconstruir(true)
	await quadros(3)
	var depois := _raio_para_baixo(corpo, ponto.x, ponto.z)
	ok(depois.is_empty() or depois["position"].y < antes_y - 0.2, "o buraco é PASSÁVEL: o raio desce de %.2f para %.2f" % [antes_y, depois["position"].y if not depois.is_empty() else -1.0])
	var vivas1 := e.celulas_vivas()
	g._golpe(ponto, 1.2)
	ok(e.celulas_vivas() <= vivas1, "golpe repetido no mesmo lugar não ressuscita nada")

	print("\n-- limite de destruição ao redor do jogador --")
	jogador.global_position = Vector3(200, 0, 0)
	var longe := g._golpe(ponto + Vector3(0.5, -0.5, 0), 1.5)
	ok(longe == 0, "golpe a 200 m do jogador não quebra nada (%d)" % longe)

	print("\n-- afastar-se restaura --")
	g._t = 99.0
	g._process(0.1)
	await quadros(3)
	ok(g.abertas() == 0 and corpo.get_node_or_null("Destrutivel") == null, "a cabana voltou ao normal")
	var restaurado := _raio_para_baixo(corpo, ponto.x, ponto.z)
	ok(not restaurado.is_empty() and absf(restaurado["position"].y - antes_y) < 0.05, "telhado inteiro de novo (y %.2f)" % (restaurado["position"].y if not restaurado.is_empty() else -1.0))
	print("\nDESTRUICAO_DE_ESTRUTURAS %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
