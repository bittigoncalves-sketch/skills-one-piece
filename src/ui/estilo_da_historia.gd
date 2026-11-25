class_name EstiloDaHistoria
extends RefCounted
# ============================================================================
#  O VISUAL DOS PAINÉIS DO MODO HISTÓRIA — janela M, inventário N, menu B.
#
#  Saiu da `JanelaDeStatus` (30/09/2026) quando o inventário e o menu de comportamento
#  dos pets passaram a precisar da MESMA cara: fundo azul-petróleo quase preto, borda e
#  títulos dourados, botões com contorno dourado, teclas como plaquinhas com a letra.
#  Sem ícone (decisão do dono na janela M): texto, cor e forma simples.
#  A paleta mora AQUI; a `JanelaDeStatus` aponta para ela — uma paleta só.
# ============================================================================

## O dourado é o do aviso de nível, menos saturado: título, não alarme.
const DOURADO := Color(0.95, 0.79, 0.40)
const TEXTO := Color(0.93, 0.95, 0.97)
const TEXTO_2 := Color(0.66, 0.76, 0.82)     # rótulos
const TEXTO_3 := Color(0.46, 0.55, 0.60)     # o que menos importa
## 0,96 e não menos: com 0,93 o boneco do jogo aparecia como fantasma atrás do texto.
const FUNDO := Color(0.02, 0.075, 0.09, 0.96)
const FUNDO_CABECA := Color(0.035, 0.12, 0.14, 0.97)
const FUNDO_LINHA := Color(1.0, 1.0, 1.0, 0.035)


## O fundo de um painel (janela inteira).
static func painel() -> StyleBoxFlat:
	if GuiMinecraft.disponivel():
		return GuiMinecraft.painel(0.96)
	var st := StyleBoxFlat.new()
	st.bg_color = FUNDO
	st.border_color = Color(DOURADO, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	return st


## Faixa de título com as teclas que fecham, como a da janela M.
static func cabeca(titulo: String, teclas: Array[String], margem := 24.0) -> PanelContainer:
	var faixa := PanelContainer.new()
	var mc := GuiMinecraft.disponivel()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.12, 0.12, 0.97) if mc else FUNDO_CABECA
	st.border_color = Color.BLACK if mc else Color(DOURADO, 0.55)
	st.border_width_bottom = 2
	st.corner_radius_top_left = 0 if mc else 8
	st.corner_radius_top_right = 0 if mc else 8
	st.content_margin_left = margem
	st.content_margin_right = margem
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	faixa.add_theme_stylebox_override("panel", st)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	faixa.add_child(linha)
	var t := rotulo(titulo, GuiMinecraft.OURO if mc else DOURADO, 20)
	if not mc:
		t.add_theme_color_override("font_outline_color", Estilo.LINHA)
		t.add_theme_constant_override("outline_size", 4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(t)
	for k in teclas:
		linha.add_child(tecla(k))
	var fechar := rotulo("fechar", TEXTO_3, 13)
	fechar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(fechar)
	return faixa


static func rotulo(texto: String, cor: Color, tamanho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", cor)
	l.add_theme_font_size_override("font_size", tamanho)
	return l


static func botao(texto: String, ao_clicar: Callable, primario := false) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(ao_clicar)
	estilizar_botao(b, primario)
	return b


## Contorno dourado discreto; `primario` é cheio. Desabilitado fica apagado de verdade.
static func estilizar_botao(b: Button, primario: bool, destaque := DOURADO) -> void:
	if GuiMinecraft.disponivel():
		# Botão vanilla: o "primário" (aba ativa, ação principal) usa a textura de destaque (a do mouse em cima) e texto amarelo.
		b.add_theme_stylebox_override("normal", GuiMinecraft.botao("hover" if primario else "normal"))
		b.add_theme_stylebox_override("hover", GuiMinecraft.botao("hover"))
		b.add_theme_stylebox_override("pressed", GuiMinecraft.botao("hover"))
		b.add_theme_stylebox_override("disabled", GuiMinecraft.botao("disabled"))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var tinta_mc := GuiMinecraft.AMARELO if primario else GuiMinecraft.BRANCO
		b.add_theme_color_override("font_color", tinta_mc)
		b.add_theme_color_override("font_hover_color", GuiMinecraft.AMARELO)
		b.add_theme_color_override("font_pressed_color", GuiMinecraft.AMARELO)
		b.add_theme_color_override("font_disabled_color", GuiMinecraft.CINZA)
		return
	var base := Color(destaque, 0.92) if primario else Color(0.06, 0.16, 0.19, 0.95)
	var estados := {
		"normal": [base, Color(destaque, 0.55)],
		"hover": [base.lightened(0.12), Color(destaque, 0.9)],
		"pressed": [base.darkened(0.15), destaque],
		"disabled": [Color(0.04, 0.09, 0.11, 0.6), Color(TEXTO_3, 0.25)],
	}
	for estado in estados:
		var st := StyleBoxFlat.new()
		st.bg_color = estados[estado][0]
		st.border_color = estados[estado][1]
		st.set_border_width_all(1)
		st.set_corner_radius_all(5)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 4
		st.content_margin_bottom = 4
		b.add_theme_stylebox_override(estado, st)
	var tinta := Color(0.08, 0.06, 0.02) if primario else TEXTO
	for chave in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(chave, tinta)
	b.add_theme_color_override("font_disabled_color", Color(TEXTO_3, 0.55))


## Tecla como plaquinha com a letra: forma + texto, sem ícone.
static func tecla(texto: String) -> PanelContainer:
	var placa := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.04)
	st.border_color = Color(TEXTO_2, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(0 if GuiMinecraft.disponivel() else 4)
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	placa.add_theme_stylebox_override("panel", st)
	placa.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	placa.add_child(rotulo(texto, TEXTO_2, 12))
	return placa


## Faixa de fundo discreta de uma linha de lista.
static func linha_de_lista() -> PanelContainer:
	var faixa := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = FUNDO_LINHA
	st.set_corner_radius_all(0 if GuiMinecraft.disponivel() else 5)
	st.content_margin_left = 14
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	faixa.add_theme_stylebox_override("panel", st)
	return faixa
