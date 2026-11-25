extends SceneTree
# ============================================================================
#  ILHAS DAS ESTRUTURAS DO MINE PIECE (18/10/2026). Idempotente.
#
#    python3 -I tools/mine_piece/estrutura_para_glb.py                         # 1) converte
#    "$(./find_godot.sh)" --headless --path . --script tools/mine_piece/registrar_estruturas.gd   # 2) loja
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/gerar_ilhas_mine_piece.gd [-- --saida=<caminho>]
#
#  Decisões do dono (docs/ESTRUTURAS_MINE_PIECE_PLANO.md): ilhas novas por FACÇÃO (Marinha
#  153, Foosha, Shimotsuki, acampamentos pirata e bandido EM VOLTA do East Blue, teto 30;
#  Water Seven, Wano e Shandora a leste, teto maior); navios ANCORADOS, sólidos e
#  caminháveis, com a tripulação da facção no convés; LOJAS (prédio do mod + vendedores
#  que já existem) em TODAS as ilhas, as 3 antigas também.
#
#  Grava no MAPA VIVO (sem `--saida`): as placas `baseplate_<ilha>`, relevo e praia de cada
#  ilha nova (`IlhaProcedural`), as estruturas ESPALHADAS pela ilha (lugar sorteado com a
#  semente da ilha, platô retangular sob cada uma, trilhas ligando tudo à praça e à chegada)
#  e assentadas no chão (afundadas as camadas de chão que vieram no molde), árvores do
#  bioma da ilha nos bosques, os navios no nível do mar do Minecraft (63 − altura de partida),
#  personagens `mp_*` e vendedores nos lugares que o conversor achou (`relatorio.json`).
#  Nas ilhas antigas só entram as lojas, num lugar LIVRE e plano achado por busca.
#  Troca SÓ as peças com prefixo `mpi_` e as placas destas ilhas; guarda cópia do mapa e NÃO
#  grava se o arquivo mudou durante a execução. O cadastro das ilhas é `ilhas.gd`.
# ============================================================================
const IlhaProcedural := preload("res://tools/mapa_ilha/ilha_procedural.gd")
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const RELATORIO := "res://build/mine_piece/estruturas/relatorio.json"
const PREFIXO := "mpi_"
const GRUPO := "ilhas_mine_piece"
const METROS_POR_BLOCO := 0.88
## Nível do mar do jogo: topo das placas (0) + `OceanoHistoria.nivel_relativo`.
const MAR := -0.65
## Navio sem altura de partida no mod (o barco do Mihawk): 1 bloco na água.
const AGUA_PADRAO := 1
## Do fim da praia até o costado do navio.
const FOLGA_NAVIO := 20.0
const LOJA_ARMAS := "mpe_shop_weapon"
const LOJA_DE_ROUPAS := "mpe_shop_clothes"
## Quem fica em cada loja (lugares internos que o conversor achou, na ordem).
const VENDEDORES := {"mpe_shop_weapon": ["npc_ferreiro", "npc_comida"], "mpe_shop_clothes": ["npc_vendedor_frutas"]}

## Ilha: centro, meia (metade do lado), semente, morros, estruturas (modelos — o LUGAR é
## sorteado por `_distribuir`), bioma (árvores, `BIOMAS`), personagens [[modelo, n], ...]
## na praça do meio, navios [modelo, lado, ao longo da costa, [[modelo, n], ...]].
## 22/10/2026, pedido do dono: construções ESPALHADAS pela ilha inteira (as mesmas de antes),
## platô suave sob cada uma com o relevo baixo de antes, e árvores por bioma.
const ILHAS := {
	"ilha_marinha_153": {"centro": Vector2(3000, -800), "meia": 128.0, "semente": 181001,
		"morros": [[Vector2(70, -70), 30.0, 6.0]], "bioma": "parque",
		"estruturas": ["mpe_branch_153rd", "mpe_tent_marine"],
		"personagens": [["mp_marine", 8]],
		"navios": [["mpe_ship_marine_large_1", "leste", 0.0, [["mp_marine", 4]]]]},
	"ilha_acampamento_pirata": {"centro": Vector2(3750, -450), "meia": 96.0, "semente": 181002,
		"morros": [[Vector2(45, -45), 22.0, 5.0]], "bioma": "tropical",
		"estruturas": ["mpe_tent_pirates"],
		"personagens": [["mp_pirate_pirate1", 1], ["mp_pirate_pirate2", 1], ["mp_pirate_pirate3", 1], ["mp_pirate_pirate4", 1],
			["mp_pirate_pirate5", 1], ["mp_pirate_pirate6", 1], ["mp_pirate_pirate7", 1], ["mp_pirate_pirate8", 1]],
		"navios": [["mpe_ship_alvida", "norte", 0.0, [["mp_pirate_pirate1", 1], ["mp_pirate_pirate2", 1], ["mp_pirate_pirate3", 1]]],
			["mpe_ship_pirate_mini_1", "leste", 10.0, [["mp_pirate_pirate4", 1], ["mp_pirate_pirate5", 1]]]]},
	"ilha_acampamento_bandido": {"centro": Vector2(2250, -500), "meia": 96.0, "semente": 181003,
		"morros": [[Vector2(-45, -40), 24.0, 6.0]], "bioma": "tropical",
		"estruturas": ["mpe_tent_bandit"],
		"personagens": [["mp_bandit", 6]], "navios": []},
	"ilha_vila_foosha": {"centro": Vector2(2250, 600), "meia": 128.0, "semente": 181004,
		"morros": [[Vector2(-80, 80), 30.0, 8.0]], "bioma": "temperado",
		"estruturas": ["mpe_village_foosha_road_street", "mpe_village_foosha_house1", "mpe_village_foosha_house2",
			"mpe_village_foosha_house3", "mpe_village_foosha_house4", "mpe_village_foosha_ranch1",
			"mpe_village_foosha_windmill1", "mpe_village_foosha_windmill2"],
		"personagens": [], "navios": [["mpe_ship_red_force", "sul", 0.0, []]]},
	"ilha_vila_shimotsuki": {"centro": Vector2(3750, 600), "meia": 128.0, "semente": 181005,
		"morros": [[Vector2(75, 75), 28.0, 7.0]], "bioma": "temperado",
		"estruturas": ["mpe_village_shimotsuki_dojo", "mpe_village_shimotsuki_field", "mpe_village_shimotsuki_road"],
		"personagens": [], "navios": [["mpe_ship_mihawk", "leste", 0.0, []]]},
	"ilha_water_seven": {"centro": Vector2(5000, 0), "meia": 160.0, "semente": 181006,
		"morros": [[Vector2(-100, -100), 30.0, 8.0]], "bioma": "cidade",
		"estruturas": ["mpe_water_seven_house_1", "mpe_water_seven_house_2", "mpe_water_seven_house_3",
			"mpe_water_seven_house_4", "mpe_water_seven_road", "mpe_water_seven_road_2", "mpe_water_seven_road_cross"],
		"personagens": [],
		"navios": [["mpe_ship_thousand_sunny", "sul", 0.0, []],
			["mpe_ship_oro_jackson", "leste", 0.0, [["mp_pirate_pirate6", 1], ["mp_pirate_pirate7", 1], ["mp_pirate_pirate8", 1]]]]},
	"ilha_wano": {"centro": Vector2(6500, 0), "meia": 160.0, "semente": 181007,
		"morros": [[Vector2(110, -110), 32.0, 10.0]], "bioma": "cerejeira",
		"estruturas": ["mpe_village_heian_house1", "mpe_village_heian_house2", "mpe_village_heian_house3",
			"mpe_village_heian_house4", "mpe_village_heian_garage", "mpe_village_heian_temple", "mpe_village_heian_prizon",
			"mpe_village_heian_graveyard", "mpe_village_heian_watchtower", "mpe_village_heian_road",
			"mpe_village_yukaku_house_1", "mpe_village_yukaku_house_2", "mpe_village_yukaku_house_3",
			"mpe_village_yukaku_house_4", "mpe_village_yukaku_house_5", "mpe_village_yukaku_road"],
		"personagens": [],
		"navios": [["mpe_ship_moby_dick", "norte", 0.0,
			[["mp_pirate_pirate1", 1], ["mp_pirate_pirate3", 1], ["mp_pirate_pirate5", 1], ["mp_pirate_pirate7", 1]]]]},
	"ilha_shandora": {"centro": Vector2(8000, 0), "meia": 192.0, "semente": 181008,
		"morros": [[Vector2(-130, 130), 34.0, 9.0]], "bioma": "tropical",
		"estruturas": ["mpe_village_shandora_bell", "mpe_village_shandora_house1", "mpe_village_shandora_house2",
			"mpe_village_shandora_house3", "mpe_village_shandora_road_street", "mpe_village_shandora_road_cross"],
		"personagens": [],
		"navios": [["mpe_ship_saber_of_xebec_1", "norte", 0.0, [["mp_pirate_pirate2", 1], ["mp_pirate_pirate4", 1], ["mp_pirate_pirate6", 1]]],
			["mpe_ship_saber_of_xebec_2", "sul", 0.0, [["mp_pirate_pirate1", 1], ["mp_pirate_pirate5", 1], ["mp_pirate_pirate8", 1]]]]},
}
## Árvores por bioma (modelos da loja, categoria "arvores"; arbustos atravessáveis):
## densidade = árvores por hectare da placa; espaco = distância mínima entre elas;
## clareira = ruído de bosque abaixo disto fica sem árvore (bosques e campos abertos).
const BIOMAS := {
	"temperado": {"densidade": 22.0, "espaco": 7.0, "clareira": 0.05, "arvores": [
		["floresta_tree_oak_large_green", 3], ["floresta_tree_oak_medium_green", 3], ["floresta_tree_oak_hero_green", 1],
		["floresta_tree_birch_large_green", 2], ["floresta_tree_birch_medium_green", 2], ["floresta_tree_elm_green", 2],
		["floresta_tree_maple_red", 1], ["floresta_tree_park_large_green", 1], ["arvore_verde_adulta", 2],
		["arvore_verde_jovem", 1], ["floresta_bush_large", 2], ["floresta_bush_medium", 2]]},
	"cerejeira": {"densidade": 18.0, "espaco": 7.5, "clareira": 0.05, "arvores": [
		["cerejeira_adulta", 4], ["cerejeira_jovem", 2], ["pinheiro_adulto", 2], ["pinheiro_jovem", 1],
		["floresta_tree_pine_large", 1], ["floresta_tree_maple_red", 1], ["floresta_bush_medium", 1]]},
	"tropical": {"densidade": 14.0, "espaco": 8.0, "clareira": 0.0, "arvores": [
		["palmeira_adulta", 4], ["palmeira_jovem", 3], ["palmeira_muda", 1], ["floresta_bush_large", 1],
		["floresta_bush_clumps_large", 1]]},
	"parque": {"densidade": 8.0, "espaco": 9.0, "clareira": -0.1, "arvores": [
		["floresta_tree_park_large_green", 2], ["floresta_tree_park_medium_green", 2], ["floresta_tree_simple_medium", 1],
		["floresta_tree_cypress_large", 1], ["floresta_tree_cypress_medium", 1], ["arvore_verde_adulta", 1]]},
	"cidade": {"densidade": 4.0, "espaco": 10.0, "clareira": 0.1, "arvores": [
		["floresta_tree_cypress_large", 2], ["floresta_tree_park_medium_green", 2], ["floresta_tree_cypress_medium", 1]]},
}
## Praça do meio (personagens da facção; as trilhas se encontram nela).
const PRACA := Vector2.ZERO
const RAIO_PRACA := 10.0
## Entre platôs: maior que o talude, para um não mexer no chão do outro.
const FOLGA_ENTRE := 8.0
## Da borda da placa até a pegada (o relevo desce para a praia nos últimos 30 m).
const MARGEM_COSTA := 34.0
## Desnível máximo do relevo natural sob uma construção (fora das encostas dos morros).
const DESNIVEL_MAX := 3.0
## Rua do molde (comprida ≥ 3× a largura) vai DEITADA numa trilha, não solta na ilha.
const PROPORCAO_RUA := 3.0
const VARIAR_ARVORE := 0.15
## Ilhas antigas: navios ancorados (sem tripulação: a do Luffy e a do Sanji já estão em terra)
## e onde a busca de lugar livre para as lojas começa (local à placa).
const ANTIGAS := {
	Ilhas.INICIAL: {"preferido": Vector2(152, 20), "navios": []},
	Ilhas.MACACOS: {"preferido": Vector2(-60, 0), "navios": []},
	Ilhas.EAST_BLUE: {"preferido": Vector2(-120, 60),
		"navios": [["mpe_ship_going_merry", "oeste", 70.0, []], ["mpe_ship_baratie", "sul", -25.0, []]]},
}

var bib: BibliotecaDeModelos
var dados := {}             # estrutura → relatório do conversor
var contagem := {}
var obstaculos: Array[Rect2] = []     # pegadas (xz do mundo) já ocupadas, para as lojas das ilhas antigas
var terrenos: Array = []              # peças de terreno do mapa (chão das ilhas antigas)


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var saida := MAPA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		return _falhar("mapa inválido: " + "; ".join(lido["erros"]))
	if not FileAccess.file_exists(RELATORIO):
		return _falhar("falta %s (rode tools/mine_piece/estrutura_para_glb.py)" % RELATORIO)
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(RELATORIO)):
		dados["mpe_" + str(r["estrutura"])] = r
	bib = BibliotecaDeModelos.padrao()
	var faltam := _faltam()
	if not faltam.is_empty():
		return _falhar("falta na loja: %s (rode registrar_estruturas.gd / registrar_na_loja.gd)" % str(faltam))
	for id in ILHAS:
		if not Ilhas.existe(id):
			return _falhar("a ilha %s não está no cadastro (src/historia/ilhas/ilhas.gd)" % id)
	var mapa: Dictionary = lido["mapa"]
	var pecas: Array = []
	var trocadas := 0
	var bases := {}
	for id in ILHAS:
		bases[Ilhas.TABELA[id]["base"]] = true
	var tamanho_y := 0.0
	for p: Dictionary in mapa["pecas"]:
		if String(p["id"]).begins_with(PREFIXO) or bases.has(p["id"]):
			trocadas += 1
			continue
		pecas.append(p)
		if p["tipo"] == "terreno":
			terrenos.append(p)
			tamanho_y = (p["tamanho"] as Vector3).y
		elif not String(p["id"]).begins_with("baseplate"):
			var t: Vector3 = p["tamanho"]
			var m := maxf(t.x, t.z) * 0.5
			obstaculos.append(Rect2(p["posicao"].x - m, p["posicao"].z - m, m * 2.0, m * 2.0))
	if tamanho_y == 0.0:
		return _falhar("o mapa não tem relevo: gere a ilha inicial antes")

	var t0 := Time.get_ticks_msec()
	var novas: Array[Dictionary] = []
	var grupos_novos := {GRUPO: ""}
	for id in ILHAS:
		var da_ilha := _ilha_nova(id, ILHAS[id], tamanho_y, grupos_novos)
		if da_ilha.is_empty():
			return _falhar("sem lugar para as construções da %s" % id)
		novas.append_array(da_ilha)
	var caixas := Ilhas.caixas(mapa)
	for id in ANTIGAS:
		if not caixas.has(id):
			return _falhar("a ilha antiga %s não tem placa no mapa" % id)
		var g := "%s%s" % [PREFIXO, id]
		grupos_novos[g] = GRUPO
		grupos_novos[g + "_ancorados"] = g
		var lojas := _lojas_em_lugar_livre(id, caixas[id], ANTIGAS[id]["preferido"], g)
		if lojas.is_empty():
			return _falhar("não achei lugar livre e plano para as lojas na %s" % id)
		novas.append_array(lojas)
		for n in ANTIGAS[id]["navios"]:
			novas.append_array(_navio(id, n, caixas[id].get_center(), caixas[id].size.x * 0.5, g))
	pecas.append_array(novas)

	var grupos: Array = []
	for g: Dictionary in mapa["grupos"]:
		if not grupos_novos.has(g["id"]):
			grupos.append(g)
	for g in grupos_novos:
		grupos.append({"id": g, "pai": grupos_novos[g]})
	mapa["grupos"] = grupos
	mapa["pecas"] = pecas
	var validado := MapaArquivo.validar(_cru(mapa))
	if not validado["ok"]:
		return _falhar("mapa gerado não valida: %s" % str(validado["erros"]).left(800))
	if saida == MAPA:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_ilhas_mine_piece_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			return _falhar("o mapa mudou durante a execução — mapa NÃO gravado")
	var err := MapaArquivo.salvar(saida, validado["mapa"])
	print("ILHAS_MINE_PIECE %d peças (trocadas %d) ms=%d -> %s (%s)" % [novas.size(), trocadas,
		Time.get_ticks_msec() - t0, saida, error_string(err)])
	for k in contagem:
		print("  %-30s %s" % [k, str(contagem[k])])
	quit(0 if err == OK else 1)


func _falhar(motivo: String) -> void:
	push_error("ILHAS_MINE_PIECE: " + motivo)
	quit(1)


func _faltam() -> Array:
	var faltam: Array = []
	var precisa: Array = [LOJA_ARMAS, LOJA_DE_ROUPAS]
	for v in VENDEDORES.values():
		precisa.append_array(v)
	for ilha: Dictionary in ILHAS.values():
		for e in ilha["estruturas"]:
			precisa.append(e)
		for a in BIOMAS[ilha["bioma"]]["arvores"]:
			precisa.append(a[0])
		for p in ilha["personagens"]:
			precisa.append(p[0])
		for n in ilha["navios"]:
			precisa.append(n[0])
			for c in n[3]:
				precisa.append(c[0])
	for a: Dictionary in ANTIGAS.values():
		for n in a["navios"]:
			precisa.append(n[0])
	for m in precisa:
		if not bib.tem(str(m)) and not faltam.has(m):
			faltam.append(m)
		elif str(m).begins_with("mpe_") and not dados.has(m) and not faltam.has(m):
			faltam.append(str(m) + " (relatório)")
	return faltam


# =================================================================== ILHA NOVA
func _ilha_nova(id: String, d: Dictionary, tamanho_y: float, grupos: Dictionary) -> Array[Dictionary]:
	var g := PREFIXO + id
	grupos[g] = GRUPO
	grupos[g + "_relevo"] = g
	grupos[g + "_estruturas"] = g
	grupos[g + "_gente"] = g
	grupos[g + "_ancorados"] = g
	grupos[g + "_natureza"] = g
	var centro: Vector2 = d["centro"]
	var meia: float = d["meia"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["semente"])
	var ilha := IlhaProcedural.new(centro, meia, int(d["semente"]), "%s%s_" % [PREFIXO, id], tamanho_y)
	ilha.morros = d["morros"]
	# Construções espalhadas; trilhas = árvore geradora mínima entre a chegada (costa oeste),
	# a praça e cada construção; as ruas do molde deitadas nas trilhas mais compridas.
	var lugares := _distribuir(d, ilha, rng)
	if lugares.is_empty():
		return []
	var nos: Array = [Vector2(-meia, 0), PRACA]
	for l: Dictionary in lugares:
		nos.append(l["centro"])
	ilha.trilhas = _trilhas(nos)
	lugares.append_array(_ruas(d, ilha, rng, lugares))
	_na_grade(lugares, centro)
	ilha.pracas.append({"centro": PRACA, "raio": RAIO_PRACA})
	for l: Dictionary in lugares:
		ilha.platos.append({"centro": l["centro"], "meia": l["meia"], "giro": l["giro"]})
	ilha.relevo()
	var lista: Array[Dictionary] = []
	lista.append({"id": Ilhas.TABELA[id]["base"], "tipo": "caixa", "grupo": g, "posicao": Vector3(centro.x, -1.0, centro.y),
		"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(meia * 2.0, 2.0, meia * 2.0), "cor": Color("#41a05d"),
		"material": "grade", "grade_celula": 4.0, "colisao": true})
	var terreno: Array = []
	terreno.append_array(ilha.blocos_de_terreno(g + "_relevo"))
	terreno.append_array(ilha.anel_de_praia(g + "_relevo"))
	lista.append_array(terreno)
	# O relevo como o jogo vai desenhar (em blocos): árvores e gente pousam nele.
	var blocos := RelevoEmBlocos.de_pecas(terreno)
	for k in lugares.size():
		var l: Dictionary = lugares[k]
		var y := ilha.chao_maximo(l["centro"], l["meia"], l["giro"])
		var p := _estrutura("%s%s_estrutura_%d" % [PREFIXO, id, k], l["modelo"],
			Vector3(centro.x + l["centro"].x, y, centro.y + l["centro"].y), l["giro"], g + "_estruturas")
		lista.append(p)
		lista.append_array(_vendedores(p, l["modelo"], g + "_gente"))
	lista.append_array(_personagens_na_praca(id, d, ilha, blocos, g + "_gente"))
	for n in d["navios"]:
		lista.append_array(_navio(id, n, centro, meia, g + "_gente"))
	var arvores := _arvores(id, d, ilha, blocos, rng, g + "_natureza")
	lista.append_array(arvores)
	contagem[id] = "%d peças (relevo %d, praia %d, construções %d, árvores %d)" % [lista.size(), ilha.contagem["blocos"],
		ilha.contagem["praia"], lugares.size(), arvores.size()]
	return lista


# =================================================================== DISTRIBUIÇÃO
## Lugar de cada construção (e das duas lojas), maiores primeiro: {modelo, centro, meia, giro}.
## Vazio se alguma não couber.
func _distribuir(d: Dictionary, ilha, rng: RandomNumberGenerator) -> Array:
	var itens: Array = (d["estruturas"] as Array).filter(func(m: String) -> bool: return not _e_rua(m))
	itens.append_array([LOJA_ARMAS, LOJA_DE_ROUPAS])
	itens.sort_custom(func(a: String, b: String) -> bool: return _area(a) > _area(b))
	var ocupados: Array = [{"centro": PRACA, "meia": Vector2(RAIO_PRACA, RAIO_PRACA), "giro": 0.0}]
	var lista: Array = []
	for m: String in itens:
		var r := _melhor_lugar(m, ilha, rng, ocupados, float(rng.randi_range(0, 3)) * 90.0)
		if r.is_empty():
			return []
		ocupados.append(r)
		lista.append(r)
	return lista


## Sorteio do "melhor candidato": entre vários lugares válidos (dentro da ilha, fora das
## encostas, longe FOLGA_ENTRE dos ocupados) fica o mais distante dos já ocupados — as
## construções se espalham pela ilha inteira em vez de se amontoar.
func _melhor_lugar(modelo: String, ilha, rng: RandomNumberGenerator, ocupados: Array, giro: float) -> Dictionary:
	var meia_p := _pegada(modelo) * 0.5
	var a := deg_to_rad(giro)
	var ext := Vector2(absf(cos(a)) * meia_p.x + absf(sin(a)) * meia_p.y, absf(sin(a)) * meia_p.x + absf(cos(a)) * meia_p.y)
	var lim := Vector2(ilha.meia - MARGEM_COSTA, ilha.meia - MARGEM_COSTA) - ext
	if lim.x < 0.0 or lim.y < 0.0:
		return {}
	var melhor := {}
	var melhor_d := -1.0
	var validos := 0
	for _t in 800:
		var r := {"modelo": modelo, "centro": Vector2(rng.randf_range(-lim.x, lim.x), rng.randf_range(-lim.y, lim.y)),
			"meia": meia_p, "giro": giro}
		if ocupados.any(func(o: Dictionary) -> bool: return _sobrepoe(r, o, FOLGA_ENTRE)):
			continue
		if ilha.desnivel(r) > DESNIVEL_MAX:
			continue
		var dist := INF
		for o: Dictionary in ocupados:
			dist = minf(dist, (r["centro"] as Vector2).distance_to(o["centro"]))
		if dist > melhor_d:
			melhor_d = dist
			melhor = r
		validos += 1
		if validos >= 24:
			break
	return melhor


## Árvore geradora mínima (Prim) entre os nós: [[a, b], ...].
static func _trilhas(nos: Array) -> Array:
	var arestas: Array = []
	var dentro := [0]
	var fora := range(1, nos.size())
	while not fora.is_empty():
		var melhor := [-1, -1, INF]
		for i in dentro:
			for j in fora:
				var dd: float = (nos[i] as Vector2).distance_to(nos[j])
				if dd < melhor[2]:
					melhor = [i, j, dd]
		arestas.append([nos[melhor[0]], nos[melhor[1]]])
		dentro.append(melhor[1])
		fora.erase(melhor[1])
	return arestas


## Ruas do molde deitadas ao longo das trilhas mais compridas (meio da trilha, eixo comprido
## na direção dela), sem encostar nos platôs; sem trilha que caiba, a rua vai como construção.
func _ruas(d: Dictionary, ilha, rng: RandomNumberGenerator, lugares: Array) -> Array:
	var ocupados: Array = [{"centro": PRACA, "meia": Vector2(RAIO_PRACA, RAIO_PRACA), "giro": 0.0}]
	ocupados.append_array(lugares)
	var trilhas: Array = ilha.trilhas.duplicate()
	trilhas.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Vector2).distance_to(a[1]) > (b[0] as Vector2).distance_to(b[1]))
	var lista: Array = []
	for m: String in (d["estruturas"] as Array).filter(func(x: String) -> bool: return _e_rua(x)):
		var meia_p := _pegada(m) * 0.5
		var achado := {}
		for s: Array in trilhas:
			var dir: Vector2 = (s[1] as Vector2) - (s[0] as Vector2)
			# Eixo comprido do molde em z: +z vira (sen g, cos g) no mundo; em x: (cos g, −sen g).
			var giro := rad_to_deg(atan2(dir.x, dir.y)) if meia_p.y >= meia_p.x else rad_to_deg(atan2(-dir.y, dir.x))
			var r := {"modelo": m, "centro": ((s[0] as Vector2) + (s[1] as Vector2)) * 0.5, "meia": meia_p, "giro": giro}
			if ocupados.any(func(o: Dictionary) -> bool: return _sobrepoe(r, o, IlhaProcedural.TALUDE + 1.0)):
				continue
			if ilha.desnivel(r) > DESNIVEL_MAX:
				continue
			achado = r
			trilhas.erase(s)
			break
		if achado.is_empty():
			achado = _melhor_lugar(m, ilha, rng, ocupados, float(rng.randi_range(0, 3)) * 90.0)
		if achado.is_empty():
			push_error("ILHAS_MINE_PIECE: sem lugar para %s" % m)
			continue
		ocupados.append(achado)
		lista.append(achado)
	return lista


## Construções (giro em múltiplo de 90°) com as quinas dos blocos do molde nas linhas da
## grade do relevo em blocos (a do MUNDO): lado com número par de blocos → centro numa
## linha; ímpar → no meio de um bloco. Ruas deitadas em ângulo livre ficam como estão.
func _na_grade(lugares: Array, centro: Vector2) -> void:
	var b := RelevoEmBlocos.BLOCO
	for l: Dictionary in lugares:
		var giro: float = l["giro"]
		if not is_zero_approx(fposmod(giro, 90.0)):
			continue
		var r: Dictionary = dados.get(l["modelo"], {})
		var n: Array = r.get("tamanho_blocos", [])
		if n.size() < 3:
			continue
		var nx := int(n[0])
		var nz := int(n[2])
		if is_equal_approx(fposmod(giro, 180.0), 90.0):
			var t := nx
			nx = nz
			nz = t
		var mundo: Vector2 = centro + (l["centro"] as Vector2)
		mundo.x = (roundf(mundo.x / b) if nx % 2 == 0 else floorf(mundo.x / b) + 0.5) * b
		mundo.y = (roundf(mundo.y / b) if nz % 2 == 0 else floorf(mundo.y / b) + 0.5) * b
		l["centro"] = mundo - centro


func _e_rua(modelo: String) -> bool:
	var t := _pegada(modelo)
	return "road" in modelo and maxf(t.x, t.y) >= PROPORCAO_RUA * minf(t.x, t.y)


func _area(modelo: String) -> float:
	var t := _pegada(modelo)
	return t.x * t.y


## Dois retângulos girados ({centro, meia, giro}) a menos de `folga` um do outro (eixos separadores).
static func _sobrepoe(a: Dictionary, b: Dictionary, folga: float) -> bool:
	var dd: Vector2 = (b["centro"] as Vector2) - (a["centro"] as Vector2)
	for r: Dictionary in [a, b]:
		for e: Vector2 in _eixos(r):
			if absf(dd.dot(e)) > _projecao(a, e) + _projecao(b, e) + folga:
				return false
	return true


static func _eixos(r: Dictionary) -> Array:
	var g := -deg_to_rad(float(r["giro"]))
	return [Vector2.RIGHT.rotated(g), Vector2.DOWN.rotated(g)]


static func _projecao(r: Dictionary, e: Vector2) -> float:
	var x: Array = _eixos(r)
	return (r["meia"] as Vector2).x * absf((x[0] as Vector2).dot(e)) + (r["meia"] as Vector2).y * absf((x[1] as Vector2).dot(e))


# =================================================================== ÁRVORES
## Árvores do bioma nos bosques (ruído acima de `clareira`), fora das trilhas, praças,
## platôs e areia, com distância mínima entre si e base em chão quase plano.
func _arvores(id: String, d: Dictionary, ilha, blocos: RelevoEmBlocos, rng: RandomNumberGenerator, grupo: String) -> Array[Dictionary]:
	var b: Dictionary = BIOMAS[d["bioma"]]
	var bosque := FastNoiseLite.new()
	bosque.seed = int(d["semente"]) + 7
	bosque.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	bosque.frequency = 1.0 / 55.0
	var espaco: float = b["espaco"]
	var alvo := int(float(b["densidade"]) * pow(ilha.meia * 2.0 / 100.0, 2.0))
	var peso_total := 0
	for a in b["arvores"]:
		peso_total += int(a[1])
	var grade := {}           # célula (espaco) → pontos já plantados
	var lista: Array[Dictionary] = []
	var tentativas := alvo * 30
	while lista.size() < alvo and tentativas > 0:
		tentativas -= 1
		var l := Vector2(rng.randf_range(-ilha.meia, ilha.meia), rng.randf_range(-ilha.meia, ilha.meia))
		if bosque.get_noise_2dv(l) < float(b["clareira"]):
			continue
		var sorteio := rng.randi_range(1, peso_total)
		var modelo := ""
		for a in b["arvores"]:
			sorteio -= int(a[1])
			if sorteio <= 0:
				modelo = str(a[0])
				break
		var escala := 1.0 + rng.randf_range(-VARIAR_ARVORE, VARIAR_ARVORE)
		var t := bib.tamanho_padrao(modelo) * escala
		if not ilha.livre(l, maxf(t.x, t.z) * 0.5 + 1.5):
			continue
		var celula := Vector2i(floori(l.x / espaco), floori(l.y / espaco))
		var perto := false
		for cx in range(celula.x - 1, celula.x + 2):
			for cz in range(celula.y - 1, celula.y + 2):
				for o: Vector2 in grade.get(Vector2i(cx, cz), []):
					perto = perto or o.distance_to(l) < espaco
		if perto:
			continue
		var minimo: float = ilha.chao(l)
		var maximo := minimo
		for k in 6:
			var y: float = ilha.chao(l + Vector2.RIGHT.rotated(k * TAU / 6.0) * 0.8)
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		if maximo - minimo > 1.0:
			continue
		# A base pousa no bloco mais baixo sob o tronco (o jogo desenha blocos, não o liso).
		minimo = blocos.altura(ilha.centro.x + l.x, ilha.centro.y + l.y)
		for k in 6:
			var q: Vector2 = ilha.centro + l + Vector2.RIGHT.rotated(k * TAU / 6.0) * 0.8
			minimo = minf(minimo, blocos.altura(q.x, q.y))
		if not grade.has(celula):
			grade[celula] = []
		grade[celula].append(l)
		lista.append({"id": "%s%s_arvore_%d" % [PREFIXO, id, lista.size()], "tipo": "modelo", "modelo": modelo,
			"grupo": grupo, "posicao": Vector3(ilha.centro.x + l.x, minimo - 0.08 + t.y * 0.5, ilha.centro.y + l.y),
			"rotacao_graus": Vector3(0, snappedf(rng.randf_range(0.0, 360.0), 1.0), 0), "tamanho": t,
			"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": not bib.atravessavel(modelo)})
	contagem["árvores"] = int(contagem.get("árvores", 0)) + lista.size()
	return lista


## Pegada (x, z) do modelo, em metros.
func _pegada(modelo: String) -> Vector2:
	var t := bib.tamanho_padrao(modelo)
	return Vector2(t.x, t.z)


## Peça de uma estrutura com a ORIGEM do molde (centro da base) em `chao_mundo`: o molde
## desce as camadas de chão que trouxe, para o chão dele ficar rente ao da ilha.
func _estrutura(id: String, modelo: String, chao_mundo: Vector3, giro: float, grupo: String) -> Dictionary:
	var r: Dictionary = dados.get(modelo, {})
	var base := chao_mundo - Vector3(0, int(r.get("chao_blocos", 0)) * METROS_POR_BLOCO, 0)
	return _peca_pela_origem(id, modelo, base, giro, grupo, true)


func _peca_pela_origem(id: String, modelo: String, origem: Vector3, giro: float, grupo: String, colisao: bool) -> Dictionary:
	var info := bib.info(modelo)
	var c: Vector3 = info["centro"]
	var desloc := Basis(Vector3.UP, deg_to_rad(giro)) * c
	return {"id": id, "tipo": "modelo", "modelo": modelo, "grupo": grupo, "posicao": origem + desloc,
		"rotacao_graus": Vector3(0, giro, 0), "tamanho": info["tamanho"], "cor": Color.WHITE, "material": "liso",
		"grade_celula": 4.0, "colisao": colisao, "_origem": origem}


## Personagem/NPC de pé num ponto (pés em `pe`).
func _de_pe(id: String, modelo: String, pe: Vector3, giro: float, grupo: String) -> Dictionary:
	var t := bib.tamanho_padrao(modelo)
	return {"id": id, "tipo": "modelo", "modelo": modelo, "grupo": grupo, "posicao": pe + Vector3(0, t.y * 0.5 + 0.02, 0),
		"rotacao_graus": Vector3(0, giro, 0), "tamanho": t, "cor": Color.WHITE, "material": "liso",
		"grade_celula": 4.0, "colisao": false}


## Um ponto do molde (metros, origem = centro da base) no mundo.
func _no_mundo(peca: Dictionary, local: Array) -> Vector3:
	var giro: float = (peca["rotacao_graus"] as Vector3).y
	return (peca["_origem"] as Vector3) + Basis(Vector3.UP, deg_to_rad(giro)) * Vector3(local[0], local[1], local[2])


func _vendedores(loja: Dictionary, modelo: String, grupo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if not VENDEDORES.has(modelo):
		return lista
	var lugares_: Array = dados[modelo].get("lugares_internos", [])
	for k in mini(lugares_.size(), VENDEDORES[modelo].size()):
		var pe := _no_mundo(loja, lugares_[k])
		lista.append(_de_pe("%s_vendedor_%d" % [loja["id"], k], VENDEDORES[modelo][k], pe,
			fposmod((loja["rotacao_graus"] as Vector3).y + 180.0, 360.0), grupo))
	contagem["vendedores"] = int(contagem.get("vendedores", 0)) + lista.size()
	return lista


## Personagens da facção em leque na praça, de frente para a chegada (oeste).
func _personagens_na_praca(id: String, d: Dictionary, ilha, blocos: RelevoEmBlocos, grupo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var todos: Array[String] = []
	for p in d["personagens"]:
		for n in int(p[1]):
			todos.append(str(p[0]))
	var c := PRACA
	for k in todos.size():
		var fila := int(k / 5)
		var l := c + Vector2(-2.0 - 3.5 * fila, (k % 5 - 2) * 3.0)
		lista.append(_de_pe("%s%s_personagem_%d" % [PREFIXO, id, k], todos[k],
			Vector3(ilha.centro.x + l.x, blocos.altura(ilha.centro.x + l.x, ilha.centro.y + l.y), ilha.centro.y + l.y), 90.0, grupo))
	contagem["personagens em terra"] = int(contagem.get("personagens em terra", 0)) + lista.size()
	return lista


# =================================================================== NAVIOS
## Navio ancorado paralelo à costa `lado`, FOLGA_NAVIO além da praia; tripulação no convés.
func _navio(ilha_id: String, n: Array, centro: Vector2, meia: float, grupo: String) -> Array[Dictionary]:
	var modelo := str(n[0])
	var lado := str(n[1])
	var ao_longo: float = n[2]
	var t := bib.tamanho_padrao(modelo)
	# O casco do Minecraft é comprido em z: paralelo à costa norte/sul ele gira 90°.
	var giro := 90.0 if lado in ["norte", "sul"] else 0.0
	var largura := t.x
	var fora := meia + IlhaProcedural.LARGURA_PRAIA + FOLGA_NAVIO + largura * 0.5
	var local: Vector2 = {"norte": Vector2(ao_longo, -fora), "sul": Vector2(ao_longo, fora),
		"leste": Vector2(fora, ao_longo), "oeste": Vector2(-fora, ao_longo)}[lado]
	var r: Dictionary = dados[modelo]
	var fundo := MAR - int(r.get("agua_blocos", AGUA_PADRAO)) * METROS_POR_BLOCO
	var id := "%s%s_navio_%s" % [PREFIXO, ilha_id, modelo.trim_prefix("mpe_ship_")]
	# Grupo "_ancorados": cenário parado da ilha, não barco pilotável (`perfil_barco.gd`, `ancorado`).
	var navio := _peca_pela_origem(id, modelo, Vector3(centro.x + local.x, fundo, centro.y + local.y), giro,
		PREFIXO + ilha_id + "_ancorados", true)
	var lista: Array[Dictionary] = [navio]
	var conves: Array = r.get("lugares_conves", [])
	var k := 0
	for c in n[3]:
		for i in int(c[1]):
			if k >= conves.size():
				break
			lista.append(_de_pe("%s_tripulante_%d" % [id, k], str(c[0]), _no_mundo(navio, conves[k]), giro, grupo))
			k += 1
	contagem["navios"] = int(contagem.get("navios", 0)) + 1
	contagem["tripulantes"] = int(contagem.get("tripulantes", 0)) + k
	return lista


# =================================================================== ILHAS ANTIGAS
## As duas lojas num lugar livre (sem peça por perto) e plano (variação ≤ 1,5 m), o mais
## perto possível do `preferido` (local à placa).
func _lojas_em_lugar_livre(ilha_id: String, caixa: Rect2, preferido: Vector2, grupo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var centro := caixa.get_center()
	# O relevo da ilha como o jogo desenha (em blocos): a loja pousa no bloco mais alto sob ela.
	var da_ilha := terrenos.filter(func(t: Dictionary) -> bool:
		return caixa.grow(Ilhas.MARGEM).has_point(Vector2(t["posicao"].x, t["posicao"].z)))
	var blocos := RelevoEmBlocos.de_pecas(da_ilha)
	var k := 0
	for modelo in [LOJA_ARMAS, LOJA_DE_ROUPAS]:
		var t := _pegada(modelo)
		var achado := _buscar(caixa, centro + preferido, t)
		if achado.is_empty():
			return []
		var topo := -INF
		for dx in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			for dz in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				var h := blocos.altura(achado["chao"].x + dx * t.x, achado["chao"].z + dz * t.y)
				if not is_nan(h):
					topo = maxf(topo, h)
		if topo > -INF:
			achado["chao"].y = topo
		var p := _estrutura("%s%s_loja_%d" % [PREFIXO, ilha_id, k], modelo, achado["chao"], 0.0, grupo)
		lista.append(p)
		lista.append_array(_vendedores(p, modelo, grupo))
		obstaculos.append(Rect2(achado["chao"].x - t.x * 0.5 - 2.0, achado["chao"].z - t.y * 0.5 - 2.0, t.x + 4.0, t.y + 4.0))
		k += 1
	contagem["lojas na " + ilha_id] = "em " + str(lista[0]["_origem"])
	return lista


func _buscar(caixa: Rect2, alvo: Vector2, pegada: Vector2) -> Dictionary:
	var cands: Array[Vector2] = []
	var x := caixa.position.x + 20.0 + pegada.x * 0.5
	while x < caixa.end.x - 20.0 - pegada.x * 0.5:
		var z := caixa.position.y + 20.0 + pegada.y * 0.5
		while z < caixa.end.y - 20.0 - pegada.y * 0.5:
			cands.append(Vector2(x, z))
			z += 4.0
		x += 4.0
	cands.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(alvo) < b.distance_squared_to(alvo))
	for c in cands:
		var r := Rect2(c - pegada * 0.5 - Vector2(3, 3), pegada + Vector2(6, 6))
		if obstaculos.any(func(o: Rect2): return o.intersects(r)):
			continue
		var lo := INF
		var hi := -INF
		for dx in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			for dz in [-0.5, -0.25, 0.0, 0.25, 0.5]:
				var h := _chao_antigo(c + Vector2(dx * pegada.x, dz * pegada.y))
				lo = minf(lo, h)
				hi = maxf(hi, h)
		if hi - lo <= 1.5 and lo > 0.3:
			return {"chao": Vector3(c.x, hi, c.y)}
	return {}


## Chão das ilhas antigas: o relevo da peça de terreno sob o ponto; sem relevo, a placa (0).
func _chao_antigo(p: Vector2) -> float:
	for t: Dictionary in terrenos:
		var pos: Vector3 = t["posicao"]
		var tam: Vector3 = t["tamanho"]
		if absf(p.x - pos.x) <= tam.x * 0.5 and absf(p.y - pos.z) <= tam.z * 0.5:
			return pos.y + TerrenoDoMapa.altura_local(t["relevo"], tam, p.x - pos.x, p.y - pos.z)
	return 0.0


func _cru(mapa: Dictionary) -> Dictionary:
	for p: Dictionary in mapa["pecas"]:
		p.erase("_origem")
	return JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"],
		"pecas": mapa["pecas"], "grupos": mapa["grupos"]}))
