extends SceneTree
## Estados interativos do tema: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_estados_do_tema.gd -- <arquivo.png>
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	GuiMinecraft.aplicar_global(root)
	var fundo := ColorRect.new()
	fundo.color = Color(0.2, 0.2, 0.2)
	fundo.size = Vector2(1280, 720)
	root.add_child(fundo)
	var caixa := VBoxContainer.new()
	caixa.position = Vector2(40, 30)
	caixa.add_theme_constant_override("separation", 10)
	fundo.add_child(caixa)
	var estados := {"normal": null, "hover": "hover", "pressed": "pressed", "disabled": "disabled"}
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	caixa.add_child(linha)
	var botoes := []
	for nome in estados:
		var b := Button.new()
		b.text = nome
		b.custom_minimum_size = Vector2(200, 44)
		b.disabled = nome == "disabled"
		linha.add_child(b)
		botoes.append(b)
	var l2 := HBoxContainer.new()
	l2.add_theme_constant_override("separation", 12)
	caixa.add_child(l2)
	var campo := LineEdit.new()
	campo.text = "campo de texto"
	campo.custom_minimum_size = Vector2(300, 40)
	l2.add_child(campo)
	var cb := CheckBox.new()
	cb.text = "caixa marcada"
	cb.button_pressed = true
	l2.add_child(cb)
	var op := OptionButton.new()
	op.add_item("opção A")
	op.add_item("opção B")
	l2.add_child(op)
	var sl := HSlider.new()
	sl.custom_minimum_size = Vector2(200, 24)
	sl.value = 60
	l2.add_child(sl)
	var rot := Label.new()
	rot.text = "Rótulo com acentos: ação, coração, órfão, lã — e sombra"
	caixa.add_child(rot)
	var dica := PanelContainer.new()
	dica.theme_type_variation = &"TooltipPanel"
	var dl := Label.new()
	dl.text = "Tooltip vanilla"
	dica.add_child(dl)
	caixa.add_child(dica)
	for i in 5:
		await process_frame
	# mouse em cima do 2º e apertado no 3º: simula o estado pelo próprio botão
	botoes[2].button_down.emit()
	botoes[2].set_pressed_no_signal(true)
	Input.warp_mouse(botoes[1].get_global_rect().get_center())
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	var a := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(a[0] if a.size() > 0 else "/tmp/estados_mc.png")
	quit()
