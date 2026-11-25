extends RefCounted

const FUNDO := Color("151a22")
const PAINEL := Color("1d2530")
const CAMPO := Color("131a24")
const BORDA := Color("354254")
const TEXTO := Color("e6edf5")
const SUAVE := Color("9aabc0")
const ACENTO := Color("63d3b2")

static func caixa(cor: Color, margem: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = BORDA
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = margem
	s.content_margin_right = margem
	s.content_margin_top = margem
	s.content_margin_bottom = margem
	return s

static func tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 14
	for classe in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "LineEdit", "TextEdit", "PopupMenu", "ItemList", "SpinBox"]:
		t.set_color("font_color", classe, TEXTO)
		t.set_color("font_hover_color", classe, Color.WHITE)
		t.set_color("font_focus_color", classe, Color.WHITE)
		t.set_color("font_pressed_color", classe, Color.WHITE)
		t.set_color("font_disabled_color", classe, Color("657388"))
	for classe in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", classe, caixa(PAINEL, 7))
		t.set_stylebox("hover", classe, caixa(Color("2b394a"), 7))
		t.set_stylebox("pressed", classe, caixa(Color("314859"), 7))
		t.set_stylebox("disabled", classe, caixa(FUNDO, 7))
		var foco := caixa(Color(0,0,0,0), 7)
		foco.border_color = ACENTO
		foco.set_border_width_all(2)
		t.set_stylebox("focus", classe, foco)
	for classe in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", classe, caixa(CAMPO, 7))
		var foco := caixa(CAMPO, 7)
		foco.border_color = ACENTO
		t.set_stylebox("focus", classe, foco)
		t.set_color("caret_color", classe, ACENTO)
		t.set_color("selection_color", classe, Color("375779"))
	t.set_stylebox("panel", "PanelContainer", caixa(PAINEL, 10))
	t.set_stylebox("panel", "PopupMenu", caixa(PAINEL, 8))
	t.set_stylebox("panel", "AcceptDialog", caixa(PAINEL, 14))
	t.set_stylebox("panel", "ItemList", caixa(CAMPO))
	t.set_color("font_color", "RichTextLabel", TEXTO)
	return t

static func rotulo(texto: String, tamanho: int = 14, suave: bool = false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", SUAVE if suave else TEXTO)
	return l

static func botao(texto: String, acao: Callable, dica: String = "") -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.custom_minimum_size.y = 32
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(acao)
	return b
