class_name RegrasDeItens
extends RefCounted
## REGRAS DE ITEM do Minecraft 1.20.1 que o inventário precisa (10/11/2026): limite de pilha, peça de armadura, nome e ícone.
## O jar não traz o limite em dados (está no código dos itens): aqui vai a regra vanilla por nome — 64 por padrão, 16 (ovos, bolas, placas, pérolas…),
## 1 (ferramentas, armas, armaduras, baldes, poções…). Itens do Mine Piece: espadas/armas = 1, o resto 64.

const PASTA := "res://assets/minecraft_local/"
const BauTesouros := preload("res://src/inventario/bau_de_tesouros.gd")
const DE_UM := ["_sword", "_pickaxe", "_axe", "_shovel", "_hoe", "_helmet", "_chestplate", "_leggings", "_boots", "_bucket", "_boat", "_minecart", "_horse_armor", "_bed",
	"_potion", "_chest_boat", "_raft", "_banner_pattern", "_music_disc", "_smithing_template", "_head", "_skull"]
const DE_UM_EXATOS := ["bow", "crossbow", "shield", "elytra", "trident", "fishing_rod", "flint_and_steel", "shears", "carrot_on_a_stick", "warped_fungus_on_a_stick",
	"saddle", "bucket", "water_bucket", "lava_bucket", "milk_bucket", "potion", "splash_potion", "lingering_potion", "written_book", "writable_book", "enchanted_book",
	"compass", "recovery_compass", "clock", "spyglass", "brush", "totem_of_undying", "mushroom_stew", "rabbit_stew", "beetroot_soup", "suspicious_stew", "cake", "bundle",
	"turtle_helmet", "lead", "name_tag", "debug_stick", "knowledge_book", "filled_map", "goat_horn", "firework_star_x"]
const DE_DEZESSEIS := ["ender_pearl", "snowball", "egg", "sign", "hanging_sign", "honey_bottle", "bucket_of_x", "armor_stand", "banner", "white_banner"]
const DE_DEZESSEIS_SUFIXO := ["_sign", "_hanging_sign", "_banner"]
const ARMAS_DO_MOD := ["rifle", "pistol", "pistol_gold", "senriku", "rocket_launcher", "hook", "pretzel", "forbidden_score", "shield_biscuit", "shield_uta", "shield_note"]

static var _lang: Dictionary = {}
static var _texturas := {}


static func nome_curto(id: String) -> String:
	return id.get_slice(":", 1) if id.contains(":") else id


static func limite(id: String) -> int:
	if id == BauTesouros.ID:
		return BauTesouros.LIMITE
	if id == BauMisteriosoItem.ID:
		return 1                                   # item de missão: sempre um só
	if ItensDeFruta.e_de(id):
		return ItensDeFruta.LIMITE                 # Akuma no Mi e fruta do pomar: pilha de até 64
	if ItensDoJogo.e_do_jogo(id):
		return 1                                   # item numerado do jogo (luta, fruta, vara…): sempre um só
	if ItensEpicFight.e_de(id):
		return 1                                   # arma do Epic Fight: sempre uma só
	if ItensDeBloco.e_de_bloco(id):
		return 64                                  # bloco da grade (V5): 64 por pilha, como no Minecraft
	var n := nome_curto(id)
	if id.begins_with("minepiece:"):
		var base := _base_do_mod(n)
		return 1 if base in ["SwordItem", "TieredItem", "ShieldItem"] or ARMAS_DO_MOD.has(n) or n.contains("_armor_") or n.begins_with("clothes_") else 64
	if DE_UM_EXATOS.has(n):
		return 1
	for suf in DE_UM:
		if n.ends_with(suf):
			return 1
	if DE_DEZESSEIS.has(n):
		return 16
	for suf in DE_DEZESSEIS_SUFIXO:
		if n.ends_with(suf):
			return 16
	return 64


static var _bases_do_mod: Dictionary = {}

static func _base_do_mod(n: String) -> String:
	if _bases_do_mod.is_empty():
		var f := FileAccess.open("res://mapas/east_blue/itens_do_mod.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for k in (d.get("itens", {}) as Dictionary):
					_bases_do_mod[k] = str(d["itens"][k].get("base", "Item"))
		if _bases_do_mod.is_empty():
			_bases_do_mod["_"] = "Item"
	return str(_bases_do_mod.get(n, "Item"))


## 0 cabeça, 1 peito, 2 pernas, 3 pés; −1 se não é armadura.
static func peca_de_armadura(id: String) -> int:
	var n := nome_curto(id)
	if n.ends_with("_helmet") or n == "carved_pumpkin" or n.ends_with("_head") or n.ends_with("_skull"):
		return 0
	if n.ends_with("_chestplate") or n == "elytra" or n.ends_with("_body"):
		return 1
	if n.ends_with("_leggings"):
		return 2
	if n.ends_with("_boots"):
		return 3
	return -1


static func nome(id: String) -> String:
	if id == BauTesouros.ID:
		return "Baú de tesouros · colecionável"
	if id == BauMisteriosoItem.ID:
		return BauMisteriosoItem.NOME
	if ItensDeFruta.e_de(id):
		return ItensDeFruta.nome(id)
	if ItensDoJogo.e_do_jogo(id):
		return ItensDoJogo.nome(id)
	if ItensEpicFight.e_de(id):
		return ItensEpicFight.nome(id)
	if ItensDeBloco.e_de_bloco(id):
		return ItensDeBloco.nome(id)
	if _lang.is_empty():
		var f := FileAccess.open(PASTA + "lang_en_us.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_lang = d
		if _lang.is_empty():
			_lang["_"] = ""
	var n := nome_curto(id)
	var ns := id.get_slice(":", 0) if id.contains(":") else "minecraft"
	for tipo in ["item", "block"]:
		var chave := "%s.%s.%s" % [tipo, ns, n]
		if ns == "minepiece" and McTexto.traduzir(chave) != chave:
			return McTexto.traduzir(chave)
		if _lang.has(chave):
			return str(_lang[chave])
	return n.replace("_", " ").capitalize()


## O ícone-fantasma de um slot de armadura/escudo vazio (`empty_armor_slot_helmet`…), ou null.
static func fantasma(nome: String) -> Texture2D:
	var chave := "_fantasma_" + nome
	if _texturas.has(chave):
		return _texturas[chave]
	var real := ProjectSettings.globalize_path(PASTA + "item/empty_armor_slot_%s.png" % nome)
	var tex: Texture2D = null
	if FileAccess.file_exists(real):
		var img := Image.load_from_file(real)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_texturas[chave] = tex
	return tex


## Textura do ícone (item, bloco ou do mod), ou null.
static func icone(id: String) -> Texture2D:
	if id == BauTesouros.ID:
		return BauTesouros.icone()
	if id == BauMisteriosoItem.ID:
		return BauMisteriosoItem.icone()
	if ItensDeFruta.e_de(id):
		return ItensDeFruta.icone(id)
	if ItensDoJogo.e_do_jogo(id):
		return ItensDoJogo.textura(id)
	if ItensEpicFight.e_de(id):
		return ItensEpicFight.icone(id)
	if ItensDeBloco.e_de_bloco(id):
		return ItensDeBloco.icone(id)
	if _texturas.has(id):
		return _texturas[id]
	var n := nome_curto(id)
	var candidatos: Array[String] = []
	if id.begins_with("minepiece:"):
		candidatos = ["res://mapas/modelos/mpi_%s_%s.png" % [n, n], "res://mapas/modelos/mpi_%s.png" % n, "res://assets/mine_piece/itens/%s.png" % n]
	else:
		candidatos = [PASTA + "item/%s.png" % n, PASTA + "block/%s.png" % n, PASTA + "block/%s_top.png" % n, PASTA + "block/%s_front.png" % n,
			PASTA + "block/%s_side.png" % n, PASTA + "item/%s_0.png" % n]
	var tex: Texture2D = null
	for c in candidatos:
		var real := ProjectSettings.globalize_path(c)
		if FileAccess.file_exists(real):
			var img := Image.load_from_file(real)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				break
	_texturas[id] = tex
	return tex
