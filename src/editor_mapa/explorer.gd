class_name ExplorerDoEditor
extends PanelContainer
# ============================================================================
#  EXPLORER — a lista do que existe no mapa: o Spawn e as peças, na ordem do
#  arquivo. Clicar seleciona; Ctrl/Shift+clique soma; clique duplo renomeia.
#
#  ⚠️ LAÇO DE SELEÇÃO. Selecionar na cena atualiza a lista, e selecionar na
#  lista avisa a cena. Sem a trava `_sincronizando`, marcar os itens por código
#  dispararia `multi_selected`, que pediria a mesma seleção de volta — e com
#  vários itens, uma seleção parcial no meio do caminho.
# ============================================================================

signal selecao_pedida(ids: Array[String])
signal renomear_pedido(antigo: String, novo: String)

const ICONE := {"caixa": "▣", "esfera": "●", "cilindro": "▮", "cunha": "◣", "modelo": "◆", "terreno": "▲", "area_animais": "✿"}

var _arvore: Tree
var _itens := {}                    # id -> TreeItem
var _abertos := {}                  # grupos que a pessoa expandiu (sobrevive à reconstrução)
var _sincronizando := false
var _emissao_pendente := false


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	var coluna := VBoxContainer.new()
	add_child(coluna)
	coluna.add_child(EstiloDoEditor.rotulo("Explorer"))
	_arvore = Tree.new()
	_arvore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arvore.hide_root = true
	_arvore.select_mode = Tree.SELECT_MULTI
	_arvore.columns = 2
	_arvore.set_column_expand(1, false)
	_arvore.set_column_custom_minimum_width(1, 84)
	_arvore.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	_arvore.multi_selected.connect(_ao_marcar)
	_arvore.item_activated.connect(func(): _arvore.edit_selected(true))
	_arvore.item_edited.connect(_ao_editar)
	_arvore.item_collapsed.connect(func(item: TreeItem):
		var id := String(item.get_metadata(0))
		if item.collapsed:
			_abertos.erase(id)
		else:
			_abertos[id] = true
	)
	coluna.add_child(_arvore)


func reconstruir(doc: DocumentoMapa, sel: SelecaoDoEditor) -> void:
	_sincronizando = true
	_arvore.clear()
	_itens.clear()
	var raiz := _arvore.create_item()
	_itens[SelecaoDoEditor.SPAWN] = _item(raiz, SelecaoDoEditor.SPAWN, "✚ Spawn", "jogador", false)
	_ramo(doc, raiz, "")
	_sincronizando = false
	mostrar_selecao(sel.ids())


## Um nível da hierarquia: grupos (recolhidos, salvo se a pessoa abriu) e peças.
func _ramo(doc: DocumentoMapa, pai: TreeItem, grupo_id: String) -> void:
	for id in doc.filhos_de(grupo_id):
		if doc.tem_grupo(id):
			var item := _item(pai, id, id, "▤ %d peças" % doc.pecas_de(id).size(), true)
			_itens[id] = item
			_ramo(doc, item, id)
			item.collapsed = not _abertos.has(id)
		else:
			var p := doc.peca(id)
			_itens[id] = _item(pai, id, id, "%s %s" % [ICONE.get(p["tipo"], "?"), p["tipo"]], true)


## Atualiza só o texto de tipo de uma peça (troca de forma no painel).
func atualizar_peca(doc: DocumentoMapa, id: String) -> void:
	if _itens.has(id) and doc.tem(id):
		var tipo: String = doc.peca(id)["tipo"]
		(_itens[id] as TreeItem).set_text(1, "%s %s" % [ICONE.get(tipo, "?"), tipo])


func mostrar_selecao(ids: Array[String]) -> void:
	_sincronizando = true
	var ultimo: TreeItem = null
	for id: String in _itens:
		var item := _itens[id] as TreeItem
		if ids.has(id):
			item.select(0)
			ultimo = item
			# Item escolhido por Alt+clique dentro de grupo recolhido: abre o caminho.
			var acima := item.get_parent()
			while acima != null and acima != _arvore.get_root():
				acima.collapsed = false
				acima = acima.get_parent()
		else:
			item.deselect(0)
	if ultimo:
		_arvore.scroll_to_item(ultimo)
	_sincronizando = false


func _item(raiz: TreeItem, id: String, texto: String, tipo: String, editavel: bool) -> TreeItem:
	var item := _arvore.create_item(raiz)
	item.set_text(0, texto)
	item.set_metadata(0, id)
	item.set_editable(0, editavel)
	item.set_text(1, tipo)
	item.set_custom_color(1, EstiloDoEditor.TEXTO_FRACO)
	item.set_selectable(1, false)
	return item


func _ao_marcar(_item_: TreeItem, _coluna: int, _marcado: bool) -> void:
	if _sincronizando or _emissao_pendente:
		return
	# Um clique com Shift marca vários itens, um sinal por item: junta tudo e
	# avisa uma vez só, no fim do quadro.
	_emissao_pendente = true
	_emitir_selecao.call_deferred()


func _emitir_selecao() -> void:
	_emissao_pendente = false
	var ids: Array[String] = []
	var item := _arvore.get_next_selected(null)
	while item != null:
		ids.append(String(item.get_metadata(0)))
		item = _arvore.get_next_selected(item)
	selecao_pedida.emit(ids)


func _ao_editar() -> void:
	var item := _arvore.get_edited()
	if item == null:
		return
	var antigo := String(item.get_metadata(0))
	var novo := item.get_text(0)
	# Volta o texto já; se o editor aceitar, a reconstrução põe o nome novo.
	item.set_text(0, antigo)
	renomear_pedido.emit(antigo, novo)
