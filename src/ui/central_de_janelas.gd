class_name CentralDeJanelas
extends PanelContainer
# ============================================================================
#  CENTRAL DE JANELAS — a janela única do M no Modo História (30/10/2026).
#
#  Pedido do dono: unir os menus B (tripulação/pets), N (inventário) e M (status) num só,
#  aberto pelo M, com botões de janela no topo para trocar de um para o outro; mesmo
#  tamanho para todos; personalização; B e N deixam de abrir qualquer coisa.
#
#  Só HOSPEDA: as três páginas continuam sendo as classes que já eram (`JanelaDeStatus`,
#  `InventarioDaHistoria`, `MenuDeComportamento`), com a mesma lógica e o mesmo `visible`
#  (verdadeiro só na página mostrada de uma central aberta) — por isso a `HistoriaHud` e os
#  testes continuam perguntando "o inventário está aberto?" do mesmo jeito.
#
#  TAMANHO ÚNICO: o corpo mede sempre `LARGURA` × `ALTURA` lógicos, qualquer que seja a
#  aba; o que não cabe rola dentro da página. Em tela menor a janela inteira encolhe
#  (escala), em vez de cada página inventar a própria medida.
#
#  APARÊNCIA (cor de destaque, opacidade do fundo, escala): fica no progresso, em
#  `dados_de("janelas")`, junto da última aba. Vale para a moldura, o cabeçalho e os botões
#  de aba; o texto interno das páginas segue a paleta do `EstiloDaHistoria` (gatilho: se o
#  dono quiser a cor mudando também o conteúdo, `EstiloDaHistoria.DOURADO` vira variável).
# ============================================================================

signal aba_mostrada(id: String)
signal fechou

const SISTEMA := "janelas"
const ID_DO_LAYOUT := "central"
const ABAS := [
	{"id": "status", "nome": "STATUS"},
	{"id": "mochila", "nome": "MOCHILA"},
	{"id": "blocos", "nome": "BLOCOS"},
	{"id": "bancada", "nome": "BANCADA"},
	{"id": "pets", "nome": "PETS"},
	{"id": "conquistas", "nome": "CONQUISTAS"},
]
const LARGURA := 1040.0
const ALTURA := 600.0
const MARGEM_DA_TELA := 24.0
const OPACIDADE_MINIMA := 0.5
const ESCALA_MINIMA := 0.75
const ESCALA_MAXIMA := 1.25
## Cores de destaque oferecidas (moldura, cabeçalho, abas). A primeira é a de sempre.
const CORES := {
	"dourado": Color(0.95, 0.79, 0.40),
	"azul": Color(0.45, 0.75, 1.0),
	"verde": Color(0.5, 0.88, 0.6),
	"vermelho": Color(1.0, 0.5, 0.45),
	"violeta": Color(0.78, 0.62, 1.0),
}
const PADRAO := {"aba": "status", "cor": "dourado", "opacidade": 0.96, "escala": 1.0}

var progressao: ProgressaoDoPersonagem
var aba := "status"
var aparencia := PADRAO.duplicate()

var _paginas := {}                 # id -> a página (o nó da classe original)
var _botoes := {}                  # id -> Button da aba
var _conteudo: MarginContainer
var _faixa: PanelContainer
var _painel_aparencia: PanelContainer
var _estilo_moldura: StyleBoxFlat
var _estilo_faixa: StyleBoxFlat
var _botao_aparencia: Button
var _bolinhas := {}                # cor -> Button
var _barra_opacidade: HSlider
var _barra_escala: HSlider
var _graficos: OptionButton
var _carregando := false
var _aba_salva := "status"     # a última aba usada; vale quando a página dela for adicionada


func _ready() -> void:
	GuiMinecraft.aplicar(self)    # fonte, botões e painéis do Minecraft (12/11/2026); sem as texturas locais, não faz nada
	visible = false
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_estilo_moldura = EstiloDaHistoria.painel()
	add_theme_stylebox_override("panel", _estilo_moldura)
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	raiz.add_child(_montar_faixa())
	raiz.add_child(_montar_painel_aparencia())
	_conteudo = MarginContainer.new()
	_conteudo.name = "Conteudo"
	_conteudo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_conteudo.clip_contents = true
	raiz.add_child(_conteudo)
	get_viewport().size_changed.connect(ajustar)
	_sincronizar_controles()
	_aplicar_aparencia()


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	_carregando = true
	var salvo := prog.dados_de(SISTEMA)
	aparencia = PADRAO.duplicate()
	if str(salvo.get("cor", "")) in CORES:
		aparencia.cor = str(salvo.cor)
	aparencia.opacidade = clampf(float(salvo.get("opacidade", PADRAO.opacidade)), OPACIDADE_MINIMA, 1.0)
	aparencia.escala = clampf(float(salvo.get("escala", PADRAO.escala)), ESCALA_MINIMA, ESCALA_MAXIMA)
	_aba_salva = str(salvo.get("aba", "status"))
	if _aba_salva == "inventario":
		_aba_salva = "mochila"        # a aba INVENTÁRIO foi para dentro da MOCHILA (19/11/2026): quem a deixou salva reabre na mochila
	aparencia.aba = _aba_salva
	_sincronizar_controles()
	_carregando = false
	if is_node_ready():
		_aplicar_aparencia()


## Uma página nova: o nó vira filho do corpo, preenchendo-o, e é "embutido" (sem moldura,
## sem cabeçalho e sem posicionar a si mesmo). `id` é uma das `ABAS`.
func adicionar_pagina(id: String, pagina: Control) -> void:
	_paginas[id] = pagina
	pagina.visible = false
	var rolagem := id != "status" and id != "conquistas"      # a de status já rola por dentro; a árvore de conquistas se move por arrasto/zoom
	var casa: Control = pagina
	if rolagem:
		var r := ScrollContainer.new()
		r.name = "Rolagem_" + id
		r.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		r.visible = false
		r.add_child(pagina)
		pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		casa = r
		pagina.visibility_changed.connect(func(): r.visible = pagina.visible)
	_conteudo.add_child(casa)
	if id == _aba_salva:
		aba = id
	if pagina.has_method("embutir"):
		pagina.call("embutir")
	_atualizar_abas()
	ajustar()


func tem_pagina(id: String) -> bool:
	return _paginas.has(id)


func pagina(id: String) -> Control:
	return _paginas.get(id)


func aberta() -> bool:
	return visible


## Abre a central na aba `id` (ou na última, se vazio) e a mostra.
func abrir(id := "") -> void:
	var alvo := id if _pagina_existe(id) else aba
	if not _pagina_existe(alvo):
		return
	visible = true
	mostrar(alvo)


func fechar() -> void:
	if not visible and not _alguma_pagina_visivel():
		return
	visible = false
	for id in _paginas:
		(_paginas[id] as Control).visible = false
	fechou.emit()


## Troca de aba (os botões do topo). A página mostrada é a única com `visible` verdadeiro.
func mostrar(id: String) -> void:
	if not _pagina_existe(id):
		return
	aba = id
	for outra in _paginas:
		(_paginas[outra] as Control).visible = visible and outra == id
	_atualizar_abas()
	ajustar()
	if not _carregando and progressao != null and str(aparencia.get("aba", "")) != id:
		aparencia.aba = id
		_gravar()
	aba_mostrada.emit(id)


func _pagina_existe(id: String) -> bool:
	return id != "" and _paginas.has(id)


func _alguma_pagina_visivel() -> bool:
	for id in _paginas:
		if (_paginas[id] as Control).visible:
			return true
	return false


# ----------------------------------------------------------------- tamanho
## Corpo sempre `LARGURA` × `ALTURA`; a janela inteira encolhe se a tela for menor e
## respeita a escala escolhida (nunca maior do que cabe).
func ajustar() -> void:
	if not is_inside_tree() or _conteudo == null:
		return
	_conteudo.custom_minimum_size = Vector2(LARGURA, ALTURA)
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pivot_offset = size * 0.5
	var tela := get_viewport_rect().size
	var cabe := minf((tela.x - 2.0 * MARGEM_DA_TELA) / maxf(size.x, 1.0), (tela.y - 2.0 * MARGEM_DA_TELA) / maxf(size.y, 1.0))
	var pedida := clampf(float(aparencia.get("escala", 1.0)), ESCALA_MINIMA, ESCALA_MAXIMA)
	scale = Vector2.ONE * minf(pedida, cabe)


# ----------------------------------------------------------------- montagem
func _montar_faixa() -> Control:
	_faixa = PanelContainer.new()
	_faixa.name = "Faixa"
	_estilo_faixa = StyleBoxFlat.new()
	_estilo_faixa.border_width_bottom = 2
	_estilo_faixa.corner_radius_top_left = 8
	_estilo_faixa.corner_radius_top_right = 8
	_estilo_faixa.content_margin_left = 20
	_estilo_faixa.content_margin_right = 20
	_estilo_faixa.content_margin_top = 10
	_estilo_faixa.content_margin_bottom = 10
	_faixa.add_theme_stylebox_override("panel", _estilo_faixa)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	_faixa.add_child(linha)
	for a in ABAS:
		var id := str(a.id)
		var b := Button.new()
		b.text = str(a.nome)
		b.name = "Aba_" + id
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(130, 34)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): mostrar(id))
		_botoes[id] = b
		linha.add_child(b)
	var espaco := Control.new()
	espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(espaco)
	_botao_aparencia = EstiloDaHistoria.botao("Aparência", func(): _painel_aparencia.visible = not _painel_aparencia.visible)
	_botao_aparencia.name = "BotaoAparencia"
	linha.add_child(_botao_aparencia)
	linha.add_child(EstiloDaHistoria.tecla("M"))
	linha.add_child(EstiloDaHistoria.tecla("ESC"))
	var fechar_rotulo := EstiloDaHistoria.rotulo("fechar", EstiloDaHistoria.TEXTO_3, 13)
	fechar_rotulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(fechar_rotulo)
	return _faixa


func _montar_painel_aparencia() -> Control:
	_painel_aparencia = PanelContainer.new()
	_painel_aparencia.name = "Aparencia"
	_painel_aparencia.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.28)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	_painel_aparencia.add_theme_stylebox_override("panel", st)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_painel_aparencia.add_child(linha)
	linha.add_child(EstiloDaHistoria.rotulo("Cor", EstiloDaHistoria.TEXTO_2, 14))
	for nome in CORES:
		var cor_nome := str(nome)
		var bolinha := Button.new()
		bolinha.name = "Cor_" + cor_nome
		bolinha.focus_mode = Control.FOCUS_NONE
		bolinha.custom_minimum_size = Vector2(26, 26)
		bolinha.tooltip_text = cor_nome.capitalize()
		bolinha.pressed.connect(func(): definir_cor(cor_nome))
		_bolinhas[cor_nome] = bolinha
		linha.add_child(bolinha)
	linha.add_child(EstiloDaHistoria.rotulo("Opacidade", EstiloDaHistoria.TEXTO_2, 14))
	_barra_opacidade = _slider("Opacidade", OPACIDADE_MINIMA, 1.0, 0.01)
	_barra_opacidade.value_changed.connect(func(v: float): definir_opacidade(v, false))
	_barra_opacidade.drag_ended.connect(func(_mudou: bool): _gravar())
	linha.add_child(_barra_opacidade)
	linha.add_child(EstiloDaHistoria.rotulo("Escala", EstiloDaHistoria.TEXTO_2, 14))
	_barra_escala = _slider("Escala", ESCALA_MINIMA, ESCALA_MAXIMA, 0.05)
	_barra_escala.value_changed.connect(func(v: float): definir_escala(v, false))
	_barra_escala.drag_ended.connect(func(_mudou: bool): _gravar())
	linha.add_child(_barra_escala)
	linha.add_child(EstiloDaHistoria.botao("Padrão", restaurar_aparencia))
	# Gráficos: escolha do APARELHO (não do personagem), em user://perfil_grafico.cfg.
	linha.add_child(EstiloDaHistoria.rotulo("Gráficos", EstiloDaHistoria.TEXTO_2, 14))
	_graficos = OptionButton.new()
	_graficos.name = "Graficos"
	_graficos.focus_mode = Control.FOCUS_NONE
	_graficos.tooltip_text = "Automático liga o modo Economia (sombra mais leve, objetos minúsculos escondidos) com o notebook na bateria."
	for nome in ["Automático", "Normal", "Economia"]:
		_graficos.add_item(nome)
	PerfilGrafico.carregar_uma_vez()
	_graficos.select(PerfilGrafico.modo)
	_graficos.item_selected.connect(func(i: int): PerfilGrafico.definir_modo(i, get_tree()))
	linha.add_child(_graficos)
	return _painel_aparencia


func _slider(nome: String, minimo: float, maximo: float, passo: float) -> HSlider:
	var s := HSlider.new()
	s.name = nome
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.custom_minimum_size = Vector2(150, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	return s


# --------------------------------------------------------------- aparência
func definir_cor(nome: String) -> void:
	if not nome in CORES:
		return
	aparencia.cor = nome
	_aplicar_aparencia()
	_gravar()


## `gravar` falso enquanto o controle é arrastado; o fim do arrasto grava uma vez só.
func definir_opacidade(valor: float, gravar := true) -> void:
	aparencia.opacidade = clampf(valor, OPACIDADE_MINIMA, 1.0)
	_aplicar_aparencia()
	if gravar:
		_gravar()


func definir_escala(valor: float, gravar := true) -> void:
	aparencia.escala = clampf(valor, ESCALA_MINIMA, ESCALA_MAXIMA)
	_aplicar_aparencia()
	if gravar:
		_gravar()


func restaurar_aparencia() -> void:
	aparencia.cor = PADRAO.cor
	aparencia.opacidade = PADRAO.opacidade
	aparencia.escala = PADRAO.escala
	_sincronizar_controles()
	_aplicar_aparencia()
	_gravar()


func cor_de_destaque() -> Color:
	return CORES.get(str(aparencia.get("cor", "dourado")), CORES.dourado)


func _aplicar_aparencia() -> void:
	if _estilo_moldura == null:
		return
	var destaque := cor_de_destaque()
	var alfa := float(aparencia.opacidade)
	if GuiMinecraft.disponivel():
		# Tema do Minecraft: grafite com moldura preta; a cor de destaque escolhida fica só nos botões ativos.
		_estilo_moldura.bg_color = Color(0.19, 0.19, 0.19, alfa)
		_estilo_moldura.border_color = Color.BLACK
		_estilo_faixa.bg_color = Color(0.12, 0.12, 0.12, minf(alfa + 0.01, 1.0))
		_estilo_faixa.border_color = Color.BLACK
	else:
		_estilo_moldura.bg_color = Color(EstiloDaHistoria.FUNDO, alfa)
		_estilo_moldura.border_color = Color(destaque, 0.45)
		_estilo_faixa.bg_color = Color(EstiloDaHistoria.FUNDO_CABECA, minf(alfa + 0.01, 1.0))
		_estilo_faixa.border_color = Color(destaque, 0.55)
	EstiloDaHistoria.estilizar_botao(_botao_aparencia, false, destaque)
	for nome in _bolinhas:
		var st := StyleBoxFlat.new()
		st.bg_color = CORES[nome]
		st.set_corner_radius_all(13)
		st.set_border_width_all(3 if nome == aparencia.cor else 1)
		st.border_color = Color.WHITE if nome == aparencia.cor else Color(1, 1, 1, 0.3)
		for estado in ["normal", "hover", "pressed", "focus"]:
			(_bolinhas[nome] as Button).add_theme_stylebox_override(estado, st)
	_atualizar_abas()
	ajustar()


func _atualizar_abas() -> void:
	var destaque := cor_de_destaque()
	for id in _botoes:
		var b := _botoes[id] as Button
		b.disabled = not _paginas.has(id)
		EstiloDaHistoria.estilizar_botao(b, id == aba, destaque)


func _sincronizar_controles() -> void:
	if _barra_opacidade != null:
		_barra_opacidade.set_value_no_signal(float(aparencia.opacidade))
		_barra_escala.set_value_no_signal(float(aparencia.escala))


func _gravar() -> void:
	if progressao == null or _carregando:
		return
	progressao.gravar_dados(SISTEMA, {"aba": aba, "cor": aparencia.cor,
		"opacidade": snappedf(float(aparencia.opacidade), 0.01), "escala": snappedf(float(aparencia.escala), 0.01)})
