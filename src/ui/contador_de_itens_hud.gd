class_name ContadorDeItensHud
extends HBoxContainer
## Contador dos itens do Mine Piece do jogador, logo abaixo do "M" do HUD (pedido do dono, 10/11/2026): hoje o BISCOITO do Bisu Bisu
## (criado pela técnica Biscuit, gasto 1 por guerreiro invocado). Lê `ProgressaoDoPersonagem.itens_do_mod`; só aparece quando há biscoito
## ou o jogador está com a fruta Bisu Bisu, para não poluir o HUD de quem não usa.
const ICONE := "res://mapas/modelos/mpi_biscuit_biscuit.png"
const ITEM := ItensDoMod.BISCOITO
const ALTURA := 28.0

var _prog: ProgressaoDoPersonagem
var _numero: Label
var _jogador: Node


func _init() -> void:
	name = "ContadorDeItens"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64.0, ALTURA)
	add_theme_constant_override("separation", 4)
	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.custom_minimum_size = Vector2(24.0, 24.0)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(ICONE):
		icone.texture = load(ICONE)
	add_child(icone)
	_numero = EstiloDaHistoria.rotulo("0", EstiloDaHistoria.DOURADO, 18)
	_numero.name = "Numero"
	_numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_numero)
	visible = false


func ligar(prog: ProgressaoDoPersonagem) -> void:
	_prog = prog
	prog.mudou.connect(atualizar)
	prog.itens_do_mod_mudaram.connect(atualizar)
	atualizar()


func atualizar() -> void:
	if _prog == null:
		return
	var n := _prog.item_do_mod(ITEM)
	_numero.text = "×%d" % n
	visible = n > 0 or _prog.fruta.begins_with("bisu_bisu")
