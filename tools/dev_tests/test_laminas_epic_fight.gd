extends SceneTree
## Lâminas do Epic Fight no inventário de teste (10/11/2026): seis lâminas, equipar/guardar, salvar/carregar e,
## na cena real do Modo História, modelo voxel na mão, alcance e dano do executor.
const MAPA := "user://test_laminas_ef.json"
const SAVE := "user://test_laminas_ef_progresso.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func _prog_equipada(id: String) -> ProgressaoDoPersonagem:
	var q := ProgressaoDoPersonagem.new()
	q.equipar_lamina(id, true)
	return q
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	# ---- progressão pura
	var p := ProgressaoDoPersonagem.new()
	var com_mod := not EpicFightDados.itens().is_empty()
	ok(LaminasEpicFight.ids().size() == (32 if com_mod else 6) and LaminasEpicFight.ids().all(func(i): return p.equipamentos.has(i)), "jogador novo tem todas as armas do mod (%d)" % LaminasEpicFight.ids().size())
	ok(not p.equipamentos.has("espada") and not p.equipamentos.has("machado"), "continua sem a espada antiga nem o machado")
	ok(p.equipar_lamina("ef_iron_tachi", true) and p.lamina_ef == "ef_iron_tachi" and p.item_em_uso() == "espada", "equipar tachi vira o item 'espada'")
	ok(p.itens_da_barra().has("espada"), "a lâmina aparece na barra de itens")
	var q := ProgressaoDoPersonagem.de_dict(p.para_dict())
	ok(q.lamina_ef == "ef_iron_tachi" and q.espada_equipada, "salvar/carregar mantém a lâmina equipada")
	ok(not p.equipar_lamina("ef_inexistente", true), "id inexistente é recusado")
	ok(p.equipar_lamina("ef_iron_tachi", false) and p.lamina_ef == "" and not p.itens_da_barra().has("espada"), "guardar tira da barra")
	# save antigo sem lâminas também recebe
	var antigo := ProgressaoDoPersonagem.de_dict({"formato": ProgressaoDoPersonagem.FORMATO, "equipamentos": {"vara_de_pesca": true}})
	ok(LaminasEpicFight.ids().all(func(i): return antigo.equipamentos.has(i)) and antigo.equipamentos.has("vara_de_pesca"), "save antigo recebe as lâminas e mantém a vara")
	# ---- durabilidade (1 uso por golpe que acerta; zerou = quebrou e não volta)
	var dp := ProgressaoDoPersonagem.new()
	ok(dp.durabilidade_de("ef_wooden_dagger") == LaminasEpicFight.durabilidade_maxima("ef_wooden_dagger"), "arma nova tem a durabilidade cheia")
	if com_mod:
		ok(LaminasEpicFight.durabilidade_maxima("ef_wooden_dagger") == 59 and LaminasEpicFight.durabilidade_maxima("ef_netherite_greatsword") == 2031 and LaminasEpicFight.durabilidade_maxima("ef_uchigatana") == 1625, "durabilidade do mod (madeira 59, netherite 2031, uchigatana 1625)")
	var cheia := LaminasEpicFight.durabilidade_maxima("ef_wooden_dagger")
	dp.equipar_lamina("ef_wooden_dagger", true)
	ok(not dp.gastar_durabilidade("ef_wooden_dagger", cheia - 1) and dp.durabilidade_de("ef_wooden_dagger") == 1, "gastar até sobrar 1 uso não quebra")
	var salvo := ProgressaoDoPersonagem.de_dict(dp.para_dict())
	ok(salvo.durabilidade_de("ef_wooden_dagger") == 1 and salvo.equipamentos.has("ef_wooden_dagger"), "o desgaste é salvo")
	ok(dp.gastar_durabilidade("ef_wooden_dagger") and not dp.equipamentos.has("ef_wooden_dagger") and dp.lamina_ef == "" and dp.ef_quebradas.has("ef_wooden_dagger"), "o último uso quebra: some do inventário e sai da mão")
	var depois := ProgressaoDoPersonagem.de_dict(dp.para_dict())
	ok(not depois.equipamentos.has("ef_wooden_dagger") and depois.equipamentos.has("ef_iron_dagger"), "a arma quebrada não volta ao carregar o save (as outras ficam)")
	# ---- estilo dual (mão esquerda): adaga+adaga / espada+espada, itens diferentes
	if com_mod:
		var dd := ProgressaoDoPersonagem.new()
		ok(not dd.equipar_lamina_secundaria("ef_golden_dagger", true), "sem arma principal não há segunda")
		dd.equipar_lamina("ef_iron_dagger", true)
		ok(dd.equipar_lamina_secundaria("ef_golden_dagger", true) and dd.lamina_ef_sec == "ef_golden_dagger", "adaga de ferro + adaga de ouro = dual")
		ok(not dd.equipar_lamina_secundaria("ef_iron_dagger", true) and not dd.equipar_lamina_secundaria("ef_iron_tachi", true), "a mesma arma, ou outro tipo, não vai para a esquerda")
		var dsalvo := ProgressaoDoPersonagem.de_dict(dd.para_dict())
		ok(dsalvo.lamina_ef_sec == "ef_golden_dagger", "a segunda arma é salva")
		dd.equipar_lamina("ef_iron_dagger", false)
		ok(dd.lamina_ef_sec == "", "guardar a principal guarda a segunda")
		var du := LaminasEpicFight.dados_dual("ef_iron_dagger", "ef_diamond_dagger")
		ok(du.dual and is_equal_approx(du.dano_do_mod, (LaminasEpicFight.dano_do_mod("ef_iron_dagger") + LaminasEpicFight.dano_do_mod("ef_diamond_dagger")) * 0.5), "dano dual = média das duas adagas (golpes alternam as mãos)")
		var ed := EstiloEpicFight.criar("dagger", 2.4, true)
		ok(ed != null and ed.id == &"ef_dagger_dual" and ed.sequencia_cliques.size() == 4 and ed.validar().is_empty(), "estilo dual: 4 autos do mod e válido")
		ok(ed.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA).nome == "dagger_dual_auto1" and ed.golpe_para(GolpeDirecional.Direcao.AUTO_4).nome == "dagger_dual_auto4" and ed.golpe_para(GolpeDirecional.Direcao.CORRIDA).nome == "dagger_dual_dash", "cadeia dual: auto1…auto4 e dash dual do mod")
		ok(ed.golpe_para(GolpeDirecional.Direcao.PARA_DIREITA).efetor == &"EspadaPontaL" and ed.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA).efetor != &"EspadaPontaL", "o auto2 (toolL no mod) varre a lâmina ESQUERDA; o auto1 a direita")
	# ---- dados: alcance e dano por arma
	var cm := {}
	for id in LaminasEpicFight.ids():
		var d := LaminasEpicFight.dados(id)
		cm[id] = d
		ok(d.ponta.y > d.base.y and LaminasEpicFight.cena(id) != null, "%s: tem modelo e alcance" % id)
	for velho in LaminasEpicFight.APELIDOS:
		cm[velho] = LaminasEpicFight.dados(velho)
		ok(not cm[velho].is_empty(), "o id antigo %s ainda resolve" % velho)
	ok(cm["ef_iron_spear"].ponta.y > cm["ef_iron_greatsword"].ponta.y and cm["ef_iron_greatsword"].ponta.y > cm["ef_iron_longsword"].ponta.y and cm["ef_iron_longsword"].ponta.y > cm["ef_iron_dagger"].ponta.y, "alcance: lança > montante > longa > adaga")
	ok(cm["ef_iron_greatsword"].multiplicador > cm["ef_iron_longsword"].multiplicador and cm["ef_iron_longsword"].multiplicador > cm["ef_iron_dagger"].multiplicador, "dano: montante > longa > adaga")
	ok(is_equal_approx(cm["ef_iron_longsword"].multiplicador, 1.0), "espada longa = dano base 1,0")
	if com_mod:
		# FIDELIDADE: números do Java do mod (`TieredWeaponItem.createAttributes`): dano = 1 + base + bônus do material; velocidade = 4 + atributo.
		ok(is_equal_approx(LaminasEpicFight.dano_do_mod("ef_iron_longsword"), 7.0) and is_equal_approx(LaminasEpicFight.velocidade_do_mod("ef_iron_longsword"), 1.2), "espada longa de ferro: dano 7, vel. 1,2")
		ok(is_equal_approx(LaminasEpicFight.dano_do_mod("ef_diamond_greatsword"), 15.0), "montante de diamante: dano 15 (11 + 3 + 1)")
		ok(is_equal_approx(LaminasEpicFight.dano_do_mod("ef_netherite_dagger"), 6.0) and is_equal_approx(LaminasEpicFight.velocidade_do_mod("ef_netherite_dagger"), 2.4), "adaga de netherite: dano 6, vel. 2,4")
		ok(is_equal_approx(LaminasEpicFight.dano_do_mod("ef_uchigatana"), 7.0) and is_equal_approx(LaminasEpicFight.velocidade_do_mod("ef_uchigatana"), 2.0), "uchigatana: dano 7, vel. 2,0")
		ok(is_equal_approx(LaminasEpicFight.dano_do_mod("ef_wooden_spear"), 4.0) and is_equal_approx(LaminasEpicFight.dano_do_mod("ef_netherite_spear"), 8.0), "lança: 3 + tier + 1 (madeira 4, netherite 8)")
		ok(LaminasEpicFight.dano_do_mod("ef_netherite_longsword") > LaminasEpicFight.dano_do_mod("ef_golden_longsword"), "material importa: netherite > ouro")
		ok(LaminasEpicFight.max_alvos("ef_iron_greatsword") == 4 and LaminasEpicFight.max_alvos("ef_iron_longsword") == 2 and LaminasEpicFight.max_alvos("ef_uchigatana") == 1, "max_strikes do mod: montante 4, espada longa 2, uchigatana 1")
		ok(LaminasEpicFight.impacto("ef_netherite_greatsword") > LaminasEpicFight.impacto("ef_wooden_greatsword"), "impacto sobe com o material")
		# ARTE: a textura do mod virou voxels (tem malha, e a ponta fica na altura certa)
		var modelo := LaminasEpicFight.cena("ef_iron_longsword").instantiate()
		var mi := modelo.get_node("Voxels") as MeshInstance3D
		var aabb := mi.mesh.get_aabb()
		var d_l := LaminasEpicFight.dados("ef_iron_longsword")
		ok(mi.mesh.get_surface_count() == 1 and mi.mesh.get_faces().size() > 300, "modelo da espada longa: voxels da textura real (%d vértices)" % mi.mesh.get_faces().size())
		ok(absf((mi.position.y + aabb.end.y) - d_l.ponta.y) < 0.06, "a ponta do modelo bate com o alcance (%.2f vs %.2f)" % [mi.position.y + aabb.end.y, d_l.ponta.y])
		ok(aabb.size.z < aabb.size.y * 0.2, "o modelo é fino (extrusão de 1 pixel)")
		modelo.free()
		# empunhadura padrão: lança a DUAS mãos (impacto 1,6 / 3 alvos do `two_hand`), adaga a uma (0,7 / 1)
		ok(is_equal_approx(LaminasEpicFight.impacto("ef_iron_spear"), 1.6) and LaminasEpicFight.max_alvos("ef_iron_spear") == 3, "lança de ferro: atributos de duas mãos (1,6 / 3 alvos)")
		ok(is_equal_approx(LaminasEpicFight.impacto("ef_iron_dagger"), 0.7) and LaminasEpicFight.max_alvos("ef_iron_dagger") == 1, "adaga de ferro: uma mão (0,7 / 1 alvo)")
		# sons do mod: swingSound da categoria e hitSound do material
		ok(LaminasEpicFight.sons("ef_iron_dagger").golpe == ["whoosh_small"] and LaminasEpicFight.sons("ef_iron_greatsword").golpe == ["whoosh_hard"] and LaminasEpicFight.sons("ef_iron_spear").golpe == ["whoosh_rod"] and LaminasEpicFight.sons("ef_iron_tachi").golpe == ["whoosh"], "swingSound por categoria (adaga small, montante hard, lança rod)")
		ok(LaminasEpicFight.sons("ef_wooden_tachi").impacto[0].begins_with("blunt_hit") and LaminasEpicFight.sons("ef_stone_tachi").impacto == ["blunt_hit_hard"] and LaminasEpicFight.sons("ef_iron_tachi").impacto[0].begins_with("blade_hit"), "hitSound por material (madeira contundente, pedra dura, o resto lâmina)")
		ok(SonsEpicFight.stream("blade_hit1") != null and SonsEpicFight.stream("whoosh_hard") != null, "os .ogg do mod carregam")
		var ic := LaminasEpicFight.icone("ef_diamond_greatsword")
		ok(ic != null and ic.get_width() == 16 and ItensDoJogo.textura("espada", _prog_equipada("ef_diamond_greatsword")) == ic, "a barra de itens mostra o ÍCONE DO MOD da arma empunhada")
		var estilo_rapido := EstiloEpicFight.criar("dagger", 4.8)
		var estilo_normal := EstiloEpicFight.criar("dagger", 2.4)
		ok(estilo_rapido.golpes[0].duracao() < estilo_normal.golpes[0].duracao() * 0.6 and estilo_rapido.golpes[0].velocidade_clipe > estilo_normal.golpes[0].velocidade_clipe, "velocidade do item encurta o golpe (2× vel. → ~0,5× duração)")
	# ---- cena real
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(64, 2, 64)
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
	var arma = j.get_node_or_null("EspadaDaHistoria")
	var ex: ExecutorCorpoACorpo = j.get("combate_direcional")
	ok(arma != null and ex != null, "cena real tem a espada da história e o executor")
	var mult0 := ex.multiplicador_de_dano
	ok(prog.equipamentos.has("ef_iron_greatsword"), "jogador da cena tem o montante")
	prog.equipar_lamina("ef_iron_greatsword", true)
	await quadros(30)
	ok(arma.ativa and arma.lamina_ef == "ef_iron_greatsword", "montante ativo na mão")
	ok(arma.visual() != null and arma.visual().find_child("Voxels", true, false) is MeshInstance3D, "modelo voxel montado na mão")
	var alcance_mont: float = arma.ponto(&"EspadaPonta").distance_to(arma.ponto(&"EspadaBase"))
	ok(alcance_mont > 1.2, "alcance varrido pelo executor ≈ comprimento (%.2f m)" % alcance_mont)
	ok(is_equal_approx(ex.multiplicador_de_dano, LaminasEpicFight.multiplicador("ef_iron_greatsword")), "dano do executor = do montante (%.2f)" % ex.multiplicador_de_dano)
	ok(ex.max_alvos == LaminasEpicFight.max_alvos("ef_iron_greatsword"), "executor limita os alvos por golpe ao max_strikes do montante (%d)" % ex.max_alvos)
	prog.equipar_lamina("ef_iron_dagger", true)
	await quadros(30)
	ok(ex.max_alvos == 1, "adaga: 1 alvo por golpe (max_strikes 0 do mod = o padrão 1)")
	var alcance_adaga: float = arma.ponto(&"EspadaPonta").distance_to(arma.ponto(&"EspadaBase"))
	ok(arma.lamina_ef == "ef_iron_dagger" and alcance_adaga < alcance_mont * 0.5, "trocar para a adaga encurta o alcance (%.2f m)" % alcance_adaga)
	ok(is_equal_approx(ex.multiplicador_de_dano, LaminasEpicFight.multiplicador("ef_iron_dagger")), "dano do executor = da adaga")
	# ---- bancada: receitas do mod (26, 3×3) fabricam a arma consumindo os ingredientes
	if com_mod:
		ok(BancadaEpicFight.ids().size() == 25 and BancadaEpicFight.ids().has("ef_iron_longsword") and not BancadaEpicFight.ids().has("ef_netherite_dagger"), "25 receitas de arma do mod (a luva é punho; sem netherite: é ferraria no mod)")
		var bp := ProgressaoDoPersonagem.new()
		bp.equipamentos.erase("ef_iron_longsword")
		ok(BancadaEpicFight.contagem("ef_iron_longsword") == {"X": 2, "#": 1} and not BancadaEpicFight.pode_fabricar(bp.inventario, "ef_iron_longsword"), "espada longa de ferro: 2 barras + 1 espada de ferro (padrão do mod); mochila vazia não fabrica")
		bp.inventario.inserir(InventarioMinecraft.nova("minecraft:iron_ingot", 2))
		bp.inventario.inserir(InventarioMinecraft.nova("minecraft:iron_sword", 1))
		ok(BancadaEpicFight.pode_fabricar(bp.inventario, "ef_iron_longsword") and BancadaEpicFight.fabricar(bp, "ef_iron_longsword"), "com os ingredientes fabrica")
		ok(bp.equipamentos.has("ef_iron_longsword") and bp.inventario.contar("minecraft:iron_ingot") == 0 and bp.inventario.contar("minecraft:iron_sword") == 0, "consome exatamente o padrão e entrega a arma")
		bp.durabilidade_ef["ef_iron_longsword"] = 3
		bp.ef_quebradas["ef_iron_longsword"] = true
		bp.inventario.inserir(InventarioMinecraft.nova("minecraft:iron_ingot", 2))
		bp.inventario.inserir(InventarioMinecraft.nova("minecraft:iron_sword", 1))
		ok(BancadaEpicFight.fabricar(bp, "ef_iron_longsword") and bp.durabilidade_de("ef_iron_longsword") == 250 and not bp.ef_quebradas.has("ef_iron_longsword"), "fabricar de novo restaura a durabilidade e tira da lista de quebradas")
		var bt := ProgressaoDoPersonagem.new()
		bt.inventario.inserir(InventarioMinecraft.nova("minecraft:oak_planks", 5))
		bt.inventario.inserir(InventarioMinecraft.nova("minecraft:stick", 2))
		ok(BancadaEpicFight.pode_fabricar(bt.inventario, "ef_wooden_dagger") or BancadaEpicFight.contagem("ef_wooden_dagger").size() > 0, "ingrediente por TAG (tábuas) é aceito")
		ok(not BancadaEpicFight.fabricar(ProgressaoDoPersonagem.new(), "ef_diamond_greatsword"), "sem os ingredientes não fabrica nem consome")
	# ---- habilidade inata: barra de carga (dano dos golpes) e tecla R
	if com_mod:
		ok(HabilidadesDeArma.para("greatsword").id == "steel_whirlwind" and is_equal_approx(HabilidadesDeArma.para("greatsword").consumo, 60.0), "montante: Steel Whirlwind, barra de 60")
		ok(HabilidadesDeArma.para("longsword").id == "liechtenauer" and HabilidadesDeArma.para("uchigatana").id == "battojutsu" and HabilidadesDeArma.para("spear").id == "grasping_spire" and HabilidadesDeArma.para("tachi").id == "rushing_tempo" and HabilidadesDeArma.para("dagger").id == "eviscerate" and HabilidadesDeArma.para("dagger", true).id == "blade_rush" and HabilidadesDeArma.para("sword").id == "sweeping_edge", "mapa moveset → habilidade do mod")
		prog.equipar_lamina("ef_iron_greatsword", true)
		await quadros(30)
		ok(arma.carga_max == 60.0 and arma.carga == 0.0 and not arma.usar_habilidade(), "barra vazia: R não faz nada")
		for i in 3:
			arma._carregar(LaminasEpicFight.dano_do_mod("ef_iron_greatsword"))      # 14 por golpe que acerta
		ok(arma.carga > 40.0 and not arma.carga_cheia(), "3 golpes de 14 = 42 de 60: ainda não cheia (%.0f)" % arma.carga)
		arma._carregar(LaminasEpicFight.dano_do_mod("ef_iron_greatsword"))
		ok(not arma.carga_cheia() and is_equal_approx(arma.carga, 56.0), "4 golpes = 56 de 60: falta um")
		arma._carregar(LaminasEpicFight.dano_do_mod("ef_iron_greatsword"))
		ok(arma.carga_cheia() and arma.carga == 60.0, "o 5º golpe enche a barra, limitada ao máximo (60)")
		ok(ex.estilo.golpe_para(GolpeDirecional.Direcao.HABILIDADE) != null and ex.estilo.golpe_para(GolpeDirecional.Direcao.HABILIDADE).nome == "steel_whirlwind", "o estilo do montante tem o golpe Steel Whirlwind")
		# Steel Whirlwind é CARREGADA: segurar R carrega (mais lento), soltar cedo cancela, soltar com ≥ 0,3 s executa
		ok(arma.iniciar_carga() and j.get("_proc_anim").is_playing_baked(), "segurar R toca o clipe de carga do mod")
		await quadros(10)
		ok(float(j.get_meta("ef_fator_velocidade", 1.0)) < 1.0, "carregando, o corpo anda mais devagar (%.2f)" % float(j.get_meta("ef_fator_velocidade", 1.0)))
		ok(not arma.soltar_carga() and arma.carga_cheia() and float(j.get_meta("ef_fator_velocidade", 1.0)) == 1.0 and not j.get("_proc_anim").is_playing_baked(), "soltar antes de 0,3 s cancela: a barra fica e a velocidade volta")
		ok(arma.iniciar_carga(), "carregar de novo")
		await quadros(35)
		ok(arma.soltar_carga() and ex.golpe_atual != null and ex.golpe_atual.direcao == GolpeDirecional.Direcao.HABILIDADE and arma.carga == 0.0, "soltar com ≥ 0,3 s executa o Steel Whirlwind e zera a barra")
		ex.cancelar(&"teste")
		await quadros(10)
		prog.equipar_lamina("ef_iron_longsword", true)
		await quadros(30)
		ok(arma.carga_max == 40.0, "espada longa: Liechtenauer, barra de 40")
		arma._carregar(100.0)
		ok(arma.carga_cheia() and arma.usar_habilidade() and arma.modo_ativo(), "R inicia o modo Liechtenauer")
		ok(ex.estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA).nome == "longsword_liechtenauer_auto1" and ex.estilo.golpe_para(GolpeDirecional.Direcao.FRENTE).nome == "longsword_liechtenauer_auto3", "no modo, a cadeia do clique é a do Liechtenauer do mod")
		arma._carregar(50.0)
		ok(arma.carga == 0.0, "em modo ativo a barra não enche")
		arma._modo_ate_ms = Time.get_ticks_msec() - 1
		await quadros(3)
		ok(not arma.modo_ativo() and ex.estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA).nome == "longsword_auto1", "acabou o tempo (12 s): volta a cadeia normal")
		prog.equipar_lamina("ef_iron_longsword", false)
		await quadros(20)
	# ---- Battojutsu: parado = battojutsu; correndo = battojutsu_dash (avanço do mod)
	if com_mod:
		prog.equipar_lamina("ef_uchigatana", true)
		await quadros(30)
		arma._carregar(100.0)
		ok(arma.usar_habilidade() and ex.golpe_atual.nome == "battojutsu", "Battojutsu parado")
		ex.cancelar(&"teste")
		await quadros(10)
		arma._carregar(100.0)
		j.set_meta("forcar_corrida", true)
		ok(arma.usar_habilidade() and ex.golpe_atual.nome == "battojutsu_dash", "Battojutsu correndo = battojutsu_dash")
		j.set_meta("forcar_corrida", false)
		ex.cancelar(&"teste")
		await quadros(10)
		# passiva do Battojutsu: 5 s sem agir = bainha (moveset sheathed do mod); o golpe saca
		await quadros(30)
		ok(not arma.embainhada, "uchigatana recém-empunhada: fora da bainha")
		arma._ocioso = 5.1
		await quadros(3)
		ok(arma.embainhada and ex.estilo.id == &"ef_uchigatana_sheath" and not arma._visual.visible, "5 s sem agir: embainhada (estilo da bainha, lâmina escondida)")
		ok(ex.estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA).nome == "uchigatana_sheath_auto" and ex.estilo.golpe_para(GolpeDirecional.Direcao.CORRIDA).nome == "uchigatana_sheath_dash" and ex.estilo.golpe_para(GolpeDirecional.Direcao.NO_AR).nome == "uchigatana_sheath_airslash", "estilo da bainha: auto, dash e airslash `sheath` do mod")
		ok(j.get("_proc_anim")._loco_arma.has("hold") and (j.get("_proc_anim")._loco_arma["hold"] as Animation).resource_path.ends_with("ef_hold_uchigatana_sheath.res"), "parada na bainha: pose hold_uchigatana_sheath")
		ok(ex.pedir_ataque(GolpeDirecional.Direcao.PARA_ESQUERDA) and ex.golpe_atual.nome == "uchigatana_sheath_auto" and not arma.embainhada and arma._visual.visible, "o golpe saca a lâmina")
		await quadros(80)
		ok(ex.estilo.id == &"ef_uchigatana" and not arma.embainhada, "depois do golpe sacado, volta ao estilo normal")
		prog.equipar_lamina("ef_uchigatana", false)
		await quadros(20)
	# ---- dual na cena real: a segunda adaga vai para a mão esquerda
	prog.equipar_lamina("ef_iron_dagger", true)
	await quadros(30)
	prog.equipar_lamina_secundaria("ef_golden_dagger", true)
	await quadros(30)
	ok(arma.lamina_ef_sec == "ef_golden_dagger" and is_instance_valid(arma._visual_l), "segunda adaga montada na mão esquerda")
	ok(arma._visual_l.get_parent() == j.get("_rig").item_handle_l and j.get("_rig").item_handle_l != j.get("_rig").item_handle, "a âncora da mão esquerda é outra")
	ok(ex.estilo.id == &"ef_dagger_dual", "estilo dual no executor (%s)" % ex.estilo.id)
	var pd: Vector3 = arma.ponto(&"EspadaPonta")
	var pe: Vector3 = arma.ponto(&"EspadaPontaL")
	ok(pe != Vector3.INF and pd.distance_to(pe) > 0.15, "as duas pontas existem e ficam separadas (%.2f m)" % pd.distance_to(pe))
	ok(j.get("_proc_anim")._loco_arma.has("hold") and j.get("_proc_anim")._loco_arma.has("run"), "locomoção dual do mod (hold_dual/run_dual)")
	prog.equipar_lamina_secundaria("ef_golden_dagger", false)
	await quadros(30)
	ok(arma.lamina_ef_sec == "" and not is_instance_valid(arma._visual_l) and ex.estilo.id == &"ef_dagger", "tirar da esquerda volta ao estilo de uma mão")
	prog.equipar_lamina("ef_iron_dagger", false)
	await quadros(30)
	ok(not arma.ativa and arma.lamina_ef == "" and is_equal_approx(ex.multiplicador_de_dano, mult0) and ex.max_alvos == 0, "guardar restaura estilo, dano e alvos de antes")
	print("test_laminas_epic_fight: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
