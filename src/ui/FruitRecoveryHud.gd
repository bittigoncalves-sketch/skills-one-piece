class_name FruitRecoveryHud
extends Control
## Quadrado da recuperação pós-dano. Mostra somente enquanto bloqueia frutas;
## combate normal continua disponível, portanto não deve parecer um stun total.

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
	estilo.bg_color = Color(0.13, 0.03, 0.035, 0.90)
	estilo.border_color = Color(1.0, 0.30, 0.30, 0.95)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(8)
	_bloco.add_theme_stylebox_override("panel", estilo)
	_bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bloco)
	var icone := Label.new()
	icone.text = "🍎\n⊘"
	icone.position = Vector2(0, 0)
	icone.size = Vector2(TAMANHO, 29)
	icone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icone.add_theme_font_size_override("font_size", 16)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(icone)
	_tempo = Label.new()
	_tempo.name = "Tempo"
	_tempo.position = Vector2(0, 28)
	_tempo.size = Vector2(TAMANHO, 20)
	_tempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tempo.add_theme_font_size_override("font_size", 17)
	_tempo.add_theme_color_override("font_color", Color(1.0, 0.56, 0.50))
	_tempo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_tempo.add_theme_constant_override("outline_size", 4)
	_tempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(_tempo)
	var nome := Label.new()
	nome.text = "FRUTA"
	nome.position = Vector2(0, 49)
	nome.size = Vector2(TAMANHO, 12)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 9)
	nome.add_theme_color_override("font_color", Color(1.0, 0.56, 0.50))
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco.add_child(nome)
	visible = false

func _process(_delta: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	var restante := float(eu.get("_fruit_damage_lock_timer")) if is_instance_valid(eu) else 0.0
	visible = restante > 0.05
	if not visible:
		return
	# Terceiro quadrado da mesma faixa: queda | fruta | mordida, sem cobrir
	# os status que começam abaixo em 210 px.
	_bloco.position = Vector2(size.x - TAMANHO * 3.0 - MARGEM - ENTRE * 2.0, TOPO)
	_tempo.text = "%.1fs" % restante
	_bloco.modulate.a = 0.58 + 0.42 * absf(sin(Time.get_ticks_msec() * 0.016))
