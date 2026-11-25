class_name EstiloDoEditor
extends RefCounted
# Estilo único dos painéis do editor de mapa: escuro e opaco o bastante para ler
# por cima do céu claro, sem enfeite. Um lugar só, para os três painéis não
# divergirem de tom.

const FUNDO := Color(0.11, 0.12, 0.14, 0.94)
const BORDA := Color(0.26, 0.28, 0.32)
const TEXTO := Color(0.92, 0.93, 0.95)
const TEXTO_FRACO := Color(0.62, 0.65, 0.70)
const DESTAQUE := Color(0.25, 0.60, 1.0)
const ERRO := Color(1.0, 0.45, 0.40)
const OK := Color(0.45, 0.85, 0.50)
const FONTE := 13


static func painel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = FUNDO
	s.border_color = BORDA
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func rotulo(texto: String, fraco := false, tamanho := FONTE) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", TEXTO_FRACO if fraco else TEXTO)
	return l


static func botao(texto: String, dica := "") -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.focus_mode = Control.FOCUS_NONE     # atalho de teclado não pode "apertar" o botão focado
	b.add_theme_font_size_override("font_size", FONTE)
	return b


static func campo(largura := 58.0) -> LineEdit:
	var c := LineEdit.new()
	c.custom_minimum_size = Vector2(largura, 0)
	c.add_theme_font_size_override("font_size", FONTE)
	c.select_all_on_focus = true
	return c


## Texto de explicação dentro de painel de largura fixa. ⚠️ Sem quebra de linha
## um Label pede a largura do texto inteiro, e o painel lateral cresce para fora
## da tela (visto na captura com várias peças selecionadas, 14/09/2026).
static func explicacao(texto: String) -> Label:
	var l := rotulo(texto, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1, 0)
	return l
