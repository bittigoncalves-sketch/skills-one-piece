class_name BlocosExtras
extends RefCounted
# ============================================================================
#  BLOCOS EXTRAS DO MINECRAFT (12/11/2026) — meta do dono: "pelo menos 64 blocos e suas texturas".
#
#  Cada linha é um CUBO do Minecraft 1.20.1: `nome|topo|lado|base|dureza|opções`. Textura = arquivo em `assets/minecraft_local/block/`
#  (sem `.png`); vazio em `base` = igual ao lado, vazio em `lado` = igual ao topo. Dureza do `Blocks.java` (−1 = inquebrável).
#  Opções: `t` translúcido (vidro tingido), `f` tinta de folhagem, `g` tinta de grama.
#  IDs: 26–63 e 160–255 (o intervalo 64–159 é de laje/escada/octantes de `MATERIAIS_COM_FORMAS`, que só vai até o id 31).
#  Tipo novo = uma linha aqui; nome, textura, dureza e item saem daí (`TiposDeBloco`, `TexturasDeBloco`, `ItensDeBloco`).
#  Limite: só cubos (sem laje/escada/cerca/porta dos novos). Gatilho: pedido de escada de um destes → mover o material para
#  `MATERIAIS_COM_FORMAS` (precisa de id < 32: reservar um dos ids livres 26–31).
# ============================================================================

const CORES := ["white", "orange", "magenta", "light_blue", "yellow", "lime", "pink", "gray", "light_gray", "cyan", "purple", "blue", "brown", "green", "red", "black"]
const NOMES_DAS_CORES := ["branco", "laranja", "magenta", "azul_claro", "amarelo", "lima", "rosa", "cinza", "cinza_claro", "ciano", "roxo", "azul", "marrom", "verde", "vermelho", "preto"]
## Cor aproximada de cada cor do jogo (só o plano B sem textura).
const HEX := ["#e9ecec", "#f07613", "#bd44b3", "#3aafd9", "#f8c527", "#70b919", "#ed8dac", "#3e4447", "#8e8e86", "#158991", "#792aac", "#35399d", "#724728", "#546d1b", "#a12722", "#141519"]

const LINHAS := [
	# madeiras
	"tabua_abeto|spruce_planks||2.0", "tabua_betula|birch_planks||2.0", "tabua_selva|jungle_planks||2.0", "tabua_acacia|acacia_planks||2.0",
	"tabua_carvalho_escuro|dark_oak_planks||2.0", "tabua_mangue|mangrove_planks||2.0", "tabua_cerejeira|cherry_planks||2.0",
	"tabua_bambu|bamboo_planks||2.0", "tabua_carmesim|crimson_planks||2.0", "tabua_distorcida|warped_planks||2.0",
	"tronco_abeto|spruce_log_top|spruce_log|2.0", "tronco_betula|birch_log_top|birch_log|2.0", "tronco_selva|jungle_log_top|jungle_log|2.0",
	"tronco_acacia|acacia_log_top|acacia_log|2.0", "tronco_carvalho_escuro|dark_oak_log_top|dark_oak_log|2.0",
	"tronco_mangue|mangrove_log_top|mangrove_log|2.0", "tronco_cerejeira|cherry_log_top|cherry_log|2.0",
	"folhas_abeto|spruce_leaves||0.2|f", "folhas_betula|birch_leaves||0.2|f", "folhas_selva|jungle_leaves||0.2|f", "folhas_acacia|acacia_leaves||0.2|f",
	"folhas_carvalho_escuro|dark_oak_leaves||0.2|f",
	# pedras e solos
	"andesito|andesite||1.5", "diorito|diorite||1.5", "granito|granite||1.5", "calcita|calcite||0.75", "tufo|tuff||1.5",
	"ardosia|deepslate_top|deepslate|3.0", "tijolo_de_pedra|stone_bricks||1.5", "tijolo_de_pedra_rachado|cracked_stone_bricks||1.5",
	"tijolo_de_pedra_musgoso|mossy_stone_bricks||1.5", "pedregulho_musgoso|mossy_cobblestone||2.0", "pedra_lisa|smooth_stone||2.0",
	"andesito_polido|polished_andesite||1.5", "diorito_polido|polished_diorite||1.5", "granito_polido|polished_granite||1.5",
	"pedra_negra|blackstone_top|blackstone|1.5", "tijolo_de_pedra_negra|polished_blackstone_bricks||1.5", "pedra_do_fim|end_stone||3.0",
	"netherrack|netherrack||0.4", "tijolo_do_nether|nether_bricks||2.0", "areia_das_almas|soul_sand||0.5", "terra_das_almas|soul_soil||0.5",
	"rocha_matriz|bedrock||-1", "cascalho|gravel||0.6", "areia_vermelha|red_sand||0.5", "arenito|sandstone_top|sandstone|0.8|bsandstone_bottom",
	"arenito_vermelho|red_sandstone_top|red_sandstone|0.8|bred_sandstone_bottom", "terra_grossa|coarse_dirt||0.5", "podzol|podzol_top|podzol_side|0.5|bdirt",
	"micelio|mycelium_top|mycelium_side|0.6|bdirt", "lama|mud||0.5", "tijolo_de_lama|mud_bricks||1.5", "musgo|moss_block||0.1",
	"quartzo|quartz_block_top|quartz_block_side|0.8|bquartz_block_bottom", "pilar_de_quartzo|quartz_pillar_top|quartz_pillar|0.8|bquartz_pillar_top",
	"prismarinho|prismarine||1.5", "tijolo_de_prismarinho|prismarine_bricks||1.5", "gelo_compacto|packed_ice||0.5", "gelo_azul|blue_ice||2.8",
	# minérios e blocos de metal
	"minerio_de_carvao|coal_ore||3.0", "minerio_de_ferro|iron_ore||3.0", "minerio_de_ouro|gold_ore||3.0", "minerio_de_diamante|diamond_ore||3.0",
	"minerio_de_esmeralda|emerald_ore||3.0", "minerio_de_lapis|lapis_ore||3.0", "minerio_de_redstone|redstone_ore||3.0", "minerio_de_cobre|copper_ore||3.0",
	"bloco_de_ferro|iron_block||5.0", "bloco_de_ouro|gold_block||3.0", "bloco_de_diamante|diamond_block||5.0", "bloco_de_esmeralda|emerald_block||5.0",
	"bloco_de_lapis|lapis_block||3.0", "bloco_de_carvao|coal_block||5.0", "bloco_de_cobre|copper_block||3.0", "bloco_de_ametista|amethyst_block||1.5",
	"bloco_de_redstone|redstone_block||5.0", "bloco_de_ferro_bruto|raw_iron_block||5.0",
	# decoração e utilidades
	"estante|oak_planks|bookshelf|1.5", "mesa_de_trabalho|crafting_table_top|crafting_table_side|2.5|boak_planks", "fornalha|furnace_top|furnace_side|3.5",
	"abobora|pumpkin_top|pumpkin_side|1.0", "melancia|melon_top|melon_side|1.0", "fardo_de_feno|hay_block_top|hay_block_side|0.5",
	"tnt|tnt_top|tnt_side|0.0|btnt_bottom", "esponja|sponge||0.6", "bloco_de_slime|slime_block||0.0|t", "lanterna_marinha|sea_lantern||0.3",
	"pedra_luminosa|glowstone||0.3", "lampada_de_redstone|redstone_lamp||0.3", "bloco_de_mel|honey_block_side||0.0|t", "favo_de_mel|honeycomb_block||0.6",
	"bloco_de_osso|bone_block_top|bone_block_side|2.0", "bloco_de_notas|note_block||0.8", "alvo|target_top|target_side|0.5", "obsidiana_chorosa|crying_obsidian||50.0",
]


## Todas as definições: `[{id, nome, topo, lado, base, dureza, transl, tinta, cor}]`, na ordem do registro. Pura; chamada uma vez por `TiposDeBloco.iniciar`.
static func todas() -> Array:
	var lista: Array = []
	var ids := PackedInt32Array()
	for i in range(26, 64):
		ids.append(i)
	for i in range(160, 256):
		ids.append(i)
	var defs: Array = []
	for linha in LINHAS:
		var p: PackedStringArray = (linha as String).split("|")
		var opcoes := p[4] if p.size() > 4 else ""
		var base := ""
		var flags := ""
		# Opções: letras de flag (`t`, `f`, `g`) ou `b<textura>` (base diferente). Uma só por linha.
		if opcoes.begins_with("b"):
			base = opcoes.substr(1)
		else:
			flags = opcoes
		defs.append({"nome": p[0], "topo": p[1], "lado": p[2] if p[2] != "" else p[1], "base": base if base != "" else (p[2] if p[2] != "" else p[1]),
			"dureza": float(p[3]), "transl": flags.contains("t"), "tinta": "folha" if flags.contains("f") else ("grama" if flags.contains("g") else ""), "cor": Color("#8a8a8a")})
	for i in CORES.size():
		var c: String = CORES[i]
		var n: String = NOMES_DAS_CORES[i]
		var cor := Color(HEX[i])
		defs.append({"nome": "concreto_" + n, "topo": c + "_concrete", "lado": c + "_concrete", "base": c + "_concrete", "dureza": 1.8, "transl": false, "tinta": "", "cor": cor})
		defs.append({"nome": "terracota_" + n, "topo": c + "_terracotta", "lado": c + "_terracotta", "base": c + "_terracotta", "dureza": 1.25, "transl": false, "tinta": "", "cor": cor})
	assert(defs.size() <= ids.size(), "mais blocos extras que ids livres")
	for k in defs.size():
		var d: Dictionary = defs[k]
		d["id"] = ids[k]
		lista.append(d)
	return lista


static var _por_nome := {}
static var _por_id := {}


static func _indice() -> void:
	if not _por_nome.is_empty():
		return
	for d: Dictionary in todas():
		_por_nome[d.nome] = d
		_por_id[d.id] = d


static func definicao_por_nome(nome: String) -> Dictionary:
	_indice()
	return _por_nome.get(nome, {})


static func dureza(tipo: int) -> float:
	_indice()
	return float((_por_id.get(tipo, {}) as Dictionary).get("dureza", 1.0))


static func quantidade() -> int:
	return todas().size()
