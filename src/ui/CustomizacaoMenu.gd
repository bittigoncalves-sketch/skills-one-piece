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

const COR_FUNDO := Color(0.09, 0.20, 0.42, 1.0)      # o azul pedido
const COR_PAINEL := Color(0.13, 0.28, 0.55, 0.92)
const COR_PAINEL_SEL := Color(0.20, 0.45, 0.85, 1.0)
const COR_BORDA := Color(0.35, 0.58, 0.95, 1.0)
const COR_TEXTO := Color(0.95, 0.97, 1.0, 1.0)
const COR_TEXTO_FRACO := Color(0.68, 0.78, 0.92, 1.0)

const CATEGORIAS := ["acessorios", "raca", "corpo", "cor"]
const ROTULO_CATEGORIA := {"acessorios": "ACESSÓRIOS", "raca": "RAÇA",
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
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

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
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.14, 0.30, 1.0)
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
	_viewport.transparent_bg = false
	_viewport.size = Vector2i(520, 620)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(_viewport)

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO
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
		"acessorios": _itens_acessorios()
		"raca": _itens_raca()
		"corpo": _itens_corpo()
		_: _itens_cor()


func _itens_acessorios() -> void:
	for parte in Acessorios.PARTES:
		var t := Label.new()
		t.text = String(Acessorios.PARTES[parte]["rotulo"]).to_upper()
		t.add_theme_font_size_override("font_size", 13)
		t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
		_lista_direita.add_child(t)

		# "Nenhum" é item de primeira classe: sem ele não há como TIRAR um
		# acessório, só trocar por outro.
		var nenhum := _botao("Nenhum", Acessorios.equipado_na_parte(_modelo, parte) == "")
		nenhum.gui_input.connect(func(e, pt = parte):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Acessorios.desequipar(_modelo, pt)
				_encher_direita())
		_lista_direita.add_child(nenhum)

		for id in Acessorios.por_parte(parte):
			var d := Acessorios.dados(id)
			var sel: bool = Acessorios.equipado_na_parte(_modelo, parte) == id
			var b := _botao(String(d["nome"]), sel)
			b.gui_input.connect(func(e, aid = id):
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					# A troca automática acontece dentro do `equipar`: ele tira o
					# que já ocupava a parte antes de pôr o novo.
					Acessorios.equipar(_modelo, aid)
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
	var atual := Racas.atual(_modelo)

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
				Racas.aplicar(_modelo, rid)
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

	var atual := Corpo.atual(_modelo)
	var nenhum := _botao("Sem olhos", atual == "")
	nenhum.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Corpo.remover(_modelo)
			_encher_direita())
	_lista_direita.add_child(nenhum)

	for id in Corpo.ids():
		var d := Corpo.dados(id)
		var b := _botao(String(d["nome"]), atual == id)
		b.gui_input.connect(func(e, cid = id):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				# Exclusão entre OLHOS: escolher um tira o outro, mas não mexe em
				# raça nem em acessório — são eixos independentes.
				Corpo.aplicar(_modelo, cid)
				_encher_direita())
		_lista_direita.add_child(b)


func _itens_cor() -> void:
	var t := Label.new()
	t.text = "COR DO PERSONAGEM"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", COR_TEXTO_FRACO)
	_lista_direita.add_child(t)

	var orig := _botao("Original", _cor_idx < 0)
	orig.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cor_idx = -1
			_pintar()
			_encher_direita())
	_lista_direita.add_child(orig)

	# A paleta é a MESMA do jogo (`Paleta.CORES`) — uma cor que existisse só aqui
	# seria uma promessa que a partida não cumpre.
	for i in Paleta.CORES.size():
		var d: Dictionary = Paleta.CORES[i]
		var b := _botao(String(d["nome"]).capitalize(), _cor_idx == i, d["cor"])
		b.gui_input.connect(func(e, idx = i):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_cor_idx = idx
				_pintar()
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
