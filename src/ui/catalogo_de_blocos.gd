class_name CatalogoDeBlocos
extends VBoxContainer
# ============================================================================
#  CATÁLOGO DE BLOCOS (12/11/2026) — a aba BLOCOS da central: todos os blocos do jogo numa grade de slots do Minecraft.
#  Clique esquerdo = uma pilha cheia (64) no inventário; direito = 1; o nome e a dureza aparecem embaixo ao passar o mouse.
#  É a "aba criativa": o jogo ainda não tem fonte natural para os 100+ blocos novos (gatilho: crafting/loot de bloco → esconder atrás de um modo).
# ============================================================================

const COLUNAS := 12
const LADO_DO_SLOT := 44.0
const BauTesouros := preload("res://src/inventario/bau_de_tesouros.gd")

## Ingredientes vanilla das 26 receitas do Epic Fight (`BancadaEpicFight`).
const MATERIAIS_DE_RECEITA: Array[String] = ["minecraft:stick", "minecraft:oak_planks", "minecraft:cobblestone", "minecraft:iron_ingot", "minecraft:gold_ingot", "minecraft:diamond",
	"minecraft:leather", "minecraft:iron_nugget", "minecraft:wooden_sword", "minecraft:stone_sword", "minecraft:iron_sword", "minecraft:golden_sword", "minecraft:diamond_sword"]
var progressao: ProgressaoDoPersonagem
var _info: Label
var _grade: GridContainer


func _init() -> void:
	name = "CatalogoDeBlocos"
	add_theme_constant_override("separation", 8)


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	if _grade != null:
		return
	var topo := EstiloDaHistoria.rotulo("Clique: 64 blocos · botão direito: 1 · o bloco vai para a mochila", EstiloDaHistoria.TEXTO_2, 14)
	add_child(topo)
	_info = EstiloDaHistoria.rotulo(" ", GuiMinecraft.AMARELO if GuiMinecraft.disponivel() else EstiloDaHistoria.DOURADO, 16)
	add_child(_info)
	_grade = GridContainer.new()
	_grade.columns = COLUNAS
	_grade.add_theme_constant_override("h_separation", 2)
	_grade.add_theme_constant_override("v_separation", 2)
	add_child(_grade)
	for t in tipos():
		_grade.add_child(_slot(t))
	# Materiais das receitas do Epic Fight (a BANCADA os consome): enquanto o jogo não tem como obtê-los jogando, saem daqui.
	add_child(EstiloDaHistoria.rotulo("Materiais (para a BANCADA)", GuiMinecraft.OURO if GuiMinecraft.disponivel() else EstiloDaHistoria.DOURADO, 16))
	var mats := GridContainer.new()
	mats.columns = COLUNAS
	mats.add_theme_constant_override("h_separation", 2)
	mats.add_theme_constant_override("v_separation", 2)
	add_child(mats)
	for id in MATERIAIS_DE_RECEITA:
		mats.add_child(_slot_de_item(id))
	add_child(EstiloDaHistoria.rotulo("Itens de exploração · clique: 16 · botão direito: 1", EstiloDaHistoria.DOURADO, 16))
	var itens := HBoxContainer.new()
	add_child(itens)
	itens.add_child(_slot_de_item(BauTesouros.ID))


## Os tipos que o jogador pode colocar: tudo com nome, menos água, o terreno antigo e os blocos "de octantes" (formas internas do relevo).
static func tipos() -> Array[int]:
	TiposDeBloco.iniciar()
	var r: Array[int] = []
	for t in TiposDeBloco.nome.size():
		if TiposDeBloco.nome[t].is_empty() or t == TiposDeBloco.AGUA or t == TiposDeBloco.TERRENO:
			continue
		if TiposDeBloco.forma[t] == TiposDeBloco.Forma.OCTANTES:
			continue
		r.append(t)
	return r


func _slot_de_item(id: String) -> Control:
	var b := Button.new()
	b.name = "Item_BauTesouros" if id == BauTesouros.ID else "Material_" + id.trim_prefix("minecraft:")
	b.custom_minimum_size = Vector2(LADO_DO_SLOT, LADO_DO_SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.icon = RegrasDeItens.icone(id)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(LADO_DO_SLOT) - 14)
	b.tooltip_text = RegrasDeItens.nome(id) if id == BauTesouros.ID else id.trim_prefix("minecraft:").replace("_", " ").capitalize()
	b.mouse_entered.connect(func() -> void: _info.text = b.tooltip_text)
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
			var quantidade := BauTesouros.LIMITE if id == BauTesouros.ID else 64
			dar_item(id, quantidade if e.button_index == MOUSE_BUTTON_LEFT else 1))
	return b


func dar_item(id: String, quantidade: int) -> int:
	if progressao == null or progressao.inventario == null:
		return 0
	var resto := progressao.inventario.inserir(InventarioMinecraft.nova(id, quantidade))
	var coube := quantidade - (0 if resto == null or resto.isEmpty() else resto.getCount())
	if _info != null:
		_info.text = "%d × %s na mochila" % [coube, id.trim_prefix("minecraft:")]
	return coube


func _slot(t: int) -> Control:
	var b := Button.new()
	b.name = "Bloco_%d" % t
	b.custom_minimum_size = Vector2(LADO_DO_SLOT, LADO_DO_SLOT)
	b.focus_mode = Control.FOCUS_NONE
	b.flat = false
	b.icon = ItensDeBloco.icone(ItensDeBloco.id_do_tipo(t))
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(LADO_DO_SLOT) - 14)
	var nome := ItensDeBloco.nome(ItensDeBloco.id_do_tipo(t))
	b.tooltip_text = nome
	b.mouse_entered.connect(func() -> void:
		var d := ItensDeBloco.DUREZA.get(TiposDeBloco.material_do[t], BlocosExtras.dureza(TiposDeBloco.material_do[t])) as float
		_info.text = "%s  ·  dureza %s" % [nome, "inquebrável" if d < 0.0 else str(d)])
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
			dar(t, 64 if e.button_index == MOUSE_BUTTON_LEFT else 1))
	return b


## Põe `quantidade` blocos do tipo na mochila; devolve quantos coube.
func dar(t: int, quantidade: int) -> int:
	if progressao == null or progressao.inventario == null:
		return 0
	var pilha := ItensDeBloco.nova_pilha(t, quantidade)
	var resto := progressao.inventario.inserir(pilha)
	var coube := quantidade - (0 if resto == null or resto.isEmpty() else resto.getCount())
	if _info != null:
		_info.text = "%d × %s na mochila" % [coube, ItensDeBloco.nome(ItensDeBloco.id_do_tipo(t))]
	return coube
