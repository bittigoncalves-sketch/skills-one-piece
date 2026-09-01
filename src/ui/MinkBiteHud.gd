class_name MinkBiteHud
extends Control
## Indicador compacto da investida Mink. Só aparece enquanto a técnica estiver
## em recarga: pronto não ocupa espaço, mas a penalidade fica sempre visível.

const PlayerScript := preload("res://Player.gd")
const TAMANHO := 64.0
const MARGEM := 20.0
const TOPO := 138.0 # entre o placar e os efeitos de status (que começam em 210)

var _bloco: Panel
var _tempo: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco = Panel.new()
	_bloco.name = "Bloco"
	_bloco.size = Vector2(TAMANHO, TAMANHO)
	_bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := Estilo.painel()
	estilo.bg_color = Color(0.12, 0.075, 0.04, 0.88)
	estilo.border_color = Color(1.0, 0.54, 0.18, 0.9)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	_bloco.add_theme_stylebox_override("panel", estilo)
	add_child(_bloco)

	var simbolo := Label.new()
	simbolo.text = "🦷"
	simbolo.position = Vector2(0, 2)
	simbolo.size = Vector2(TAMANHO, 25)
	simbolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	simbolo.add_theme_font_size_override("font_size", 19)
	simbolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(simbolo)

	_tempo = Label.new()
	_tempo.name = "Tempo"
	_tempo.position = Vector2(0, 25)
	_tempo.size = Vector2(TAMANHO, 25)
	_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tempo.add_theme_font_size_override("font_size", 17)
	_tempo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.46))
	_tempo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_tempo.add_theme_constant_override("outline_size", 4)
	_tempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(_tempo)

	var nome := Label.new()
	nome.text = "MORDIDA"
	nome.position = Vector2(-10, 48)
	nome.size = Vector2(TAMANHO + 20, 13)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 9)
	nome.add_theme_color_override("font_color", Color(1.0, 0.76, 0.42))
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(nome)
	visible = false

func _process(_delta: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	if not is_instance_valid(eu):
		visible = false
		return
	var cd := float(eu.get("_mink_bite_cooldown"))
	visible = cd > 0.05
	if not visible:
		return
	_bloco.position = Vector2(size.x - TAMANHO - MARGEM, TOPO)
	_tempo.text = "%.1fs" % cd
	# O último segundo pulsa para deixar claro que a mordida volta já.
	_bloco.modulate.a = 0.62 + 0.38 * absf(sin(Time.get_ticks_msec() * 0.012)) if cd < 1.0 else 1.0
