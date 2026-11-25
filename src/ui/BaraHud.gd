extends Control
## Somente apresentação do estado replicado; não decide reserva, custo ou dano.

const ACCENT := Color(0.96, 0.62, 0.83)
const MUTED := Color(0.75, 0.68, 0.79)
const WARNING := Color(1.0, 0.78, 0.49)
const READY := Color(0.80, 0.91, 0.73)
var _panel: PanelContainer
var _title: Label
var _clock: Label
var _right: Label
var _left: Label
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.025, 0.075, 0.93)
	style.border_color = Color(0.60, 0.32, 0.53, 0.8)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.set_corner_radius_all(5)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	_title = _label("BARA BARA", 13, ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_title)
	_clock = _label("", 12, MUTED)
	heading.add_child(_clock)
	var hands := HBoxContainer.new()
	hands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hands.add_theme_constant_override("separation", 18)
	column.add_child(hands)
	_right = _label("Direita: livre", 12, READY)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hands.add_child(_right)
	_left = _label("Esquerda: livre", 12, READY)
	hands.add_child(_left)
	_status = _label("Mãos prontas", 12, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	visible = false

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _local_player() -> Node3D:
	for actor in get_tree().get_nodes_in_group("player"):
		if actor is Node3D and actor.is_multiplayer_authority():
			return actor as Node3D
	return null

func _hand_label(label: Label, prefix: String, hands: Array, side: int) -> void:
	var state := "attached"
	if side < hands.size() and hands[side] is Dictionary:
		state = str(hands[side].get("state", "attached"))
	var text_value := "livre"
	var color := READY
	if state == "outbound" or state == "active":
		text_value = "em voo"
		color = ACCENT
	elif state == "returning":
		text_value = "retornando"
		color = WARNING
	elif state != "attached":
		text_value = "reservada"
		color = MUTED
	label.text = prefix + ": " + text_value
	label.add_theme_color_override("font_color", color)

func _process(delta: float) -> void:
	var actor := _local_player()
	visible = is_instance_valid(actor) and str(actor.get("current_fruit_id")) == "bara_bara" \
		and str(actor.get("combat_mode")) == "fruit"
	if not visible:
		modulate.a = 0.0
		return
	modulate.a = move_toward(modulate.a, 1.0, delta * 8.0)
	var width := minf(344.0, maxf(180.0, size.x - 24.0))
	_panel.size = Vector2(width, 0.0)
	# Barra de skills ocupa a direita. Em tela estreita, o painel sobe acima dela.
	var bottom_clearance := 116.0 if size.x >= 1050.0 else 260.0
	_panel.position = Vector2((size.x - width) * 0.5, maxf(180.0, size.y - bottom_clearance - _panel.size.y))
	var action := (actor.get_meta("bara_action") as Node) if actor.has_meta("bara_action") else null
	var active := is_instance_valid(action) and not action.is_queued_for_deletion()
	var hands: Array = []
	_title.text = "BARA BARA"
	_clock.text = ""
	_status.text = "Mãos prontas"
	_status.add_theme_color_override("font_color", MUTED)
	if active:
		var slot := str(action.get("slot"))
		var elapsed := float(action.get("elapsed"))
		var action_hands = action.get("hands")
		if action_hands is Array:
			hands = action_hands
		_title.text = "BARA BARA  /  " + slot
		_clock.text = "%.1f s" % elapsed
		_status.text = "Preparando a técnica" if elapsed < (0.24 if slot == "Z" else 0.38) else "Aguarde a recomposição"
		if slot == "C":
			if elapsed < 0.65:
				_status.text = "Canhão: preparando"
			elif action.get("_ball_active") == true:
				_status.text = "Canhão: disparo"
			else:
				_status.text = "Canhão: recuperação"
		if action.get("_cancelled") == true:
			_status.text = "Técnica interrompida · recompondo"
	_hand_label(_right, "Direita", hands, 1)
	_hand_label(_left, "Esquerda", hands, 0)
	var feedback := str(actor.get_meta("bara_feedback", ""))
	if feedback != "" and Time.get_ticks_msec() < int(actor.get_meta("bara_feedback_until", 0)):
		_status.text = feedback
		_status.add_theme_color_override("font_color", WARNING)
