class_name GuiMinecraft
extends RefCounted
# ============================================================================
#  O TEMA "MINECRAFT" DAS JANELAS DO MODO HISTÓRIA (12/11/2026).
#
#  Decisão do dono (12/11/2026): botões, fonte, painéis e HUD do Modo História com a cara do Minecraft 1.20.1. As texturas
#  são do jar (`assets/minecraft_local/gui/`, fora do git; `tools/minecraft/copiar_da_extracao.py` e
#  `copiar_gui_do_jar.py`). Sem elas `disponivel()` é falso e tudo fica como era (o `EstiloDaHistoria` decide).
#
#  O que o vanilla mede (lido no `widgets.png`, 256×256): botão 200×20 — normal (0, 66), com o mouse (0, 86), desligado (0, 46);
#  bordas de 2–3 px, então um corte 9-slice de 3 px estica sem estragar a moldura.
#  Cores do texto no vanilla: branco-acinzentado E0E0E0, com o mouse FFFFA0, desligado A0A0A0; a sombra é o texto a 25 %.
# ============================================================================

const PASTA := "res://assets/minecraft_local/gui/"
const ESCALA := 2                       # "GUI scale 2": 1 pixel vanilla = 2 da tela
const BRANCO := Color("#E0E0E0")
const AMARELO := Color("#FFFFA0")
const CINZA := Color("#A0A0A0")
const OURO := Color("#FFAA00")          # o "§6" do vanilla: título e destaque
const SOMBRA := Color(0.16, 0.16, 0.16, 1.0)

## `GUI_VANILLA=0` no ambiente volta ao visual antigo (comparar/depurar).
static var ligado := OS.get_environment("GUI_VANILLA") != "0"
static var _cache := {}
static var _tema: Theme


## As texturas e a fonte existem neste computador?
static func disponivel() -> bool:
	return ligado and FonteMinecraft.fonte() != null and imagem("widgets.png") != null


static func imagem(nome: String) -> Image:
	if _cache.has(nome):
		return _cache[nome]
	var caminho := ProjectSettings.globalize_path(PASTA + nome)
	var img: Image = null
	if FileAccess.file_exists(caminho):
		img = Image.load_from_file(caminho)
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
		else:
			img = null
	_cache[nome] = img
	return img


## Estilo de botão vanilla para um estado ("normal", "hover", "pressed", "disabled").
static func botao(estado: String) -> StyleBoxTexture:
	var chave := "botao_" + estado
	if _cache.has(chave):
		return _cache[chave]
	var y := 66
	match estado:
		"hover", "pressed":
			y = 86
		"disabled":
			y = 46
	var st := StyleBoxTexture.new()
	st.texture = ImageTexture.create_from_image(imagem("widgets.png"))
	st.region_rect = Rect2(0, y, 200, 20)
	st.texture_margin_left = 3
	st.texture_margin_right = 3
	st.texture_margin_top = 3
	st.texture_margin_bottom = 3
	# Os cortes são em pixels da TEXTURA; a escala do GUI vem do `texture_filter`/tamanho do controle — a moldura de 3 px
	# fica fina em tela cheia, então o conteúdo ganha margem extra para o texto não encostar na borda.
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 6
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_cache[chave] = st
	return st


## Painel escuro de menu: cinza-grafite quase opaco com moldura preta de 2 px e um friso claro por dentro (o das telas de opções).
static func painel(opacidade := 0.96) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.19, 0.19, 0.19, opacidade)
	st.border_color = Color(0.0, 0.0, 0.0, 1.0)
	st.set_border_width_all(2)
	st.set_corner_radius_all(0)
	st.anti_aliasing = false
	return st


## Tema das janelas: fonte pixel, tamanho 16 (2× o vanilla), botões e sombra de texto do vanilla. Um por processo.
static func tema() -> Theme:
	if _tema != null:
		return _tema
	var t := Theme.new()
	t.default_font = FonteMinecraft.fonte()
	t.default_font_size = 16
	for tipo in ["Label", "Button", "CheckBox", "OptionButton", "RichTextLabel"]:
		t.set_color("font_shadow_color", tipo, SOMBRA)
		t.set_constant("shadow_offset_x", tipo, ESCALA)
		t.set_constant("shadow_offset_y", tipo, ESCALA)
	t.set_color("font_color", "Label", BRANCO)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(estado, "Button", botao(estado))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", BRANCO)
	t.set_color("font_hover_color", "Button", AMARELO)
	t.set_color("font_pressed_color", "Button", AMARELO)
	t.set_color("font_disabled_color", "Button", CINZA)
	# Tooltip do vanilla (`TooltipRenderUtil`): fundo roxo quase preto e moldura roxa.
	var dica := StyleBoxFlat.new()
	dica.bg_color = Color(0.063, 0.0, 0.063, 0.94)
	dica.border_color = Color(0.31, 0.0, 1.0, 0.6)
	dica.set_border_width_all(2)
	dica.set_corner_radius_all(0)
	dica.content_margin_left = 8
	dica.content_margin_right = 8
	dica.content_margin_top = 4
	dica.content_margin_bottom = 4
	t.set_stylebox("panel", "TooltipPanel", dica)
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	# Campo de texto: fundo preto com moldura cinza (o `EditBox` do vanilla).
	var campo := StyleBoxFlat.new()
	campo.bg_color = Color.BLACK
	campo.border_color = Color(0.63, 0.63, 0.63)
	campo.set_border_width_all(1)
	campo.set_corner_radius_all(0)
	campo.content_margin_left = 6
	campo.content_margin_right = 6
	campo.content_margin_top = 4
	campo.content_margin_bottom = 4
	t.set_stylebox("normal", "LineEdit", campo)
	t.set_stylebox("focus", "LineEdit", campo)
	t.set_color("font_color", "LineEdit", Color("#E0E0E0"))
	_tema = t
	return t


## Põe a janela (e tudo que está dentro dela) no tema do Minecraft: fonte, botões e pixels nítidos. Sem as texturas, não faz nada.
static func aplicar(janela: Control) -> void:
	if not disponivel():
		return
	janela.theme = tema()
	janela.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## TODAS as interfaces do jogo (menus, customização, lojas, HUDs, arena): o tema vai na janela raiz e é herdado por todo `Control`
## que não tenha o seu próprio (decisão do dono, 12/11/2026: "personalização de todas as GUIs"). O que tem override explícito
## (cores, tamanhos, `StyleBox` de painel) mantém; o resto ganha fonte, botões, sombra e pixels nítidos.
static func aplicar_global(raiz: Window) -> void:
	if not disponivel():
		return
	raiz.theme = tema()
	raiz.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST


## A fonte pixel não tem emoji (símbolos acima de U+2190 viram pontinhos): com o tema ligado, tira-os dos rótulos e botões da árvore.
static func limpar_emojis(raiz: Node) -> void:
	if not disponivel():
		return
	if raiz is Label or raiz is Button:
		var t: String = raiz.text
		var novo := ""
		for i in t.length():
			var c := t.unicode_at(i)
			if c < 0x2190 and c != 0xFE0F:
				novo += t[i]
		novo = novo.strip_edges()
		if novo != t:
			raiz.text = novo
	for f in raiz.get_children():
		limpar_emojis(f)


# ============================================================================
#  NORMALIZAÇÃO DAS TELAS COM ESTILO PRÓPRIO (12/11/2026, "personalização de TODAS as GUIs")
#  Muitas telas (customização, HUDs de técnica, arena, toque) montam `StyleBoxFlat` arredondados com cores próprias. Em vez de editar
#  cada arquivo, esta passagem roda UMA vez por tela nova (ver `ligar_normalizacao`): cantos retos, sem sombra, painéis escuros em
#  grafite com moldura preta, botões neutros com a textura vanilla, emoji fora. Cores fortes (botão azul/vermelho de ação, barras de
#  vida/energia) ficam como são: são informação, não decoração.
# ============================================================================
const _NOMES_DE_ESTILO := ["panel", "normal", "hover", "pressed", "disabled", "focus", "fill", "background"]


## Liga a normalização automática: toda tela nova (Control sem pai Control) é ajustada 3 quadros depois de entrar na árvore.
static func ligar_normalizacao(arvore: SceneTree) -> void:
	if not disponivel() or OS.get_environment("GUI_SEM_NORM") == "1":
		return
	arvore.node_added.connect(func(no: Node) -> void:
		if no is Control and not (no.get_parent() is Control) and no.get_parent() != null:
			# Filho de CanvasLayer não herda o tema da janela raiz: cada tela de topo leva o seu.
			if (no as Control).theme == null:
				(no as Control).theme = tema()
				(no as Control).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_normalizar_adiado(arvore, no, no.has_method("_create_play_card")))      # o menu inicial (sem referenciar a classe: evita ciclo com o GameFlow)


static func _normalizar_adiado(arvore: SceneTree, no: Node, conservar_acao: bool) -> void:
	for i in 3:
		await arvore.process_frame
		if not is_instance_valid(no):
			return
	normalizar(no, conservar_acao)


## `conservar_acao`: botões de cor forte ficam como são (o menu inicial usa azul/vermelho para jogar); nas outras telas todo botão vira vanilla.
static func normalizar(no: Node, conservar_acao := false) -> void:
	if no is Control:
		var c := no as Control
		var botao_neutro := c is Button and not (c is CheckBox) and not (c is OptionButton) and not (c is CheckButton)
		for nome in _NOMES_DE_ESTILO:
			if not c.has_theme_stylebox_override(nome):
				continue
			var st := c.get_theme_stylebox(nome)
			if st is StyleBoxFlat:
				var f := st as StyleBoxFlat
				if botao_neutro and nome in ["normal", "hover", "pressed", "disabled"] and not (conservar_acao and _e_cor_de_acao(f.bg_color)):
					c.add_theme_stylebox_override(nome, botao("hover" if nome == "pressed" else (nome if nome != "focus" else "normal")))
					continue
				f.set_corner_radius_all(0)
				f.shadow_size = 0
				f.anti_aliasing = false
				if nome == "panel" and _e_escura(f.bg_color):
					f.bg_color = Color(0.17, 0.17, 0.17, f.bg_color.a)
					f.border_color = Color.BLACK
					if f.border_width_left == 0 and f.border_width_top == 0:
						f.set_border_width_all(2)
		if c is Label or c is Button:
			var t: String = c.text
			var novo := ""
			for i in t.length():
				var u := t.unicode_at(i)
				if u < 0x2190 and u != 0xFE0F:
					novo += t[i]
			novo = novo.strip_edges()
			if novo != t and not novo.is_empty():
				c.text = novo
	for f in no.get_children():
		normalizar(f, conservar_acao)


## Cor "de ação" (botão azul de criar, vermelho de perigo…): saturada e clara o bastante para ser informação.
static func _e_cor_de_acao(cor: Color) -> bool:
	return cor.s > 0.45 and cor.v > 0.35


static func _e_escura(cor: Color) -> bool:
	return cor.v < 0.35
