extends SceneTree
# ============================================================================
#  TAMANHO PADRÃO + NAVIOS na loja (30/09/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/aplicar_tamanhos_padrao.gd
#
#  Decisão do dono: construções escaladas POR TIPO, medidas contra o jogador (1,6 m;
#  porta ≥ 2,2 m), valendo também ao arrastar da loja; navios numa categoria própria
#  com ficha de propriedades. Este script é a TABELA que preencheu o catálogo — rodar
#  de novo dá o mesmo resultado (idempotente). Grava só `tamanho_padrao`, a categoria
#  `navios` e a ficha; não mexe em arquivo .glb nem no mapa.
#
#  Por que FATOR por kit e não altura por peça: a loja tem kits inteiros na MESMA
#  escala interna (o kit medieval "first/second age": casa, cabana, torre, mercado,
#  fazenda, porto). Um fator só por kit mantém cada peça proporcional às vizinhas —
#  a cabana continua menor que a casa, que continua menor que a torre. A régua foi
#  conferida contra o jogador: cabana ×8 = 6 m de altura; templo-catedral ×6 = 26 m.
#  Objetos soltos (barril, carroça) e natureza têm ALTURA-alvo própria.
#
#  ⚠️ Não rodar com o editor de mapa aberto: ele também grava o catálogo.
# ============================================================================

## Kit medieval "first/second age" — escala interna ~1:8.
const KIT_ERAS := 8.0
## Kit "fantasy" (estalagem, ferreiro, moinho) — escala interna ~1:2,6.
const KIT_FANTASIA := 2.6

## id → fator sobre o tamanho do arquivo.
const FATORES := {
	# --- Kit eras: moradias
	"hut": KIT_ERAS, "hut-4mjwbyd6vw": KIT_ERAS, "huts": KIT_ERAS, "hut-wxi3kau5ey": KIT_ERAS,
	"shack": KIT_ERAS, "shack-huzljcbud2": KIT_ERAS,
	"house_2": KIT_ERAS, "house-k6tp5nfud2": KIT_ERAS, "house-nihggju7dw": KIT_ERAS,
	"house-ojjirwv6bo": KIT_ERAS, "house-rswoyslblu": KIT_ERAS, "houses": KIT_ERAS,
	"houses-gejac1uvvu": KIT_ERAS, "houses-vcodg5hfyi": KIT_ERAS, "house-vz1clbwmsx": KIT_ERAS,
	"house-yladpcju8u": KIT_ERAS, "tower_house": KIT_ERAS, "wooden_house_tower": KIT_ERAS,
	# --- Kit eras: trabalho e comércio
	"storage_house": KIT_ERAS, "storage_hut": KIT_ERAS, "storage_shed": KIT_ERAS,
	"storage_shed_2": KIT_ERAS, "storage_shed-fktsddpqaa": KIT_ERAS, "business_building": KIT_ERAS,
	"market_stalls": KIT_ERAS, "market_stalls-4zahrv2tlg": KIT_ERAS, "market_stalls_compact": KIT_ERAS,
	"market_stalls-old8vu6lpl": KIT_ERAS, "market_stalls-puzz5f91oe": KIT_ERAS, "village_market": KIT_ERAS,
	"town_center": KIT_ERAS, "town_center-76gtksh4km": KIT_ERAS, "town_center-coerw5nfde": KIT_ERAS,
	"town_center-cuqufjeifh": KIT_ERAS, "town_center_second_age": KIT_ERAS,
	"farm": KIT_ERAS, "farm-91wmlb9kko": KIT_ERAS, "farm_dirt": KIT_ERAS, "farm-o4wptlsfin": KIT_ERAS,
	"small_farm": KIT_ERAS, "crops": KIT_ERAS, "sawmill": KIT_ERAS, "mine": KIT_ERAS,
	"windmill": KIT_ERAS, "windmill-jphoi9xdlg": KIT_ERAS,
	# --- Kit eras: porto (o cais grande "dock_long/wide/stairs" já vem em metros)
	"port": KIT_ERAS, "port-4se6lmhgpf": KIT_ERAS, "shipping_port": KIT_ERAS,
	"shipping_port-rdx8w8uqip": KIT_ERAS, "docks": KIT_ERAS, "dock_2": KIT_ERAS, "dock-xvikobh2un": KIT_ERAS,
	# --- Kit eras: defesa, militar, templos
	"watch_tower": KIT_ERAS, "watch_tower-cmxuj2gt7d": KIT_ERAS, "watch_tower-vjzzw37vsk": KIT_ERAS,
	"small_watch_tower": KIT_ERAS, "stone_tower": KIT_ERAS, "stone_tower-djlad6p90f": KIT_ERAS,
	"barracks": KIT_ERAS, "barracks-a1c1l8gjtx": KIT_ERAS, "barracks-dvlksxgxwc": KIT_ERAS,
	"barracks-lnyadhesva": KIT_ERAS, "barracks-pud1kbv4kf": KIT_ERAS, "barracks-uxcowrbsxx": KIT_ERAS,
	"archery_towers": KIT_ERAS, "archery_towers-ia5qojiait": KIT_ERAS, "archery_training_grounds": KIT_ERAS,
	"archery_training_grounds-5dwpau7c3k": KIT_ERAS, "archery_building": KIT_ERAS, "archery_second_age_le": KIT_ERAS,
	"castle": KIT_ERAS, "castle_fortress": KIT_ERAS, "castle_gate": KIT_ERAS, "castle-y15ye6kwly": KIT_ERAS,
	"fortress": KIT_ERAS, "wooden_fortress": KIT_ERAS, "wooden_fortress_gate": KIT_ERAS,
	"wooden_encampment": KIT_ERAS, "wonder_first_age_leve": KIT_ERAS, "wooden_monument": KIT_ERAS,
	"stone_wall": KIT_ERAS, "stone_wall_towers": KIT_ERAS, "wall_towers": KIT_ERAS,
	"wall_towers_door_seco": KIT_ERAS, "wooden_wall": KIT_ERAS, "wooden_wall-l0txlurnes": KIT_ERAS,
	"temple-nr264crtsr": KIT_ERAS, "temple": KIT_ERAS,
	# Templos de torre alta: ×8 daria 31–35 m, maior que o coliseu. ×6 = 18–26 m.
	"temple-ce2mn7lh6a": 6.0, "temple-v36ujierxs": 6.0, "temple_first_age_leve": 6.0, "wodden_temple": 6.0,
	# --- Kit fantasia
	"fantasy_barracks": KIT_FANTASIA, "fantasy_house-bh2xhwunmf": KIT_FANTASIA,
	"fantasy_house-dcpho4sua3": KIT_FANTASIA, "fantasy_inn": KIT_FANTASIA, "fantasy_sawmill": KIT_FANTASIA,
	"fantasy_stable": KIT_FANTASIA, "blacksmith": KIT_FANTASIA, "mill": KIT_FANTASIA,
	# A casa baixa do kit (1,07 m) ficaria com 2,8 m — porta abaixo da cabeça do jogador.
	"fantasy_house": 3.6,
	"bell_tower": 3.0,
}

## id → ["altura" | "lado", metros]: objetos soltos e natureza.
const ALVOS := {
	"barrel": ["altura", 1.0], "barrel_2": ["altura", 1.0], "crate": ["altura", 0.9],
	"package": ["altura", 0.7], "package-kyvd6qcqrd": ["altura", 0.6], "hay": ["altura", 1.1],
	"cart": ["altura", 2.0], "bench": ["altura", 0.9], "bench-7uslzo3n9y": ["altura", 0.75],
	"cauldron": ["altura", 0.9], "bonfire": ["altura", 0.5], "well": ["altura", 2.6],
	"market_stand": ["altura", 3.0], "market_stand-dgim5hgisb": ["altura", 3.0], "gazebo": ["altura", 3.8],
	"sawmill_saw": ["altura", 1.5], "fence": ["altura", 1.1], "stairs": ["lado", 2.0],
	"path_straight": ["lado", 3.0], "dock": ["altura", 3.0], "dock_broken": ["altura", 3.0],
	# Natureza: aglomerados de árvores (vários troncos num modelo só).
	"pine_trees": ["altura", 13.0], "trees": ["altura", 11.0],
	"palm_tree": ["altura", 8.5], "palm_tree-a6ckjyfsib": ["altura", 7.5], "palm_tree-p0tgwyxbgr": ["altura", 8.0],
	"logs": ["lado", 4.5], "trees_cut": ["lado", 6.0], "trees_cut-zhm3d5kkrh": ["lado", 6.0],
	"pedra": ["altura", 1.4], "rock": ["altura", 2.2], "rock-4vhwf8xubn": ["altura", 2.0],
	"rock-6cyts1cpil": ["altura", 2.4], "rock-bvlfuhfaui": ["altura", 2.8], "rock-cg6ybeddtz": ["altura", 1.8],
	"rock-kvxsmwoftt": ["altura", 1.6], "rock_2": ["altura", 3.5], "rock-jmfmh7ztl9": ["altura", 1.5],
	"rock-rtlrqyjfms": ["altura", 2.0], "rocks": ["altura", 1.6], "rocks_2": ["altura", 1.8], "rocks_3": ["altura", 1.8],
	"rocks-38eda0gjwz": ["altura", 7.0], "rocks-e1rgb5i2kf": ["altura", 3.5],
	"rocks-fy3szrmvue": ["altura", 6.0], "rocks-ifu6cm2xow": ["altura", 7.5],
	"mountain": ["altura", 30.0], "mountain_group": ["altura", 30.0], "mountains": ["altura", 34.0],
	"mountain-xy4ej3zg3i": ["altura", 35.0],
}

## Navios conferidos pelas miniaturas (decisão do dono: os três barcos-casa entram).
const NAVIOS := {
	"boat": "bote", "small_ship": "chalupa", "ship": "galeao",
	"house-g7esjlfi4v": "barco_casa", "house-2kytqgs4rh": "barco_casa", "house": "barco_casa",
}


func _initialize() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var erros := 0
	var categoria := "navios"
	if not bib.tem_categoria(categoria):
		var r := bib.criar_categoria("navios")
		if not r["ok"]:
			push_error("categoria navios: %s" % r["erro"])
			quit(1)
			return
		categoria = r["id"]
	var aplicados := 0
	for id: String in FATORES:
		if not _existe(bib, id):
			erros += 1
			continue
		var t: Vector3 = bib.info(id)["tamanho"]
		erros += int(bib.definir_tamanho_padrao(id, t * float(FATORES[id])) != OK)
		aplicados += 1
	for id: String in ALVOS:
		if not _existe(bib, id):
			erros += 1
			continue
		var t: Vector3 = bib.info(id)["tamanho"]
		var alvo: Array = ALVOS[id]
		var base := t.y if alvo[0] == "altura" else maxf(t.x, t.z)
		erros += int(bib.definir_tamanho_padrao(id, t * (float(alvo[1]) / base)) != OK)
		aplicados += 1
	var navios: Array[String] = []
	for id: String in NAVIOS:
		if not _existe(bib, id):
			erros += 1
			continue
		var ficha := FichaDeNavio.da_classe(NAVIOS[id])
		erros += int(bib.definir_ficha_de_navio(id, ficha) != OK)
		# O barco é escalado para ter o comprimento da ficha (maior lado do modelo).
		var t: Vector3 = bib.info(id)["tamanho"]
		var comprimento := maxf(t.x, maxf(t.y, t.z))
		erros += int(bib.definir_tamanho_padrao(id, t * (float(ficha["comprimento"]) / comprimento)) != OK)
		navios.append(id)
		aplicados += 1
	erros += int(bib.marcar_categoria(navios, categoria, true) != OK)
	# Os barcos-casa saem de "construção" (categoria em que nenhum deles estava, mas a
	# regra fica escrita: navio não é casa da vila).
	if bib.tem_categoria("construao"):
		bib.marcar_categoria(navios, "construao", false)
	for id in bib.ids():
		var p := bib.tamanho_padrao(id)
		if FATORES.has(id) or ALVOS.has(id) or NAVIOS.has(id):
			print("TAMANHO %-36s %6.1f × %5.1f × %6.1f m" % [id, p.x, p.y, p.z])
	print("TAMANHOS_PADRAO aplicados=%d navios=%d erros=%d" % [aplicados, navios.size(), erros])
	quit(1 if erros else 0)


func _existe(bib: BibliotecaDeModelos, id: String) -> bool:
	if bib.tem(id):
		return true
	push_error("modelo ausente da loja: %s" % id)
	return false
