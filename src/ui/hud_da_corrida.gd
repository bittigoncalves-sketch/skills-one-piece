extends CanvasLayer
# ============================================================================
#  HUD DA CORRIDA DE CARANGUEJOS (06/10/2026).
#
#  No alto: relógio contra o limite (5:00), posição, portão e o nome do trecho. No meio:
#  a contagem 3-2-1-JÁ e o aviso de queda. No fim: o painel do resultado (posição,
#  tempo, prêmio e a classificação). Só desenha: quem manda é a `CorridaDeCaranguejos`.
#  Mesmo visual do Modo História (`EstiloDaHistoria`).
# ============================================================================

const E := preload("res://src/ui/estilo_da_historia.gd")
const VERDE := Color(0.35, 0.86, 0.55)
const VERMELHO := Color(0.95, 0.36, 0.3)

var _topo: PanelContainer
var _relogio: Label
var _posicao: Label
var _portao: Label
var _trecho: Label
var _centro: Label
var _resultado: PanelContainer
var _centro_ate := 0.0
var _agora := 0.0


func _ready() -> void:
	layer = 6
	name = "HudDaCorrida"
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)

	_topo = PanelContainer.new()
	_topo.add_theme_stylebox_override("panel", E.painel())
	# Canto superior DIREITO, crescendo para a esquerda: o alto à esquerda tem as barras de
	# vida e energia, e o meio tem os avisos da HUD da história (o painel no meio cobria
	# o aviso — foto de 06/10).
	_topo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_topo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_topo.offset_right = -18
	_topo.offset_top = 18
	raiz.add_child(_topo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 26)
	_topo.add_child(linha)
	_relogio = _bloco(linha, "TEMPO", "0:00.0")
	_posicao = _bloco(linha, "POSIÇÃO", "—")
	_portao = _bloco(linha, "PORTÃO", "—")
	_trecho = _bloco(linha, "TRECHO", "Largada")
	_trecho.custom_minimum_size.x = 230

	_centro = E.rotulo("", E.DOURADO, 96)
	_centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centro.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_centro.add_theme_constant_override("outline_size", 14)
	_centro.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_centro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_centro.grow_vertical = Control.GROW_DIRECTION_BOTH
	raiz.add_child(_centro)

	_resultado = PanelContainer.new()
	_resultado.add_theme_stylebox_override("panel", E.painel())
	_resultado.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_resultado.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_resultado.grow_vertical = Control.GROW_DIRECTION_BOTH
	_resultado.visible = false
	raiz.add_child(_resultado)
	visible = false


func _bloco(pai: Control, titulo: String, valor: String) -> Label:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	pai.add_child(col)
	col.add_child(E.rotulo(titulo, E.TEXTO_3, 13))
	var v := E.rotulo(valor, E.TEXTO, 28)
	col.add_child(v)
	return v


func _process(delta: float) -> void:
	_agora += delta
	if _centro.visible and _centro_ate > 0.0 and _agora >= _centro_ate:
		_centro.visible = false


static func relogio(s: float) -> String:
	s = maxf(s, 0.0)
	return "%d:%04.1f" % [int(s / 60.0), fmod(s, 60.0)]


## Uma vez por quadro durante a corrida.
func atualizar(tempo: float, limite: float, posicao: int, total: int, portao: int, portoes: int, trecho: String) -> void:
	visible = true
	_relogio.text = "%s / %s" % [relogio(tempo), relogio(limite)]
	var falta := limite - tempo
	_relogio.add_theme_color_override("font_color", VERMELHO if falta < 30.0 else E.TEXTO)
	_posicao.text = "%dº / %d" % [posicao, total]
	_posicao.add_theme_color_override("font_color", E.DOURADO if posicao == 1 else E.TEXTO)
	_portao.text = "%d / %d" % [portao, portoes]
	_trecho.text = trecho


## Texto grande no meio por `segundos` (0 = até o próximo).
func centro(texto: String, cor := E.DOURADO, segundos := 0.0) -> void:
	_centro.text = texto
	_centro.add_theme_color_override("font_color", cor)
	_centro.visible = not texto.is_empty()
	_centro_ate = _agora + segundos if segundos > 0.0 else 0.0


func resultado(r: Dictionary) -> void:
	for f in _resultado.get_children():
		f.queue_free()
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	_resultado.add_child(margem)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(460, 0)
	margem.add_child(col)
	var titulo := "CHEGADA!" if bool(r.completou) else "TEMPO ESGOTADO"
	col.add_child(E.rotulo(titulo, E.DOURADO if bool(r.completou) else VERMELHO, 34))
	if bool(r.completou):
		col.add_child(E.rotulo("%dº lugar  ·  %s" % [int(r.posicao), relogio(float(r.tempo))], E.TEXTO, 24))
	col.add_child(E.rotulo("Prêmio: %d moedas" % int(r.premio) if int(r.premio) > 0 else "Sem prêmio — complete a volta em até %s" % relogio(float(r.limite)),
		VERDE if int(r.premio) > 0 else E.TEXTO_2, 20))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	col.add_child(lista)
	var i := 1
	for c: Dictionary in r.classificacao:
		var t := relogio(float(c.tempo)) if float(c.tempo) >= 0.0 else "—"
		var l := E.rotulo("%d.  %s   %s" % [i, str(c.nome), t], E.DOURADO if bool(c.jogador) else E.TEXTO_2, 17)
		lista.add_child(l)
		i += 1
	col.add_child(E.rotulo("Voltando para a ilha…", E.TEXTO_3, 14))
	_resultado.visible = true
	visible = true


func esconder() -> void:
	_resultado.visible = false
	_centro.visible = false
	visible = false
