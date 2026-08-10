class_name StatsHud
extends Control
# HUD de status do jogador: barra de VIDA (verde, máx 2048), barra de ENERGIA (azul,
# máx 4096), indicador da assistência de mira (E) e contador de DANO total causado.
# Lê vida/energia direto do player a cada frame (sem fio manual).

# As barras mostram o corpo DESTE peer. `get_first_node_in_group("player")` devolve
# o primeiro da árvore — no cliente, o corpo do HOST (que nunca regenera energia
# aqui). Ver Player.local_player().
const PlayerScript := preload("res://Player.gd")

const BAR_W := 340.0
const BAR_H := 28.0

var _hp_fill: ColorRect
var _hp_label: Label
var _en_fill: ColorRect
var _en_label: Label
var _assist_label: Label
var _dmg_label: Label
var _room_label: Label
var _anim_label: Label
var _total_damage: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var x := 20.0
	var y := 20.0
	_add_bar_bg(x, y)
	_hp_fill = _add_fill(x, y, Color(0.22, 0.86, 0.34))     # verde
	_hp_label = _add_bar_label(x, y)

	y += BAR_H + 10.0
	_add_bar_bg(x, y)
	_en_fill = _add_fill(x, y, Color(0.28, 0.56, 1.0))      # azul
	_en_label = _add_bar_label(x, y)

	y += BAR_H + 16.0
	_dmg_label = _add_text(x, y, 22, Color(1.0, 0.85, 0.4))
	_dmg_label.text = "DANO TOTAL: 0"
	y += 32.0
	_assist_label = _add_text(x, y, 20, Color(0.8, 0.5, 0.5))
	set_aim_assist(false)

	# ID da sala (topo-centro) — só aparece quando você é o HOST e a tecla M é pressionada/menu aberto.
	_room_label = Label.new()
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 24)
	_room_label.add_theme_color_override("font_color", Color(0.25, 0.55, 1.0))
	_room_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_room_label.add_theme_constant_override("outline_size", 5)
	_room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_label.visible = false
	add_child(_room_label)

	# Nome da animação de teste (rodapé-centro) — some sozinho.
	_anim_label = Label.new()
	_anim_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_anim_label.position.y = -60
	_anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anim_label.add_theme_font_size_override("font_size", 26)
	_anim_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_anim_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_anim_label.add_theme_constant_override("outline_size", 6)
	_anim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_label.visible = false
	add_child(_anim_label)

func show_anim_name(text: String) -> void:
	if _anim_label == null:
		return
	_anim_label.text = "🎬 " + text
	_anim_label.visible = true
	_anim_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_anim_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _anim_label.visible = false)
	_room_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_room_label.offset_left = 0
	_room_label.offset_right = 0
	_room_label.offset_top = 16
	_room_label.offset_bottom = 50

func _process(_dt: float) -> void:
	if _room_label:
		var host: bool = GameFlow.mode == GameFlow.Mode.HOST and str(GameFlow.room_id) != ""
		var m_active: bool = (get_parent() and get_parent().has_method("is_char_menu_open") and get_parent().is_char_menu_open()) or Input.is_physical_key_pressed(KEY_M)
		var show_room: bool = host and m_active
		_room_label.visible = show_room
		if show_room:
			_room_label.text = "SALA: %s   —   compartilhe este ID" % GameFlow.room_id
	var p := PlayerScript.local_player(get_tree())
	if p == null:
		return
	_set_bar(_hp_fill, _hp_label, p.get("health"), p.get("max_health"), "VIDA")
	_set_bar(_en_fill, _en_label, p.get("energy"), p.get("max_energy"), "ENERGIA")

func _set_bar(fill: ColorRect, label: Label, val, mx, nome: String) -> void:
	if val == null or mx == null:
		return
	var r: float = clampf(float(val) / maxf(float(mx), 1.0), 0.0, 1.0)
	fill.size.x = (BAR_W - 4.0) * r
	label.text = "%s  %d / %d" % [nome, int(round(float(val))), int(round(float(mx)))]

func set_aim_assist(on: bool) -> void:
	if _assist_label == null:
		return
	_assist_label.text = "MIRA ASSISTIDA (E): " + ("LIGADA" if on else "DESLIGADA")
	_assist_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if on else Color(0.8, 0.5, 0.5))

func add_damage_dealt(amount: float) -> void:
	_total_damage += amount
	if _dmg_label:
		_dmg_label.text = "DANO TOTAL: %d" % int(round(_total_damage))

func on_player_damaged(_amount: float, _hp: float, _mhp: float) -> void:
	pass   # a barra já atualiza sozinha no _process

# ---- construtores de widget ----
func _add_bar_bg(x: float, y: float) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = Vector2(x - 2, y - 2)
	bg.size = Vector2(BAR_W, BAR_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _add_fill(x: float, y: float, col: Color) -> ColorRect:
	var f := ColorRect.new()
	f.color = col
	f.position = Vector2(x, y)
	f.size = Vector2(BAR_W - 4.0, BAR_H - 4.0)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	return f

func _add_bar_label(x: float, y: float) -> Label:
	return _add_text(x + 10.0, y + 3.0, 16, Color(1, 1, 1))

func _add_text(x: float, y: float, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
