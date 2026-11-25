extends SceneTree
## Centro de treino voxel no MAPA REAL, no lugar da loja de armas onde está o NPC ferreiro (20/11/2026, decisão do dono: "colocar onde
## está o npc ferreiro"; a ferraria `blacksmith_1` ficou como estava). Roda com --headless. Confere: a peça entrou, a loja de armas
## `mpi_ilha_inicial_loja_0` saiu e a ferraria continua; o modelo está no catálogo; a colisão existe; o ferreiro e o vendedor de comida
## continuam únicos, de pé no chão e FORA da geometria; a loja do ferreiro abre.
const SAVE := "user://test_centro_treino_mapa.json"
var MAPA := "res://mapas/historia/baseplate.json"   # `-- mapa=res://...` troca (comparação com o mapa antigo)
var falhas := 0
var total := 0
func _init() -> void: executar.call_deferred()
func ok(sim: bool, msg: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + msg)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func achar(no: Node, id: String) -> Node:
	if str(no.name) == id: return no
	for f in no.get_children():
		var r := achar(f, id)
		if r != null: return r
	return null
func executar() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mapa="): MAPA = a.substr(5)
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPA))
	var pecas: Array = json["pecas"]
	var ids := pecas.map(func(p): return str(p.get("id", "")))
	ok(ids.has("centro_treino_voxel_1") and ids.has("blacksmith_1") and not ids.has("mpi_ilha_inicial_loja_0"), "mapa: centro entrou, a loja de armas saiu e a ferraria ficou (%d peças)" % pecas.size())
	var centro_p: Dictionary = pecas[ids.find("centro_treino_voxel_1")]
	var cp: Array = centro_p["posicao"]
	ok(ids.count("centro_treino_voxel_1") == 1, "mapa: uma só peça do centro")
	var bib := BibliotecaDeModelos.padrao()
	ok(bib.tem("centro_treino_voxel"), "catálogo conhece o modelo")
	var tam := bib.tamanho_padrao("centro_treino_voxel")
	ok(absf(tam.x - 11.1) < 0.05 and absf(tam.z - 12.91) < 0.05, "tamanho de catálogo (%s)" % tam)
	var forma := bib.forma_de_colisao("centro_treino_voxel", tam)
	ok(forma is ConcavePolygonShape3D and (forma as ConcavePolygonShape3D).get_faces().size() > 3000, "colisão em malha com triângulos (%d vértices)" % ((forma as ConcavePolygonShape3D).get_faces().size() if forma is ConcavePolygonShape3D else 0))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = MAPA
	modo.carregar_tudo_forcado = 0      # como no jogo real: a ilha do jogador monta primeiro (headless montaria todas, e o ferreiro das outras ilhas barraria o da vila)
	modo.progresso_forcado = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var cena: Node = current_scene
	var peca: Node = achar(cena, "centro_treino_voxel_1")
	ok(peca != null, "peça montada na cena")
	var npcs: NpcsDaIlha = cena.get("_npcs")
	# O ferreiro da ilha inicial é uma PEÇA de NPC do mapa (`mpi_ilha_inicial_loja_0_vendedor_0`), longe da ferraria: remover o prédio não o toca.
	var ferreiros: Array = npcs.npcs.filter(func(n): return n.tipo == "npc_ferreiro" and str(n.name).begins_with("Npc_mpi_ilha_inicial"))
	ok(ferreiros.size() == 1, "ferreiro da ilha inicial existe, uma vez (%d)" % ferreiros.size())
	var j: Node3D = cena.jogador_local()
	var hud: Node = cena.get("_hud")
	if ferreiros.size() == 1 and j != null:
		var f: NpcDaIlha = ferreiros[0]
		j.global_position = f.global_position + Vector3(0, 1, 1)
		ok(npcs.interagir() and hud.loja_aberta(), "E abre a loja do ferreiro (%s)" % f.global_position)
		hud.fechar_loja()
	# Plano B do `colocar_npcs`: sem nenhum ferreiro, ele nasce ao lado do centro (e só um)
	var vazio := NpcsDaIlha.new()
	vazio.progressao = cena.progressao
	var dados := {"pecas": [{"modelo": "centro_treino_voxel", "posicao": Vector3(cp[0], cp[1], cp[2]), "tamanho": Vector3(11.1, 4.83, 12.91), "rotacao_graus": Vector3(0, 180.0, 0)}]}
	load("res://src/historia/missoes/inicio_da_jornada.gd").colocar_npcs(cena.get_node("Mapa"), dados, MapaMontador.biblioteca_em_uso(), vazio)
	var reserva: Array = vazio.npcs.filter(func(n): return n.tipo == "npc_ferreiro")
	ok(reserva.size() == 1 and (reserva[0] as Node3D).global_position.distance_to(Vector3(cp[0], cp[1] - 2.415, cp[2])) < 11.0, "plano B: ferreiro ao lado do centro (%s)" % (reserva[0].global_position if reserva.size() == 1 else "nenhum"))
	# colisão real e NPCs: o ferreiro e o vendedor de comida (peças do mapa, não mexi neles) de pé no chão, fora da geometria
	var espaco := (cena as Node3D).get_world_3d().direct_space_state
	var vendedores: Array = npcs.npcs.filter(func(n): return str(n.name).begins_with("Npc_mpi_ilha_inicial_loja_0_vendedor"))
	ok(vendedores.size() == 2, "dois vendedores da ex-loja continuam (%d)" % vendedores.size())
	for v: NpcDaIlha in vendedores:
		var pe: Vector3 = v.global_position
		var chao := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(pe + Vector3(0, 0.6, 0), pe + Vector3(0, -8, 0)))
		var dentro := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(pe + Vector3(0, 0.15, 0), pe + Vector3(0, 1.9, 0)))
		print("  ", v.name, " pé=", pe, " chão=", chao.get("position", "nenhum"))
		ok(not chao.is_empty() and absf(chao.position.y - pe.y) < 0.35, "%s pisa no chão (pé %.2f, chão %s)" % [v.name, pe.y, chao.get("position", Vector3.ZERO).y if not chao.is_empty() else "nenhum"])
		ok(dentro.is_empty(), "%s não está dentro de colisão (corpo livre)" % v.name)
	# terreno em volta do centro (raios fora da pegada) e a pegada do centro
	var base_y := float(cp[1]) - 2.415
	var fora: Array[float] = []
	for off in [Vector3(-9, 0, 0), Vector3(9, 0, 0), Vector3(0, 0, -11), Vector3(0, 0, 11)]:
		var h := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(cp[0], 40, cp[2]) + off, Vector3(cp[0], -10, cp[2]) + off))
		if not h.is_empty(): fora.append(h.position.y)
	print("  terreno ao redor do centro: ", fora, " base do centro: ", base_y)
	ok(fora.size() >= 3 and fora.all(func(y): return absf(y - base_y) < 1.2), "terreno ao redor bate com a base do centro (±1,2 m)")
	var achou_chao := false
	var achou_telhado := false
	for i in 40:
		var x := float(cp[0]) + (i % 8 - 3.5) * 1.2
		var z := float(cp[2]) + (i / 8 - 2.0) * 1.8
		var h2 := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -10, z)))
		if not h2.is_empty():
			achou_chao = true
			if h2.position.y > base_y + 3.0: achou_telhado = true
	ok(achou_chao, "raios verticais sobre a pegada encontram chão")
	ok(achou_telhado, "e o telhado/estrutura do pavilhão tem colisão acima do chão")
	# bonecos de treino no pátio (20/11/2026): peças, catálogo, de pé no piso do centro e com colisão própria
	ok(ids.count("boneco_de_treino_1") == 1 and ids.count("boneco_de_treino_2") == 1 and bib.tem("boneco_de_treino_voxel"), "mapa/catálogo: dois bonecos de treino voxel")
	for id_ in ["boneco_de_treino_1", "boneco_de_treino_2"]:
		var bp: Dictionary = pecas[ids.find(id_)]
		var bpos: Array = bp["posicao"]
		var pe := Vector3(bpos[0], float(bpos[1]) - 1.07, bpos[2])
		var piso := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(pe + Vector3(0.5, 3, 0.72), pe + Vector3(0.5, -3, 0.72)))
		ok(not piso.is_empty() and absf(piso.position.y - pe.y) < 0.3, "%s: base apoiada no piso do pátio (base %.2f, piso %s)" % [id_, pe.y, piso.get("position", Vector3.ZERO).y if not piso.is_empty() else "nenhum"])
		var tronco := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(pe + Vector3(0, 1.3, 3), pe + Vector3(0, 1.3, -3)))
		ok(not tronco.is_empty(), "%s: o tronco tem colisão" % id_)
		var caixa_c: Vector3 = Vector3(cp[0], cp[1], cp[2])
		ok(pe.distance_to(caixa_c - Vector3(0, 2.415, 0)) < 9.0, "%s: dentro do centro (%.1f m do centro)" % [id_, pe.distance_to(caixa_c - Vector3(0, 2.415, 0))])
	print("RESULTADO CENTRO: %d checks, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
