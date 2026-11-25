extends CanvasLayer
## Entrada da campanha. A aparência só é persistida quando o jogador escolhe Jogar.
signal escolheu(tipo: String)
const Corpo := preload("res://src/player/corpo_historia.gd")
const Tons := preload("res://src/player/tons_de_pele.gd")
const Escolha := preload("res://src/ui/escolha_corpo_historia.gd")
var corpo := ""
var tom_de_pele := Tons.PADRAO
var aparencia: Dictionary = {}
var _conteudo: Control
var _previa: PreviaDoPersonagem
var _jogar: Button
var _customizar: Button
var _aviso: Label
var _resumo: Label
var _editor: CanvasLayer


func _ready() -> void:
	name = "EntradaHistoria"
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tom_de_pele = Tons.normalizar(tom_de_pele)
	_conteudo = Control.new()
	_conteudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_conteudo)
	var fundo := ColorRect.new()
	fundo.color = Color("101d27")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_conteudo.add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado: String in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 64)
	for lado: String in ["top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 48)
	_conteudo.add_child(margem)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 48)
	margem.add_child(linha)
	var esquerda := VBoxContainer.new()
	esquerda.name = "AcoesEsquerda"
	esquerda.custom_minimum_size.x = 320
	esquerda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	esquerda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	esquerda.size_flags_stretch_ratio = .85
	esquerda.add_theme_constant_override("separation", 20)
	linha.add_child(esquerda)
	var titulo := EstiloDaHistoria.rotulo("Modo História", EstiloDaHistoria.DOURADO, 30)
	esquerda.add_child(titulo)
	_aviso = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 17)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.custom_minimum_size.y = 58
	esquerda.add_child(_aviso)
	_jogar = _botao_colorido("Jogar", Color("42b966"), _ao_jogar)
	esquerda.add_child(_jogar)
	_customizar = _botao_colorido("Customizar", Color("df5656"), _abrir_customizacao)
	esquerda.add_child(_customizar)
	var voltar := EstiloDaHistoria.botao("Voltar ao menu", func(): escolheu.emit(""))
	voltar.name = "Voltar"
	voltar.focus_mode = Control.FOCUS_ALL
	voltar.custom_minimum_size.y = 42
	esquerda.add_child(voltar)
	var direita := VBoxContainer.new()
	direita.name = "PersonagemDireita"
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.size_flags_stretch_ratio = 1.15
	direita.add_theme_constant_override("separation", 16)
	linha.add_child(direita)
	_previa = PreviaDoPersonagem.new()
	_previa.name = "PreviaFrontal"
	_previa.corpo_historia = corpo if corpo in Corpo.TIPOS else "masculino"
	_previa.tom_de_pele = tom_de_pele
	_previa.aparencia_historia = aparencia.duplicate()
	_previa.permitir_giro = false
	_previa.mostrar_base = false
	_previa.custom_minimum_size = Vector2(300, 420)
	_previa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_previa.ready.connect(_iluminar_previa)
	direita.add_child(_previa)
	_resumo = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 17)
	_resumo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	direita.add_child(_resumo)
	_atualizar_textos()
	_jogar.grab_focus()


func _iluminar_previa() -> void:
	# Luz na frente (-Z): mantém rosto e tons escuros legíveis na vista frontal.
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-10, 180, 0)
	luz.light_energy = .9
	_previa.viewport.add_child(luz)


func _botao_colorido(texto: String, cor: Color, acao: Callable) -> Button:
	var botao := Button.new()
	botao.name = texto
	botao.text = texto
	botao.custom_minimum_size.y = 72
	botao.add_theme_font_size_override("font_size", 24)
	botao.pressed.connect(acao)
	for estado: String in ["normal", "hover", "pressed", "disabled"]:
		var tinta := cor.lightened(.18) if estado == "hover" else cor
		if estado == "pressed": tinta = cor.darkened(.15)
		if estado == "disabled": tinta = cor.darkened(.45)
		if GuiMinecraft.disponivel():
			# A normalização da GUI conserva StyleBoxTexture; o tom não vira cinza.
			var estilo := GuiMinecraft.botao(estado).duplicate() as StyleBoxTexture
			estilo.modulate_color = tinta
			botao.add_theme_stylebox_override(estado, estilo)
		else:
			var estilo := StyleBoxFlat.new()
			estilo.bg_color = tinta.darkened(.3)
			botao.add_theme_stylebox_override(estado, estilo)
	for estado: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		botao.add_theme_color_override(estado, Color.WHITE)
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.border_color = Color.WHITE
	foco.set_border_width_all(2)
	botao.add_theme_stylebox_override("focus", foco)
	return botao


func _atualizar_textos() -> void:
	var definido := corpo in Corpo.TIPOS
	_aviso.text = "Seu personagem está pronto para jogar." if definido else "Escolha sexo e tom de pele em Customizar."
	_resumo.text = "%s · %s" % [corpo.capitalize(), Tons.CATALOGO.data[tom_de_pele].nome] if definido else "Prévia do personagem"


func _ao_jogar() -> void:
	if _jogar.disabled: return
	if corpo not in Corpo.TIPOS:
		_abrir_customizacao()
		return
	_jogar.disabled = true
	_customizar.disabled = true
	escolheu.emit(corpo)


func _abrir_customizacao() -> void:
	if is_instance_valid(_editor): return
	_editor = Escolha.new()
	_editor.corpo_inicial = corpo
	_editor.tom_de_pele = tom_de_pele
	_editor.aparencia = aparencia.duplicate()
	_editor.texto_confirmar = "Concluir personalização"
	_editor.texto_voltar = "Cancelar"
	_editor.texto_aviso = "A aparência será salva ao escolher Jogar."
	_editor.escolheu.connect(_fechar_customizacao)
	add_child(_editor)
	_conteudo.hide()


func _fechar_customizacao(tipo: String) -> void:
	if tipo in Corpo.TIPOS:
		corpo = tipo
		tom_de_pele = _editor.tom_de_pele
		aparencia = _editor.aparencia.duplicate()
		_previa.corpo_historia = corpo
		_previa.tom_de_pele = tom_de_pele
		_previa.aparencia_historia = aparencia.duplicate()
		_previa.remontar()
		_atualizar_textos()
	_editor.queue_free()
	_editor = null
	_conteudo.show()
	_jogar.grab_focus()


func mostrar_erro() -> void:
	_aviso.text = "Não foi possível salvar. Tente Jogar novamente."
	_jogar.disabled = false
	_customizar.disabled = false
