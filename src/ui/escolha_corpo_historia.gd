extends CanvasLayer
## Editor da campanha: rascunho isolado, prévia pelo mesmo construtor do PlayerRig.
signal escolheu(tipo: String)
const CorpoHistoria := preload("res://src/player/corpo_historia.gd")
const Tons := preload("res://src/player/tons_de_pele.gd")
const Catalogo := preload("res://src/player/aparencia_historia.gd")
var tom_de_pele := Tons.PADRAO
var aparencia: Dictionary = {}
var corpo_inicial := ""
var texto_confirmar := "Entrar no Modo História"
var texto_voltar := "Voltar ao menu"
var texto_aviso := "A escolha fica salva nesta campanha."
var _previa: PreviaDoPersonagem
var _tons: Dictionary = {}
var _opcoes: Dictionary = {}
var _nome_tom: Label
var _aviso: Label
var _entrar: Button
var _selecionado := ""
var _botoes: Dictionary = {}
var _abas: TabContainer
var _zoom_rosto := false
var _estado_estampa: Label


func _ready() -> void:
	name = "EscolhaCorpoHistoria"
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	tom_de_pele = Tons.normalizar(tom_de_pele)
	aparencia = Catalogo.normalizar(aparencia)
	_selecionado = corpo_inicial if corpo_inicial in CorpoHistoria.TIPOS else ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var fundo := ColorRect.new()
	fundo.color = Color("101d27")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado: String in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 32)
	add_child(margem)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 32)
	margem.add_child(linha)
	var esquerda := VBoxContainer.new()
	esquerda.custom_minimum_size.x = 500
	esquerda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esquerda.add_theme_constant_override("separation", 16)
	linha.add_child(esquerda)
	esquerda.add_child(EstiloDaHistoria.rotulo("Personalizar personagem", EstiloDaHistoria.DOURADO, 25))
	_abas = TabContainer.new()
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	esquerda.add_child(_abas)
	var corpo := _pagina("Corpo")
	corpo.add_child(EstiloDaHistoria.rotulo("Sexo", EstiloDaHistoria.TEXTO, 18))
	var sexos := HBoxContainer.new()
	corpo.add_child(sexos)
	var grupo := ButtonGroup.new()
	for tipo: String in CorpoHistoria.TIPOS:
		var botao := EstiloDaHistoria.botao(tipo.capitalize(), _selecionar.bind(tipo))
		botao.name = tipo.capitalize()
		botao.custom_minimum_size.y = 46
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.focus_mode = Control.FOCUS_ALL
		botao.toggle_mode = true
		botao.button_group = grupo
		botao.button_pressed = tipo == _selecionado
		sexos.add_child(botao)
		_botoes[tipo] = botao
	_nome_tom = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 18)
	corpo.add_child(_nome_tom)
	var faixa := HBoxContainer.new()
	faixa.add_theme_constant_override("separation", 10)
	corpo.add_child(faixa)
	var grupo_tons := ButtonGroup.new()
	for id: String in Tons.CATALOGO.data:
		var botao := Button.new()
		botao.name = "Tom_" + id
		botao.tooltip_text = Tons.CATALOGO.data[id].nome
		botao.custom_minimum_size = Vector2(56, 44)
		botao.toggle_mode = true
		botao.button_group = grupo_tons
		botao.button_pressed = id == tom_de_pele
		var borda := ColorRect.new()
		borda.name = "BordaTom"
		borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		botao.add_child(borda)
		borda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		borda.offset_left = 2
		borda.offset_top = 2
		borda.offset_right = -2
		borda.offset_bottom = -2
		var amostra := ColorRect.new()
		amostra.name = "Amostra"
		amostra.color = Color(Tons.CATALOGO.data[id].pele)
		amostra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		borda.add_child(amostra)
		amostra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		amostra.offset_left = 3
		amostra.offset_top = 3
		amostra.offset_right = -3
		amostra.offset_bottom = -3
		botao.pressed.connect(_selecionar_tom.bind(id))
		faixa.add_child(botao)
		_tons[id] = botao
	var porte := _pagina("Porte")
	_opcao(porte, "porte", "Tipo de corpo")
	var cabelo := _pagina("Cabelo")
	_opcao(cabelo, "cabelo", "Penteado")
	_opcao(cabelo, "cor_cabelo", "Cor do cabelo")
	var rosto := _pagina("Rosto")
	_opcao(rosto, "nariz", "Nariz")
	_opcao(rosto, "olhos", "Formato dos olhos")
	_opcao(rosto, "cor_olhos", "Cor dos olhos")
	_opcao(rosto, "sobrancelhas", "Sobrancelhas")
	_opcao(rosto, "oculos", "Óculos")
	var roupas := _pagina("Roupas")
	_opcao(roupas, "roupa", "Parte de cima")
	_opcao(roupas, "cor_roupa", "Cor da roupa")
	_opcao(roupas, "calca", "Calça")
	_opcao(roupas, "cor_calca", "Cor da calça (calça branca larga)")
	_opcao(roupas, "roupa_intima", "Roupa de baixo")
	_opcao(roupas, "sapatos", "Calçados")
	_montar_estampa(roupas)
	var acessorios := _pagina("Acessórios")      # importados do customizador antigo do menu principal (bloqueado)
	_opcao(acessorios, "acc_cabeca", "Cabeça")
	_opcao(acessorios, "acc_rosto", "Rosto")
	_opcao(acessorios, "acc_costas", "Costas")
	_opcao(acessorios, "acc_tronco", "Tronco")
	_opcao(acessorios, "acc_cintura", "Cintura")
	_opcao(acessorios, "acc_pescoco", "Pescoço")
	_opcao(acessorios, "acc_peruca", "Peruca colorida")
	_opcao(acessorios, "acc_tatuagem", "Tatuagem")
	_opcao(acessorios, "acc_ombro", "Ombro")
	_opcao(acessorios, "acc_orelhas", "Orelhas")
	_opcao(acessorios, "acc_bracos", "Braços")
	_opcao(acessorios, "acc_maos", "Mãos")
	_opcao(acessorios, "acc_item", "Item na mão")
	_opcao(acessorios, "acc_cauda", "Cauda")
	_opcao(acessorios, "acc_pernas", "Pernas")
	_opcao(acessorios, "acc_pes", "Pés")
	_aviso = EstiloDaHistoria.rotulo(texto_aviso, EstiloDaHistoria.TEXTO_2, 15)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	esquerda.add_child(_aviso)
	_entrar = EstiloDaHistoria.botao(texto_confirmar, _confirmar, true)
	_entrar.name = "Entrar"
	_entrar.custom_minimum_size.y = 48
	_entrar.focus_mode = Control.FOCUS_ALL
	_entrar.disabled = _selecionado.is_empty()
	esquerda.add_child(_entrar)
	var voltar := EstiloDaHistoria.botao(texto_voltar, func(): escolheu.emit(""))
	voltar.name = "Voltar"
	voltar.focus_mode = Control.FOCUS_ALL
	voltar.custom_minimum_size.y = 40
	esquerda.add_child(voltar)
	var direita := VBoxContainer.new()
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(direita)
	_previa = PreviaDoPersonagem.new()
	_previa.name = "PreviaPersonalizacao"
	_previa.corpo_historia = _selecionado if not _selecionado.is_empty() else "masculino"
	_previa.tom_de_pele = tom_de_pele
	_previa.aparencia_historia = aparencia.duplicate()
	_previa.mostrar_base = false
	_previa.custom_minimum_size = Vector2(320, 390)
	_previa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_previa.ready.connect(_iluminar)
	direita.add_child(_previa)
	var vistas := HBoxContainer.new()
	vistas.alignment = BoxContainer.ALIGNMENT_CENTER
	direita.add_child(vistas)
	for vista: String in ["Frente", "Perfil", "Costas"]:
		var botao := EstiloDaHistoria.botao(vista, _girar.bind(vista))
		botao.custom_minimum_size = Vector2(100, 38)
		botao.focus_mode = Control.FOCUS_ALL
		vistas.add_child(botao)
	var dica := EstiloDaHistoria.rotulo("Arraste o personagem para girar", EstiloDaHistoria.TEXTO_2, 14)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direita.add_child(dica)
	_abas.tab_changed.connect(_mudar_aba)
	_marcar_tom()
	(_botoes[_selecionado if not _selecionado.is_empty() else "masculino"] as Button).grab_focus()


func _pagina(titulo: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = titulo
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_abas.add_child(scroll)
	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado: String in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 16)
	scroll.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	margem.add_child(coluna)
	return coluna


func _opcao(pai: Control, chave: String, titulo: String) -> void:
	pai.add_child(EstiloDaHistoria.rotulo(titulo, EstiloDaHistoria.TEXTO, 17))
	var lista := OptionButton.new()
	lista.name = "Opcao_" + chave
	lista.custom_minimum_size.y = 42
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in Catalogo.OPCOES[chave]:
		lista.add_item(Catalogo.OPCOES[chave][id])
		lista.set_item_metadata(lista.item_count - 1, id)
		if aparencia[chave] == id: lista.select(lista.item_count - 1)
	lista.item_selected.connect(func(indice: int):
		aparencia[chave] = str(lista.get_item_metadata(indice))
		_atualizar_previa())
	pai.add_child(lista)
	_opcoes[chave] = lista


## ESTAMPA (19/11/2026): imagem do jogador sobre a roupa (dragão, serpente…). O arquivo é validado, reduzido e copiado por `EstampasHistoria`; a aparência guarda só o id.
func _montar_estampa(pai: Control) -> void:
	pai.add_child(EstiloDaHistoria.rotulo("Estampa na roupa", EstiloDaHistoria.TEXTO, 17))
	_estado_estampa = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 14)
	_estado_estampa.name = "EstadoEstampa"
	_estado_estampa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_opcao(pai, "estampa_local", "Onde fica a imagem")
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	pai.add_child(linha)
	var escolher := EstiloDaHistoria.botao("Escolher imagem…", _abrir_dialogo_de_estampa)
	escolher.name = "EscolherEstampa"
	escolher.custom_minimum_size.y = 42
	escolher.focus_mode = Control.FOCUS_ALL
	linha.add_child(escolher)
	var remover := EstiloDaHistoria.botao("Remover", func(): _definir_estampa(""))
	remover.name = "RemoverEstampa"
	remover.custom_minimum_size.y = 42
	remover.focus_mode = Control.FOCUS_ALL
	linha.add_child(remover)
	pai.add_child(_estado_estampa)
	_mostrar_estado_da_estampa()


func _abrir_dialogo_de_estampa() -> void:
	var d := FileDialog.new()
	d.name = "DialogoDeEstampa"
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.title = "Escolha a imagem da estampa"
	d.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imagens"])
	d.file_selected.connect(func(caminho: String):
		_importar_estampa(caminho)
		d.queue_free())
	d.canceled.connect(d.queue_free)
	add_child(d)
	d.popup_centered_ratio(0.7)


func _importar_estampa(caminho: String) -> void:
	var id := EstampasHistoria.importar(caminho)
	if id.is_empty():
		_estado_estampa.text = EstampasHistoria.ultimo_erro
		return
	_definir_estampa(id)


func _definir_estampa(id: String) -> void:
	aparencia["estampa"] = id if not id.is_empty() else "original"
	_mostrar_estado_da_estampa()
	_atualizar_previa()


func _mostrar_estado_da_estampa() -> void:
	var tem: bool = str(aparencia.get("estampa", "original")) != "original"
	_estado_estampa.text = "Imagem aplicada." if tem else "Nenhuma imagem. PNG, JPG ou WEBP de até 8 MB; fundo transparente (PNG) funciona melhor."


func _selecionar(tipo: String) -> void:
	_selecionado = tipo
	_entrar.disabled = false
	for id: String in _botoes:
		(_botoes[id] as Button).set_pressed_no_signal(id == tipo)
		EstiloDaHistoria.estilizar_botao(_botoes[id], id == tipo)
	_aviso.text = texto_aviso
	_atualizar_previa()


func _confirmar() -> void:
	if _selecionado in CorpoHistoria.TIPOS:
		_entrar.disabled = true
		escolheu.emit(_selecionado)


func _selecionar_tom(id: String) -> void:
	tom_de_pele = Tons.normalizar(id)
	_marcar_tom()
	_atualizar_previa()


func _marcar_tom() -> void:
	_nome_tom.text = "Tom de pele: " + str(Tons.CATALOGO.data[tom_de_pele].nome)
	for tom: String in _tons:
		(_tons[tom] as Button).set_pressed_no_signal(tom == tom_de_pele)
		(_tons[tom].get_node("BordaTom") as ColorRect).color = EstiloDaHistoria.DOURADO if tom == tom_de_pele else Color("596571")


func _atualizar_previa() -> void:
	_previa.corpo_historia = _selecionado if not _selecionado.is_empty() else "masculino"
	_previa.tom_de_pele = tom_de_pele
	_previa.aparencia_historia = aparencia.duplicate()
	_previa.remontar()
	_enquadrar()


func _mudar_aba(indice: int) -> void:
	_zoom_rosto = indice in [1, 2]
	_enquadrar()


func _girar(vista: String) -> void:
	_previa._giro = {"Frente": 0.0, "Perfil": PI * .5, "Costas": PI}[vista]
	_previa.modelo.rotation.y = _previa._giro


func _enquadrar() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_previa): return
	if _zoom_rosto:
		_previa.camera.position = Vector3(0, 1.70, -1.25)
		_previa.camera.look_at(Vector3(0, 1.70, 0))
	else:
		_previa.enquadrar()


func _iluminar() -> void:
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-10, 180, 0)
	luz.light_energy = .9
	_previa.viewport.add_child(luz)


func mostrar_erro() -> void:
	_aviso.text = "Não foi possível salvar. Tente novamente ou volte ao menu."
	_entrar.disabled = false
