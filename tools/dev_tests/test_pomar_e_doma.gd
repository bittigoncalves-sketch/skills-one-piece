extends SceneTree
# ============================================================================
#  TESTE — árvores, frutas do pomar e doma (01/10/2026, docs/FRUTAS_E_DOMA_CHECKPOINT.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pomar_e_doma.gd
#
#  A. loja: os 88 modelos da natureza, frutíferas com pontos de fruta, colisão de tronco,
#     atravessáveis, tamanhos;
#  B. progresso: frutas e pets individuais (ida e volta, save antigo, nomes, morte);
#  C. jogo (Modo História, jogador de verdade) numa CÓPIA do mapa vivo com 4 frutíferas
#     plantadas perto do nascimento: frutas grudadas, queda, coleta passando por cima,
#     rebrotar, teto de 30 no chão, fruta na mão, herbívoro calmo, doma (Y) com sorte,
#     pet que segue, máximo de 6 fora, revide de bicho bravo contra o pet, morte
#     permanente (domado e gaivota).
#  Mapa e progresso de teste em user:// — os do jogador não são lidos nem gravados.
# ============================================================================

const MAPA_VIVO := "res://mapas/historia/baseplate.json"
const MAPA_TESTE := "user://test_pomar_mapa.json"
const PROGRESSO := "user://test_pomar_progresso.json"
const FRUTIFERAS := ["arvore_verde_adulta", "cerejeira_adulta", "pinheiro_adulto", "arvore_gigante"]

var _falhas := 0
var _bib: BibliotecaDeModelos
var _arvores_postas: Array[Dictionary] = []


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	seed(7)
	print("\n===== POMAR E DOMA =====")
	_bib = BibliotecaDeModelos.padrao()
	_loja()
	_progresso()
	await _no_jogo()
	print("\nPOMAR_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ A. loja
func _loja() -> void:
	print("\n-- A. loja --")
	var por_cat := {"arvores": 0, "frutas": 0, "floresta": 0}
	for id in _bib.ids():
		for c in por_cat:
			if _bib.categorias_do_modelo(id).has(c):
				por_cat[c] += 1
	_ok(por_cat["frutas"] == 6 and por_cat["arvores"] >= 50 and por_cat["floresta"] >= 30,
		"categorias novas: %s" % str(por_cat))
	for id in FRUTIFERAS:
		var m := _bib.instanciar(id)
		var pontos := m.find_children("Fruta_*", "", true, false).size()
		m.free()
		var faces := (_bib.forma_de_colisao(id, _bib.tamanho_padrao(id)) as ConcavePolygonShape3D).get_faces().size() / 3
		_ok(pontos == 5 and not _bib.frutas_da_arvore(id).is_empty() and faces <= 40,
			"%s: 5 pontos de fruta, dá %s, colide só pelo tronco (%d faces)" % [id, str(_bib.frutas_da_arvore(id)), faces])
	var sem_colisao := ["fruta_maca", "floresta_grass_large", "floresta_bush_large", "floresta_mushroom_red_large", "crops"]
	_ok(sem_colisao.all(func(i: String) -> bool: return _bib.atravessavel(i)), "fruta, capim, arbusto, cogumelo e plantação atravessáveis")
	_ok(not _bib.atravessavel("floresta_rock_05") and not _bib.atravessavel("pinheiro_adulto"), "pedra e árvore colidem")
	var h_maca := _bib.tamanho_padrao("fruta_maca").y
	var h_pinheiro := _bib.tamanho_padrao("pinheiro_adulto").y
	_ok(h_maca > 0.35 and h_maca < 0.55 and h_pinheiro > 9.0 and h_pinheiro < 11.0,
		"escala do jogador: maçã %.2f m, pinheiro %.1f m" % [h_maca, h_pinheiro])


# ------------------------------------------------------------- B. progresso
func _progresso() -> void:
	print("\n-- B. progresso --")
	var p := ProgressaoDoPersonagem.new()
	_ok(p.pets.is_empty(), "jogo novo começa sem nenhum pet (pedido do dono, 18/10/2026)")
	p.ganhar_fruta_do_pomar("fruta_maca", 3)
	_ok(p.gastar_fruta_do_pomar("fruta_maca") and p.quantas_frutas_do_pomar("fruta_maca") == 2, "ganhar e gastar fruta")
	_ok(not p.gastar_fruta_do_pomar("fruta_cereja"), "não gasta o que não tem")
	var c1 := p.adicionar_pet("rabbit", "Coelho")
	var c2 := p.adicionar_pet("rabbit", "Coelho")
	_ok(c1 == "rabbit_1" and c2 == "rabbit_2" and p.nome_do_pet(c2) == "Coelho 2" and p.especie_do_pet(c2) == "rabbit",
		"vários da mesma espécie, com nome numerado (%s, %s)" % [p.nome_do_pet(c1), p.nome_do_pet(c2)])
	var volta := ProgressaoDoPersonagem.de_dict(JSON.parse_string(JSON.stringify(p.para_dict())))
	_ok(volta.quantas_frutas_do_pomar("fruta_maca") == 2 and volta.tem_pet("rabbit_2") and volta.tem_pet("rabbit_1"),
		"ida e volta pelo arquivo guarda frutas e pets")
	p.remover_pet("rabbit_1")
	_ok(not p.tem_pet("rabbit_1"), "pet removido some")
	var antigo := ProgressaoDoPersonagem.new().para_dict()
	antigo["pets"] = {"gaivota": {"modo": "agressivo"}, "caranguejo": {"modo": "livre"}, "lixo": {"modo": "x"}}
	antigo.erase("frutas_do_pomar")
	var lido := ProgressaoDoPersonagem.de_dict(antigo)
	_ok(lido.tem_pet("gaivota") and lido.modo_do_pet("gaivota") == &"agressivo" and lido.especie_do_pet("caranguejo") == "caranguejo"
		and not lido.tem_pet("lixo") and lido.frutas_do_pomar.is_empty(), "save de antes de 01/10 continua valendo")
	var vazio := ProgressaoDoPersonagem.new().para_dict()
	vazio["pets"] = {}
	_ok(ProgressaoDoPersonagem.de_dict(vazio).pets.is_empty(), "quem perdeu todos os pets não os ganha de volta ao carregar")


# ------------------------------------------------------------------ C. jogo
func _mapa_de_teste() -> String:
	var lido := MapaArquivo.carregar(MAPA_VIVO)
	var mapa: Dictionary = lido["mapa"]
	var terrenos := (mapa["pecas"] as Array).filter(func(p: Dictionary) -> bool: return p["tipo"] == "terreno")
	var spawn: Vector3 = mapa["spawn"]["posicao"]
	# Num descampado ao norte da praça da vila.
	var lugares := [Vector2(150, -55), Vector2(162, -55), Vector2(174, -55), Vector2(186, -55)]
	for i in FRUTIFERAS.size():
		var id: String = FRUTIFERAS[i]
		var t := _bib.tamanho_padrao(id)
		var c: Vector2 = lugares[i]
		var chao := _chao_do_relevo(terrenos, c)
		var p := {"id": "teste_frutifera_%d" % i, "tipo": "modelo", "modelo": id,
			"posicao": Vector3(c.x, chao + t.y * 0.5, c.y), "rotacao_graus": Vector3.ZERO, "tamanho": t,
			"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true, "grupo": ""}
		(mapa["pecas"] as Array).append(p)
		_arvores_postas.append(p)
	_ok(MapaArquivo.salvar(MAPA_TESTE, mapa) == OK, "cópia do mapa vivo com 4 frutíferas em user://")
	return MAPA_TESTE


func _chao_do_relevo(terrenos: Array, c: Vector2) -> float:
	for p: Dictionary in terrenos:
		var pos: Vector3 = p["posicao"]
		var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], c.x - pos.x, c.y - pos.z)
		if not is_nan(y):
			return pos.y + y
	return 0.0


func _no_jogo() -> void:
	print("\n-- C. no Modo História, com o jogador de verdade --")
	var caminho := _mapa_de_teste()
	var modo_script: Script = load("res://src/historia/ModoHistoria.gd")
	modo_script.set("mapa_forcado", caminho)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo_script.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 160:
		await process_frame
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var modo := current_scene
	var pomar := modo.get_node_or_null("Pomar") as PomarDaIlha
	var pop := modo.get_node_or_null("Animais") as PopulacaoDeAnimais
	var mao := modo.get_node_or_null("FrutaNaMao") as FrutaNaMao
	var comp: Node = modo.get_node_or_null("Companhia")
	var prog: ProgressaoDoPersonagem = modo.get("progressao")
	var hud: Node = modo.get("_hud")
	_ok(jogador != null and pomar != null and pop != null and mao != null and comp != null, "Modo História com pomar, animais, mão e pets")
	if jogador == null or pomar == null:
		return
	await _frutas_nas_arvores(pomar)
	await _queda_e_coleta(pomar, jogador, prog, hud)
	await _mao_e_doma(modo, pomar, pop, mao, comp, prog, jogador, hud)
	modo_script.set("mapa_forcado", "")
	modo_script.set("progresso_forcado", "")
	PomarDaIlha.intervalo_de_queda = 300.0
	PomarDaIlha.tempo_de_rebrotar = 300.0
	PopulacaoDeAnimais.renasce_em = 30.0
	modo_script.set("chance_de_doma", 0.35)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAPA_TESTE))


func _frutas_nas_arvores(pomar: PomarDaIlha) -> void:
	print("\n-- C1. frutas grudadas --")
	var minhas := _minhas(pomar)
	_ok(minhas.size() == 4 and pomar.arvores.size() >= 4,
		"as 4 frutíferas do teste no pomar (%d no mapa todo)" % pomar.arvores.size())
	var fora := []
	var especies := {}
	for a in minhas:
		especies[a["fruta"]] = true
		var peca: Dictionary = _arvores_postas.filter(func(p: Dictionary) -> bool: return p["id"] == a["id"])[0]
		var c: Vector3 = peca["posicao"]
		var t: Vector3 = peca["tamanho"]
		for g: Dictionary in a["galhos"]:
			var p: Vector3 = (g["visual"] as Node3D).global_position
			var dentro := absf(p.x - c.x) <= t.x * 0.55 and absf(p.z - c.z) <= t.z * 0.55 \
				and p.y >= c.y - t.y * 0.5 + t.y * 0.25 and p.y <= c.y + t.y * 0.55
			if not dentro or not (g["visual"] as Node3D).visible:
				fora.append(a["id"])
	_ok(fora.is_empty(), "20 frutas na copa das 4 árvores do teste, visíveis %s" % str(fora))
	var cerejeira: Dictionary = minhas.filter(func(a: Dictionary) -> bool: return a["id"] == "teste_frutifera_1")[0]
	var pinheiro: Dictionary = minhas.filter(func(a: Dictionary) -> bool: return a["id"] == "teste_frutifera_2")[0]
	_ok(cerejeira["fruta"] == "fruta_cereja" and pinheiro["fruta"] == "fruta_pinha", "cerejeira dá cereja, pinheiro dá pinha")
	await physics_frame


func _queda_e_coleta(pomar: PomarDaIlha, jogador: Node3D, prog: ProgressaoDoPersonagem, hud: Node) -> void:
	print("\n-- C2. queda, coleta, rebrotar --")
	jogador.global_position = Vector3(150, 40, 0)   # longe das árvores (não pegar sem querer)
	var caidas := []
	pomar.fruta_caiu.connect(func(arv: String, f: String): caidas.append([arv, f]))
	PomarDaIlha.intervalo_de_queda = 1.0
	pomar.set("_relogio", 1.0)
	for i in 80:
		await physics_frame
	_ok(caidas.size() == 1 and pomar.no_chao.size() == 1, "a cada intervalo cai UMA fruta de uma árvore (%d)" % caidas.size())
	PomarDaIlha.intervalo_de_queda = 9999.0
	pomar.set("_relogio", 9999.0)
	var total := 0
	var presentes := 0
	for a in pomar.arvores:
		for g in a["galhos"]:
			total += 1
			presentes += int(g["presente"])
	_ok(presentes == total - 1, "o galho da que caiu ficou vazio (%d de %d na copa)" % [presentes, total])
	if pomar.no_chao.is_empty():
		return
	var item: FrutaNoChao = pomar.no_chao[0]
	for i in 120:
		await physics_frame
		if item.no_chao:
			break
	var chao := _chao_em(item.global_position)
	_ok(item.no_chao and absf(item.global_position.y - chao - 0.15) < 0.1,
		"caiu, quicou e parou no chão (%.2f m acima do relevo)" % (item.global_position.y - chao))
	var fruta := item.fruta_id
	var antes := prog.quantas_frutas_do_pomar(fruta)
	jogador.global_position = item.global_position + Vector3.UP * 0.5
	jogador.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	var aviso: Label = hud.get("_aviso")
	_ok(prog.quantas_frutas_do_pomar(fruta) == antes + 1 and pomar.no_chao.is_empty(),
		"passar por cima recolhe: %s × %d" % [fruta, prog.quantas_frutas_do_pomar(fruta)])
	_ok(aviso != null and aviso.text.begins_with("+1 "), "aviso no HUD: \"%s\"" % (aviso.text if aviso else "?"))
	PomarDaIlha.tempo_de_rebrotar = 0.5
	for a in pomar.arvores:
		for g in a["galhos"]:
			if not g["presente"]:
				g["volta_em"] = float(pomar.get("_agora")) + 0.5
	var fim := Time.get_ticks_msec() + 1200       # tempo de verdade (headless corre quadros)
	while Time.get_ticks_msec() < fim:
		await process_frame
	var cheias := 0
	for a in pomar.arvores:
		for g in a["galhos"]:
			cheias += int(g["presente"] and (g["visual"] as Node3D).visible)
	_ok(cheias == total, "o galho rebrota depois do prazo (%d de %d)" % [cheias, total])
	# Teto: 30 no chão; a mais antiga some.
	PomarDaIlha.tempo_de_rebrotar = 0.0
	jogador.global_position = Vector3(150, 60, 0)
	for i in 40:
		pomar.derrubar_uma()
		await process_frame
	_ok(pomar.no_chao.size() == PomarDaIlha.MAX_NO_CHAO, "no chão, no máximo %d (%d)" % [PomarDaIlha.MAX_NO_CHAO, pomar.no_chao.size()])
	for f in pomar.no_chao.duplicate():
		f.queue_free()
	pomar.no_chao.clear()


func _mao_e_doma(modo: Node, _pomar: PomarDaIlha, pop: PopulacaoDeAnimais, mao: FrutaNaMao, comp: Node,
		prog: ProgressaoDoPersonagem, jogador: Node3D, hud: Node) -> void:
	print("\n-- C3. fruta na mão e doma --")
	var aviso: Label = hud.get("_aviso")
	prog.ganhar_fruta_do_pomar("fruta_maca", 30)
	var inv: InventarioDaHistoria = hud.call("inventario")
	var slot := -1
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		if InventarioMinecraft.id_de(prog.inventario.pilha(i)) == ItensDeFruta.tag_pomar("fruta_maca"):
			slot = i
	_ok(slot >= 0, "a maçã é item na hotbar (`pomar:fruta_maca`)")
	prog.inventario.selecionado = slot - InventarioMinecraft.HOTBAR_INI
	for i in 3:
		await process_frame
	_ok(mao.fruta_id == "fruta_maca", "selecionar o slot da maçã na hotbar a põe na mão")
	for i in 3:
		await process_frame
	var na_mao := jogador.find_child("FrutaNaMao", true, false)
	_ok(na_mao != null and str(jogador.get_meta("fruta_na_mao", "")) == "fruta_maca", "a maçã aparece presa na mão do personagem")
	# Herbívoro calmo: o coelho (alerta 8 m) não foge de quem tem fruta na mão.
	var coelho := _um(pop, "rabbit")
	PopulacaoDeAnimais.renasce_em = 1.0
	await _encostar(jogador, coelho, 2.5, pop)
	for i in 90:
		await physics_frame
	_ok(coelho.estado != AnimalDaIlha.Estado.FUGINDO and _dist(jogador, coelho) < 4.0,
		"com fruta na mão o coelho não foge (%.1f m)" % _dist(jogador, coelho))
	# Sorte: 0 % gasta a fruta e não doma.
	modo.set("chance_de_doma", 0.0)
	var macas := prog.quantas_frutas_do_pomar("fruta_maca")
	var pets_antes_da_tentativa := prog.pets.size()
	mao.pedir_doma()
	_ok(prog.quantas_frutas_do_pomar("fruta_maca") == macas - 1 and prog.pets.size() == pets_antes_da_tentativa and aviso.text.contains("não confiou"),
		"tentativa que falha gasta 1 fruta e não doma (\"%s\")" % aviso.text)
	# 100 %: vira pet no lugar; a área repõe o selvagem.
	modo.set("chance_de_doma", 1.0)
	var onde := coelho.global_position
	mao.pedir_doma()
	await physics_frame
	var pet: Node3D = comp.call("pet_fora", "rabbit_1")
	_ok(prog.tem_pet("rabbit_1") and pet is PetDomado and pet.global_position.distance_to(onde) < 0.6 and not coelho.visible,
		"domado: vira o pet \"Coelho\" no mesmo lugar (\"%s\")" % aviso.text)
	for i in 90:
		await physics_frame
	_ok(coelho.vivo() and coelho.visible or coelho.nivel_de_detalhe == 2, "a área repõe um coelho selvagem")
	# Segue o dono.
	jogador.global_position += Vector3(12, 0, 0)
	jogador.global_position.y = _chao_em(jogador.global_position) + 1.0
	for i in 300:
		await physics_frame
	_ok(_dist(jogador, pet) < 5.5, "o pet segue o dono (%.1f m)" % _dist(jogador, pet))
	# Longe de herbívoro: avisa e não gasta.
	jogador.global_position = Vector3(150, 60, 0)
	macas = prog.quantas_frutas_do_pomar("fruta_maca")
	mao.pedir_doma()
	_ok(prog.quantas_frutas_do_pomar("fruta_maca") == macas and aviso.text.contains("Nenhum animal"), "sem herbívoro perto: avisa e não gasta")
	# Máximo de 6 fora: doma mais 6 (galinhas, vacas, ovelhas...) — o 7º vai para o inventário.
	var domados := 1
	var no_inventario := ""
	for a in pop.animais:
		if domados >= 7 or not FichaDeAnimal.domavel(a.ficha) or not a.vivo() or a.especie == "rabbit":
			continue
		await _encostar(jogador, a, 2.0, pop)
		var antes := prog.pets.size()
		mao.pedir_doma()
		await physics_frame
		if prog.pets.size() == antes + 1:
			domados += 1
			if aviso.text.contains("inventário"):
				no_inventario = aviso.text
	_ok(int(comp.call("quantos_fora")) == 6 and not no_inventario.is_empty(),
		"6 pets fora no máximo; o 7º domado foi para o inventário (\"%s\")" % no_inventario)
	var guardado := ""
	for id in prog.pets:
		if not comp.call("esta_fora", id):
			guardado = id
	_ok(not guardado.is_empty() and not inv.tirar(guardado) and str(comp.get("motivo")).contains("máximo"),
		"inventário recusa tirar o 7º: \"%s\"" % str(comp.get("motivo")))
	# O soco do próprio dono não acha o pet (sem hitbox, camada 0).
	var pet_coelho: Node3D = comp.call("pet_fora", "rabbit_1")
	if pet_coelho != null:
		_ok(pet_coelho.get_node_or_null("Visual/Hurtbox") == null and (pet_coelho as CollisionObject3D).collision_layer == 0,
			"pet domado sem hitbox de golpe e na camada 0 (o dono não o fere)")
	# Revide e morte permanente.
	var bufalo := _um(pop, "bizon") if _um(pop, "bizon") != null else _um(pop, "bufalo")
	var pet_luta: Node3D = null
	for id in prog.pets:
		var corpo: Node3D = comp.call("pet_fora", id)
		if corpo is PetDomado:
			pet_luta = corpo
			break
	if bufalo != null and pet_luta != null and not bufalo.is_in_group("pets_historia"):
		pet_luta.global_position = bufalo.global_position + Vector3(2, 0.3, 0)
		bufalo.take_damage(1.0, pet_luta.global_position)
		_ok(bufalo.oponente == pet_luta, "bicho bravo atacado por um pet revida contra o PET")
	var id_morto: String = pet_luta.get("pet_id") if pet_luta != null else ""
	var nome_morto: String = prog.nome_do_pet(id_morto)
	pet_luta.call("take_damage", 99999.0, pet_luta.global_position)
	for i in 5:
		await process_frame
	_ok(not prog.tem_pet(id_morto) and aviso.text.contains("morreu") and inv.get("_linhas").has(id_morto) == false,
		"pet morto (%s) sai do progresso e do inventário para sempre" % nome_morto)
	comp.call("recolher", guardado)
	# Sem pets iniciais desde 18/10/2026: a gaivota entra pelo progresso, como um pet ganho.
	var id_gaivota := prog.adicionar_pet("gaivota", "Gaivota")
	_ok(comp.call("chamar", id_gaivota) or str(comp.get("motivo")).contains("máximo"), "gaivota chamada (ou cheio)")
	if not comp.call("esta_fora", id_gaivota):
		for id in prog.pets:
			if comp.call("esta_fora", id):
				comp.call("recolher", id)
				break
		comp.call("chamar", id_gaivota)
	var gaivota: Node3D = comp.call("pet_fora", id_gaivota)
	if gaivota != null:
		gaivota.call("take_damage", 999.0)
		for i in 5:
			await process_frame
	_ok(gaivota != null and not prog.tem_pet(id_gaivota), "a gaivota também morre de vez")
	mao.guardar()
	await process_frame
	_ok(str(jogador.get_meta("fruta_na_mao", "")) == "" and jogador.find_child("FrutaNaMao", true, false) == null,
		"Guardar esvazia a mão")


# ------------------------------------------------------------------ apoio
func _minhas(pomar: PomarDaIlha) -> Array:
	return pomar.arvores.filter(func(a: Dictionary) -> bool: return String(a["id"]).begins_with("teste_frutifera_"))


func _um(pop: PopulacaoDeAnimais, especie: String) -> AnimalDaIlha:
	for a in pop.animais:
		if a.especie == especie and a.vivo():
			return a
	return null


func _encostar(jogador: Node3D, animal: AnimalDaIlha, distancia: float, pop: PopulacaoDeAnimais) -> void:
	# Na altura do PRÓPRIO bicho (ele está no relevo): o raio de chão pode bater num
	# tronco ou pedra da floresta e pôr o jogador lá em cima.
	jogador.global_position = animal.global_position + Vector3(distancia, 0.6, 0)
	jogador.velocity = Vector3.ZERO
	animal.estado = AnimalDaIlha.Estado.PARADO
	animal.set("_relogio", 99.0)
	pop.atualizar_detalhe()
	await physics_frame


func _dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func _chao_em(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 300, p.z), Vector3(p.x, -50, p.z), 1)
	var excluir: Array[RID] = []
	for a in get_nodes_in_group("animais"):
		excluir.append((a as CollisionObject3D).get_rid())
	q.exclude = excluir
	var h := root.get_world_3d().direct_space_state.intersect_ray(q)
	return (h["position"] as Vector3).y if not h.is_empty() else 0.0
