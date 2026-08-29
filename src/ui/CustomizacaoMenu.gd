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
#  Um `SubViewport` com câmera, luz e o modelo de verdade (`CharacterBuilder`),
#  mostrado num `SubViewportContainer`. É o mesmo modelo que entra em partida —
#  então o que se vê aqui é o que se leva, e não uma maquete que pode divergir.
#
#  ⚠️ O viewport precisa de `own_world_3d = true`. Sem isso ele compartilha o
#  mundo da cena principal: a arena inteira apareceria atrás do personagem, e a
#  luz daqui vazaria para o jogo.
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
var _modelo: Node3D = null
var _viewport: SubViewport = null
var _lista_direita: VBoxContainer = null
var _botoes_categoria: Dictionary = {}
var _cor_idx := -1
var _cor_grupo := "time"   # "time" | "pele"
var _giro := 0.0
var _camera: Camera3D = null
var _arrastando := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_montar()
	Visual.carregar_uma_vez()
	Visual.aplicar(_modelo)
	_selecionar_categoria("acessorios")
	# ⚠️ ENQUADRAR SÓ NO QUADRO SEGUINTE. `_caixa_visual` lê `global_transform`
	# de cada malha, e o Godot só propaga as transformações depois que a árvore
	# processa. Enquadrar dentro do `_ready` mede a hierarquia ainda em repouso e
	# devolve uma caixa errada — foi o que pôs a câmera dentro do tronco.
	await get_tree().process_frame
	_enquadrar()


## ⚠️ SEM GIRO AUTOMÁTICO. O personagem girava sozinho, e isso atrapalha o que o
## menu existe para fazer: comparar duas opções. Quando ele nunca para, cada
## escolha aparece num ângulo diferente e a comparação vira memória. Agora ele
## fica parado e gira quando o jogador ARRASTA — quem quer ver as costas vê, na
## hora que quiser.
func _ao_arrastar(e: InputEvent) -> void:
	if _modelo == null or not is_instance_valid(_modelo):
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = e.pressed
	elif e is InputEventMouseMotion and _arrastando:
		# 0,01 rad por pixel: uma volta completa em ~630 px, que é
		# aproximadamente a largura do painel. Assim o gesto natural (arrastar de
		# ponta a ponta) dá a volta inteira.
		_giro -= (e as InputEventMouseMotion).relative.x * 0.01
		_modelo.rotation.y = _giro


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

	var cont := SubViewportContainer.new()
	cont.stretch = true
	# O container é quem recebe o arrasto: é ele que ocupa a área do personagem.
	cont.mouse_filter = Control.MOUSE_FILTER_STOP
	cont.gui_input.connect(_ao_arrastar)
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.add_child(cont)

	_viewport = SubViewport.new()
	# ⚠️ mundo PRÓPRIO: sem isto o viewport herda o mundo da cena e a arena
	# inteira apareceria atrás do personagem.
	_viewport.own_world_3d = true
	# ⚠️ TRANSPARENTE, senão o personagem aparece dentro de um RETÂNGULO AZUL
	# recortado sobre a arte. O viewport pinta o próprio fundo antes da cena, e
	# com a imagem atrás isso vira uma janela opaca no meio da tela.
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(520, 620)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(_viewport)

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	# BG_CLEAR_COLOR (e não BG_COLOR) é o que respeita o `transparent_bg` acima:
	# com BG_COLOR o ambiente pinta a cor de qualquer jeito e a transparência do
	# viewport não vale nada.
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.68, 0.90)
	env.ambient_light_energy = 0.9
	amb.environment = env
	_viewport.add_child(amb)

	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-38.0), 0.0)
	luz.light_energy = 1.5
	_viewport.add_child(luz)

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_viewport.add_child(_camera)
	_camera.current = true

	_montar_modelo()
	return caixa


func _montar_modelo() -> void:
	var dados := CharacterBuilder.build_character("base")
	_modelo = dados.get("node") as Node3D
	if _modelo == null:
		push_warning("[Customizacao] não consegui montar o personagem de prévia")
		return
	_modelo.position = Vector3(0, 0.0, 0)
	_viewport.add_child(_modelo)


## ⚠️ ENQUADRAMENTO MEDIDO, não números fixos. A primeira versão punha a câmera
## em (0, 1.0, 2.6) — e o modelo do `CharacterBuilder` vem no tamanho NATIVO
## dele, sem a escala que o rig aplica em partida. Resultado: a câmera nascia
## dentro do tronco e a tela mostrava uma parede verde.
##
## Aqui a moldura sai da caixa do próprio modelo: altura e largura decidem a
## distância, então trocar de personagem ou mudar a proporção do rig continua
## enquadrando.
## ⚠️ SEMPRE ADIADO. `_enquadrar` lê `global_transform` das malhas, e o Godot só
## propaga isso depois que a árvore processa. Chamar logo após equipar mede a
## peça nova ainda em repouso e devolve uma moldura errada — é o mesmo erro que
## já pôs a câmera dentro do tronco no `_ready` (ver docs/erros.md).
func _reenquadrar() -> void:
	await get_tree().process_frame
	_enquadrar()


func _enquadrar() -> void:
	if _modelo == null or _camera == null:
		return
	var cx := _caixa_visual(_modelo)
	var alvo := cx.position + cx.size * 0.5
	# O maior lado manda: personagem alto pede recuo por altura, largo por
	# largura. `tan(fov/2)` converte "quanto cabe" em "a que distância".
	var maior: float = maxf(cx.size.y, maxf(cx.size.x, cx.size.z))
	var dist: float = (maior * 0.5) / tan(deg_to_rad(_camera.fov * 0.5))
	dist *= 1.35   # respiro nas bordas: personagem colado na moldura sufoca
	# ⚠️ CÂMERA NO −Z, não no +Z. O personagem olha para −Z (convenção do Godot e
	# deste projeto, ver `RosaDosVentos`), então pôr a câmera no +Z mostra as
	# COSTAS — e num menu de customização o rosto é o que o jogador quer ver. O
	# giro lento leva as costas ao quadro sozinho, para quem quer ver as asas.
	# ⚠️ IDEMPOTENTE: NÃO MOVE O MODELO. A primeira versão deslocava o modelo para
	# centrar o alvo no eixo — e cada nova chamada subtraía de novo, acumulando
	# DERIVA. Como `_enquadrar` agora roda a cada troca de raça e de acessório,
	# isso empurrava o personagem para longe da câmera a cada clique.
	#
	# Em vez disso, a mira usa o EIXO do modelo em X/Z (para o giro ficar
	# centrado) e a altura do centro da caixa em Y (para o enquadramento
	# vertical). Chamar dez vezes dá o mesmo resultado de chamar uma.
	# `alvo` já está em MUNDO. Em X/Z a mira usa o EIXO do modelo, para o giro
	# ficar centrado; em Y usa a altura do centro da caixa, para o enquadramento
	# vertical pegar o corpo inteiro.
	var base := _modelo.global_position
	var mira := Vector3(base.x, alvo.y, base.z)
	_camera.position = Vector3(mira.x, mira.y, mira.z - dist)
	_camera.look_at(mira, Vector3.UP)


## A caixa que o modelo realmente OCUPA, em coordenadas de MUNDO.
##
## ⚠️ MUNDO, não espaço do modelo. A primeira versão convertia para o espaço do
## modelo (`raiz.global_transform.affine_inverse()`) e devolvia 3,6 de altura —
## mas o rig tem escala 1,8, então o corpo mede 6,48 no mundo, que é onde a
## câmera está. A distância saía calculada pela metade e o enquadramento pegava
## só a cabeça.
##
## `VisualInstance3D.get_aabb()` sozinho não serve: ele é da malha, não da
## hierarquia, e o rig tem membros pendurados em vários nós.
func _caixa_visual(raiz: Node3D) -> AABB:
	var malhas: Array = []
	FxUtil._collect_meshes(raiz, malhas)
	var uniao := AABB()
	var primeiro := true
	for m in malhas:
		if not (m is MeshInstance3D) or (m as MeshInstance3D).mesh == null:
			continue
		var mi := m as MeshInstance3D
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		uniao = a if primeiro else uniao.merge(a)
		primeiro = false
	if primeiro:
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 2.0, 1.0))
	return uniao


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
					_reenquadrar()
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
				_reenquadrar()
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

	var nenhuma := _botao("Humano", atual == "")
	nenhuma.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Racas.remover(_modelo)
			_pintar()
			_encher_direita())
	_lista_direita.add_child(nenhuma)

	for id in Racas.ids():
		var d := Racas.dados(id)
		var b := _botao(String(d["nome"]), atual == id)
		b.gui_input.connect(func(e, rid = id):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Visual.raca = rid
				Visual.aplicar(_modelo)
				# Repintar DEPOIS de aplicar: as peças do Mink Lobo nascem sem
				# material e só ficam da cor do personagem quando a pintura passa
				# por elas.
				_pintar()
				# Raça muda a silhueta (pernas longas, asas, cauda): sem
				# re-enquadrar, o personagem sai do quadro.
				_reenquadrar()
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
func _pintar() -> void:
	if _modelo == null or not is_instance_valid(_modelo):
		return
	var malhas: Array = []
	FxUtil._collect_meshes(_modelo, malhas)
	for m in malhas:
		if not (m is MeshInstance3D):
			continue
		# Peça de raça marcada com `segue_cor` é pintada COMO se fosse corpo —
		# é isso que faz as orelhas e o rabo do Mink Lobo ficarem da cor do
		# personagem, que foi o pedido.
		if _e_adorno(m) and not Racas.segue_cor(m):
			continue
		if _cor_idx < 0:
			(m as MeshInstance3D).material_override = null
			continue
		# ⚠️ O MESMO MATERIAL DO JOGO (`Materiais.superficie` = cel shading), e
		# não um `StandardMaterial3D` avulso. A prévia existe para o jogador
		# decidir como vai ficar EM PARTIDA — se ela usa outra iluminação, ela
		# mente, e a cor escolhida aqui aparece diferente lá. É o mesmo motivo de
		# a paleta ser a do jogo em vez de uma lista só do menu.
		var lista: Array = Paleta.PELES if _cor_grupo == "pele" else Paleta.CORES
		if _cor_idx >= lista.size():
			continue
		var c: Color = lista[_cor_idx]["cor"]
		(m as MeshInstance3D).material_override = Materiais.superficie(c)


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
