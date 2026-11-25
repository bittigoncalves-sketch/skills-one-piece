class_name JanelaDaTripulacao
extends PanelContainer
# ============================================================================
#  A JANELA DA TRIPULAÇÃO (15/10/2026) — "Navegar?" e a escolha dos aliados.
#
#  Duas páginas na mesma janela, as duas MODAIS (só os botões respondem; ESC não fecha —
#  o dono pediu que o jogador só siga respondendo sim ou não):
#    1. PERGUNTA   "Deseja navegar?"  Sim / Não
#    2. TRIPULAÇÃO à esquerda cada aliado em 3D (arrastável); à direita seis vagas cinza
#                  com "+". Arrastar põe na vaga; arrastar a vaga de volta para a lista
#                  (ou para outra vaga) tira/troca. Zarpar / Cancelar.
#
#  Só desenha e coleta a resposta: a regra (mínimo 3) é da `Tripulacao`, e quem leva o
#  jogador à costa ou ao leme é o `comando.gd`, que escuta os três sinais.
# ============================================================================

## "Não" ou "Cancelar": o jogador desistiu de navegar.
signal recusou
## Zarpar com menos que `Tripulacao.MINIMO`: tripulação insuficiente.
signal insuficiente
## Zarpar com 3 a 6 aliados; `ids` são as chaves do progresso.
signal zarpou(ids: Array[String])

const LARGURA := 820.0
const LADO_DA_VITRINE := 112
const ID_DA_VITRINE := "tripulante"

var progressao: ProgressaoDoPersonagem
var biblioteca: BibliotecaDeModelos

var _pergunta: Control
var _montagem: Control
var _cartoes := {}                        # id → Cartao
var _vagas: Array[Vaga] = []
var _lugares: Array = ["", "", "", "", "", ""]   # id ou "" por vaga
var _lista: VBoxContainer
var _contador: Label
var _aviso: Label
var _zarpar: Button


func ligar(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> void:
	progressao = prog
	biblioteca = bib


func _ready() -> void:
	GuiMinecraft.aplicar(self)    # fonte, botões e painéis do Minecraft (12/11/2026); sem as texturas locais, não faz nada
	add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	custom_minimum_size = Vector2(LARGURA, 0)
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	raiz.add_child(EstiloDaHistoria.cabeca("NAVEGAÇÃO", [] as Array[String]))
	_pergunta = _montar_pergunta()
	_montagem = _montar_tripulacao()
	raiz.add_child(_pergunta)
	raiz.add_child(_montagem)
	_montagem.visible = false


# ------------------------------------------------------------------ páginas

func _montar_pergunta() -> Control:
	var margem := MarginContainer.new()
	margem.name = "Pergunta"
	for lado in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(lado, 40)
	margem.add_theme_constant_override("margin_top", 28)
	margem.add_theme_constant_override("margin_bottom", 28)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 20)
	margem.add_child(coluna)
	var texto := EstiloDaHistoria.rotulo("Deseja navegar?", EstiloDaHistoria.TEXTO, 22)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(texto)
	var dica := EstiloDaHistoria.rotulo("Você escolherá a tripulação antes de zarpar.", EstiloDaHistoria.TEXTO_2, 14)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(dica)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 16)
	var sim := EstiloDaHistoria.botao("Sim", responder_sim, true)
	sim.name = "Sim"
	var nao := EstiloDaHistoria.botao("Não", responder_nao)
	nao.name = "Nao"
	botoes.add_child(sim)
	botoes.add_child(nao)
	coluna.add_child(botoes)
	return margem


func _montar_tripulacao() -> Control:
	var margem := MarginContainer.new()
	margem.name = "Montagem"
	for lado in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(lado, 24)
	margem.add_theme_constant_override("margin_top", 12)
	margem.add_theme_constant_override("margin_bottom", 18)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)
	var titulos := HBoxContainer.new()
	titulos.add_child(_titulo("ALIADOS", 1.0))
	titulos.add_child(_titulo("TRIPULAÇÃO", 1.6))
	coluna.add_child(titulos)
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 18)
	coluna.add_child(corpo)

	# Esquerda: a lista rolável, que também é onde se solta uma vaga para tirar o aliado.
	var area := AreaDaLista.new()
	area.janela = self
	area.name = "AreaDaLista"
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.size_flags_stretch_ratio = 1.0
	area.custom_minimum_size = Vector2(280, 2 * (LADO_DA_VITRINE + 40) + 24)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = EstiloDaHistoria.FUNDO_LINHA
	fundo.set_corner_radius_all(6)
	area.add_theme_stylebox_override("panel", fundo)
	corpo.add_child(area)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.name = "Lista"
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 8)
	rolagem.add_child(_lista)

	# Direita: seis vagas, três por linha.
	var grade := GridContainer.new()
	grade.name = "Vagas"
	grade.columns = 3
	grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade.size_flags_stretch_ratio = 1.6
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	corpo.add_child(grade)
	for i in Tripulacao.MAXIMO:
		var vaga := Vaga.new()
		vaga.janela = self
		vaga.indice = i
		vaga.name = "Vaga_%d" % i
		vaga.custom_minimum_size = Vector2(LADO_DA_VITRINE + 16, LADO_DA_VITRINE + 40)
		grade.add_child(vaga)
		_vagas.append(vaga)

	_contador = EstiloDaHistoria.rotulo("", EstiloDaHistoria.DOURADO, 15)
	_contador.name = "Contador"
	coluna.add_child(_contador)
	_aviso = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 13)
	_aviso.name = "Aviso"
	coluna.add_child(_aviso)
	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_END
	rodape.add_theme_constant_override("separation", 12)
	var cancelar_b := EstiloDaHistoria.botao("Cancelar", cancelar)
	cancelar_b.name = "Cancelar"
	_zarpar = EstiloDaHistoria.botao("Zarpar", zarpar, true)
	_zarpar.name = "Zarpar"
	rodape.add_child(cancelar_b)
	rodape.add_child(_zarpar)
	coluna.add_child(rodape)
	return margem


func _titulo(texto: String, proporcao: float) -> Label:
	var l := EstiloDaHistoria.rotulo(texto, EstiloDaHistoria.TEXTO_2, 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = proporcao
	return l


# ------------------------------------------------------------------ uso

## Mostra a pergunta "Deseja navegar?".
func perguntar() -> void:
	_pergunta.visible = true
	_montagem.visible = false
	visible = true
	_centralizar()


func aberta() -> bool:
	return visible


func fechar() -> void:
	visible = false


func responder_nao() -> void:
	fechar()
	recusou.emit()


func responder_sim() -> void:
	_lugares = ["", "", "", "", "", ""]
	_pergunta.visible = false
	_montagem.visible = true
	_reconstruir_lista()
	_atualizar()
	_centralizar()
	_centralizar.call_deferred()


func cancelar() -> void:
	fechar()
	recusou.emit()


func zarpar() -> void:
	var ids := escolhidos()
	fechar()
	if ids.size() < Tripulacao.MINIMO:
		insuficiente.emit()
	else:
		zarpou.emit(ids)


## Os aliados nas vagas, na ordem das vagas.
func escolhidos() -> Array[String]:
	var saida: Array[String] = []
	for id in _lugares:
		if str(id) != "":
			saida.append(str(id))
	return saida


func em_uso(id: String) -> bool:
	return _lugares.has(id)


func vaga_de(id: String) -> int:
	return _lugares.find(id)


## Põe `id` na vaga `indice` (de onde estiver). Vaga ocupada troca com a de origem.
func colocar(indice: int, id: String) -> bool:
	if indice < 0 or indice >= _lugares.size() or not _cartoes.has(id):
		return false
	var origem := _lugares.find(id)
	var antigo := str(_lugares[indice])
	if origem == indice:
		return true
	if origem >= 0:
		_lugares[origem] = antigo     # vindo de outra vaga: o ocupante vai para a origem
	_lugares[indice] = id
	_atualizar()
	return true


## Tira o aliado da vaga (ele volta à lista).
func tirar(indice: int) -> void:
	if indice >= 0 and indice < _lugares.size():
		_lugares[indice] = ""
		_atualizar()


func _centralizar() -> void:
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


# ------------------------------------------------------------------ desenho

func _reconstruir_lista() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_cartoes.clear()
	for a in Tripulacao.disponiveis(progressao, biblioteca):
		var cartao := Cartao.new()
		cartao.janela = self
		cartao.id = str(a["id"])
		cartao.especie = str(a["especie"])
		cartao.nome_do_aliado = str(a["nome"])
		cartao.categoria = a["categoria"]
		cartao.name = "Aliado_" + cartao.id
		_lista.add_child(cartao)
		_cartoes[cartao.id] = cartao
		cartao.montar(biblioteca)


func _atualizar() -> void:
	for i in _vagas.size():
		_vagas[i].mostrar(str(_lugares[i]))
	for id in _cartoes:
		(_cartoes[id] as Cartao).modulate = Color(1, 1, 1, 0.35) if em_uso(str(id)) else Color.WHITE
	var n := escolhidos().size()
	_contador.text = "Tripulação %d / %d  ·  mínimo %d" % [n, Tripulacao.MAXIMO, Tripulacao.MINIMO]
	var total := _cartoes.size()
	_aviso.text = "" if total >= Tripulacao.MINIMO else \
		"Você só tem %d aliado(s): não há tripulação suficiente para zarpar." % total
	_zarpar.tooltip_text = "" if n >= Tripulacao.MINIMO else "Com menos de %d a tripulação é insuficiente." % Tripulacao.MINIMO


func nome_do_aliado(id: String) -> String:
	return (_cartoes[id] as Cartao).nome_do_aliado if _cartoes.has(id) else id


func especie_do_aliado(id: String) -> String:
	return (_cartoes[id] as Cartao).especie if _cartoes.has(id) else id


# ------------------------------------------------------------------ peças

## O modelo girando num SubViewport próprio (mundo separado, fundo transparente).
class Vitrine extends SubViewportContainer:
	var _pivo: Node3D

	func montar(especie: String, bib: BibliotecaDeModelos, lado: int) -> void:
		stretch = true
		custom_minimum_size = Vector2(lado, lado)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vp := SubViewport.new()
		vp.size = Vector2i(lado, lado)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.85, 0.9, 1.0)
		env.ambient_light_energy = 0.7
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var sol := DirectionalLight3D.new()
		sol.rotation_degrees = Vector3(-40, 35, 0)
		sol.light_energy = 1.1
		vp.add_child(sol)
		var camera := Camera3D.new()
		camera.fov = 38.0
		vp.add_child(camera)
		camera.position = Vector3(0, 0.62, 2.1)
		camera.look_at_from_position(camera.position, Vector3(0, 0.45, 0))
		_pivo = Node3D.new()
		vp.add_child(_pivo)
		var modelo := Tripulacao.modelo_de_vitrine(especie, bib)
		if modelo != null:
			_pivo.add_child(modelo)
		else:
			# Sem modelo (espécie removida): uma caixa neutra, para a vaga não ficar vazia.
			var m := MeshInstance3D.new()
			m.mesh = BoxMesh.new()
			(m.mesh as BoxMesh).size = Vector3(0.5, 0.5, 0.5)
			m.position.y = 0.3
			_pivo.add_child(m)

	func _process(delta: float) -> void:
		if _pivo != null and is_visible_in_tree():
			_pivo.rotate_y(delta * 0.9)


## Um aliado na lista da esquerda. Arrastar leva o id.
class Cartao extends PanelContainer:
	var janela: JanelaDaTripulacao
	var id := ""
	var especie := ""
	var nome_do_aliado := ""
	var categoria := Tripulacao.Categoria.TERRESTRE

	func montar(bib: BibliotecaDeModelos) -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.06, 0.16, 0.19, 0.95)
		st.border_color = Color(EstiloDaHistoria.DOURADO, 0.35)
		st.set_border_width_all(1)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(6)
		add_theme_stylebox_override("panel", st)
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 10)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(linha)
		var vitrine := Vitrine.new()
		vitrine.name = "Vitrine"
		linha.add_child(vitrine)
		vitrine.montar(especie, bib, JanelaDaTripulacao.LADO_DA_VITRINE - 20)
		var textos := VBoxContainer.new()
		textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
		textos.alignment = BoxContainer.ALIGNMENT_CENTER
		linha.add_child(textos)
		var n := EstiloDaHistoria.rotulo(nome_do_aliado, EstiloDaHistoria.TEXTO, 15)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		textos.add_child(n)
		var c := EstiloDaHistoria.rotulo(Tripulacao.NOMES_DA_CATEGORIA[categoria], EstiloDaHistoria.TEXTO_3, 12)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		textos.add_child(c)

	func _get_drag_data(_em: Vector2) -> Variant:
		if janela == null or janela.em_uso(id):
			return null
		var dica := EstiloDaHistoria.rotulo(nome_do_aliado, EstiloDaHistoria.DOURADO, 15)
		if get_viewport().gui_is_dragging():
			set_drag_preview(dica)
		else:
			dica.free()
		return {JanelaDaTripulacao.ID_DA_VITRINE: id}


## Uma das seis vagas: cinza com "+" até receber um aliado.
class Vaga extends PanelContainer:
	var janela: JanelaDaTripulacao
	var indice := 0
	var ocupante := ""
	var _conteudo: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mostrar("")

	func mostrar(id: String) -> void:
		ocupante = id
		if is_instance_valid(_conteudo):
			remove_child(_conteudo)
			_conteudo.queue_free()
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(6)
		st.set_border_width_all(1)
		if id.is_empty():
			st.bg_color = Color(0.36, 0.38, 0.40, 0.55)       # cinza
			st.border_color = Color(0.6, 0.62, 0.65, 0.5)
			var mais := EstiloDaHistoria.rotulo("+", Color(0.82, 0.84, 0.86), 44)
			mais.name = "Mais"
			mais.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mais.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mais.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_conteudo = mais
			mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			st.bg_color = Color(0.06, 0.16, 0.19, 0.95)
			st.border_color = Color(EstiloDaHistoria.DOURADO, 0.8)
			var caixa := VBoxContainer.new()
			caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var vitrine := Vitrine.new()
			vitrine.name = "Vitrine"
			caixa.add_child(vitrine)
			vitrine.montar(janela.especie_do_aliado(id), janela.biblioteca, JanelaDaTripulacao.LADO_DA_VITRINE)
			var nome := EstiloDaHistoria.rotulo(janela.nome_do_aliado(id), EstiloDaHistoria.TEXTO, 13)
			nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caixa.add_child(nome)
			_conteudo = caixa
			mouse_default_cursor_shape = Control.CURSOR_DRAG
		add_theme_stylebox_override("panel", st)
		add_child(_conteudo)

	func _get_drag_data(_em: Vector2) -> Variant:
		if ocupante.is_empty():
			return null
		if get_viewport().gui_is_dragging():
			set_drag_preview(EstiloDaHistoria.rotulo(janela.nome_do_aliado(ocupante), EstiloDaHistoria.DOURADO, 15))
		return {JanelaDaTripulacao.ID_DA_VITRINE: ocupante}

	func _can_drop_data(_em: Vector2, dados: Variant) -> bool:
		return dados is Dictionary and (dados as Dictionary).has(JanelaDaTripulacao.ID_DA_VITRINE)

	func _drop_data(_em: Vector2, dados: Variant) -> void:
		janela.colocar(indice, str((dados as Dictionary)[JanelaDaTripulacao.ID_DA_VITRINE]))


## A lista da esquerda aceita o aliado de uma vaga: soltar aqui o tira da tripulação.
class AreaDaLista extends PanelContainer:
	var janela: JanelaDaTripulacao

	func _can_drop_data(_em: Vector2, dados: Variant) -> bool:
		return dados is Dictionary and (dados as Dictionary).has(JanelaDaTripulacao.ID_DA_VITRINE) \
			and janela.em_uso(str((dados as Dictionary)[JanelaDaTripulacao.ID_DA_VITRINE]))

	func _drop_data(_em: Vector2, dados: Variant) -> void:
		var vaga := janela.vaga_de(str((dados as Dictionary)[JanelaDaTripulacao.ID_DA_VITRINE]))
		janela.tirar(vaga)
