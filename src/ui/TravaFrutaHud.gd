class_name TravaFrutaHud
extends Control
## Trava pós-fruta: o quinto quadrado da faixa superior.
##
## Pedido do dono (2026-09-01): "um contador quadrado de 5 segundos como o
## contador da estrelinha/Aú na tela". Por isso ele é o MESMO desenho do
## `SpinKickHud` — mesmo tamanho, mesma faixa, mesma moldura —, e não um
## indicador com estilo próprio: dois relógios que fazem a mesma coisa (contar
## para baixo até liberar algo) devem se parecer, senão o jogador aprende dois
## vocabulários visuais para uma ideia só.
##
## ⚠️ MOSTRA "PODER", não o nome de uma skill. A trava não é de um slot — é dos
## quatro ao mesmo tempo, e o rótulo precisa dizer isso.

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
	estilo.bg_color = Color(0.07, 0.035, 0.045, 0.90)
	estilo.border_color = Color(1.0, 0.62, 0.35, 0.92)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	_bloco.add_theme_stylebox_override("panel", estilo)
	add_child(_bloco)

	var icone := Label.new()
	icone.text = "✶"
	icone.position = Vector2(0, 2)
	icone.size = Vector2(TAMANHO, 25)
	icone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icone.add_theme_font_size_override("font_size", 25)
	icone.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	_bloco.add_child(icone)

	_tempo = Label.new()
	_tempo.name = "Tempo"
	_tempo.position = Vector2(0, 27)
	_tempo.size = Vector2(TAMANHO, 20)
	_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tempo.add_theme_font_size_override("font_size", 17)
	_tempo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	_tempo.add_theme_color_override("font_outline_color", Color.BLACK)
	_tempo.add_theme_constant_override("outline_size", 4)
	_bloco.add_child(_tempo)

	var nome := Label.new()
	nome.text = "PODER"
	nome.position = Vector2(0, 49)
	nome.size = Vector2(TAMANHO, 12)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 10)
	nome.add_theme_color_override("font_color", Color(1.0, 0.85, 0.7))
	_bloco.add_child(nome)

	visible = false


func _process(_delta: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	var t := float(eu.get("_trava_pos_fruta")) if is_instance_valid(eu) else 0.0
	visible = t > 0.05
	if not visible:
		return
	# O quinto quadrado: um a mais à esquerda que a Aú, na mesma faixa.
	_bloco.position = Vector2(size.x - TAMANHO * 5.0 - MARGEM - ENTRE * 4.0, TOPO)
	_tempo.text = "%.1fs" % t
