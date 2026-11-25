extends SceneTree
# ============================================================================
#  VENDEDOR DE BARCOS + FROTA SALVA (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_vendedor_de_barcos.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_vendedor_de_barcos.gd -- --tela
#
#  Pedido do dono: NPC que vende barcos (1 moeda cada) e nenhum barco no mapa. Decisões
#  dele: o barco comprado fica seu (salvo), nasce na água ao lado do vendedor e volta ao
#  cais ao abrir o jogo; um de cada tipo; os 7 barcos do mapa saem.
#  Na cena real da história com o MAPA VIVO (o porto de verdade) e save de TESTE:
#  nenhum barco nasce do mapa; a loja lista bote, chalupa e galeão; sem moeda não
#  compra; comprar põe o barco na água, sem tocar o fundo nem o cenário, com a proa para
#  o mar e longe dos outros; reabrir a história traz a frota de volta ao cais; "Trazer ao
#  cais" devolve um barco levado para longe; Y pilota o barco comprado.
# ============================================================================

## Os 3 que o teste compra (de 12): o menor, o Going Merry e um dos maiores.
const COMPRADOS := ["mpe_ship_mihawk", "mpe_ship_going_merry", "mpe_ship_moby_dick"]
const SAVE := "user://test_vendedor_de_barcos_progresso.json"
const PASTA := "res://art_src/validation/vendedor_de_barcos"
const VENDEDOR := "npc_vendedor_barcos"

var total := 0
var falhas := 0
var tela := false


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func abrir() -> Node:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", SAVE)
	root.get_node("GameFlow").start_story()
	await quadros(150)
	return current_scene


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var modo := await abrir()
	var prog: ProgressaoDoPersonagem = modo.get("progressao")
	var nav: Node = modo.get("_navegacao")
	var npcs: NpcsDaIlha = modo.get("_npcs")
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)

	print("\n-- mapa sem barcos --")
	ok(nav.barcos.is_empty(), "nenhum barco nasce do mapa (%d)" % nav.barcos.size())
	var vendedores := npcs.npcs.filter(func(n): return n.tipo == VENDEDOR)
	ok(vendedores.size() == 1, "o vendedor de barcos está no porto")
	if vendedores.is_empty():
		return _fim()
	var vendedor: NpcDaIlha = vendedores[0]
	ok(vendedor.find_child("Remo", false, false) != null, "ele tem o remo ao lado")
	jogador.global_position = vendedor.global_position + vendedor.global_basis.z * -2.0 + Vector3.UP
	await quadros(10)
	ok(npcs.interagir(), "E perto do vendedor abre a loja")
	var loja: LojaDeNpc = vendedor.loja()
	var bib := MapaMontador.biblioteca_em_uso()
	var linhas := loja.linhas(prog, bib)
	var nomes: Array = linhas.map(func(l): return l["nome"])
	# Os 12 navios do Mine Piece no lugar dos 3 antigos (pedido do dono, 18/10/2026).
	ok(nomes.size() == 12 and nomes[0] == "Barco do Mihawk" and not nomes.has("Bote") and not nomes.has("Galeão")
		and nomes.has("Going Merry") and nomes.has("Moby Dick"), "à venda os 12 do mod, do menor ao maior: %s" % str(nomes))
	ok(linhas.all(func(l): return not l["botoes"][0]["ativo"]), "sem moeda, o botão Comprar fica apagado")
	ok(loja.executar(prog, bib, "comprar", "mpe_ship_mihawk").begins_with("Sem moedas") and prog.barcos.is_empty(), "sem moeda não compra")

	print("\n-- comprar três (o menor, o Going Merry e um dos maiores) --")
	prog.ganhar_ouro(300000)
	for id in COMPRADOS:
		var aviso := loja.executar(prog, bib, "comprar", id)
		print("     ", aviso)
		ok(prog.barcos.has(id) and aviso.contains("no cais"), "%s comprado e atracado" % id)
	ok(prog.ouro == 0 and loja.PRECO_DO_NAVIO == 100000, "custou 100 mil moedas cada (sobrou %d)" % prog.ouro)
	ok(loja.executar(prog, bib, "comprar", "mpe_ship_mihawk").contains("já é seu"), "não compra o mesmo tipo duas vezes")
	ok(loja.linhas(prog, bib).filter(func(l): return l["botoes"][0]["acao"] == "trazer").size() == 3, "comprado vira \"Trazer ao cais\"")
	await quadros(5)
	ok(nav.barcos.size() == 1 and nav.barco_do_jogador("mpe_ship_moby_dick") != null,
		"só 1 barco na água (o último comprado): %d" % nav.barcos.size())
	var troca := loja.executar(prog, bib, "trazer", "mpe_ship_going_merry")
	await quadros(5)
	ok(troca.contains("de volta ao cais") and nav.barcos.size() == 1 and nav.barco_do_jogador("mpe_ship_going_merry") != null
		and nav.barco_do_jogador("mpe_ship_moby_dick") == null, "trazer outro TROCA o barco: %s" % troca)
	_conferir_vagas(nav, vendedor, "na compra")
	await _foto(modo, vendedor, "barcos_comprados")
	var poses := {}
	for b in nav.barcos:
		poses[b.get_meta("frota")] = b.global_transform

	print("\n-- Y pilota o barco comprado --")
	var bote: CharacterBody3D = nav.barco_do_jogador("mpe_ship_going_merry")
	jogador.global_position = bote.leme.global_position + Vector3.UP * 0.9
	await quadros(4)
	# Y no leme abre o "Navegar?" da tripulação; o comando é assumido depois da resposta.
	ok(nav.candidato() == bote and nav.interagir(), "Y no posto de comando do Going Merry chama a navegação")
	nav.assumir(bote)
	ok(nav.ativo() and nav.barco == bote, "o jogador assume o leme do Going Merry")
	ok(loja.executar(prog, bib, "trazer", "mpe_ship_going_merry").contains("Solte o leme"), "com o leme na mão, não traz ao cais")
	nav.sair(true)
	await quadros(30)

	print("\n-- o convés leva quem está em cima --")
	var pe: Vector3 = bote.ponto_no_conves_livre()
	ok(pe.is_finite(), "há lugar livre no convés do Going Merry (%s)" % str(pe))
	if pe.is_finite():
		jogador.global_position = pe + Vector3.UP * 0.9
		jogador.set("velocity", Vector3.ZERO)
		await quadros(30)
		var relativo := bote.to_local(jogador.global_position)
		var de := bote.global_position
		bote.definir_pilotado(true)
		bote.definir_comando(1.0, 0.0)
		await quadros(240)
		bote.limpar_comando()
		bote.definir_pilotado(false)
		var andou := Vector2(bote.global_position.x - de.x, bote.global_position.z - de.z).length()
		var desvio := bote.to_local(jogador.global_position).distance_to(relativo)
		ok(andou > 3.0 and desvio < 2.0 and jogador.global_position.y > AguaDoMundo.nivel_em(jogador.global_position.x, jogador.global_position.z) + 1.0,
			"o navio andou %.1f m e o jogador foi junto no convés (desvio %.2f m)" % [andou, desvio])

	print("\n-- trazer ao cais --")
	bote.global_position += Vector3(60, 0, 0)
	await quadros(2)
	var aviso_trazer := loja.executar(prog, bib, "trazer", "mpe_ship_going_merry")
	ok(aviso_trazer.contains("de volta ao cais"), "\"Trazer ao cais\": %s" % aviso_trazer)
	ok(bote.global_position.distance_to(vendedor.global_position) < 120.0, "o Going Merry voltou para perto do vendedor (%.1f m)" % bote.global_position.distance_to(vendedor.global_position))

	print("\n-- reabrir a história --")
	ok(FileAccess.file_exists(SAVE), "o save de teste foi gravado")
	jogador.global_position = vendedor.global_position + Vector3(-30, 1, 0)
	root.get_node("GameFlow").back_to_menu()
	await quadros(30)
	modo = await abrir()
	prog = modo.get("progressao")
	nav = modo.get("_navegacao")
	npcs = modo.get("_npcs")
	vendedor = npcs.npcs.filter(func(n): return n.tipo == VENDEDOR)[0]
	ok(prog.barcos.size() == 3, "o save trouxe os 3 barcos (%s)" % str(prog.barcos.keys()))
	ok(nav.barcos.size() == 1 and nav.barco_do_jogador("mpe_ship_going_merry") != null,
		"volta só o último usado, o Going Merry (%d na água)" % nav.barcos.size())
	_conferir_vagas(nav, vendedor, "ao reabrir")
	for b in nav.barcos:
		var antes: Transform3D = poses.get(b.get_meta("frota"), Transform3D())
		ok(b.global_position.distance_to(antes.origin) < 0.05, "%s voltou à mesma vaga do cais" % b.get_meta("frota"))
	_fim()


func _conferir_vagas(nav: Node, vendedor: Node3D, quando: String) -> void:
	for b: CharacterBody3D in nav.barcos:
		var nivel := AguaDoMundo.nivel_em(b.global_position.x, b.global_position.z)
		ok(not is_nan(nivel) and absf(b.global_position.y - nivel) < 0.05, "%s %s: na linha d'água (%.2f / %.2f)" % [b.name, quando, b.global_position.y, nivel])
		var fora := (b.global_position - vendedor.global_position)
		fora.y = 0
		var proa := -b.global_basis.z
		ok(proa.dot(fora.normalized()) > 0.95, "%s %s: proa para longe do vendedor" % [b.name, quando])
		var casco: Vector3 = b.tamanho_casco
		var calado := float(b.perfil["calado"])
		var raio := PhysicsRayQueryParameters3D.create(b.global_position + Vector3.UP * 0.5, b.global_position + Vector3.DOWN * (calado + 0.3), 1)
		raio.exclude = b.call("rids_proprios")
		ok(b.get_world_3d().direct_space_state.intersect_ray(raio).is_empty(), "%s %s: quilha livre do fundo (calado %.2f m)" % [b.name, quando, calado])
		var caixa := BoxShape3D.new()
		caixa.size = casco
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = caixa
		q.transform = Transform3D(b.global_basis, b.global_position + Vector3.UP * (casco.y * 0.5 - calado))
		q.collision_mask = 1
		q.exclude = b.call("rids_proprios")
		var toques := b.get_world_3d().direct_space_state.intersect_shape(q, 4)
		var nomes := toques.map(func(t): return str((t["collider"] as Node).name))
		ok(toques.is_empty(), "%s %s: casco não toca cenário nem outro barco %s" % [b.name, quando, str(nomes)])
		print("     %s em (%.1f, %.1f) a %.1f m do vendedor" % [b.name, b.global_position.x, b.global_position.z, fora.length()])


func _foto(modo: Node, vendedor: Node3D, nome: String) -> void:
	if not tela:
		return
	var cam := Camera3D.new()
	modo.add_child(cam)
	cam.global_position = vendedor.global_position + Vector3(-14, 22, 34)
	cam.look_at(vendedor.global_position + Vector3(30, 0, 0))
	cam.make_current()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join(nome + ".png")))
	cam.queue_free()
	print("     foto: ", PASTA.path_join(nome + ".png"))


func _fim() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nVENDEDOR_DE_BARCOS %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
