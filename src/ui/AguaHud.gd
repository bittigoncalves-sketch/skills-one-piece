class_name AguaHud
extends Control
# ============================================================================
#  ÁGUA NO HUD — fôlego e visão submersa (01/10/2026, docs/AGUA_PLANO.md).
#
#  Decisão do dono: fôlego de 30 s com a cabeça submersa; acabou, perde vida. A barra
#  (o mesmo `BarraHud` da vida, em azul-claro) só aparece embaixo d'água ou enquanto o
#  fôlego volta. Com a CÂMERA submersa, a tela ganha uma tinta azul — fica ATRÁS das
#  barras e janelas do HUD (primeiro filho da camada).
# ============================================================================

const COR_FOLEGO := Color(0.55, 0.85, 1.0)
const TINTA := Color(0.05, 0.28, 0.38, 0.24)

var na_agua: JogadorNaAgua = null
var _tinta: ColorRect
var _barra: BarraHud
var _rotulo: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tinta = ColorRect.new()
	_tinta.name = "VisaoSubmersa"
	_tinta.color = TINTA
	_tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tinta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tinta.visible = false
	add_child(_tinta)
	_barra = BarraHud.new()
	_barra.name = "Folego"
	_barra.cor = COR_FOLEGO
	_barra.custom_minimum_size = Vector2(220, 14)
	_barra.size = Vector2(220, 14)
	_barra.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_barra.position = Vector2(-110, -150)
	_barra.visible = false
	add_child(_barra)
	_rotulo = Label.new()
	_rotulo.text = "FÔLEGO"
	_rotulo.add_theme_font_size_override("font_size", 13)
	_rotulo.add_theme_color_override("font_color", COR_FOLEGO)
	_rotulo.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_rotulo.position = Vector2(-110, -172)
	_rotulo.visible = false
	add_child(_rotulo)


func _process(_delta: float) -> void:
	# ⚠️ Filho direto de CanvasLayer: as âncoras de tela inteira não dimensionam (ficava
	# 0×0 e a tinta não aparecia — captura de 01/10/2026). Ocupa a tela pelo tamanho dela.
	var tela := get_viewport_rect().size
	if size != tela:
		position = Vector2.ZERO
		size = tela
		_tinta.size = tela
		_barra.position = Vector2(tela.x * 0.5 - 110.0, tela.y - 150.0)
		_rotulo.position = Vector2(tela.x * 0.5 - 110.0, tela.y - 172.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var p := cam.global_position
		var nivel := AguaDoMundo.nivel_em(p.x, p.z)
		# Com a visão submersa do mar (névoa, cáusticas — 14/10/2026) a tinta chapada sai.
		_tinta.visible = not is_nan(nivel) and p.y < nivel and get_tree().get_first_node_in_group("visao_submersa") == null
	if na_agua == null or not is_instance_valid(na_agua):
		return
	var fracao := na_agua.folego / JogadorNaAgua.FOLEGO_MAXIMO
	var mostrar := na_agua.cabeca_submersa or fracao < 0.999
	_rotulo.text = "FÔLEGO ∞ · SHARKMAN" if na_agua.respiracao_infinita() else "FÔLEGO"
	_barra.visible = mostrar
	_rotulo.visible = mostrar
	_barra.valor(fracao)
