class_name HudMinecraft
extends Control
# ============================================================================
#  CORAÇÕES E XP NO ESTILO DO MINECRAFT (o ícone de fome saiu em 18/11/2026: fome e sede são barras no canto direito, `SobrevivenciaHud`) (12/11/2026) — o HUD de sobrevivência acima da hotbar.
#
#  Layout MEDIDO no vanilla 1.20.1 (`Gui.renderPlayerHealth`, `icons.png` 256×256), em pixels do vanilla; 1 px = `ESCALA` da tela:
#    · hotbar 182×22; a barra de XP tem 182×5, 7 px acima do topo da hotbar; o número do nível, verde, 6 px acima dela;
#    · 10 corações de 9×9, passo de 8 px, começam no canto esquerdo da hotbar, 17 px acima do topo dela (10 px acima do XP);
#    · 10 ícones de fome, mesma altura, alinhados à DIREITA da hotbar, da direita para a esquerda.
#  Texturas em `icons.png`: fundo do coração (16, 0), cheio (52, 0), meio (61, 0); fome: fundo (16, 27), cheia (52, 27), meia (61, 27);
#  XP: vazia (0, 64, 182, 5), cheia (0, 69, 182, 5).
#
#  O que cada coisa mede aqui (não é a regra do vanilla de 20 pontos): 10 corações = a vida máxima do personagem (24 HP vira
#  10 corações de 2,4 HP), 10 comidas = a fome máxima das provisões, XP = progresso dentro do nível atual.
#  Fica de fora (gatilho: o dono pedir): tremor de regeneração, piscar ao tomar dano, coração dourado/envenenado, fome tremendo.
# ============================================================================

const ESCALA := 3
const TEXTURA := "icons.png"
const ICONES := 10
const PASSO := 8
const LADO := 9
## Cor do número do nível no vanilla (`0x80FF20`).
const COR_DO_NIVEL := Color("#80FF20")

var progressao: ProgressaoDoPersonagem
var barra: Control                      # a hotbar: de onde sai a posição
var jogador: Node
var _tex: Texture2D
## CORAÇÕES desligados (12/11/2026, pedido do dono: "modifica os corações para barrinha em cima da barra de energia"): a vida volta a ser a barra do canto superior
## esquerdo (`VidaEnergiaHud`), acima da barra de energia; aqui ficam só a fome e o XP. GATILHO para religar: o dono pedir os corações de volta.
const CORACOES := false
var _meios_vida := -1                   # vida em meios corações (0–20)
var _xp_largura := -1
var _nivel := -1
var _rotulo_nivel: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var img := GuiMinecraft.imagem(TEXTURA)
	if img != null:
		_tex = ImageTexture.create_from_image(img)
	_rotulo_nivel = Label.new()
	_rotulo_nivel.name = "Nivel"
	_rotulo_nivel.add_theme_font_override("font", FonteMinecraft.fonte())
	_rotulo_nivel.add_theme_font_size_override("font_size", 8 * ESCALA)
	_rotulo_nivel.add_theme_color_override("font_color", COR_DO_NIVEL)
	_rotulo_nivel.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo_nivel.add_theme_constant_override("outline_size", ESCALA * 2)
	_rotulo_nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_nivel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo_nivel)


## Só vale com as texturas locais (sem elas o HUD antigo continua sozinho).
static func disponivel() -> bool:
	return GuiMinecraft.imagem(TEXTURA) != null and FonteMinecraft.fonte() != null


func _process(_d: float) -> void:
	if barra == null or not is_instance_valid(barra) or _tex == null:
		return
	var pai := get_parent()
	visible = barra.visible and not (pai != null and pai.has_method("is_menu_open") and pai.is_menu_open())
	if not visible:
		return
	if jogador == null or not is_instance_valid(jogador):
		jogador = get_tree().get_first_node_in_group("player")
	var meios_v := _meios(float(jogador.health) / maxf(float(jogador.max_health), 1.0)) if jogador != null else 0
	var xp_max := maxf(float(progressao.xp_necessario()), 1.0) if progressao != null else 1.0
	var larg_xp := clampi(roundi(float(progressao.xp if progressao != null else 0) / xp_max * 182.0), 0, 182)
	var nivel := progressao.nivel if progressao != null else 1
	var mudou := meios_v != _meios_vida or larg_xp != _xp_largura or nivel != _nivel
	_meios_vida = meios_v
	_xp_largura = larg_xp
	if nivel != _nivel:
		_nivel = nivel
		_rotulo_nivel.text = str(nivel)
	# A origem acompanha a hotbar (ela se move com a escala da janela): o topo dela é 22 px vanilla abaixo do topo do controle.
	var r := barra.get_global_rect()
	var esq := r.position.x
	var topo := r.position.y + 22.0
	var novo := Vector2(esq, topo - 40.0 * ESCALA)
	if novo != global_position or size.x != 182.0 * ESCALA:
		global_position = novo
		size = Vector2(182.0, 40.0) * ESCALA
		mudou = true
		# O número do nível (`h − 35`) fica no meio, entre os corações e a fome; o rótulo tem 3 px de folga em cima (acentos).
		_rotulo_nivel.size = Vector2(182.0 * ESCALA, 12.0 * ESCALA)
		_rotulo_nivel.position = Vector2(0.0, (40.0 - 13.0 - 3.0) * ESCALA)
	if mudou:
		queue_redraw()


## Fração 0–1 → meios corações (0–20), arredondando PARA CIMA: quem tem 1 HP ainda vê meio coração (o vanilla faz o mesmo).
static func _meios(fracao: float) -> int:
	if fracao <= 0.0:
		return 0
	return clampi(ceili(fracao * 20.0 - 0.0001), 1, 20)


func _icone(origem: Vector2i) -> Rect2:
	return Rect2(origem.x, origem.y, LADO, LADO)


func _draw() -> void:
	if _tex == null:
		return
	var s := float(ESCALA)
	# Coordenadas locais em px vanilla: o topo da hotbar está na linha 40. XP: 7 px acima dele (`h − 29`).
	var y_xp := (40.0 - 7.0) * s
	draw_texture_rect_region(_tex, Rect2(0, y_xp, 182.0 * s, 5.0 * s), Rect2(0, 64, 182, 5))
	if _xp_largura > 0:
		draw_texture_rect_region(_tex, Rect2(0, y_xp, _xp_largura * s, 5.0 * s), Rect2(0, 69, _xp_largura, 5))
	# Corações: 17 px acima do topo da hotbar (`h − 39`), 9 de altura.
	var y_ic := (40.0 - 17.0) * s
	for i in ICONES:
		if CORACOES:
			var x_c := float(i * PASSO) * s
			draw_texture_rect_region(_tex, Rect2(x_c, y_ic, 9.0 * s, 9.0 * s), _icone(Vector2i(16, 0)))
			var meio_i := _meios_vida - i * 2
			if meio_i >= 2:
				draw_texture_rect_region(_tex, Rect2(x_c, y_ic, 9.0 * s, 9.0 * s), _icone(Vector2i(52, 0)))
			elif meio_i == 1:
				draw_texture_rect_region(_tex, Rect2(x_c, y_ic, 9.0 * s, 9.0 * s), _icone(Vector2i(61, 0)))
