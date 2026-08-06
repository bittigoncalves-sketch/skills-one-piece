class_name Inventory
extends Control
# Inventário em cinza e branco (grade 6×4). Abre/fecha via Hud (tecla I/TAB).

const C_BG    := Color(0.14, 0.15, 0.17)
const C_PANEL := Color(0.22, 0.23, 0.26)
const C_SLOT  := Color(0.30, 0.32, 0.36)
const C_WHITE := Color(0.95, 0.96, 0.98)

var _grid: GridContainer
var _items: Array = []
var _open := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()

func is_open() -> bool:
	return _open

func toggle() -> void:
	_open = not _open
	visible = _open
	Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if _open else Input.MOUSE_MODE_CAPTURED)

func add_item(item: Dictionary) -> void:
	_items.append(item)
	_redraw()

# -------------------------------------------------------------------- build ---
func _build() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(C_BG, C_WHITE, 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 420)
	add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 18)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var titulo := Label.new()
	titulo.text = "INVENTÁRIO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", C_WHITE)
	vb.add_child(titulo)

	var faixa := PanelContainer.new()
	faixa.add_theme_stylebox_override("panel", _box(C_PANEL, C_PANEL, 0))
	vb.add_child(faixa)

	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	var gm := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		gm.add_theme_constant_override(m, 10)
	gm.add_child(_grid)
	faixa.add_child(gm)

	var dica := Label.new()
	dica.text = "I / TAB para fechar"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	vb.add_child(dica)

	_redraw()

func _redraw() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	for i in 24:  # 6 x 4
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(72, 72)
		cell.add_theme_stylebox_override("panel", _box(C_SLOT, C_WHITE, 1))
		if i < _items.size():
			cell.add_child(_item_widget(_items[i]))
		_grid.add_child(cell)

func _item_widget(it: Dictionary) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var chip := ColorRect.new()
	chip.color = it.get("cor", C_WHITE)
	chip.custom_minimum_size = Vector2(28, 28)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(chip)
	var l := Label.new()
	l.text = str(it.get("nome", "")).split(" ")[0]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", C_WHITE)
	v.add_child(l)
	return v

func _box(bg: Color, borda: Color, largura: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	if largura > 0:
		sb.set_border_width_all(largura)
		sb.border_color = borda
	return sb
