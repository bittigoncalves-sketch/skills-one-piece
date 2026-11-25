extends VBoxContainer
## Escolha atômica da forma/modelo; editor guarda a mudança no desfazer/refazer.
signal escolheu(valores: Dictionary)
const Estilo := preload("res://src/skills_builder/estilo_builder.gd")
var biblioteca: BibliotecaDeModelos
var atual := {}
var _busca: LineEdit
var _modelos: OptionButton


func montar() -> void:
	name = "SeletorTransformacao"
	add_child(Estilo.rotulo("Asset da transformação", 14))
	var linha := HBoxContainer.new()
	add_child(linha)
	for forma in ["Fumaça", "Luz"]:
		var b := Estilo.botao(forma, func(): escolheu.emit({"visual": forma, "modelo": ""}))
		b.name = forma
		b.toggle_mode = true
		b.set_pressed_no_signal(atual.get("visual", "Fumaça") == forma)
		linha.add_child(b)
	var nome := str(atual.get("modelo", "")) if atual.get("visual") == "Modelo da loja" else str(atual.get("visual", "Fumaça"))
	var escolhido := Estilo.rotulo("Selecionado: " + nome, 12, true)
	escolhido.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(escolhido)
	_busca = LineEdit.new()
	_busca.name = "BuscarAsset"
	_busca.placeholder_text = "Buscar modelo da loja"
	_busca.text_changed.connect(_listar.unbind(1))
	add_child(_busca)
	_modelos = OptionButton.new()
	_modelos.name = "ModelosTransformacao"
	_modelos.fit_to_longest_item = false
	_modelos.item_selected.connect(func(i):
		if i > 0: escolheu.emit({"visual": "Modelo da loja", "modelo": _modelos.get_item_metadata(i)}))
	add_child(_modelos)
	_listar()


func _listar() -> void:
	_modelos.clear()
	_modelos.add_item("Escolher modelo da loja…")
	if biblioteca == null: return
	var termo := _busca.text.to_lower().strip_edges()
	for id in biblioteca.ids():
		var nome := str(biblioteca.info(id).get("nome", id))
		if not termo.is_empty() and not termo in nome.to_lower() and not termo in id.to_lower(): continue
		_modelos.add_item(nome)
		_modelos.set_item_metadata(_modelos.item_count - 1, id)
		if atual.get("visual") == "Modelo da loja" and atual.get("modelo") == id:
			_modelos.select(_modelos.item_count - 1)
