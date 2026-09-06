class_name CharacterMenu
extends PanelContainer
# Menu de PERSONAGENS CENTRALIZADO na tela (mesmo estilo da barra de técnicas:
# painel glassmorphism cinza/branco). Abre/fecha com a tecla M.
# Lista os personagens; clicar troca o modelo do jogador.

# O menu troca o modelo / estilo do corpo DESTE peer — ver Player.local_player().
const PlayerScript := preload("res://Player.gd")

# ELENCO TRANCADO NO BASE (decisão do usuário). O trabalho de animação está
# concentrado nele; os demais voltam descomentando as linhas abaixo.
const CHARS := [
	{"id": "base", "nome": "Base (voxel)"},
	{"id": "bluebuddy", "nome": "Blue Buddy (skinnado)"},
]

# Fora de uso enquanto o elenco está trancado — mantidos para não perder os ids.
const CHARS_TRANCADOS := [
	{"id": "ace",        "nome": "Ace"},         # skinnado (Meshy)
	{"id": "nami",       "nome": "Nami"},        # skinnado (Meshy)
	{"id": "blackbeard", "nome": "Barba Negra"}, # skinnado (Meshy)
	{"id": "crocodile",  "nome": "Crocodile"},   # skinnado (Meshy)
	{"id": "buggy",      "nome": "Buggy (voxel)"},
]

const STYLES := [
	{"id": "karate_tritao", "nome": "Karatê Tritão"},
	{"id": "pacifista",     "nome": "Pacifista"},
	{"id": "mink",          "nome": "Mink (Electro)"},
	{"id": "boxe",          "nome": "Boxe"},
	{"id": "cyborg",        "nome": "Cyborg (Franky)"},
	{"id": "teste_animacao","nome": "Teste de Animação"},
]

var _open := false
var _list: VBoxContainer
var _buttons: Dictionary = {}
var _style_buttons: Dictionary = {}

func _ready() -> void:
	_center_on_screen()
	_build()
	visible = false

func is_open() -> bool:
	return _open

func toggle() -> void:
	_open = not _open
	visible = _open
	Input.mouse_mode = (Input.MOUSE_MODE_VISIBLE if _open else Input.MOUSE_MODE_CAPTURED)
	if _open:
		_refresh_highlight()

# ------------------------------------------------------------------ build ---
func _center_on_screen() -> void:
	# Ancora no CENTRO da tela e cresce pros dois lados -> o painel fica centralizado
	# (não colide mais com o HUD do canto superior esquerdo).
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

func _build() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.12, 0.15, 0.42)
	bg.set_corner_radius_all(10)
	bg.border_color = Color(0.85, 0.88, 0.92, 0.50)
	bg.set_border_width_all(1)
	bg.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	bg.shadow_size = 10
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 14)
	add_child(margin)

	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 10)
	margin.add_child(main_vb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	main_vb.add_child(hb)

	# Coluna 1: Personagens & Frutas
	var col_char := VBoxContainer.new()
	col_char.add_theme_constant_override("separation", 8)
	hb.add_child(col_char)

	var titulo := Label.new()
	titulo.text = "PERSONAGENS & AKUMA"
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color(1, 1, 1))
	col_char.add_child(titulo)

	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.85, 0.88, 0.92, 0.25)
	sep.add_theme_stylebox_override("separator", ss)
	col_char.add_child(sep)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	col_char.add_child(_list)

	for c in CHARS:
		var btn := Button.new()
		btn.text = c["nome"]
		btn.custom_minimum_size = Vector2(180, 34)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", _btn_box(false))
		btn.add_theme_stylebox_override("hover", _btn_box(true))
		btn.add_theme_stylebox_override("pressed", _btn_box(true))
		btn.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		btn.pressed.connect(_on_pick.bind(str(c["id"])))
		_list.add_child(btn)
		_buttons[str(c["id"])] = btn

	# Divisor Vertical
	var vsep := VSeparator.new()
	var vss := StyleBoxFlat.new()
	vss.bg_color = Color(0.85, 0.88, 0.92, 0.25)
	vsep.add_theme_stylebox_override("separator", vss)
	hb.add_child(vsep)

	# Coluna 2: Estilos de Luta
	var col_style := VBoxContainer.new()
	col_style.add_theme_constant_override("separation", 8)
	hb.add_child(col_style)

	var titulo_s := Label.new()
	titulo_s.text = "ESTILOS DE LUTA (Tecla 2)"
	titulo_s.add_theme_font_size_override("font_size", 16)
	titulo_s.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	col_style.add_child(titulo_s)

	var sep_s := HSeparator.new()
	sep_s.add_theme_stylebox_override("separator", ss)
	col_style.add_child(sep_s)

	var list_styles := VBoxContainer.new()
	list_styles.add_theme_constant_override("separation", 6)
	col_style.add_child(list_styles)

	for s in STYLES:
		var btn_s := Button.new()
		btn_s.text = s["nome"]
		btn_s.custom_minimum_size = Vector2(180, 34)
		btn_s.focus_mode = Control.FOCUS_NONE
		btn_s.add_theme_stylebox_override("normal", _btn_box(false))
		btn_s.add_theme_stylebox_override("hover", _btn_box(true))
		btn_s.add_theme_stylebox_override("pressed", _btn_box(true))
		btn_s.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		btn_s.pressed.connect(_on_pick_style.bind(str(s["id"])))
		list_styles.add_child(btn_s)
		_style_buttons[str(s["id"])] = btn_s

	var sep_bottom := HSeparator.new()
	sep_bottom.add_theme_stylebox_override("separator", ss)
	main_vb.add_child(sep_bottom)

	var dica := Label.new()
	dica.text = "M para fechar  •  no jogo: 1 = Akuma no Mi   2 = Estilo   3 = Espada"
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.add_theme_font_size_override("font_size", 12)
	dica.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	main_vb.add_child(dica)

func _btn_box(active: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Color(0.30, 0.34, 0.40, 0.75) if active else Color(0.20, 0.22, 0.26, 0.60)
	b.set_corner_radius_all(6)
	b.set_border_width_all(1)
	b.border_color = Color(0.80, 0.83, 0.90, 0.55)
	b.content_margin_left = 10.0
	b.content_margin_right = 10.0
	b.content_margin_top = 5.0
	b.content_margin_bottom = 5.0
	return b

# ------------------------------------------------------------------ ações ---
func _on_pick(char_id: String) -> void:
	var player := PlayerScript.local_player(get_tree())
	if player and player.has_method("set_character"):
		player.set_character(char_id)
	elif player and player.has_method("_setup_character_model"):
		player._setup_character_model(char_id)
	_refresh_highlight()
	toggle()  # fecha e recaptura o mouse

func _on_pick_style(style_id: String) -> void:
	var player := PlayerScript.local_player(get_tree())
	if player and player.has_method("set_fighting_style"):
		player.set_fighting_style(style_id)
	_refresh_highlight()
	toggle()

func _refresh_highlight() -> void:
	var player := PlayerScript.local_player(get_tree())
	var cur_char := ""
	var cur_style := ""
	if player:
		cur_char = str(player.get("character_id"))
		if "current_style_idx" in player and "STYLES_LIST" in player:
			var idx: int = player.get("current_style_idx")
			var slist: Array = player.get("STYLES_LIST")
			if idx >= 0 and idx < slist.size():
				cur_style = str(slist[idx])
	for id in _buttons:
		var b: Button = _buttons[id]
		b.text = ("● " + CHARS_nome(id)) if id == cur_char else CHARS_nome(id)
	for id in _style_buttons:
		var b: Button = _style_buttons[id]
		b.text = ("● " + STYLE_nome(id)) if id == cur_style else STYLE_nome(id)

func CHARS_nome(id: String) -> String:
	for c in CHARS:
		if str(c["id"]) == id:
			return str(c["nome"])
	return id

func STYLE_nome(id: String) -> String:
	for s in STYLES:
		if str(s["id"]) == id:
			return str(s["nome"])
	return id
