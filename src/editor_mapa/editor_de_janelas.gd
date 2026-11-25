class_name EditorDeJanelas
extends Control
# ============================================================================
#  EDITOR DE JANELAS — o modo "Janelas" do editor de mapa (05/10/2026).
#
#  Pedido do dono: um botão ao lado de "Hitboxes" troca o editor do 3D para a edição
#  das janelas do jogo: na faixa da loja (onde ficavam os modelos 3D) a lista de
#  janelas; escolhida uma, ela se edita como num canvas. Decisões dele: muda
#  posição, tamanho, texto e aparência; janelas do Modo História; salvo no projeto.
#
#  • Meio: uma TELA do tamanho do jogo (1280×720) com a janela de verdade montada
#    com dados de exemplo (`CatalogoDeJanelas`), em escala. Clique escolhe o
#    elemento mais de dentro; arrastar move; as alças redimensionam.
#  • Direita: a árvore de elementos (para os pequenos ou escondidos) e as
#    propriedades (X, Y, largura, altura, texto, fonte, cor do texto, cor de fundo).
#  • Tudo vai para o `LayoutDeJanelas` (aplicado na hora) e "Salvar layout" grava o
#    arquivo do projeto, que o jogo lê ao montar cada janela.
#
#  Elemento dentro de lista (container): a lista decide a posição; arrastar não move
#  e o tamanho vira o tamanho MÍNIMO dele (avisado no painel).
# ============================================================================

signal aviso(texto: String, erro: bool)

const TELA := Vector2(1280, 720)
const ALCA := 8.0
## Faixas do editor de mapa (as mesmas da loja à esquerda e do painel à direita).
const ESQUERDA := 228.0
const DIREITA := 310.0
const TOPO := 56.0
const BASE := 34.0
const FUNDO_DA_TELA := Color(0.16, 0.22, 0.28)

var biblioteca: BibliotecaDeModelos
var janela_id := ""
var janela: Control = null
var selecionado: Control = null

var _lista: ItemList
var _arvore: Tree
var _campos := {}
var _rotulo_texto: Label
var _info: Label
var _aviso_lista: Label
var _moldura: Control
var _imagem: TextureRect
var _viewport: SubViewport
var _tela: Control
var _apoio: Node
var _sobre: Control
var _arraste := {}
var _pairando: Control = null
var _preenchendo := false
var _marcando := false


func _ready() -> void:
	name = "EditorDeJanelas"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_montar_lista()
	_montar_centro()
	_montar_painel()
	visible = false


# ------------------------------------------------------------------ abrir/fechar
func abrir() -> void:
	visible = true
	if janela_id.is_empty() and not CatalogoDeJanelas.ids().is_empty():
		escolher_janela(CatalogoDeJanelas.ids()[0])


func fechar() -> void:
	visible = false
	_arraste = {}


func ativo() -> bool:
	return visible


## Monta (ou remonta) a janela `id` na tela. Remontar a MESMA janela (restaurar)
## mantém o elemento escolhido; trocar de janela começa sem seleção.
func escolher_janela(id: String) -> void:
	var caminho_sel := caminho_selecionado() if id == janela_id and janela != null else ""
	janela_id = id
	_limpar_janela()
	janela = CatalogoDeJanelas.criar(id, _tela, _apoio, biblioteca)
	var i := CatalogoDeJanelas.ids().find(id)
	if i >= 0 and _lista.get_selected_items() != PackedInt32Array([i]):
		_lista.select(i)
	selecionado = null
	_montar_arvore()
	selecionar(LayoutDeJanelas.no_por_caminho(janela, caminho_sel) as Control if not caminho_sel.is_empty() else null)


func _limpar_janela() -> void:
	if janela != null and is_instance_valid(janela):
		janela.get_parent().remove_child(janela)
		janela.queue_free()
	janela = null
	for f in _apoio.get_children():
		_apoio.remove_child(f)
		f.queue_free()


func selecionar(no: Control) -> void:
	selecionado = no
	_preencher_campos()
	_marcar_na_arvore()
	_sobre.queue_redraw()


func caminho_selecionado() -> String:
	return LayoutDeJanelas.caminho_de(janela, selecionado) if janela != null and selecionado != null else ""


# ------------------------------------------------------------------ edição
## Muda um campo do elemento selecionado: grava no layout e aplica na hora.
func mudar(campo: String, valor: Variant) -> void:
	mudar_no(selecionado, campo, valor)


func mudar_no(no: Control, campo: String, valor: Variant) -> void:
	if no == null or janela == null:
		return
	var caminho := LayoutDeJanelas.caminho_de(janela, no)
	if caminho.is_empty():
		return
	LayoutDeJanelas.gravar(janela_id, caminho, campo, valor)
	LayoutDeJanelas.aplicar_no(no, {campo: LayoutDeJanelas.do_elemento(janela_id, caminho)[campo]})
	if not _preenchendo:
		_preencher_campos()
	_sobre.queue_redraw()


## Quem um arraste move: o próprio elemento, se ele é livre; senão o ancestral livre
## mais próximo (puxar a cabeça de uma janela move a janela).
func movel_de(no: Control) -> Control:
	var atual := no
	while atual != null and atual != janela and not movivel(atual):
		atual = atual.get_parent() as Control
	return atual if atual != null and movivel(atual) else null


## Volta o elemento selecionado ao original (remonta a janela sem o que mudou nele).
func restaurar() -> void:
	var caminho := caminho_selecionado()
	if caminho.is_empty():
		return
	LayoutDeJanelas.esquecer(janela_id, caminho)
	escolher_janela(janela_id)
	aviso.emit("Elemento restaurado: %s" % caminho, false)


func salvar() -> Error:
	var erro := LayoutDeJanelas.salvar()
	aviso.emit("Layout das janelas salvo (%s)" % LayoutDeJanelas.caminho() if erro == OK \
		else "Não foi possível salvar o layout: %s" % error_string(erro), erro != OK)
	return erro


func movivel(no: Control) -> bool:
	return no != null and not (no.get_parent() is Container)


# ------------------------------------------------------------------ canvas
func _escala() -> float:
	return _imagem.size.x / TELA.x if _imagem.size.x > 0.0 else 1.0


func para_tela(ponto: Vector2) -> Vector2:
	return ponto / _escala()


func _retangulo_no_canvas(no: Control) -> Rect2:
	var r := no.get_global_rect()
	return Rect2(r.position * _escala(), r.size * _escala())


## O elemento mais de dentro (e mais à frente) sob `ponto` (coordenadas da tela 1280×720).
func elemento_em(ponto: Vector2) -> Control:
	if janela == null:
		return null
	return _mais_fundo(janela, ponto)


func _mais_fundo(no: Control, ponto: Vector2) -> Control:
	if not no.is_visible_in_tree() or not no.get_global_rect().has_point(ponto):
		return null
	var filhos := no.get_children()
	for i in range(filhos.size() - 1, -1, -1):
		var f := filhos[i] as Control
		if f != null:
			var achou := _mais_fundo(f, ponto)
			if achou != null:
				return achou
	return no


func _alcas(r: Rect2) -> Array[Rect2]:
	var pts := [r.position, Vector2(r.get_center().x, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.get_center().y), r.end, Vector2(r.get_center().x, r.end.y),
		Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.get_center().y)]
	var saida: Array[Rect2] = []
	for p in pts:
		saida.append(Rect2(p - Vector2.ONE * ALCA * 0.5, Vector2.ONE * ALCA))
	return saida


func _canvas_input(evento: InputEvent) -> void:
	if janela == null:
		return
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var b := evento as InputEventMouseButton
		if b.pressed:
			_comecar_arraste(b.position)
		else:
			_terminar_arraste()
		accept_event()
	elif evento is InputEventMouseMotion:
		var m := evento as InputEventMouseMotion
		if not _arraste.is_empty():
			_seguir_arraste(m.position, m.shift_pressed)
		else:
			var sob := elemento_em(para_tela(m.position))
			if sob != _pairando:
				_pairando = sob
				_sobre.queue_redraw()
		accept_event()


## Alça do selecionado → redimensiona ELE. Senão o clique ESCOLHE o que está sob o
## cursor (o mais de dentro, para as propriedades) e o arraste move o livre mais
## próximo dele (`movel_de`).
func _comecar_arraste(ponto: Vector2) -> void:
	if selecionado != null:
		var alcas := _alcas(_retangulo_no_canvas(selecionado))
		for i in alcas.size():
			if alcas[i].grow(2).has_point(ponto):
				_arraste = {"modo": i, "no": selecionado, "inicio": ponto, "rect": Rect2(selecionado.position, selecionado.size)}
				return
	var achou := elemento_em(para_tela(ponto))
	if achou == null:
		return
	if achou != selecionado:
		selecionar(achou)
	var movel := movel_de(achou)
	if movel != null:
		_arraste = {"modo": -1, "no": movel, "inicio": ponto, "rect": Rect2(movel.position, movel.size)}


## Arrastar: -1 move; 0–7 são as alças (cantos e meios, sentido horário a partir do
## canto de cima à esquerda). Shift encaixa de 8 em 8 px.
func _seguir_arraste(ponto: Vector2, encaixe: bool) -> void:
	var d: Vector2 = (ponto - (_arraste["inicio"] as Vector2)) / _escala()
	var r: Rect2 = _arraste["rect"]
	var passo := 8.0 if encaixe else 1.0
	var novo := r
	match int(_arraste["modo"]):
		-1:
			novo.position = r.position + d
		0: novo = Rect2(r.position + d, r.size - d)
		1: novo = Rect2(r.position + Vector2(0, d.y), r.size - Vector2(0, d.y))
		2: novo = Rect2(r.position + Vector2(0, d.y), r.size + Vector2(d.x, -d.y))
		3: novo.size = r.size + Vector2(d.x, 0)
		4: novo.size = r.size + d
		5: novo.size = r.size + Vector2(0, d.y)
		6: novo = Rect2(r.position + Vector2(d.x, 0), r.size + Vector2(-d.x, d.y))
		7: novo = Rect2(r.position + Vector2(d.x, 0), r.size - Vector2(d.x, 0))
	novo.position = novo.position.snapped(Vector2.ONE * passo)
	novo.size = novo.size.snapped(Vector2.ONE * passo).max(Vector2(4, 4))
	var no: Control = _arraste["no"]
	if not is_instance_valid(no):
		return
	if movivel(no) and novo.position != no.position:
		mudar_no(no, "pos", novo.position)
	if int(_arraste["modo"]) >= 0 and novo.size != no.size:
		mudar_no(no, "tam", novo.size)


func _terminar_arraste() -> void:
	_arraste = {}
	_preencher_campos()


func _desenhar_selecao() -> void:
	if janela == null:
		return
	if _pairando != null and is_instance_valid(_pairando) and _pairando != selecionado:
		_sobre.draw_rect(_retangulo_no_canvas(_pairando), Color(EstiloDoEditor.DESTAQUE, 0.45), false, 1.0)
	if selecionado != null and is_instance_valid(selecionado):
		var r := _retangulo_no_canvas(selecionado)
		_sobre.draw_rect(r, EstiloDoEditor.DESTAQUE, false, 2.0)
		for a in _alcas(r):
			_sobre.draw_rect(a, Color.WHITE)
			_sobre.draw_rect(a, EstiloDoEditor.DESTAQUE, false, 1.0)


func _process(_delta: float) -> void:
	if visible:
		_sobre.queue_redraw()


# ------------------------------------------------------------------ montagem
func _montar_lista() -> void:
	var lado := PanelContainer.new()
	lado.name = "ListaDeJanelas"
	lado.add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	add_child(lado)
	lado.anchor_bottom = 1.0
	lado.offset_left = 8.0
	lado.offset_right = ESQUERDA
	lado.offset_top = TOPO
	lado.offset_bottom = -BASE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	lado.add_child(col)
	col.add_child(EstiloDoEditor.rotulo("JANELAS"))
	_lista = ItemList.new()
	_lista.name = "Janelas"
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	for j in CatalogoDeJanelas.JANELAS:
		_lista.add_item(str(j["nome"]))
	_lista.item_selected.connect(func(i: int): escolher_janela(CatalogoDeJanelas.ids()[i]))
	col.add_child(_lista)
	var salvar_b := EstiloDoEditor.botao("Salvar layout", "Ctrl+S — grava o layout das janelas no projeto")
	salvar_b.name = "SalvarLayout"
	salvar_b.pressed.connect(salvar)
	col.add_child(salvar_b)
	_aviso_lista = EstiloDoEditor.explicacao("Clique escolhe; arraste move; alças redimensionam; Shift encaixa de 8 em 8 px.")
	col.add_child(_aviso_lista)


func _montar_centro() -> void:
	_moldura = Control.new()
	_moldura.name = "Moldura"
	_moldura.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_moldura)
	_moldura.anchor_right = 1.0
	_moldura.anchor_bottom = 1.0
	_moldura.offset_left = ESQUERDA + 8.0
	_moldura.offset_right = -DIREITA - 16.0
	_moldura.offset_top = TOPO
	_moldura.offset_bottom = -BASE
	var fundo := ColorRect.new()
	fundo.color = Color(0.06, 0.07, 0.08)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_moldura.add_child(fundo)
	# A tela do jogo SEMPRE em 1280×720 (as janelas se ancoram nela como no jogo) e,
	# na moldura, só a IMAGEM dela reduzida. Um SubViewportContainer com `stretch`
	# redimensionava a própria tela para o tamanho da moldura: a janela aparecia em
	# tamanho real, cortada, e a seleção não batia com o desenho (foto de 05/10/2026).
	_viewport = SubViewport.new()
	_viewport.name = "TelaDoJogo"
	_viewport.size = Vector2i(TELA)
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true          # a janela não reage: quem edita é o canvas
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_imagem = TextureRect.new()
	_imagem.name = "Tela"
	_imagem.texture = _viewport.get_texture()
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_SCALE
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moldura.add_child(_imagem)
	_tela = Control.new()
	_tela.name = "Raiz"
	_tela.size = TELA
	_viewport.add_child(_tela)
	var chao := ColorRect.new()
	chao.name = "FundoDaTela"
	chao.color = FUNDO_DA_TELA
	chao.size = TELA
	chao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.add_child(chao)
	_apoio = Node.new()
	_apoio.name = "Apoio"
	_viewport.add_child(_apoio)
	_sobre = Control.new()
	_sobre.name = "Canvas"
	_sobre.mouse_filter = Control.MOUSE_FILTER_STOP
	_sobre.gui_input.connect(_canvas_input)
	_sobre.draw.connect(_desenhar_selecao)
	_moldura.add_child(_sobre)
	_moldura.resized.connect(_ajustar_tela)
	_ajustar_tela.call_deferred()


## A tela 16:9 cabe inteira no meio, centrada.
func _ajustar_tela() -> void:
	var area := _moldura.size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var k := minf(area.x / TELA.x, area.y / TELA.y)
	var tam := TELA * k
	var pos := (area - tam) * 0.5
	for c: Control in [_imagem, _sobre]:
		c.position = pos
		c.size = tam


func _montar_painel() -> void:
	var lado := VBoxContainer.new()
	lado.name = "PainelDaJanela"
	add_child(lado)
	lado.anchor_left = 1.0
	lado.anchor_right = 1.0
	lado.anchor_bottom = 1.0
	lado.offset_left = -DIREITA
	lado.offset_right = -8.0
	lado.offset_top = TOPO
	lado.offset_bottom = -BASE
	var caixa_arvore := PanelContainer.new()
	caixa_arvore.add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	caixa_arvore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lado.add_child(caixa_arvore)
	var col_a := VBoxContainer.new()
	caixa_arvore.add_child(col_a)
	col_a.add_child(EstiloDoEditor.rotulo("ELEMENTOS"))
	_arvore = Tree.new()
	_arvore.name = "Elementos"
	_arvore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arvore.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	_arvore.item_selected.connect(func():
		if _marcando:
			return
		var it := _arvore.get_selected()
		if it != null and janela != null:
			var no := LayoutDeJanelas.no_por_caminho(janela, str(it.get_metadata(0))) as Control
			if no != null and no != selecionado:
				selecionado = no
				_preencher_campos()
				_sobre.queue_redraw())
	col_a.add_child(_arvore)

	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.size_flags_stretch_ratio = 1.3
	lado.add_child(caixa)
	var rol := ScrollContainer.new()
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caixa.add_child(rol)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	rol.add_child(col)
	col.add_child(EstiloDoEditor.rotulo("PROPRIEDADES"))
	_info = EstiloDoEditor.explicacao("Escolha um elemento na tela ou na árvore.")
	_info.name = "Info"
	col.add_child(_info)
	var grade := GridContainer.new()
	grade.columns = 4
	col.add_child(grade)
	for par in [["x", "X"], ["y", "Y"], ["l", "Larg."], ["a", "Alt."]]:
		grade.add_child(EstiloDoEditor.rotulo(par[1], true))
		var sp := SpinBox.new()
		sp.name = "Campo_" + par[0]
		sp.min_value = -4000
		sp.max_value = 4000
		sp.step = 1
		sp.custom_minimum_size.x = 82
		sp.value_changed.connect(func(_v): _campo_geometria())
		grade.add_child(sp)
		_campos[par[0]] = sp
	_rotulo_texto = EstiloDoEditor.rotulo("Texto", true)
	col.add_child(_rotulo_texto)
	var texto := LineEdit.new()
	texto.name = "Campo_texto"
	texto.text_submitted.connect(func(t: String): mudar("texto", t))
	texto.focus_exited.connect(func(): if selecionado != null and "text" in selecionado and texto.text != str(selecionado.get("text")): mudar("texto", texto.text))
	col.add_child(texto)
	_campos["texto"] = texto
	var linha_fonte := HBoxContainer.new()
	col.add_child(linha_fonte)
	linha_fonte.add_child(EstiloDoEditor.rotulo("Fonte (px)", true))
	var fonte := SpinBox.new()
	fonte.name = "Campo_fonte"
	fonte.min_value = 6
	fonte.max_value = 96
	fonte.value_changed.connect(func(v: float): if not _preenchendo: mudar("fonte", int(v)))
	linha_fonte.add_child(fonte)
	_campos["fonte"] = fonte
	for par in [["cor_texto", "Cor do texto"], ["cor_fundo", "Cor de fundo"]]:
		var l := HBoxContainer.new()
		col.add_child(l)
		var r := EstiloDoEditor.rotulo(par[1], true)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(r)
		var cor := ColorPickerButton.new()
		cor.name = "Campo_" + par[0]
		cor.custom_minimum_size = Vector2(70, 24)
		var campo: String = par[0]
		cor.color_changed.connect(func(c: Color): if not _preenchendo: mudar(campo, c))
		l.add_child(cor)
		_campos[par[0]] = cor
	var restaurar_b := EstiloDoEditor.botao("Restaurar elemento", "Volta o elemento ao original (esquece o que mudou nele)")
	restaurar_b.name = "Restaurar"
	restaurar_b.pressed.connect(restaurar)
	col.add_child(restaurar_b)


func _campo_geometria() -> void:
	if _preenchendo or selecionado == null:
		return
	var pos := Vector2(_campos["x"].value, _campos["y"].value)
	var tam := Vector2(_campos["l"].value, _campos["a"].value)
	if movivel(selecionado) and pos != selecionado.position:
		mudar("pos", pos)
	if tam != selecionado.size:
		mudar("tam", tam)


func _preencher_campos() -> void:
	_preenchendo = true
	var tem := selecionado != null and is_instance_valid(selecionado)
	for k in _campos:
		(_campos[k] as Control).visible = tem
	(_campos["cor_fundo"] as Control).get_parent().visible = tem
	(_campos["cor_texto"] as Control).get_parent().visible = tem
	_rotulo_texto.visible = tem
	if not tem:
		_info.text = "Escolha um elemento na tela ou na árvore."
		_preenchendo = false
		return
	var em_lista := not movivel(selecionado)
	_info.text = "%s  ·  %s%s" % [caminho_selecionado(), selecionado.get_class(),
		"\nDentro de uma lista: a posição segue a lista; o tamanho vira o mínimo." if em_lista else ""]
	_campos["x"].value = selecionado.position.x
	_campos["y"].value = selecionado.position.y
	_campos["l"].value = selecionado.size.x
	_campos["a"].value = selecionado.size.y
	_campos["x"].editable = not em_lista
	_campos["y"].editable = not em_lista
	var tem_texto := "text" in selecionado
	_campos["texto"].visible = tem_texto
	_rotulo_texto.visible = tem_texto
	if tem_texto:
		_campos["texto"].text = str(selecionado.get("text"))
	_campos["fonte"].value = selecionado.get_theme_font_size("font_size")
	_campos["cor_texto"].color = selecionado.get_theme_color("font_color")
	var fundo := selecionado is Panel or selecionado is PanelContainer or selecionado is Button or selecionado is ColorRect
	_campos["cor_fundo"].visible = fundo
	_campos["cor_fundo"].get_parent().visible = fundo
	if fundo:
		var sb := selecionado.get_theme_stylebox("normal" if selecionado is Button else "panel")
		_campos["cor_fundo"].color = (selecionado as ColorRect).color if selecionado is ColorRect \
			else ((sb as StyleBoxFlat).bg_color if sb is StyleBoxFlat else Color.BLACK)
	_preenchendo = false


func _montar_arvore() -> void:
	_arvore.clear()
	if janela == null:
		return
	var raiz := _arvore.create_item()
	_item(raiz, janela)
	_marcar_na_arvore()


func _item(item: TreeItem, no: Control) -> void:
	item.set_text(0, "%s  (%s)" % [no.name if not String(no.name).begins_with("@") else "·", no.get_class()])
	item.set_metadata(0, LayoutDeJanelas.caminho_de(janela, no))
	for f in no.get_children():
		if f is Control:
			_item(_arvore.create_item(item), f as Control)


func _marcar_na_arvore() -> void:
	if _arvore == null or _arvore.get_root() == null:
		return
	var alvo := caminho_selecionado()
	_marcando = true
	_arvore.deselect_all()
	var it := _arvore.get_root()
	while it != null and not alvo.is_empty():
		if str(it.get_metadata(0)) == alvo:
			_arvore.set_selected(it, 0)
			_arvore.scroll_to_item(it)
			break
		it = it.get_next_in_tree()
	_marcando = false
