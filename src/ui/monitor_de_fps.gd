extends CanvasLayer
## MONITOR DE FPS (18/10/2026, pedido do dono: "adicionar monitor de fps"). Canto superior
## direito, em todo modo (o `GameFlow` cria um só, na raiz, e ele atravessa a troca de cena).
## Quadros por segundo e tempo de quadro médio do último meio segundo; F3 liga/desliga.

const INTERVALO := 0.5

var _rotulo: Label
var _tempo := 0.0
var _quadros := 0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rotulo = Label.new()
	_rotulo.name = "Fps"
	_rotulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rotulo.offset_left = -170.0
	_rotulo.offset_right = -10.0
	_rotulo.offset_top = 4.0
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.add_theme_font_size_override("font_size", 13)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 4)
	add_child(_rotulo)


func _process(delta: float) -> void:
	_tempo += delta
	_quadros += 1
	if _tempo < INTERVALO:
		return
	var fps := _quadros / _tempo
	_rotulo.text = "%d FPS · %.1f ms" % [roundi(fps), 1000.0 * _tempo / _quadros]
	# Verde ≥ 55, amarelo ≥ 30, vermelho abaixo.
	_rotulo.add_theme_color_override("font_color", Color("#7be07b") if fps >= 55.0 else (Color("#f0d060") if fps >= 30.0 else Color("#ff6b5b")))
	_tempo = 0.0
	_quadros = 0


func _unhandled_key_input(evento: InputEvent) -> void:
	var k := evento as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()
