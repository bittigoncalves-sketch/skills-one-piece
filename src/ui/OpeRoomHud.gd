extends Control
## Estado espacial do próprio jogador, separado dos cooldowns dos quatro slots.

const CYAN := Color(0.38, 0.94, 0.96)
const MUTED := Color(0.59, 0.73, 0.77)
const WARNING := Color(1.0, 0.76, 0.37)
var _panel: PanelContainer
var _title: Label
var _status: Label
var _time: Label
var _gauge: ProgressBar

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.045, 0.058, 0.92)
	style.border_color = Color(0.24, 0.69, 0.73, 0.60)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	_title = _label("OPE OPE  /  ROOM", 13, CYAN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_time = _label("18 m", 15, CYAN)
	row.add_child(_time)
	_gauge = ProgressBar.new()
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.custom_minimum_size.y = 3
	_gauge.show_percentage = false
	_gauge.max_value = 18.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.23, 0.26)
	_gauge.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	_gauge.add_theme_stylebox_override("fill", fill)
	column.add_child(_gauge)
	_status = _label("Z  •  Abra seu campo cirúrgico", 12, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	visible = false

func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _local_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D and node.is_multiplayer_authority():
			return node as Node3D
	return null

func _process(delta: float) -> void:
	var actor := _local_player()
	var show_panel := is_instance_valid(actor) and str(actor.get("current_fruit_id")) == "ope_ope" \
		and str(actor.get("combat_mode")) == "fruit"
	visible = show_panel
	if not show_panel:
		modulate.a = 0.0
		return
	modulate.a = move_toward(modulate.a, 1.0, delta * 7.0)
	var width := minf(338.0, size.x - 32.0)
	_panel.position = Vector2((size.x - width) * 0.5, 74.0)
	_panel.size.x = width
	var room := actor.get_meta("ope_room", null) as Node
	var active := is_instance_valid(room) and not room.is_queued_for_deletion()
	var inside := false
	var remaining := 0.0
	if active:
		remaining = float(room.get("remaining"))
		var center: Vector3 = room.get("center")
		inside = actor.global_position.distance_to(center) <= float(room.get("radius"))
		_time.text = "%.1f s" % remaining
		_title.text = "ROOM  /  %s" % ("EM OPERAÇÃO" if inside else "FORA DO CAMPO")
		_status.text = "X  Trocar   ·   C  Arremessar   ·   V  Perfurar" if inside else "Retorne ao ROOM para usar suas técnicas."
		_status.add_theme_color_override("font_color", MUTED if inside else WARNING)
	else:
		_time.text = "18 m"
		_title.text = "OPE OPE  /  ROOM"
		_status.text = "Z  •  Abra seu campo cirúrgico"
		_status.add_theme_color_override("font_color", MUTED)
	_gauge.value = remaining
	_gauge.modulate = WARNING if active and (remaining < 4.0 or not inside) else Color.WHITE
	if Time.get_ticks_msec() < int(actor.get_meta("ope_feedback_until", 0)):
		_status.text = str(actor.get_meta("ope_feedback", ""))
		_status.add_theme_color_override("font_color", WARNING)
