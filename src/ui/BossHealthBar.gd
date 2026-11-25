class_name BossHealthBar
extends CanvasLayer
## Observa o estado replicado; não simula vida nem concede recompensa.
var _panel: VBoxContainer
var _name: Label
var _bar: ProgressBar
var _hint: Label

func _ready() -> void:
	layer = 6
	var anchor := Control.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_panel = VBoxContainer.new()
	anchor.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -180
	_panel.offset_right = 180
	_panel.offset_top = 158
	_panel.offset_bottom = 220
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_name)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(360, 14)
	_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.18, 0.22)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", background)
	_bar.add_theme_stylebox_override("fill", fill)
	_name.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name.add_theme_constant_override("shadow_offset_x", 1)
	_name.add_theme_constant_override("shadow_offset_y", 1)
	_panel.add_child(_bar)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_hint)

func _process(_delta: float) -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	_panel.visible = boss != null
	if boss == null:
		return
	_name.text = boss.definition.display_name
	_bar.max_value = boss.definition.max_health
	_bar.value = boss.health
	_hint.text = "Derrotado" if boss.dead else "Aproxime-se para desafiar"
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority() and not boss.dead:
			var distance: float = player.global_position.distance_to(boss.global_position)
			_hint.text = "Aproxime-se · %d m" % int(distance) if distance > boss.definition.aggro_range else "O Boxeador"
			break
