class_name PainelDoPincel
extends PanelContainer
# ============================================================================
#  PAINEL DO PINCEL DE RELEVO — aparece embaixo, no centro, com a ferramenta
#  Relevo (Ctrl+5) ativa. Mexe direto no `PincelDeRelevo` do editor; o editor só
#  chama `atualizar()` quando o raio muda pelo teclado ([ e ]).
# ============================================================================

var pincel: PincelDeRelevo

var _modos: Array[Button] = []
var _solo: OptionButton
var _linha_solo: Control
var _raio: HSlider
var _forca: HSlider
var _valor_raio: Label
var _valor_forca: Label


func _init(p: PincelDeRelevo) -> void:
	pincel = p


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	# Duas linhas: numa só, com o seletor de solo, o painel passava da faixa livre
	# entre a loja e o painel lateral e a "Força" sumia atrás dele (captura 01/10).
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	add_child(coluna)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	coluna.add_child(linha)
	linha.add_child(EstiloDoEditor.rotulo("Relevo", false, 14))

	var grupo := ButtonGroup.new()
	var nomes := [
		[PincelDeRelevo.Modo.ELEVAR, "Elevar", "Clique ergue o chão; Shift+clique afunda"],
		[PincelDeRelevo.Modo.APLAINAR, "Aplainar", "Nivela na altura do ponto onde a pincelada começou"],
		[PincelDeRelevo.Modo.PINTAR, "Pintar solo", "Pinta o solo escolhido ao lado"],
	]
	for item in nomes:
		var b := EstiloDoEditor.botao(item[1], item[2])
		b.name = "Modo_%d" % item[0]
		b.toggle_mode = true
		b.button_group = grupo
		var m: int = item[0]
		b.pressed.connect(func():
			pincel.modo = m
			atualizar())
		linha.add_child(b)
		_modos.append(b)

	_linha_solo = HBoxContainer.new()
	linha.add_child(_linha_solo)
	_solo = OptionButton.new()
	_solo.focus_mode = Control.FOCUS_NONE
	for nome in TerrenoDoMapa.SOLOS:
		_solo.add_item("Automático" if nome == "auto" else nome.capitalize())
	_solo.item_selected.connect(func(i): pincel.solo = i)
	_linha_solo.add_child(_solo)

	var ajustes := HBoxContainer.new()
	ajustes.add_theme_constant_override("separation", 8)
	coluna.add_child(ajustes)
	linha = ajustes
	linha.add_child(EstiloDoEditor.rotulo("Raio [ ]", true))
	_raio = _slider(PincelDeRelevo.RAIO_MIN, PincelDeRelevo.RAIO_MAX, 0.5)
	_raio.value_changed.connect(func(v):
		pincel.raio = v
		_valor_raio.text = "%.1f m" % v)
	linha.add_child(_raio)
	_valor_raio = EstiloDoEditor.rotulo("", true)
	_valor_raio.custom_minimum_size = Vector2(48, 0)
	linha.add_child(_valor_raio)
	linha.add_child(EstiloDoEditor.rotulo("Força", true))
	_forca = _slider(0.05, 1.0, 0.05)
	_forca.value_changed.connect(func(v):
		pincel.forca = v
		_valor_forca.text = "%d %%" % roundi(v * 100.0))
	linha.add_child(_forca)
	_valor_forca = EstiloDoEditor.rotulo("", true)
	_valor_forca.custom_minimum_size = Vector2(40, 0)
	linha.add_child(_valor_forca)
	atualizar()


## Reescreve os controles a partir do pincel (sem disparar sinais).
func atualizar() -> void:
	if _raio == null:
		return
	for b in _modos:
		b.set_pressed_no_signal(b.name == "Modo_%d" % pincel.modo)
	_linha_solo.visible = pincel.modo == PincelDeRelevo.Modo.PINTAR
	_solo.select(pincel.solo)
	_raio.set_value_no_signal(pincel.raio)
	_forca.set_value_no_signal(pincel.forca)
	_valor_raio.text = "%.1f m" % pincel.raio
	_valor_forca.text = "%d %%" % roundi(pincel.forca * 100.0)
	reset_size()


func _slider(minimo: float, maximo: float, passo: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.custom_minimum_size = Vector2(110, 20)
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s
