class_name SpinKickHud
extends Control
## Recarga da aú: quarto quadrado da faixa superior, com ícone de giro.

const PlayerScript := preload("res://Player.gd")
const TAMANHO := 64.0
const MARGEM := 20.0
const TOPO := 138.0
const ENTRE := 8.0
var _bloco: Panel
var _tempo: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco = Panel.new()
	_bloco.name = "Bloco"
	_bloco.size = Vector2(TAMANHO, TAMANHO)
	var estilo := Estilo.painel()
	estilo.bg_color = Color(0.045, 0.045, 0.07, 0.90)
	estilo.border_color = Color(0.94, 0.94, 1.0, 0.92)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	_bloco.add_theme_stylebox_override("panel", estilo)
	add_child(_bloco)
	var icone := Label.new()
	icone.text = "↻"
	icone.position = Vector2(0, 2)
	icone.size = Vector2(TAMANHO, 25)
	icone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icone.add_theme_font_size_override("font_size", 25)
	icone.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
	_bloco.add_child(icone)
	_tempo = Label.new()
	_tempo.name = "Tempo"
	_tempo.position = Vector2(0, 27)
	_tempo.size = Vector2(TAMANHO, 20)
	_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tempo.add_theme_font_size_override("font_size", 17)
	_tempo.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
	_tempo.add_theme_color_override("font_outline_color", Color.BLACK)
	_tempo.add_theme_constant_override("outline_size", 4)
	_bloco.add_child(_tempo)
	var nome := Label.new()
	nome.text = "AÚ"
	nome.position = Vector2(0, 49)
	nome.size = Vector2(TAMANHO, 12)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 10)
	nome.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
	_bloco.add_child(nome)
	visible = false

func _process(_delta: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	var cd := float(eu.get("_spin_kick_cooldown")) if is_instance_valid(eu) else 0.0
	visible = cd > 0.05
	if not visible:
		return
	_bloco.position = Vector2(size.x - TAMANHO * 4.0 - MARGEM - ENTRE * 3.0, TOPO)
	_tempo.text = "%.1fs" % cd
