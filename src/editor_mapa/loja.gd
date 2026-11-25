class_name LojaDoEditor
extends PanelContainer
# ============================================================================
#  LOJA — os modelos .glb importados, no lado esquerdo do editor (o equivalente à
#  Toolbox/Creator Store do Roblox Studio).
#
#    Importar arquivos / Importar pasta   copia para mapas/modelos/ (ImportadorDeModelos)
#    busca                                filtra pelo nome exibido
#    clique num modelo                    insere no centro da tela
#    arrastar um modelo                   o editor segue o mouse e solta no ponto do mapa
#    botão direito                        Renomear… / Apagar / Categorias ▸
#    Ctrl/Shift + clique                  seleciona vários SEM inserir (para marcar
#                                         categoria em lote)
#    seletor de categoria + ☰             filtra; cria, renomeia e apaga categoria
#
#  Categoria é ETIQUETA (várias por modelo) e só organiza — decisão do dono,
#  16/09/2026. Quem guarda é a `BibliotecaDeModelos`.
#
#  A loja NÃO mexe no mapa: ela pede (`inserir_pedido`, `arraste_pedido`) e o
#  `EditorDeMapa` decide onde e como, com desfazer. Apagar um modelo é operação de
#  ARQUIVO e não tem desfazer — por isso pergunta antes e diz quantas peças usam.
# ============================================================================

signal inserir_pedido(id: String)
signal arraste_pedido(id: String)
signal aviso(texto: String, erro: bool)
signal biblioteca_mudou

const LIMIAR_DE_ARRASTE_PX := 6.0
const MENU_RENOMEAR := 0
const MENU_APAGAR := 1
const MENU_ESCALAVEL := 2
const CAT_NOVA := 1000              # dentro do submenu "Categorias"
const GER_NOVA := 0
const GER_RENOMEAR := 1
const GER_APAGAR := 2
## Valores especiais do filtro (ids de categoria nunca têm "@").
const FILTRO_TODAS := "@todas"
const FILTRO_SEM := "@sem"

var biblioteca: BibliotecaDeModelos
var miniaturas: GeradorDeMiniaturas
## id do modelo -> quantas peças do mapa ABERTO usam (o editor fornece).
var contar_uso := Callable()

var _lista: ItemList
var _busca: LineEdit
var _dialogo_arquivos: FileDialog
var _dialogo_pasta: FileDialog
var _menu: PopupMenu
var _submenu_categorias: PopupMenu
var _filtro: OptionButton
var _gerenciar: MenuButton
var _filtro_atual := FILTRO_TODAS
var _alvos_do_menu: Array[String] = []
var _vazia: Label
var _pressionado: Dictionary = {}
var _alvo_do_menu := ""
var _importando := false


func configurar(bib: BibliotecaDeModelos, gerador: GeradorDeMiniaturas) -> void:
	biblioteca = bib
	miniaturas = gerador
	miniaturas.biblioteca = bib
	miniaturas.pronta.connect(_ao_ficar_pronta)
	atualizar_lista()


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	add_child(coluna)
	coluna.add_child(EstiloDoEditor.rotulo("Loja"))

	var botoes := HBoxContainer.new()
	coluna.add_child(botoes)
	var arquivos := EstiloDoEditor.botao("Importar arquivos", "Um ou vários .glb")
	arquivos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arquivos.pressed.connect(func(): _dialogo_arquivos.popup_centered_ratio(0.7))
	botoes.add_child(arquivos)
	var pasta := EstiloDoEditor.botao("Pasta", "Todos os .glb de uma pasta (sem subpastas)")
	pasta.pressed.connect(func(): _dialogo_pasta.popup_centered_ratio(0.7))
	botoes.add_child(pasta)

	_busca = EstiloDoEditor.campo()
	_busca.placeholder_text = "Buscar…"
	_busca.select_all_on_focus = false
	_busca.clear_button_enabled = true
	_busca.text_changed.connect(func(_t): atualizar_lista())
	coluna.add_child(_busca)

	var linha_cat := HBoxContainer.new()
	coluna.add_child(linha_cat)
	_filtro = OptionButton.new()
	_filtro.focus_mode = Control.FOCUS_NONE
	_filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filtro.clip_text = true
	_filtro.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	_filtro.item_selected.connect(func(i):
		_filtro_atual = str(_filtro.get_item_metadata(i))
		_atualizar_gerenciar()
		atualizar_lista()
	)
	linha_cat.add_child(_filtro)
	_gerenciar = MenuButton.new()
	_gerenciar.text = "☰"
	_gerenciar.tooltip_text = "Criar, renomear ou apagar categoria"
	_gerenciar.flat = false
	var pg := _gerenciar.get_popup()
	pg.add_item("Nova categoria…", GER_NOVA)
	pg.add_item("Renomear esta categoria…", GER_RENOMEAR)
	pg.add_item("Apagar esta categoria…", GER_APAGAR)
	pg.id_pressed.connect(_ao_gerenciar)
	linha_cat.add_child(_gerenciar)

	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.icon_mode = ItemList.ICON_MODE_TOP
	_lista.max_columns = 2
	_lista.same_column_width = true
	_lista.fixed_column_width = 92
	_lista.fixed_icon_size = Vector2i(84, 84)
	_lista.max_text_lines = 2
	_lista.select_mode = ItemList.SELECT_MULTI
	_lista.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lista.add_theme_font_size_override("font_size", 12)
	_lista.gui_input.connect(_ao_mexer_na_lista)
	coluna.add_child(_lista)

	_vazia = EstiloDoEditor.explicacao("Nenhum modelo ainda. Importe um .glb.")
	coluna.add_child(_vazia)

	_dialogo_arquivos = _novo_dialogo(FileDialog.FILE_MODE_OPEN_FILES, "Importar modelos .glb")
	_dialogo_arquivos.files_selected.connect(func(caminhos): importar(caminhos))
	_dialogo_pasta = _novo_dialogo(FileDialog.FILE_MODE_OPEN_DIR, "Importar todos os .glb de uma pasta")
	_dialogo_pasta.dir_selected.connect(importar_pasta)

	_menu = PopupMenu.new()
	_submenu_categorias = PopupMenu.new()
	_submenu_categorias.hide_on_checkable_item_selection = false
	_submenu_categorias.id_pressed.connect(_ao_marcar_categoria)
	_menu.add_submenu_node_item("Categorias", _submenu_categorias)
	# Escalada frontal (03/10/2026): marca quais modelos o jogador escala.
	_menu.add_check_item("Escalável", MENU_ESCALAVEL)
	_menu.add_separator()
	_menu.add_item("Renomear…", MENU_RENOMEAR)
	_menu.add_item("Apagar da loja", MENU_APAGAR)
	_menu.id_pressed.connect(_ao_escolher_no_menu)
	add_child(_menu)


func atualizar_lista() -> void:
	if _lista == null or biblioteca == null:
		return
	_atualizar_filtro()
	_lista.clear()
	var filtro := _busca.text.strip_edges().to_lower()
	for id in biblioteca.ids():
		var nome: String = biblioteca.info(id)["nome"]
		if not filtro.is_empty() and not nome.to_lower().contains(filtro) and not id.contains(filtro):
			continue
		var cats := biblioteca.categorias_do_modelo(id)
		if (_filtro_atual == FILTRO_SEM and not cats.is_empty()) \
				or (_filtro_atual != FILTRO_TODAS and _filtro_atual != FILTRO_SEM and not cats.has(_filtro_atual)):
			continue
		var i := _lista.add_item(nome, miniaturas.em_cache(id) if miniaturas else null)
		_lista.set_item_metadata(i, id)
		var nomes_cat := PackedStringArray()
		for c in cats:
			nomes_cat.append(biblioteca.nome_da_categoria(c))
		var padrao := biblioteca.tamanho_padrao(id)
		var dica := "%s\n%s triângulos · %s\nentra com %.1f × %.1f × %.1f m" % [nome, biblioteca.info(id)["triangulos"],
			", ".join(nomes_cat) if not nomes_cat.is_empty() else "sem categoria", padrao.x, padrao.y, padrao.z]
		var ficha := biblioteca.ficha_de_navio(id)
		if cats.has("montarias"):
			dica += "\nPet de montaria · Y monta/desmonta no modo história"
		if not ficha.is_empty():
			dica += "\nNavio: " + FichaDeNavio.resumo(ficha)
		_lista.set_item_tooltip(i, dica + "\nclique insere, arraste posiciona, Ctrl+clique seleciona")
		if miniaturas and miniaturas.em_cache(id) == null:
			miniaturas.pedir(id)
	_vazia.visible = biblioteca.ids().is_empty()


## Seleciona o filtro por valor (FILTRO_TODAS, FILTRO_SEM ou id de categoria).
func filtrar(valor: String) -> void:
	_filtro_atual = valor
	atualizar_lista()
	_atualizar_gerenciar()


func ids_selecionados() -> Array[String]:
	var ids: Array[String] = []
	for i in _lista.get_selected_items():
		ids.append(id_do_indice(i))
	return ids


func _atualizar_filtro() -> void:
	# O filtro some se a categoria escolhida foi apagada.
	if not (_filtro_atual in [FILTRO_TODAS, FILTRO_SEM]) and not biblioteca.tem_categoria(_filtro_atual):
		_filtro_atual = FILTRO_TODAS
	_filtro.clear()
	_filtro_item("Todas (%d)" % biblioteca.ids().size(), FILTRO_TODAS)
	_filtro_item("Sem categoria (%d)" % biblioteca.contar_na_categoria(""), FILTRO_SEM)
	for c in biblioteca.categorias():
		_filtro_item("%s (%d)" % [c["nome"], biblioteca.contar_na_categoria(c["id"])], c["id"])
	_atualizar_gerenciar()


func _filtro_item(texto: String, valor: String) -> void:
	_filtro.add_item(texto)
	var i := _filtro.item_count - 1
	_filtro.set_item_metadata(i, valor)
	if valor == _filtro_atual:
		_filtro.select(i)


func _atualizar_gerenciar() -> void:
	var real := not (_filtro_atual in [FILTRO_TODAS, FILTRO_SEM])
	var pg := _gerenciar.get_popup()
	pg.set_item_disabled(pg.get_item_index(GER_RENOMEAR), not real)
	pg.set_item_disabled(pg.get_item_index(GER_APAGAR), not real)


func id_do_indice(i: int) -> String:
	return String(_lista.get_item_metadata(i)) if i >= 0 and i < _lista.item_count else ""


func quantidade_visivel() -> int:
	return _lista.item_count


# ---------------------------------------------------------------- importar
## Importa um por quadro, dizendo o progresso; no fim, um resumo só.
func importar(caminhos: PackedStringArray) -> void:
	if _importando or caminhos.is_empty():
		return
	_importando = true
	var novos := 0
	var repetidos := 0
	var falhas: PackedStringArray = []
	for i in caminhos.size():
		aviso.emit("Importando %d/%d: %s…" % [i + 1, caminhos.size(), caminhos[i].get_file()], false)
		await get_tree().process_frame
		var r := ImportadorDeModelos.importar(biblioteca, caminhos[i])
		if not r["ok"]:
			falhas.append(r["erro"])
		elif r["repetido"]:
			repetidos += 1
		else:
			novos += 1
	_importando = false
	atualizar_lista()
	biblioteca_mudou.emit()
	var resumo := "%d modelo(s) importado(s)" % novos
	if repetidos > 0:
		resumo += ", %d já estavam na loja" % repetidos
	if not falhas.is_empty():
		resumo += ". Recusados: " + " | ".join(falhas)
	aviso.emit(resumo + ".", not falhas.is_empty())


func importar_pasta(pasta: String) -> void:
	var glbs := ImportadorDeModelos.glbs_da_pasta(pasta)
	if glbs.is_empty():
		aviso.emit("Nenhum .glb diretamente em %s (subpastas não entram)." % pasta, true)
		return
	importar(glbs)


func importando() -> bool:
	return _importando


# ------------------------------------------------------------ clique/arraste
func _ao_mexer_na_lista(evento: InputEvent) -> void:
	if evento is InputEventMouseButton:
		var b := evento as InputEventMouseButton
		var indice := _lista.get_item_at_position(b.position, true)
		# Com Ctrl/Shift o clique só SELECIONA (o ItemList cuida da seleção múltipla).
		var so_seleciona := b.ctrl_pressed or b.shift_pressed or b.meta_pressed
		if b.button_index == MOUSE_BUTTON_LEFT and b.pressed and indice >= 0 and not so_seleciona:
			_pressionado = {"id": id_do_indice(indice), "ponto": b.position}
		elif b.button_index == MOUSE_BUTTON_LEFT and not b.pressed and not _pressionado.is_empty():
			inserir_pedido.emit(_pressionado["id"])
			_pressionado = {}
		elif b.button_index == MOUSE_BUTTON_RIGHT and b.pressed and indice >= 0:
			_alvo_do_menu = id_do_indice(indice)
			# Botão direito num item FORA da seleção: vale só ele. Dentro: vale a seleção
			# inteira (é assim que se marca categoria em vários de uma vez).
			if not _lista.is_selected(indice):
				_lista.deselect_all()
				_lista.select(indice)
			_alvos_do_menu = ids_selecionados()
			_montar_submenu_categorias()
			var todos_escalam := _alvos_do_menu.all(func(mid: String) -> bool: return biblioteca.escalavel(mid))
			_menu.set_item_checked(_menu.get_item_index(MENU_ESCALAVEL), todos_escalam)
			var varios := _alvos_do_menu.size() > 1
			_menu.set_item_disabled(_menu.get_item_index(MENU_RENOMEAR), varios)
			_menu.set_item_disabled(_menu.get_item_index(MENU_APAGAR), varios)
			_menu.popup(Rect2i(Vector2i(b.global_position), Vector2i.ZERO))
	elif evento is InputEventMouseMotion and not _pressionado.is_empty():
		var m := evento as InputEventMouseMotion
		if m.position.distance_to(_pressionado["ponto"]) >= LIMIAR_DE_ARRASTE_PX:
			# A partir daqui o editor segue o mouse (mesmo fora da lista) e decide
			# onde soltar. A lista esquece o clique, senão soltar viraria "inserir".
			arraste_pedido.emit(_pressionado["id"])
			_pressionado = {}


# ------------------------------------------------------ renomear e apagar
func _ao_escolher_no_menu(opcao: int) -> void:
	if opcao == MENU_ESCALAVEL:
		var sim := not _menu.is_item_checked(_menu.get_item_index(MENU_ESCALAVEL))
		marcar_escalavel(_alvos_do_menu, sim)
		return
	if not biblioteca.tem(_alvo_do_menu):
		return
	var id := _alvo_do_menu
	match opcao:
		MENU_RENOMEAR:
			var dialogo := AcceptDialog.new()
			dialogo.title = "Renomear modelo"
			var campo := LineEdit.new()
			campo.text = biblioteca.info(id)["nome"]
			campo.select_all_on_focus = true
			dialogo.add_child(campo)
			dialogo.register_text_enter(campo)
			dialogo.confirmed.connect(func():
				var motivo := biblioteca.renomear(id, campo.text)
				aviso.emit(motivo if not motivo.is_empty() else "Modelo renomeado.", not motivo.is_empty())
				atualizar_lista()
			)
			dialogo.visibility_changed.connect(func():
				if not dialogo.visible:
					dialogo.queue_free()
			)
			add_child(dialogo)
			dialogo.popup_centered(Vector2i(320, 90))
			campo.grab_focus()
		MENU_APAGAR:
			var usos: int = contar_uso.call(id) if contar_uso.is_valid() else 0
			var dialogo := ConfirmationDialog.new()
			dialogo.title = "Apagar modelo"
			dialogo.dialog_text = "Apagar \"%s\" da loja? O arquivo copiado é removido e não há desfazer." % biblioteca.info(id)["nome"]
			if usos > 0:
				dialogo.dialog_text += "\n\n%d peça(s) deste mapa usam este modelo e vão virar marcador rosa." % usos
			dialogo.ok_button_text = "Apagar"
			dialogo.confirmed.connect(func(): apagar(id))
			dialogo.visibility_changed.connect(func():
				if not dialogo.visible:
					dialogo.queue_free()
			)
			add_child(dialogo)
			dialogo.popup_centered()


# ------------------------------------------------------------- categorias
func _montar_submenu_categorias() -> void:
	_submenu_categorias.clear()
	var cats := biblioteca.categorias()
	for i in cats.size():
		_submenu_categorias.add_check_item(str(cats[i]["nome"]), i)
		var todos := true
		var algum := false
		for mid in _alvos_do_menu:
			var tem := biblioteca.categorias_do_modelo(mid).has(cats[i]["id"])
			todos = todos and tem
			algum = algum or tem
		_submenu_categorias.set_item_checked(i, todos)
		if algum and not todos:
			_submenu_categorias.set_item_text(i, "%s (alguns)" % cats[i]["nome"])
	if not cats.is_empty():
		_submenu_categorias.add_separator()
	_submenu_categorias.add_item("Nova categoria…", CAT_NOVA)


func _ao_marcar_categoria(opcao: int) -> void:
	if opcao == CAT_NOVA:
		var alvos := _alvos_do_menu.duplicate()
		_pedir_texto("Nova categoria", "", func(nome: String):
			var r := biblioteca.criar_categoria(nome)
			if not r["ok"]:
				aviso.emit(r["erro"], true)
				return
			marcar(alvos, r["id"], true)
		)
		return
	var cats := biblioteca.categorias()
	if opcao < 0 or opcao >= cats.size():
		return
	var marcado := not _submenu_categorias.is_item_checked(_submenu_categorias.get_item_index(opcao))
	marcar(_alvos_do_menu, cats[opcao]["id"], marcado)
	_montar_submenu_categorias()


## Marca ou desmarca os modelos como escaláveis (o menu e o teste chamam aqui).
func marcar_escalavel(modelos: Array[String], sim: bool) -> void:
	var erro := biblioteca.definir_escalavel(modelos, sim)
	if erro != OK:
		aviso.emit("Falha ao gravar \"escalável\": %s" % error_string(erro), true)
	else:
		aviso.emit("%d modelo(s) %s." % [modelos.size(), "escaláveis" if sim else "não escaláveis"], false)


## Põe ou tira os modelos da categoria (o menu e o teste chamam aqui).
func marcar(modelos: Array[String], categoria: String, dentro: bool) -> void:
	var erro := biblioteca.marcar_categoria(modelos, categoria, dentro)
	atualizar_lista()
	var nome := biblioteca.nome_da_categoria(categoria)
	if erro != OK:
		aviso.emit("Falha ao gravar a categoria: %s" % error_string(erro), true)
	else:
		aviso.emit("%d modelo(s) %s \"%s\"." % [modelos.size(), "em" if dentro else "fora de", nome], false)


func _ao_gerenciar(opcao: int) -> void:
	match opcao:
		GER_NOVA:
			_pedir_texto("Nova categoria", "", func(nome: String):
				var r := biblioteca.criar_categoria(nome)
				aviso.emit("Categoria \"%s\" criada." % nome if r["ok"] else r["erro"], not r["ok"])
				if r["ok"]:
					filtrar(r["id"])
			)
		GER_RENOMEAR:
			var id := _filtro_atual
			_pedir_texto("Renomear categoria", biblioteca.nome_da_categoria(id), func(nome: String):
				var motivo := biblioteca.renomear_categoria(id, nome)
				aviso.emit(motivo if not motivo.is_empty() else "Categoria renomeada.", not motivo.is_empty())
				atualizar_lista()
			)
		GER_APAGAR:
			var id := _filtro_atual
			var dialogo := ConfirmationDialog.new()
			dialogo.title = "Apagar categoria"
			dialogo.dialog_text = "Apagar a categoria \"%s\"? Os %d modelo(s) dela continuam na loja, só perdem a etiqueta." \
				% [biblioteca.nome_da_categoria(id), biblioteca.contar_na_categoria(id)]
			dialogo.ok_button_text = "Apagar categoria"
			dialogo.confirmed.connect(func():
				biblioteca.apagar_categoria(id)
				filtrar(FILTRO_TODAS)
				aviso.emit("Categoria apagada.", false)
			)
			_abrir_dialogo(dialogo)


func _pedir_texto(titulo: String, inicial: String, ao_confirmar: Callable) -> void:
	var dialogo := AcceptDialog.new()
	dialogo.title = titulo
	var campo := LineEdit.new()
	campo.text = inicial
	campo.select_all_on_focus = true
	dialogo.add_child(campo)
	dialogo.register_text_enter(campo)
	dialogo.confirmed.connect(func(): ao_confirmar.call(campo.text))
	_abrir_dialogo(dialogo, Vector2i(320, 90))
	campo.grab_focus()


func _abrir_dialogo(dialogo: AcceptDialog, tamanho := Vector2i.ZERO) -> void:
	dialogo.visibility_changed.connect(func():
		if not dialogo.visible:
			dialogo.queue_free()
	)
	add_child(dialogo)
	dialogo.popup_centered(tamanho)


func apagar(id: String) -> void:
	var erro := biblioteca.remover(id)
	atualizar_lista()
	biblioteca_mudou.emit()
	aviso.emit("Modelo apagado da loja." if erro == OK else "Falha ao apagar: %s" % error_string(erro), erro != OK)


func _ao_ficar_pronta(id: String, textura: Texture2D) -> void:
	for i in _lista.item_count:
		if id_do_indice(i) == id:
			_lista.set_item_icon(i, textura)


func _novo_dialogo(modo: FileDialog.FileMode, titulo: String) -> FileDialog:
	var d := FileDialog.new()
	d.file_mode = modo
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.title = titulo
	d.filters = PackedStringArray(["*.glb ; Modelo glTF binário"])
	# A janela do sistema quando existe (portal no Linux); senão, a do Godot.
	d.use_native_dialog = true
	d.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	add_child(d)
	return d
