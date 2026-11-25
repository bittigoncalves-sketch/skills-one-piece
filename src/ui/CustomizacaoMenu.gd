class_name CustomizacaoMenu
extends Control
# ============================================================================
#  MENU DE CUSTOMIZAÇÃO — acessórios e cor, com o personagem no meio.
#
#  Pedido do dono (2026-08-27):
#    • à ESQUERDA as categorias: Acessórios e Cor
#    • à DIREITA os itens da categoria escolhida
#    • fundo AZUL, personagem no CENTRO
#    • escolher um item equipa no personagem do centro, na hora
#    • dois acessórios da MESMA parte do corpo não convivem: equipar o novo
#      tira o antigo sozinho
#
#  ------------------------------------------------- ONDE MORA CADA REGRA
#  A exclusão mútua **não está aqui**. Ela mora no catálogo
#  (`src/customizacao/Acessorios.gd`), no campo `parte` de cada acessório, e é o
#  `Acessorios.equipar` que a aplica. Deixar a regra no dado e não na tela é o
#  que faz um acessório novo entrar sem ninguém mexer no menu — e é o que faz o
#  Gear 2, que também veste o chapéu, obedecer à mesma regra de graça.
#
#  ------------------------------------------------------- O PERSONAGEM 3D
#  A `PreviaDoPersonagem` (src/ui/PreviaDoPersonagem.gd): viewport com mundo
#  próprio, luz, câmera enquadrada pela caixa do modelo e giro por arrasto. Morava
#  aqui até 30/09/2026; saiu para a janela de Status (M) usar a MESMA montagem.
# ============================================================================

## A arte de fundo da tela, desenhada pelo dono. `COR_FUNDO` sobrevive como a
## cor de reserva: se o arquivo sumir, a tela volta a ser o azul chapado em vez
## de ficar transparente sobre a arena.
const FUNDO := "res://assets/ui/fundo_customizacao.png"
const COR_FUNDO := Color(0.09, 0.20, 0.42, 1.0)      # o azul original da tela
const COR_PAINEL := Color(0.13, 0.28, 0.55, 0.92)
const COR_PAINEL_SEL := Color(0.20, 0.45, 0.85, 1.0)
const COR_BORDA := Color(0.35, 0.58, 0.95, 1.0)
const COR_TEXTO := Color(0.95, 0.97, 1.0, 1.0)
const COR_TEXTO_FRACO := Color(0.68, 0.78, 0.92, 1.0)

# ⚠️ "cabelo" é categoria PRÓPRIA, e não mais uma parte dentro de ACESSÓRIOS:
# são 12 estilos, e enfiá-los na lista que já tem sete partes do corpo faria o
# jogador rolar muito para achar qualquer coisa. Decisão do dono (2026-08-29).
const CATEGORIAS := ["acessorios", "raca", "cabelo", "corpo", "cor"]
const ROTULO_CATEGORIA := {"acessorios": "ACESSÓRIOS", "raca": "RAÇA",
	"cabelo": "CABELO",
	"corpo": "CORPO", "cor": "COR"}

signal fechado

var _categoria := "acessorios"
var _previa: PreviaDoPersonagem = null
## O modelo e o viewport moram na `_previa`; os nomes antigos ficaram como atalho —
## o menu aplica o visual em `_modelo` a cada escolha, e a `medir_customizacao` lê
## os dois.
var _modelo: Node3D:
	get: return _previa.modelo if _previa != null else null
var _viewport: SubViewport:
	get: return _previa.viewport if _previa != null else null
var _lista_direita: VBoxContainer = null
var _botoes_categoria: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A prévia monta o modelo, aplica o visual salvo e enquadra no quadro seguinte.
	_montar()
	_selecionar_categoria("acessorios")


## Arrastar gira o personagem (sem giro automático — ver `PreviaDoPersonagem.arrastar`).
func _ao_arrastar(e: InputEvent) -> void:
	_previa.arrastar(e)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()


func fechar() -> void:
	hide()
	fechado.emit()


# ---------------------------------------------------------------- montagem
func _montar() -> void:
	# ⚠️ A ARTE DE FUNDO (2026-08-29). Antes era o azul chapado que o dono pediu
	# quando a tela nasceu; agora é a arte que ele desenhou para ela.
	#
	# `KEEP_ASPECT_COVERED` e não `STRETCH`: a imagem é 1536x1024 (3:2) e a
	# janela raramente terá essa proporção — esticar deformaria o navio e a
	# ilha. Cobrindo, sobra imagem fora da tela em vez de faltar.
	var fundo := TextureRect.new()
	fundo.texture = load(FUNDO)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	# ⚠️ VÉU. A arte é clara e cheia de detalhe (nuvens, reflexo do sol, folhas),
	# e texto branco sobre ela some em metade da tela. O véu escurece o
	# suficiente para a leitura sem apagar o desenho — é o que deixa a arte ser
	# fundo, e não concorrente do menu.
	var veu := ColorRect.new()
	veu.color = Color(0.04, 0.08, 0.18, 0.45)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margem.add_theme_constant_override(m, 36)
	add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	coluna.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "CUSTOMIZAÇÃO"
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", COR_TEXTO)
	coluna.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "MONTE SUA IDENTIDADE  •  A PRÉVIA É A MESMA APARÊNCIA DA PARTIDA"
	subtitulo.add_theme_font_size_override("font_size", 12)
	subtitulo.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	coluna.add_child(subtitulo)

	var linha := HBoxContainer.new()
	linha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Sem isto o HBox adota a altura mínima do filho mais alto e estoura a tela.
	linha.custom_minimum_size = Vector2(0, 0)
	linha.add_theme_constant_override("separation", 24)
	coluna.add_child(linha)

	linha.add_child(_coluna_esquerda())
	linha.add_child(_centro())
	linha.add_child(_coluna_direita())

	var voltar := _botao("← VOLTAR", false)
	voltar.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			fechar())
	coluna.add_child(voltar)


func _coluna_esquerda() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(240, 0)
	v.add_theme_constant_override("separation", 10)
	for c in CATEGORIAS:
		var b := _botao(String(ROTULO_CATEGORIA[c]), false)
		b.gui_input.connect(func(e, cat = c):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_selecionar_categoria(cat))
		_botoes_categoria[c] = b
		v.add_child(b)
	return v


func _centro() -> Control:
	var caixa := PanelContainer.new()
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ⚠️ SEMI-TRANSPARENTE desde que há arte de fundo. Opaco, este painel virava
	# um retângulo azul recortado no meio da imagem — tapava justo o pedaço que
	# o desenho tem de melhor. O pouco de azul que fica separa o personagem do
	# mar sem esconder a arte, e a borda continua marcando onde se arrasta para
	# girar.
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.12, 0.28, 0.32)
	st.border_color = COR_BORDA
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	caixa.add_theme_stylebox_override("panel", st)

	_previa = PreviaDoPersonagem.new()
	_previa.name = "Previa"
	_previa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_previa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.add_child(_previa)
	return caixa


func _coluna_direita() -> Control:
	var painel := PanelContainer.new()
	painel.custom_minimum_size = Vector2(300, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.16, 0.34, 0.9)
	st.border_color = COR_BORDA
	st.set_border_width_all(1)
	st.set_corner_radius_all(10)
	painel.add_theme_stylebox_override("panel", st)

	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 12)
	painel.add_child(m)

	# ⚠️ A LISTA ROLA, NÃO CRESCE. Sem o `ScrollContainer`, cada item novo
	# aumentava a altura MÍNIMA do painel, e o painel empurrava a tela inteira:
	# com os seis acessórios o menu chegou a 1.022 px numa tela de 720. O
	# personagem ficava enquadrado dentro de um viewport de 818 px de altura,
	# do qual só a parte de cima aparecia — parecia defeito de câmera, e era de
	# layout.
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(rolagem)

	_lista_direita = VBoxContainer.new()
	_lista_direita.add_theme_constant_override("separation", 8)
	_lista_direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista_direita)
	return painel


# ------------------------------------------------------------------ estado
func _selecionar_categoria(cat: String) -> void:
	_categoria = cat
	for c in _botoes_categoria:
		_estilo_botao(_botoes_categoria[c], c == cat)
	_encher_direita()


func _encher_direita() -> void:
	for f in _lista_direita.get_children():
		f.queue_free()
	if Visual.customizacao_bloqueada() and _categoria != "raca":
		var aviso := Label.new()
		aviso.text = "PRESET BUGGY ATIVO\nAcessórios, cabelo, olhos e cores estão nulos enquanto a raça Palhaço estiver selecionada."
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso.add_theme_font_size_override("font_size", 16)
		aviso.add_theme_color_override("font_color", COR_TEXTO_FRACO)
		_lista_direita.add_child(aviso)
		return
	match _categoria:
		"cabelo": _itens_cabelo()
		"acessorios": _itens_acessorios()
		"raca": _itens_raca()
		"corpo": _itens_corpo()
		_: _itens_cor()


## As partes que aparecem em OUTRO lugar do menu: cabelo tem categoria própria e
## boca mora em CORPO, junto dos olhos. Continuam sendo partes do catálogo (é o
## que lhes dá exclusão mútua e limpeza); só não se listam aqui duas vezes.
const PARTES_EM_OUTRA_CATEGORIA := ["cabelo", "boca"]

func _itens_acessorios() -> void:
	for parte in Acessorios.PARTES:
		if parte in PARTES_EM_OUTRA_CATEGORIA:
			continue
		var t := Label.new()
		t.text = String(Acessorios.PARTES[parte]["rotulo"]).to_upper()
		t.add_theme_font_size_override("font_size", 13)
		t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
		_lista_direita.add_child(t)

		# "Nenhum" é item de primeira classe: sem ele não há como TIRAR um
		# acessório, só trocar por outro.
		var nenhum := _botao("Nenhum", Visual.equipado(String(parte)) == "")
		nenhum.gui_input.connect(func(e, pt = parte):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.equipar(String(pt), "")
				Visual.aplicar(_modelo)
				_encher_direita())
		_lista_direita.add_child(nenhum)

		for id in Acessorios.por_parte(parte):
			var d := Acessorios.dados(id)
			var sel: bool = Visual.equipado(String(parte)) == id
			var b := _botao(String(d["nome"]), sel)
			b.gui_input.connect(func(e, aid = id):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					# A troca automática acontece dentro do `equipar`: ele tira o
					# que já ocupava a parte antes de pôr o novo.
					Visual.equipar(Acessorios.parte_de(aid), aid)
					Visual.aplicar(_modelo)
					_previa.reenquadrar()
					_encher_direita())
			_lista_direita.add_child(b)


## CABELO. Os 12 estilos da folha 2D; a COR mora na categoria Cor, junto das
## outras, porque é escolha independente do estilo — foi o que o dono pediu.
func _itens_cabelo() -> void:
	var t := Label.new()
	t.text = "ESTILO"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t)

	var nenhum := _botao("Careca", Visual.equipado("cabelo") == "")
	nenhum.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Visual.equipar("cabelo", "")
			Visual.aplicar(_modelo)
			_encher_direita())
	_lista_direita.add_child(nenhum)

	for id in Acessorios.por_parte("cabelo"):
		var d := Acessorios.dados(id)
		# A bolinha do botão mostra a COR ESCOLHIDA: sem ela o jogador escolhe o
		# estilo sem ver o tom em que ele vai sair.
		var b := _botao(String(d["nome"]), Visual.equipado("cabelo") == id,
			Visual.cor_do_cabelo())
		b.gui_input.connect(func(e, cid = id):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.equipar("cabelo", cid)
				Visual.aplicar(_modelo)
				_previa.reenquadrar()
				_encher_direita())
		_lista_direita.add_child(b)


func _itens_raca() -> void:
	var t := Label.new()
	t.text = "RAÇA"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t)

	# ⚠️ Raça é escolha ÚNICA — a lista inteira é uma só, sem separar por parte
	# do corpo como nos acessórios. Ninguém é Oni e Sharkman ao mesmo tempo, e
	# quem garante isso é o `Racas.aplicar`, que tira a anterior antes.
	var atual: String = Visual.raca

	# ⚠️ SEM BOTÃO "NENHUMA". Havia um, rotulado "Humano", de quando o catálogo
	# não tinha o humano dentro. Desde a folha de 2026-08-29 ele é uma das doze
	# raças, e é exatamente para isso que o dono o listou: é ele quem devolve o
	# personagem ao padrão. Manter os dois daria duas entradas com o mesmo
	# efeito, uma delas sem selecionar nada na lista.

	for id in Racas.ids():
		var d := Racas.dados(id)
		var b := _botao(String(d["nome"]), atual == id)
		b.gui_input.connect(func(e, rid = id):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.definir_raca(rid)
				Visual.aplicar(_modelo)
				# ⚠️ NÃO REPINTAR AQUI. Havia um `_pintar()` nesta linha, de
				# quando a tela era dona da cor; ele lia `_cor_idx`, que deixou
				# de ser escrito quando o estado passou para o `Visual` e ficou
				# preso em −1. O efeito era `material_override = null` em tudo:
				# escolher Oni pintava de vermelho e a linha seguinte APAGAVA a
				# pintura. Quem pinta agora é o `Visual.aplicar` acima.
				# Raça muda a silhueta (pernas longas, asas, cauda): sem
				# re-enquadrar, o personagem sai do quadro.
				_previa.reenquadrar()
				_encher_direita())
		_lista_direita.add_child(b)


func _itens_corpo() -> void:
	var t := Label.new()
	t.text = "OLHOS"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t)

	var atual: String = Visual.olho
	var nenhum := _botao("Sem olhos", atual == "")
	nenhum.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Visual.olho = ""
			Visual.aplicar(_modelo)
			_encher_direita())
	_lista_direita.add_child(nenhum)

	for id in Corpo.ids():
		var d := Corpo.dados(id)
		var b := _botao(String(d["nome"]), atual == id)
		b.gui_input.connect(func(e, cid = id):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				# Exclusão entre OLHOS: escolher um tira o outro, mas não mexe em
				# raça nem em acessório — são eixos independentes.
				Visual.olho = cid
				Visual.aplicar(_modelo)
				_encher_direita())
		_lista_direita.add_child(b)

	# BOCA. Fica aqui, e não em ACESSÓRIOS, porque é feição do personagem como o
	# olho — não é algo que se veste. Decisão do dono (2026-08-29).
	var tb := Label.new()
	tb.text = "BOCA"
	tb.add_theme_font_size_override("font_size", 13)
	tb.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(tb)

	var sem_boca := _botao("Sem boca", Visual.equipado("boca") == "")
	sem_boca.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Visual.equipar("boca", "")
			Visual.aplicar(_modelo)
			_encher_direita())
	_lista_direita.add_child(sem_boca)

	for id in Acessorios.por_parte("boca"):
		var d := Acessorios.dados(id)
		var b := _botao(String(d["nome"]), Visual.equipado("boca") == id)
		b.gui_input.connect(func(e, bid = id):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.equipar("boca", bid)
				Visual.aplicar(_modelo)
				_encher_direita())
		_lista_direita.add_child(b)


func _itens_cor() -> void:
	var t := Label.new()
	t.text = "COR DO PERSONAGEM"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t)

	var orig := _botao("Original", Visual.cor_idx < 0)
	orig.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Visual.cor_idx = -1
			Visual.aplicar(_modelo)
			_encher_direita())
	_lista_direita.add_child(orig)

	# A paleta de TIME é a MESMA do jogo — uma cor que existisse só aqui seria
	# uma promessa que a partida não cumpre.
	_grupo_de_cores("time", Paleta.CORES)

	var t2 := Label.new()
	t2.text = "TOM DE PELE"
	t2.add_theme_font_size_override("font_size", 13)
	t2.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t2)
	_grupo_de_cores("pele", Paleta.PELES)

	# COR DO CABELO. Lista separada porque é outro eixo: mudar o tom do cabelo
	# não pode desmarcar a cor do corpo, e vice-versa.
	var t3 := Label.new()
	t3.text = "COR DO CABELO"
	t3.add_theme_font_size_override("font_size", 13)
	t3.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t3)
	for i in Paleta.CABELOS.size():
		var d: Dictionary = Paleta.CABELOS[i]
		var b := _botao(String(d["nome"]), Visual.cabelo_idx == i, d["cor"])
		b.gui_input.connect(func(e, idx = i):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.cabelo_idx = idx
				Visual.aplicar(_modelo)
				_encher_direita())
		_lista_direita.add_child(b)


## Um grupo de cores. Os dois grupos são EXCLUSIVOS entre si: escolher um tom de
## pele desmarca a cor de time e vice-versa — o corpo tem UMA cor, e deixar dois
## botões acesos mentiria sobre isso.
func _grupo_de_cores(grupo: String, lista: Array) -> void:
	for i in lista.size():
		var d: Dictionary = lista[i]
		var sel: bool = Visual.cor_grupo == grupo and Visual.cor_idx == i
		var b := _botao(String(d["nome"]).capitalize(), sel, d["cor"])
		b.gui_input.connect(func(e, idx = i, g = grupo):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.cor_grupo = g
				Visual.cor_idx = idx
				Visual.aplicar(_modelo)
				_encher_direita())
		_lista_direita.add_child(b)


## Pinta o CORPO — e as peças de raça marcadas para acompanhar a cor (o Mink
## Lobo). Acessório não entra: chapéu de palha azul deixaria de ser chapéu de
## palha. Chifre de Oni também não, pelo mesmo motivo.
## A pintura vive em `Visual.pintar` desde 2026-08-29 — prévia e partida usam a
## MESMA função, senão as duas podem divergir e a prévia deixa de prometer o que
## a partida cumpre. A cópia que existia aqui foi removida por ter virado uma
## segunda fonte de verdade que discordava da primeira.


## Acessório ou peça de raça — o que NÃO é corpo.
func _e_adorno(n: Node) -> bool:
	var p: Node = n
	while p != null:
		var nome := String(p.name)
		if nome.begins_with(Acessorios.MARCA) or nome.begins_with(Racas.MARCA) \
				or nome.begins_with(Corpo.MARCA):
			return true
		p = p.get_parent()
	return false


# --------------------------------------------------------------- widgets
func _botao(texto: String, selecionado: bool, amostra := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 14)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 10)
	m.add_child(h)
	p.add_child(m)

	if amostra.a > 0.0:
		var quadro := ColorRect.new()
		quadro.color = amostra
		quadro.custom_minimum_size = Vector2(18, 18)
		quadro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(quadro)

	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", COR_TEXTO)
	h.add_child(l)

	_estilo_botao(p, selecionado)
	return p


func _estilo_botao(p: PanelContainer, selecionado: bool) -> void:
	if GuiMinecraft.disponivel():
		p.add_theme_stylebox_override("panel", GuiMinecraft.botao("hover" if selecionado else "normal"))
		return
	var st := StyleBoxFlat.new()
	st.bg_color = COR_PAINEL_SEL if selecionado else COR_PAINEL
	st.border_color = COR_BORDA if selecionado else Color(0.25, 0.42, 0.72)
	st.set_border_width_all(2 if selecionado else 1)
	st.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", st)


## Salva ao fechar, e não a cada clique: o jogador mexe muito e sai uma vez, e
## escrever no disco a cada botão só multiplicaria IO pelo mesmo resultado.
func _exit_tree() -> void:
	Visual.salvar()
