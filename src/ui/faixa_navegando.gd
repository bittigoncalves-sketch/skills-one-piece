class_name FaixaNavegando
extends PanelContainer
# ============================================================================
#  A FAIXA "NAVEGANDO" (15/10/2026) — o retângulo no topo da tela enquanto a viagem dura.
#
#  Pedido do dono: depois de zarpar, mesmo que o jogador deixe o leme, a UI continua
#  escrevendo NAVEGANDO; ela só some quando o barco entra numa ilha. Quem manda é o
#  `comando.gd` (sinal `viagem_mudou`); aqui só o desenho. Não pega o mouse.
# ============================================================================

var _titulo: Label
var _subtitulo: Label


func _ready() -> void:
	name = "FaixaNavegando"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.02, 0.075, 0.09, 0.9)
	st.border_color = Color(EstiloDaHistoria.DOURADO, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)           # retângulo: cantos quase retos
	st.content_margin_left = 34
	st.content_margin_right = 34
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	add_theme_stylebox_override("panel", st)
	var coluna := VBoxContainer.new()
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_theme_constant_override("separation", 0)
	add_child(coluna)
	_titulo = EstiloDaHistoria.rotulo("NAVEGANDO", EstiloDaHistoria.DOURADO, 24)
	_titulo.name = "Titulo"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_constant_override("outline_size", 4)
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	coluna.add_child(_titulo)
	_subtitulo = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 14)
	_subtitulo.name = "Subtitulo"
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_subtitulo)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	position.y = 14.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH


func mostrar(ativa: bool, subtitulo := "") -> void:
	visible = ativa
	_subtitulo.text = subtitulo
	_subtitulo.visible = not subtitulo.is_empty()
	reset_size()
	if ativa:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
		position.y = 14.0
