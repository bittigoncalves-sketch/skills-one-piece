class_name MainMenu
extends Control

# ============================================================================
#  MENU PRINCIPAL — SKILLS ONE PIECE (Estilo Clean Claro)
# ============================================================================

var _open := false
var _hud_ref: Node = null

const COLOR_BG := Color(0.98, 0.98, 0.98, 1.0)
const COLOR_TEXT_DARK := Color(0.1, 0.1, 0.1, 1.0)
const COLOR_TEXT_LIGHT := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_BLUE := Color(0.2, 0.5, 1.0, 1.0)
const COLOR_BORDER := Color(0.85, 0.85, 0.85, 1.0)
const COLOR_CARD_BG := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CARD_HOVER := Color(0.95, 0.96, 0.98, 1.0)

var _device_options: Array = []
var _online_input: LineEdit
var _lan_status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	if _hud_ref == null:
		# Estamos na cena principal (MainMenu.tscn)
		call_deferred("open_menu")
	else:
		# Fomos instanciados pela HUD, o HUD que chama open_menu
		visible = false

func setup(hud: Node) -> void:
	_hud_ref = hud

func is_open() -> bool:
	return _open

func toggle() -> void:
	if _open:
		close_menu()
	else:
		open_menu()

func open_menu() -> void:
	_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Workaround p/ bug do Godot no Linux/Wayland que trava o mouse no centro
	if _open and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_ui() -> void:
	# Fundo branco
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Margem principal
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 40)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 40)
	margin.add_child(main_vbox)

	# --- LOGO ---
	var logo_vbox := VBoxContainer.new()
	logo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_vbox.add_theme_constant_override("separation", -10)
	main_vbox.add_child(logo_vbox)

	var lbl_skills := Label.new()
	lbl_skills.text = "S  K  I  L  L  S"
	lbl_skills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_skills.add_theme_font_size_override("font_size", 24)
	lbl_skills.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	logo_vbox.add_child(lbl_skills)

	var lbl_op := RichTextLabel.new()
	lbl_op.bbcode_enabled = true
	lbl_op.text = "[center][b][color=#1a5fb4]ONE[/color] [color=#c01c28]P I E C E[/color][/b][/center]"
	lbl_op.custom_minimum_size = Vector2(0, 80)
	lbl_op.add_theme_font_size_override("normal_font_size", 72)
	lbl_op.add_theme_font_size_override("bold_font_size", 72)
	lbl_op.scroll_active = false
	# Simula o contorno e sombra via outline nativo do texto
	lbl_op.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_op.add_theme_constant_override("outline_size", 12)
	logo_vbox.add_child(lbl_op)

	var lbl_jp := Label.new()
	lbl_jp.text = "—— ワンピース ——"
	lbl_jp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_jp.add_theme_font_size_override("font_size", 20)
	lbl_jp.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	logo_vbox.add_child(lbl_jp)

	# --- CONTEÚDO CENTRAL (Botões + Dispositivo) ---
	var center_hbox := HBoxContainer.new()
	center_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_hbox.add_theme_constant_override("separation", 50)
	main_vbox.add_child(center_hbox)

	# Esquerda: Botões Principais
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(450, 0)
	left_vbox.add_theme_constant_override("separation", 15)
	center_hbox.add_child(left_vbox)

	var btn_single = _create_main_button("JOGAR SINGLEPLAYER", "COMECE SUA AVENTURA", "☠️", true)
	btn_single.gui_input.connect(_on_btn_input.bind(btn_single, _on_singleplayer_pressed))
	left_vbox.add_child(btn_single)

	var btn_online = _create_main_button("ONLINE", "CRIE UMA SALA OU ENTRE POR ID", "🌐", false)
	var online_vbox_parent: VBoxContainer = btn_online.get_meta("content_vbox")
	var online_margin := MarginContainer.new()
	online_margin.add_theme_constant_override("margin_top", 14)
	var online_vbox := VBoxContainer.new()
	online_vbox.add_theme_constant_override("separation", 10)
	online_margin.add_child(online_vbox)

	var in_style := StyleBoxFlat.new()
	in_style.bg_color = COLOR_CARD_HOVER
	in_style.set_corner_radius_all(6)
	in_style.set_border_width_all(1)
	in_style.border_color = COLOR_BORDER

	# --- CRIAR SERVIDOR ---
	var btn_create := Button.new()
	btn_create.text = "＋  CRIAR SERVIDOR"
	btn_create.custom_minimum_size = Vector2(0, 40)
	btn_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var create_style := in_style.duplicate()
	create_style.bg_color = COLOR_BLUE
	create_style.border_color = Color(0.1, 0.4, 0.85, 1.0)
	btn_create.add_theme_stylebox_override("normal", create_style)
	btn_create.add_theme_stylebox_override("hover", _hover_style(create_style))
	btn_create.add_theme_stylebox_override("pressed", create_style)
	btn_create.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_create.add_theme_font_size_override("font_size", 15)
	btn_create.pressed.connect(_on_create_server_pressed)
	online_vbox.add_child(btn_create)

	# --- CONECTAR POR LAN ---
	# Caminho SEM digitação: o host anuncia por UDP e este botão acha sozinho.
	# Fica logo abaixo do CRIAR SERVIDOR porque é o par natural dele — um abre a
	# sala, o outro entra nela. O campo de ID continua abaixo, para internet.
	var btn_lan := Button.new()
	btn_lan.text = "🔍  CONECTAR POR LAN"
	btn_lan.custom_minimum_size = Vector2(0, 40)
	btn_lan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lan_style := in_style.duplicate()
	lan_style.bg_color = Color(0.13, 0.55, 0.35, 1.0)
	lan_style.border_color = Color(0.08, 0.40, 0.25, 1.0)
	btn_lan.add_theme_stylebox_override("normal", lan_style)
	btn_lan.add_theme_stylebox_override("hover", _hover_style(lan_style))
	btn_lan.add_theme_stylebox_override("pressed", lan_style)
	btn_lan.add_theme_color_override("font_color", Color(1, 1, 1))
	btn_lan.add_theme_font_size_override("font_size", 15)
	btn_lan.pressed.connect(_on_lan_pressed.bind(btn_lan))
	online_vbox.add_child(btn_lan)

	_lan_status = Label.new()
	_lan_status.add_theme_font_size_override("font_size", 12)
	_lan_status.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	_lan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lan_status.visible = false
	online_vbox.add_child(_lan_status)

	# --- ENTRAR POR ID ---
	var online_hbox := HBoxContainer.new()
	online_hbox.add_theme_constant_override("separation", 8)
	_online_input = LineEdit.new()
	_online_input.placeholder_text = "ID DA SALA"
	_online_input.custom_minimum_size = Vector2(0, 40)
	_online_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_online_input.add_theme_font_size_override("font_size", 14)
	_online_input.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	_online_input.add_theme_stylebox_override("normal", in_style)
	online_hbox.add_child(_online_input)

	var btn_join := Button.new()
	btn_join.text = "ENTRAR"
	btn_join.custom_minimum_size = Vector2(85, 40)
	var join_style := in_style.duplicate()
	btn_join.add_theme_stylebox_override("normal", join_style)
	btn_join.add_theme_stylebox_override("hover", _hover_style(join_style))
	btn_join.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	btn_join.add_theme_font_size_override("font_size", 14)
	btn_join.pressed.connect(_on_join_pressed)
	online_hbox.add_child(btn_join)
	online_vbox.add_child(online_hbox)

	online_vbox_parent.add_child(online_margin)
	left_vbox.add_child(btn_online)
	_online_input.text_submitted.connect(func(_t): _on_join_pressed())

	var btn_config = _create_main_button("CONFIGURAÇÕES", "AJUSTE AS OPÇÕES DO JOGO", "⚙️", true)
	btn_config.gui_input.connect(_on_btn_input.bind(btn_config, _on_config_pressed))
	left_vbox.add_child(btn_config)

	# Direita: Seletor de Dispositivo
	var right_vbox := VBoxContainer.new()
	center_hbox.add_child(right_vbox)

	var dev_panel := PanelContainer.new()
	var dp_style := StyleBoxFlat.new()
	dp_style.bg_color = COLOR_CARD_BG
	dp_style.border_color = COLOR_BORDER
	dp_style.set_border_width_all(1)
	dp_style.set_corner_radius_all(8)
	dp_style.shadow_color = Color(0, 0, 0, 0.05)
	dp_style.shadow_size = 10
	dev_panel.add_theme_stylebox_override("panel", dp_style)
	dev_panel.custom_minimum_size = Vector2(280, 0)
	right_vbox.add_child(dev_panel)

	var dev_margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		dev_margin.add_theme_constant_override(m, 20)
	dev_panel.add_child(dev_margin)

	var dev_list := VBoxContainer.new()
	dev_list.add_theme_constant_override("separation", 15)
	dev_margin.add_child(dev_list)

	var lbl_dev := Label.new()
	lbl_dev.text = "ESTOU JOGANDO EM:"
	lbl_dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dev.add_theme_font_size_override("font_size", 14)
	lbl_dev.add_theme_font_size_override("font_weight", 700)
	lbl_dev.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	dev_list.add_child(lbl_dev)

	var opt_cel := _create_device_option("📱", "CELULAR", false); opt_cel.set_meta("dev_id", "celular")
	var opt_tab := _create_device_option("📱", "TABLET", false); opt_tab.set_meta("dev_id", "tablet")
	var opt_pc := _create_device_option("💻", "PC / NOTEBOOK", true); opt_pc.set_meta("dev_id", "pc")
	_device_options = [opt_cel, opt_tab, opt_pc]

	for opt in _device_options:
		dev_list.add_child(opt)
		opt.gui_input.connect(_on_device_selected.bind(opt))

	var lbl_dev_info := Label.new()
	lbl_dev_info.text = "Padrão definido para PC / Notebook"
	lbl_dev_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dev_info.add_theme_font_size_override("font_size", 11)
	lbl_dev_info.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	right_vbox.add_child(lbl_dev_info)

	# --- RODAPÉ ---
	var footer := Control.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)

	var lbl_version := Label.new()
	lbl_version.text = "VERSÃO 0.1.0"
	lbl_version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl_version.position = Vector2(40, -60)
	lbl_version.add_theme_font_size_override("font_size", 14)
	lbl_version.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	footer.add_child(lbl_version)

	var social_hbox := HBoxContainer.new()
	social_hbox.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	social_hbox.position.y = -70
	social_hbox.add_theme_constant_override("separation", 15)
	footer.add_child(social_hbox)

	social_hbox.add_child(_create_social_btn("👾")) # Discord
	social_hbox.add_child(_create_social_btn("🐙")) # GitHub
	social_hbox.add_child(_create_social_btn("📖")) # Wiki/Docs

	var btn_exit := Button.new()
	btn_exit.text = "🚪 SAIR DO JOGO"
	btn_exit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_exit.position = Vector2(-220, -70)
	btn_exit.custom_minimum_size = Vector2(180, 45)
	btn_exit.add_theme_font_size_override("font_size", 14)
	btn_exit.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	var exit_style := dp_style.duplicate()
	btn_exit.add_theme_stylebox_override("normal", exit_style)
	btn_exit.add_theme_stylebox_override("hover", _hover_style(exit_style))
	btn_exit.pressed.connect(_on_quit_pressed)
	footer.add_child(btn_exit)


func _create_main_button(title: String, subtitle: String, icon: String, center_y: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.05)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 90)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hbox := HBoxContainer.new()
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_right", 20)
	if center_y:
		m.add_theme_constant_override("margin_top", 20)
		m.add_theme_constant_override("margin_bottom", 20)
	else:
		m.add_theme_constant_override("margin_top", 18)
		m.add_theme_constant_override("margin_bottom", 18)
	m.add_child(hbox)
	panel.add_child(m)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 40)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	icon_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_lbl)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m2 := MarginContainer.new()
	m2.add_theme_constant_override("margin_left", 20)
	m2.add_child(vbox)
	hbox.add_child(m2)
	panel.set_meta("content_vbox", vbox)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.add_theme_font_size_override("font_size", 20)
	t_lbl.add_theme_font_size_override("font_weight", 800)
	t_lbl.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	vbox.add_child(t_lbl)

	var s_lbl := Label.new()
	s_lbl.text = subtitle
	s_lbl.add_theme_font_size_override("font_size", 12)
	s_lbl.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	vbox.add_child(s_lbl)

	var arrow := Label.new()
	arrow.text = "＞"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.visible = center_y
	hbox.add_child(arrow)

	# Hover effects
	panel.mouse_entered.connect(func(): style.bg_color = COLOR_CARD_HOVER)
	panel.mouse_exited.connect(func(): style.bg_color = COLOR_CARD_BG)
	
	return panel

func _create_device_option(icon: String, text: String, active: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = COLOR_BLUE if active else COLOR_BORDER
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 50)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("active", active)

	var hbox := HBoxContainer.new()
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	m.add_child(hbox)
	panel.add_child(m)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	hbox.add_child(icon_lbl)

	var t_lbl := Label.new()
	t_lbl.text = text
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 13)
	t_lbl.add_theme_font_size_override("font_weight", 700)
	t_lbl.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	hbox.add_child(t_lbl)

	var check := Label.new()
	check.text = "✅" if active else "◯"
	check.add_theme_font_size_override("font_size", 16)
	check.add_theme_color_override("font_color", COLOR_BLUE if active else COLOR_BORDER)
	hbox.add_child(check)
	panel.set_meta("check_lbl", check)
	panel.set_meta("stylebox", style)

	return panel

func _create_social_btn(icon: String) -> Button:
	var btn := Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(45, 45)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", _hover_style(style))
	return btn

func _hover_style(base: StyleBoxFlat) -> StyleBoxFlat:
	var h = base.duplicate()
	h.bg_color = COLOR_CARD_HOVER
	return h

# --- INTERAÇÕES ---
func _on_btn_input(event: InputEvent, panel: PanelContainer, callback: Callable) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		callback.call()

func _on_device_selected(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for opt in _device_options:
			var style: StyleBoxFlat = opt.get_meta("stylebox")
			var check: Label = opt.get_meta("check_lbl")
			if opt == panel:
				opt.set_meta("active", true)
				style.border_color = COLOR_BLUE
				check.text = "✅"
				check.add_theme_color_override("font_color", COLOR_BLUE)
			else:
				opt.set_meta("active", false)
				style.border_color = COLOR_BORDER
				check.text = "◯"
				check.add_theme_color_override("font_color", COLOR_BORDER)
		GameFlow.set_device(str(panel.get_meta("dev_id", "pc")))

# --- MODOS (via fachada GameFlow) ---
func _on_singleplayer_pressed() -> void:
	GameFlow.start_singleplayer()

func _on_create_server_pressed() -> void:
	# Cria a sala (host). O ID gerado (codifica o IP do host) aparece no HUD do jogo.
	GameFlow.create_room()

# Procura uma sala aberta na rede local e entra. Sem digitar nada.
# É corrotina porque a busca escuta o farol por alguns segundos — o botão fica
# desabilitado e com texto de progresso, senão parece que o clique não pegou.
func _on_lan_pressed(btn: Button) -> void:
	btn.disabled = true
	var texto_original := btn.text
	btn.text = "🔍  PROCURANDO..."
	_lan_status.visible = true
	_lan_status.text = "ouvindo a rede local…"
	_lan_status.add_theme_color_override("font_color", COLOR_TEXT_DARK)

	var r: Dictionary = await GameFlow.join_lan()

	# Se deu certo, a cena já trocou e este nó pode nem existir mais.
	if not is_instance_valid(btn):
		return
	btn.disabled = false
	btn.text = texto_original
	if bool(r.get("ok", false)):
		_lan_status.text = "conectado em %s" % str(r.get("ip", ""))
		return
	_lan_status.text = "%s.\nUse o ID da sala abaixo se o host estiver em outra rede." % str(r.get("motivo", "falhou"))
	_lan_status.add_theme_color_override("font_color", Color(0.75, 0.25, 0.2))

func _on_join_pressed() -> void:
	var id := _online_input.text.strip_edges()
	if id.is_empty():
		return
	GameFlow.join_room(id)



func _on_play_pressed() -> void:
	close_menu()

func _on_config_pressed() -> void:
	print("Settings not implemented yet.")

func _on_quit_pressed() -> void:
	get_tree().quit()
