class_name HudDoDuelo
extends CanvasLayer
# ============================================================================
#  HUD DO DUELO COM A ALVIDA (22/11/2026) — layout do plano do Codex (`art_src/references/missao_alvida/PLANO.md`): topo esquerdo = jogador + 7 CORAÇÕES (e o número), topo direito = Alvida + 7 corações,
#  centro = a revelação da rodada (as duas jogadas e o que aconteceu, sem cobrir os lutadores), base = três botões grandes Pedra / Papel / Tesoura (teclas 1 2 3 ou clique).
#  `bloquear(true)` apaga os botões e ignora teclas: é o que impede escolher duas vezes e jogar no meio das animações. Só desenha e avisa (`escolheu(jogada)`); as regras são do `DueloPpt`.
# ============================================================================
signal escolheu(jogada: int)

const COR_CHEIO := Color(0.92, 0.18, 0.24)
const COR_VAZIO := Color(0.22, 0.10, 0.12)
const COR_FUNDO := Color(0.03, 0.04, 0.07, 0.86)
const DOURADO := Color(0.95, 0.79, 0.40)
const TECLAS := [KEY_1, KEY_2, KEY_3]
const SIMBOLOS := ["Pedra", "Papel", "Tesoura"]

var vidas_do_jogador := DueloPpt.VIDAS
var vidas_da_alvida := DueloPpt.VIDAS
var bloqueado := true
var _botoes: Array[Button] = []
var _centro: Label
var _titulo: Label
var _mouse_antes := Input.MOUSE_MODE_VISIBLE
var _barras: Dictionary = {}        # "jogador"/"alvida" → Control (corações)
var _numeros: Dictionary = {}       # → Label


func _ready() -> void:
	name = "HudDoDuelo"
	layer = 90
	var raiz := Control.new()
	raiz.name = "Raiz"
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	raiz.add_child(_placa("jogador", "Você", false))
	raiz.add_child(_placa("alvida", "Alvida", true))
	_titulo = _rotulo(22, DOURADO)
	_titulo.name = "Titulo"
	_titulo.text = "Pedra, papel e tesoura  ·  7 acertos vencem"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_titulo.position.y = 18.0
	raiz.add_child(_titulo)
	_centro = _rotulo(34, Color(0.98, 0.96, 0.9))
	_centro.name = "Revelacao"
	_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_centro.anchor_top = 0.2
	_centro.anchor_bottom = 0.2
	_centro.offset_top = 0.0
	_centro.add_theme_constant_override("outline_size", 10)
	_centro.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	raiz.add_child(_centro)
	var base := HBoxContainer.new()
	base.name = "Botoes"
	base.alignment = BoxContainer.ALIGNMENT_CENTER
	base.add_theme_constant_override("separation", 24)
	base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	base.offset_top = -150.0
	base.offset_bottom = -34.0
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(base)
	for i in 3:
		var b := Button.new()
		b.name = SIMBOLOS[i]
		b.text = "%s\n[%d]" % [SIMBOLOS[i], i + 1]
		b.custom_minimum_size = Vector2(190, 104)
		b.add_theme_font_size_override("font_size", 26)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_escolher.bind(i))
		base.add_child(b)
		_botoes.append(b)
	_mouse_antes = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	atualizar_vidas(vidas_do_jogador, vidas_da_alvida)
	bloquear(true)


func _exit_tree() -> void:
	Input.mouse_mode = _mouse_antes


func _placa(quem: String, nome: String, direita: bool) -> Control:
	var p := PanelContainer.new()
	p.name = "Placa_" + quem
	var est := StyleBoxFlat.new()
	est.bg_color = COR_FUNDO
	est.border_color = DOURADO
	est.set_border_width_all(2)
	est.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", est)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if direita:
		p.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 18)
	p.position.y = 54.0
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(topo)
	var n := _rotulo(22, Color.WHITE)
	n.text = nome
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(n)
	var num := _rotulo(22, COR_CHEIO)
	num.name = "Numero"
	topo.add_child(num)
	_numeros[quem] = num
	var cora := Control.new()
	cora.name = "Coracoes"
	cora.custom_minimum_size = Vector2(DueloPpt.VIDAS * 34.0, 32.0)
	cora.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cora.draw.connect(_desenhar_coracoes.bind(cora, quem))
	col.add_child(cora)
	_barras[quem] = cora
	return p


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Coração em pixel-art 7×6 (cada célula 4 px).
const MASCARA := ["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]


func _desenhar_coracoes(c: Control, quem: String) -> void:
	var vidas := vidas_do_jogador if quem == "jogador" else vidas_da_alvida
	for k in DueloPpt.VIDAS:
		var cor := COR_CHEIO if k < vidas else COR_VAZIO
		var x0 := k * 34.0 + 1.0
		for y in MASCARA.size():
			for x in 7:
				if MASCARA[y][x] == "1":
					c.draw_rect(Rect2(x0 + x * 4.0, 2.0 + y * 4.0, 4.0, 4.0), cor)


func atualizar_vidas(do_jogador: int, da_alvida: int) -> void:
	vidas_do_jogador = do_jogador
	vidas_da_alvida = da_alvida
	for q in _barras:
		(_barras[q] as Control).queue_redraw()
	if _numeros.has("jogador"):
		(_numeros["jogador"] as Label).text = "%d/%d" % [do_jogador, DueloPpt.VIDAS]
		(_numeros["alvida"] as Label).text = "%d/%d" % [da_alvida, DueloPpt.VIDAS]


func bloquear(sim: bool) -> void:
	bloqueado = sim
	for b in _botoes:
		b.disabled = sim
	if not sim and not _botoes.is_empty():
		_botoes[0].grab_focus()


func mostrar_texto(t: String) -> void:
	if _centro != null:
		_centro.text = t


func texto_da_revelacao(r: Dictionary) -> String:
	var j := "%s  ×  %s" % [DueloPpt.NOMES[int(r["jogador"])], DueloPpt.NOMES[int(r["alvida"])]]
	match str(r["evento"]):
		DueloPpt.EMPATE: return j + "\nEmpate — você desvia do golpe!"
		DueloPpt.ACERTO_DO_JOGADOR: return j + "\nVocê acerta a Alvida!"
		_: return j + "\nA Alvida acerta você!"


func _input(e: InputEvent) -> void:
	if bloqueado or not (e is InputEventKey) or not (e as InputEventKey).pressed or (e as InputEventKey).echo:
		return
	var i := TECLAS.find((e as InputEventKey).keycode)
	if i >= 0:
		get_viewport().set_input_as_handled()             # a hotbar também ouve 1–9
		_escolher(i)


func _escolher(i: int) -> void:
	if bloqueado:
		return
	bloquear(true)
	escolheu.emit(i)
