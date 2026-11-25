extends Control
const Doc = preload("res://document.gd")
const View = preload("res://view.gd")
const Timeline = preload("res://timeline.gd")
const Selection = preload("res://selection.gd")
var document := Doc.new()
var project := ""
var editor_dir := ""
var document_path := ""
var saved_state := ""
var undo_stack: Array = []
var redo_stack: Array = []
var pending: Dictionary = {}
var drag_pose: Dictionary = {}
var drag_value := Vector3.ZERO
var time := 0.0
var playing := false
var assembling := false
var refreshing := false
var selected := "Torso"
var selected_tokens: Array = ["Torso"]
var selected_roots: Array = ["Torso"]
var bone_items: Dictionary = {}
var selection_update_pending := false
var transform_mode := "rotation"
var view: Control
var timeline: Control
var bones: Tree
var filter: LineEdit
var group_filter: OptionButton
var values: Array[SpinBox] = []
var name_field: LineEdit
var status: Label
var selection_label: Label
var context_label: Label
var play_button: Button
var loop_button: CheckButton
var weapon_button: CheckButton
var duration: SpinBox
var clock_field: SpinBox
var point_name: LineEdit
var point_time: SpinBox
var smooth_button: CheckButton
var save_button: Button
var modes: Dictionary = {}
var open_dialog: FileDialog
var save_dialog: FileDialog
var confirm: ConfirmationDialog
var auto_time := 0.0
var testing := false
var pending_action: Callable
const FRIENDLY := {"Torso":"Quadril", "Head":"Cabeça", "Neck":"Pescoço", "Chest":"Peito",
	"UpperArm_L":"Braço esquerdo", "UpperArm_R":"Braço direito", "ForeArm_L":"Antebraço esquerdo",
	"ForeArm_R":"Antebraço direito", "Hand_L":"Mão esquerda", "Hand_R":"Mão direita",
	"Foot_L":"Pé esquerdo", "Foot_R":"Pé direito", "Grip_R":"Pega direita", "Yoru":"Yoru · espada",
	"Thigh_L":"Coxa esquerda", "Thigh_R":"Coxa direita", "Shin_L":"Canela esquerda", "Shin_R":"Canela direita",
	"Wrist_L":"Punho esquerdo", "Wrist_R":"Punho direito", "Clavicle_L":"Ombro esquerdo", "Clavicle_R":"Ombro direito"}

func _ready() -> void:
	project = ProjectSettings.globalize_path("res://").path_join("../../..").simplify_path()
	editor_dir = project.path_join("tools/anim_editor")
	testing = testing or "--smoke-test" in OS.get_cmdline_user_args()
	get_tree().auto_accept_quit = false
	get_window().min_size = Vector2i(1120,760)
	_theme()
	_build_ui()
	if view.rig.error == "": seed_document()
	saved_state = JSON.stringify(document.data)
	refresh()
	if view.rig.error == "": view.frame_all()
	if view.rig.error != "": tell(view.rig.error)
	elif not testing:
		if FileAccess.file_exists(_recovery_path()):
			confirm.dialog_text = "Há uma sessão recuperável. Abrir o trabalho que ficou salvo automaticamente?"
			pending_action = func(): load_document(_recovery_path()); document_path = ""; tell("Sessão recuperada. Use Salvar para escolher um nome.")
			confirm.popup_centered()
		else: tell("Corpo atual + Yoru prontos. Selecione uma peça, ajuste a pose e clique em + Ponto.")

func _theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color","Label",Color("dce6f4"))
	for type_name in ["Button","OptionButton","CheckButton"]:
		for state_name in ["normal","hover","pressed","focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("263449") if state_name == "normal" else Color("3c536d")
			box.set_corner_radius_all(6)
			box.content_margin_left = 12
			box.content_margin_right = 12
			box.content_margin_top = 7
			box.content_margin_bottom = 7
			if state_name == "focus":
				box.bg_color = Color.TRANSPARENT
				box.set_border_width_all(2)
				box.border_color = Color("63c8bf")
			theme.set_stylebox(state_name,type_name,box)

func label(parent: Node, text: String, small: bool = false) -> Label:
	var widget := Label.new()
	widget.text = text
	if small: widget.add_theme_font_size_override("font_size",12); widget.modulate = Color("a6b7cd")
	parent.add_child(widget)
	return widget

func button(parent: Node, text: String, action: Callable, tip: String = "") -> Button:
	var widget := Button.new()
	widget.text = text
	widget.tooltip_text = tip
	widget.custom_minimum_size.y = 34
	widget.pressed.connect(action)
	parent.add_child(widget)
	return widget

func row(parent: Node) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	parent.add_child(box)
	return box

func spin(parent: Node, lo: float, hi: float, step: float, action: Callable) -> SpinBox:
	var widget := SpinBox.new()
	widget.min_value = lo
	widget.max_value = hi
	widget.step = step
	widget.custom_minimum_size.x = 94
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widget.value_changed.connect(action)
	parent.add_child(widget)
	return widget

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margin.add_child(layout)
	var top := row(layout)
	label(top,"ESTÚDIO  /  ANIMAÇÃO")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	button(top,"Novo",func(): protect(new_document),"Ctrl+N")
	button(top,"Abrir",func(): protect(func(): open_dialog.popup_centered_ratio(.7)),"Ctrl+O · projetos e clipes antigos")
	save_button = button(top,"Salvar",save_document,"Ctrl+S · salva poses, montagem e espada")
	button(top,"Salvar como",func(): save_dialog.popup_centered_ratio(.7),"Ctrl+Shift+S")
	button(top,"Exportar para o jogo",export_document,"Gera uma animação .tres com corpo e espada")
	var heading := row(layout)
	name_field = LineEdit.new()
	name_field.placeholder_text = "Nome da skill ou animação"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_field.text_changed.connect(func(value):
		if not refreshing: begin_edit(); document.data.name = value; end_edit())
	heading.add_child(name_field)
	button(heading,"Desfazer",undo,"Ctrl+Z")
	button(heading,"Refazer",redo,"Ctrl+Shift+Z")
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 220
	body.add_child(left)
	label(left,"CORPO E ESPADA")
	label(left,"126 articulações · corpo atual",true)
	filter = LineEdit.new()
	filter.placeholder_text = "Buscar osso ou parte do corpo…"
	filter.text_changed.connect(func(_text): populate_bones())
	left.add_child(filter)
	group_filter = OptionButton.new()
	for text in ["Tudo","Corpo","Dedos das mãos","Dedos dos pés","Encaixes","Rosto","Espada"]: group_filter.add_item(text)
	group_filter.item_selected.connect(func(_index): populate_bones())
	left.add_child(group_filter)
	label(left,"Ctrl + clique: combinar partes",true)
	bones = Tree.new()
	bones.hide_root = true
	bones.select_mode = Tree.SELECT_MULTI
	bones.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bones.multi_selected.connect(func(_item,_column,_on):
		if not refreshing and not selection_update_pending:
			selection_update_pending = true
			call_deferred("_tree_selection_changed"))
	left.add_child(bones)
	weapon_button = CheckButton.new()
	weapon_button.text = "Yoru equipada"
	weapon_button.toggled.connect(func(on):
		if not refreshing: begin_edit(); document.data.weapon = on; end_edit(); refresh())
	left.add_child(weapon_button)
	button(left,"Selecionar Yoru",func(): select_bone("Yoru"))
	var center_split := HSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center_split)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_split.add_child(center)
	var views := row(center)
	for pair in [["Perspectiva","perspective"],["Frente","front"],["Lado","side"]]:
		button(views,pair[0],func(): view.view_preset(pair[1]))
	button(views,"Enquadrar",func(): view.frame_all(),"Ver corpo e espada inteiros")
	var joints_toggle := CheckButton.new()
	joints_toggle.text = "Ossos"
	joints_toggle.button_pressed = true
	joints_toggle.toggled.connect(func(on): view.show_joints = on; view.overlay.queue_redraw())
	views.add_child(joints_toggle)
	view = View.new()
	center.add_child(view)
	view.build(project)
	view.selected.connect(func(key): select_parts([view_token(key)],true))
	view.selection_extended.connect(func(key):
		var token := view_token(key)
		var tokens := selected_tokens.duplicate()
		if tokens.has(token): tokens.erase(token)
		else: tokens.append(token)
		if not tokens.is_empty(): select_parts(tokens,true))
	view.edit_started.connect(start_drag)
	view.transformed.connect(drag_transform)
	view.edit_finished.connect(func(): end_edit(); refresh())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 264
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_split.add_child(scroll)
	var inspector := VBoxContainer.new()
	inspector.custom_minimum_size.x = 248
	inspector.add_theme_constant_override("separation",10)
	scroll.add_child(inspector)
	selection_label = label(inspector,"Quadril")
	var workspace := OptionButton.new()
	workspace.add_item("Animar · gravar movimentos")
	workspace.add_item("Ajustar corpo · juntas e pivôs")
	workspace.item_selected.connect(func(index):
		assembling = index == 1; playing = false
		if not assembling and transform_mode == "pivot": transform_mode = "rotation"
		refresh())
	inspector.add_child(workspace)
	var grid := GridContainer.new()
	grid.columns = 2
	inspector.add_child(grid)
	for pair in [["Mover  W","position"],["Girar  E","rotation"],["Tamanho  R","scale"],["Pivô","pivot"]]:
		var widget := button(grid,pair[0],func(): set_mode(pair[1]))
		widget.toggle_mode = true
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes[pair[1]] = widget
	context_label = label(inspector,"")
	context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_label.custom_minimum_size = Vector2(230,52)
	for i in 3:
		var axis_row := row(inspector)
		var axis_label := label(axis_row,["X","Y","Z"][i])
		axis_label.modulate = View.COLORS[i]
		values.append(spin(axis_row,-100,100,.01,func(value): change_value(i,value)))
	button(inspector,"Enquadrar seleção  F",func(): view.frame_selected())
	button(inspector,"Pose T · zerar valores",neutral_pose,"Rotação 0°, deslocamento 0 m e tamanho 1×; pode desfazer")
	button(inspector,"Guarda com Yoru",guard_pose,"Posiciona as duas mãos no cabo da espada")
	var hands := row(inspector)
	button(hands,"Fechar mão",func(): hand_pose(-.65),"Aplica ao lado selecionado; escolha a outra mão para repetir")
	button(hands,"Abrir mão",func(): hand_pose(0))
	var point_bar := row(layout)
	label(point_bar,"Ponto")
	point_name = LineEdit.new()
	point_name.placeholder_text = "Ex.: Preparar / Cortar / Recuperar"
	point_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	point_name.custom_minimum_size.x = 180
	point_name.text_submitted.connect(func(value): rename_point(value))
	point_name.focus_exited.connect(func(): rename_point(point_name.text))
	point_bar.add_child(point_name)
	var point_row := row(point_bar)
	label(point_row,"Começa em")
	point_time = spin(point_row,0,120,1/30.0,func(value):
		if not refreshing: begin_edit(); relocate_point(time,Doc.snap_time(value)); end_edit(); refresh())
	point_time.suffix = "s"
	smooth_button = CheckButton.new()
	smooth_button.text = "Suavizar até o próximo"
	smooth_button.tooltip_text = "Age no trecho que SAI deste ponto. Ligado: caminha até o próximo ponto. Desligado: segura esta pose e salta no próximo."
	smooth_button.toggled.connect(func(on):
		if not refreshing: begin_edit(); document.transition(time,not on); end_edit(); refresh())
	point_bar.add_child(smooth_button)
	var point_actions := row(point_bar)
	button(point_actions,"Duplicar",duplicate_point,"Copia a pose um quadro adiante")
	button(point_actions,"Apagar",delete_point,"Delete · remove o ponto inteiro")
	var transport := row(layout)
	play_button = button(transport,"▶ Tocar",toggle_play,"Espaço")
	button(transport,"■ Início",func(): seek(0))
	button(transport,"−1 quadro",func(): seek(time-1/30.0),"Seta esquerda")
	button(transport,"+1 quadro",func(): seek(time+1/30.0),"Seta direita")
	clock_field = spin(transport,0,120,1/30.0,func(value):
		if not refreshing: seek(value))
	clock_field.suffix = "s"
	label(transport,"Duração")
	duration = spin(transport,1/30.0,120,1/30.0,set_duration)
	duration.suffix = "s"
	loop_button = CheckButton.new()
	loop_button.text = "Loop"
	loop_button.toggled.connect(func(on):
		if not refreshing:
			var was_playing := playing
			begin_edit(); document.data.loop = on; end_edit()
			playing = was_playing
			refresh())
	transport.add_child(loop_button)
	button(transport,"+ Ponto  K",mark_point,"Guarda a pose completa neste quadro")
	button(transport,"Fechar loop",close_loop,"Copia a primeira pose para o fim")
	timeline = Timeline.new()
	timeline.document = document
	layout.add_child(timeline)
	timeline.seek.connect(seek)
	timeline.drag_started.connect(begin_edit)
	timeline.moved.connect(relocate_point)
	timeline.drag_finished.connect(func(): end_edit(); refresh())
	status = label(layout,"",true)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	open_dialog = FileDialog.new()
	open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.filters = PackedStringArray(["*.json ; Animações e projetos"])
	open_dialog.current_dir = editor_dir.path_join("clips")
	open_dialog.file_selected.connect(load_document)
	add_child(open_dialog)
	save_dialog = FileDialog.new()
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.filters = PackedStringArray(["*.json ; Projeto de animação"])
	DirAccess.make_dir_recursive_absolute(editor_dir.path_join("projects"))
	save_dialog.current_dir = editor_dir.path_join("projects")
	save_dialog.file_selected.connect(func(path): document_path = path; save_document())
	add_child(save_dialog)
	confirm = ConfirmationDialog.new()
	confirm.title = "Trabalho em andamento"
	confirm.ok_button_text = "Continuar"
	confirm.cancel_button_text = "Voltar"
	confirm.confirmed.connect(func():
		if pending_action.is_valid(): pending_action.call())
	add_child(confirm)
	populate_bones()

func populate_bones() -> void:
	if not view or not view.rig: return
	var previous := refreshing
	refreshing = true
	var collapsed: Dictionary = {}
	for token in bone_items:
		if is_instance_valid(bone_items[token]): collapsed[token] = bone_items[token].collapsed
	bones.clear()
	bone_items.clear()
	var root_item := bones.create_item()
	var query := filter.text.to_lower()
	var category: String = ["","body","fingers","toes","socket","face_anchor","weapon"][group_filter.selected]
	var groups_heading := bones.create_item(root_item)
	groups_heading.set_text(0,"PARTES COMPLETAS")
	groups_heading.set_selectable(0,false)
	for group in Selection.GROUPS:
		var info: Dictionary = Selection.GROUPS[group]
		if query != "" and not query in str(info.label).to_lower(): continue
		if category != "": continue
		var item := bones.create_item(groups_heading)
		item.set_text(0,info.label)
		item.set_metadata(0,"#"+group)
		item.set_tooltip_text(0,"Transforma a parte inteira, incluindo suas articulações e peças filhas.")
		bone_items["#"+group] = item
		if selected_tokens.has("#"+group): item.select(0)
	groups_heading.visible = groups_heading.get_child_count() > 0
	var bones_heading := bones.create_item(root_item)
	bones_heading.set_text(0,"OSSOS INDIVIDUAIS")
	bones_heading.set_selectable(0,false)
	for key in view.rig.joints:
		var friendly := str(FRIENDLY.get(key,key))
		if query != "" and not query in (str(key)+" "+friendly).to_lower(): continue
		if category != "" and view.rig.categories[key] != category: continue
		var parent_name := str(view.rig.joints[key].get_parent().name)
		var parent_item: TreeItem = bone_items.get(parent_name,bones_heading)
		var item := bones.create_item(parent_item)
		item.set_text(0,friendly)
		item.set_tooltip_text(0,str(key))
		item.set_metadata(0,key)
		bone_items[key] = item
		if selected_tokens.has(key): item.select(0)
	for token in collapsed:
		if bone_items.has(token): bone_items[token].collapsed = collapsed[token]
	refreshing = previous

## Um clique no 3D pega o MEMBRO inteiro: braco, perna ou cabeca. Shift pega a
## peca exata, e a arvore da esquerda sempre pega exata. Osso sem membro (tronco,
## quadril, espada) cai nele mesmo.
func view_token(key: String) -> String:
	if not view.rig.joints.has(key): return key
	if view.exact_pick: return key
	var limb := Selection.limb_for(key,view.rig)
	return limb if limb != "" else key

func select_bone(key: String) -> void:
	if not view.rig.joints.has(key): return
	select_parts([key],true)

func select_parts(tokens: Array, reveal: bool = false) -> void:
	var roots := Selection.roots_for(tokens,view.rig)
	if roots.is_empty(): return
	selected_tokens = tokens.duplicate()
	selected_roots = roots
	selected = str(roots[0])
	view.current = selected
	view.selected_members = Selection.members(roots,view.rig)
	if reveal:
		# A click in 3D must reveal its item even when a text/category filter hid it.
		var hidden := false
		for token in tokens:
			if not bone_items.has(token): hidden = true
		if hidden:
			filter.set_text("")
			group_filter.select(0)
	populate_bones()
	refresh()
	if reveal: reveal_selection.call_deferred()

func _tree_selection_changed() -> void:
	selection_update_pending = false
	if refreshing: return
	var tokens: Array = []
	var item := bones.get_next_selected(null)
	while item:
		if item.get_metadata(0) is String: tokens.append(item.get_metadata(0))
		item = bones.get_next_selected(item)
	if not tokens.is_empty(): select_parts(tokens,true)

func reveal_selection() -> void:
	if not bone_items.has(selected_tokens[0]): return
	var item: TreeItem = bone_items[selected_tokens[0]]
	var parent := item.get_parent()
	while parent:
		parent.collapsed = false
		parent = parent.get_parent()
	bones.scroll_to_item(item,true)

func set_mode(mode: String) -> void:
	if mode == "pivot" and not assembling:
		tell("Pivô fica em Ajustar corpo. Ele muda onde a junta dobra, mantendo a malha no lugar.")
		return
	transform_mode = mode
	refresh()

func refresh() -> void:
	if not view or view.rig.error != "": return
	refreshing = true
	view.rig.setup_pose(document.data.setup)
	if not assembling: view.rig.apply_pose(document.sample(time))
	view.rig.sword.visible = bool(document.data.weapon)
	view.mode = transform_mode
	view.current = selected
	view.overlay.queue_redraw()
	name_field.text = str(document.data.name)
	selection_label.text = Selection.title(selected_tokens,str(FRIENDLY.get(selected,selected)))
	selection_label.tooltip_text = selected
	var value: Vector3 = view.rig.displayed(selected,transform_mode)
	for i in 3:
		values[i].min_value = .01 if transform_mode == "scale" else -1000
		values[i].max_value = 1000
		values[i].step = 1 if transform_mode == "rotation" else (.01 if transform_mode == "scale" else .001)
		values[i].suffix = "°" if transform_mode == "rotation" else ("×" if transform_mode == "scale" else "m")
		values[i].set_value_no_signal(rad_to_deg(value[i]) if transform_mode == "rotation" else value[i])
	for mode in modes:
		modes[mode].set_pressed_no_signal(mode == transform_mode)
	modes.pivot.disabled = not assembling
	context_label.text = "Referência T: 0°, 0 m, 1×. Valores positivos ou negativos ficam gravados no ponto." if not assembling else ("Pivô: distância da junta original, em metros. Mantém a malha no lugar." if transform_mode == "pivot" else "Montagem relativa à pose T: 0°, 0 m, 1×. Salvar preserva os ajustes.")
	if selected_roots.size() > 1:
		context_label.text += " Valores da primeira parte; a mesma variação é aplicada às demais."
	var point := document.point_at(time)
	point_name.editable = point >= 0
	point_time.editable = point >= 0
	smooth_button.disabled = point < 0
	point_name.text = str(document.data.points[point].label) if point >= 0 else ""
	point_time.set_value_no_signal(time)
	point_time.max_value = float(document.data.length)
	smooth_button.set_pressed_no_signal(not bool(document.data.points[point].hold) if point >= 0 else false)
	loop_button.set_pressed_no_signal(bool(document.data.loop))
	weapon_button.set_pressed_no_signal(bool(document.data.weapon))
	duration.set_value_no_signal(float(document.data.length))
	clock_field.max_value = float(document.data.length)
	clock_field.set_value_no_signal(time)
	play_button.text = "Ⅱ Pausar" if playing else "▶ Tocar"
	timeline.time = time
	timeline.selected = time if point >= 0 else -1
	timeline.queue_redraw()
	save_button.text = "Salvar •" if dirty() else "Salvar"
	refreshing = false

func begin_edit() -> void:
	playing = false
	if pending.is_empty(): pending = {"data":document.data.duplicate(true),"time":time}

func end_edit() -> void:
	if not pending.is_empty() and JSON.stringify(pending.data) != JSON.stringify(document.data):
		undo_stack.append(pending)
		if undo_stack.size() > 80: undo_stack.pop_front()
		redo_stack.clear()
	pending = {}
	if save_button: save_button.text = "Salvar •" if dirty() else "Salvar"

func undo() -> void:
	if undo_stack.is_empty(): return
	redo_stack.append({"data":document.data.duplicate(true),"time":time})
	var entry: Dictionary = undo_stack.pop_back()
	document.data = entry.data
	time = entry.time
	playing = false
	refresh()

func redo() -> void:
	if redo_stack.is_empty(): return
	undo_stack.append({"data":document.data.duplicate(true),"time":time})
	var entry: Dictionary = redo_stack.pop_back()
	document.data = entry.data
	time = entry.time
	playing = false
	refresh()

func start_drag() -> void:
	begin_edit()
	drag_pose = view.rig.capture_setup()
	drag_value = view.rig.displayed(selected,transform_mode)

func drag_transform(axis: int, amount: float) -> void:
	if assembling and not pending.is_empty(): document.data = pending.data.duplicate(true)
	view.rig.setup_pose(drag_pose)
	var value := drag_value
	if transform_mode == "scale": value[axis] = maxf(.01,snap_axis(drag_value[axis]*amount))
	else: value[axis] = snap_axis(drag_value[axis]+amount)
	_apply_value(value)
	refresh()

## A regua: o valor gruda nos passos de View.STEPS, na unidade que o painel
## mostra. Shift solta. Vale para o arraste no 3D; digitar no campo continua
## aceitando qualquer numero.
func snap_axis(raw: float) -> float:
	if view.free_drag or not View.STEPS.has(transform_mode): return raw
	var step: float = View.STEPS[transform_mode]
	if transform_mode == "rotation": return deg_to_rad(snappedf(rad_to_deg(raw),step))
	return snappedf(raw,step)

func change_value(axis: int, number: float) -> void:
	if refreshing or not view: return
	begin_edit()
	var value: Vector3 = view.rig.displayed(selected,transform_mode)
	value[axis] = deg_to_rad(number) if transform_mode == "rotation" else number
	_apply_value(value)
	end_edit()
	refresh()

func _apply_value(value: Vector3) -> void:
	var before: Dictionary = view.rig.capture_setup() if assembling else {}
	var first: Vector3 = view.rig.displayed(selected,transform_mode)
	for key in selected_roots:
		var shown: Vector3 = view.rig.displayed(key,transform_mode)
		var adjusted: Vector3 = shown*value/first if transform_mode == "scale" else shown+value-first
		var absolute: Vector3 = view.rig.absolute_value(key,transform_mode,adjusted)
		if transform_mode == "pivot": view.rig.move_pivot(key,absolute)
		else: view.rig.joints[key].set(transform_mode,absolute)
	if assembling:
		commit_setup(before)
	else: document.mark(time,view.rig.capture())

func commit_setup(before: Dictionary) -> void:
	document.data.setup = view.rig.capture_setup()
	# Rebase existing animation values when the authored rest pose changes.
	for path in document.data.tracks:
		var key: String = str(path).get_slice(":",0)
		var prop: String = str(path).get_slice(":",1)
		if not before.has(key): continue
		var old := Doc.vector(before[key][prop])
		var after := Doc.vector(document.data.setup[key][prop])
		if old.is_equal_approx(after): continue
		for k in document.data.tracks[path]:
			var v := Doc.vector(k[1])
			k[1] = Doc.array(v*after/old if prop == "scale" else v+after-old)

func guard_pose() -> void:
	begin_edit()
	view.rig.setup_pose(document.data.setup)
	var before: Dictionary = view.rig.capture_setup()
	view.rig.guard_pose()
	if assembling: commit_setup(before)
	else: document.mark(time,view.rig.capture(),"Guarda com Yoru")
	end_edit(); refresh()

func mark_point() -> void:
	if assembling: tell("Selecione Animar para marcar uma pose."); return
	begin_edit()
	document.mark(time,view.rig.capture())
	end_edit()
	refresh()
	tell("Ponto em %.2f s. Arraste a barra para mudar seu tempo; \"Suavizar até o próximo\" controla a saída deste ponto." % time)

func rename_point(value: String) -> void:
	if refreshing: return
	var idx := document.point_at(time)
	if idx < 0 or value == str(document.data.points[idx].label): return
	begin_edit(); document.data.points[idx].label = value; end_edit()
	timeline.queue_redraw()

func relocate_point(old: float, target_time: float) -> void:
	if document.move_point(old,target_time): time = target_time
	else: tell("Já existe um ponto neste quadro. Escolha outro instante.")

func delete_point() -> void:
	begin_edit(); document.remove_point(time); end_edit(); refresh()

func duplicate_point() -> void:
	if document.point_at(time) < 0: tell("Selecione um ponto na barra de tempo."); return
	var original: Dictionary = document.data.points[document.point_at(time)].duplicate()
	var target_time := Doc.snap_time(time+1/30.0)
	while document.point_at(target_time) >= 0: target_time = Doc.snap_time(target_time+1/30.0)
	if target_time > float(document.data.length): tell("Aumente a duração para duplicar este ponto."); return
	begin_edit()
	var pose: Dictionary = view.rig.capture()
	time = target_time
	document.mark(time,pose,str(original.label)+" · cópia")
	document.transition(time,bool(original.hold))
	end_edit(); refresh()

func neutral_pose() -> void:
	begin_edit()
	var before: Dictionary = view.rig.capture_setup()
	view.rig.setup_pose({})
	view.rig.t_pose()
	if assembling: commit_setup(before)
	else: document.mark(time,view.rig.capture(),"Pose T")
	end_edit(); refresh()

func hand_pose(angle: float) -> void:
	begin_edit()
	var before: Dictionary = view.rig.capture_setup()
	var side := "L" if selected.ends_with("_L") else "R"
	for finger in ["Index","Middle","Ring","Little","Thumb"]:
		for i in range(1,4):
			var key := "%s%d_%s" % [finger,i,side]
			view.rig.joints[key].rotation.x = angle
	if assembling: commit_setup(before)
	else: document.mark(time,view.rig.capture())
	end_edit(); refresh()

func close_loop() -> void:
	if document.data.points.is_empty(): tell("Marque a primeira pose para fechar o loop."); return
	begin_edit()
	view.rig.setup_pose(document.data.setup)
	view.rig.apply_pose(document.sample(float(document.data.points[0].time)))
	document.mark(float(document.data.length),view.rig.capture(),"Volta ao início")
	var tail := document.point_at(float(document.data.length))
	if tail >= 0: document.data.points[tail].label = "Volta ao início"
	end_edit(); refresh()

func set_duration(value: float) -> void:
	if refreshing: return
	var last := float(document.data.length)
	var tail := document.point_at(last)
	for p in document.data.points:
		if float(p.time) > value + Doc.EPS and absf(float(p.time)-last) > Doc.EPS:
			tell("Mova ou apague os pontos depois de %.2f s antes de encurtar." % value)
			refresh(); return
	if tail >= 0 and absf(value-last) > Doc.EPS and document.point_at(value) >= 0:
		tell("Já existe um ponto em %.2f s, que seria o novo fim. Mova-o antes." % value)
		refresh(); return
	begin_edit()
	document.data.length = value
	# O ponto que fechava o clipe acompanha o novo fim.
	if tail >= 0: document.move_point(last,value)
	time = minf(time,value)
	end_edit(); refresh()

func seek(value: float) -> void:
	playing = false
	time = clampf(value,0,float(document.data.length))
	refresh()

func toggle_play() -> void:
	if assembling: tell("Selecione Animar para reproduzir."); return
	playing = not playing
	if playing and time >= float(document.data.length): time = 0
	refresh()

func _process(delta: float) -> void:
	if not view or view.rig.error != "": return
	if playing:
		time += delta
		if time >= float(document.data.length):
			if bool(document.data.loop): time = fposmod(time,float(document.data.length))
			else: time = float(document.data.length); playing = false
		refresh()
	auto_time += delta
	if not testing and auto_time >= 15 and dirty():
		auto_time = 0
		var err := document.save(_recovery_path())
		if err != OK: tell("Falha ao salvar recuperação: erro %d" % err)

func dirty() -> bool:
	return JSON.stringify(document.data) != saved_state

func _recovery_path() -> String:
	return editor_dir.path_join("sessions/recovery.json")

func seed_document() -> void:
	# Um clipe novo abre e fecha na Pose T. Os dois pontos sao editaveis como
	# quaisquer outros; o que eles garantem e que a animacao nunca comeca nem
	# termina numa pose residual, e que o loop emenda sem salto.
	view.rig.setup_pose({})
	view.rig.t_pose()
	var neutral: Dictionary = view.rig.capture()
	document.mark(0,neutral,"Pose T · início")
	document.mark(float(document.data.length),neutral,"Pose T · fim")

func new_document() -> void:
	document.data = Doc.fresh()
	seed_document()
	document_path = ""
	time = 0
	playing = false
	undo_stack.clear(); redo_stack.clear()
	saved_state = JSON.stringify(document.data)
	refresh()

func load_document(path: String) -> void:
	var candidate := Doc.new()
	var error := candidate.load_file(path)
	if error != "": tell(error); return
	for track in candidate.data.tracks:
		if not view.rig.joints.has(str(track).get_slice(":",0)):
			tell("Este clipe usa um osso ausente no corpo atual: " + str(track)); return
	document.data = candidate.data
	document_path = path if path.begins_with(editor_dir.path_join("projects")+"/") else ""
	saved_state = JSON.stringify(document.data)
	time = 0; playing = false
	undo_stack.clear(); redo_stack.clear()
	refresh()
	tell("Aberto: " + path.get_file() + (" · Salvar criará uma cópia em projetos." if document_path == "" else ""))

func safe_name() -> String:
	var result := ""
	for ch in str(document.data.name).strip_edges():
		if ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-": result += ch.to_lower()
		elif ch == " ": result += "_"
	return result if result != "" else "nova_skill"

func save_document() -> void:
	if document_path == "":
		save_dialog.current_file = safe_name()+".json"
		save_dialog.popup_centered_ratio(.7)
		return
	var err := document.save(document_path)
	if err != OK: tell("Não foi possível salvar: erro %d" % err); return
	saved_state = JSON.stringify(document.data)
	if not testing and FileAccess.file_exists(_recovery_path()): DirAccess.remove_absolute(_recovery_path())
	refresh()
	tell("Salvo: " + document_path)

func export_document() -> void:
	if document.data.tracks.is_empty(): tell("Marque pelo menos um ponto antes de exportar."); return
	var path := project.path_join("assets/animations/studio_"+safe_name()+".tres")
	var err := ResourceSaver.save(document.animation(),path+".tmp.tres")
	if err == OK: err = DirAccess.rename_absolute(path+".tmp.tres",path)
	if err != OK: tell("Exportação falhou: erro %d" % err); return
	tell("Exportado: " + path.get_file() + " · No jogo: modo estilo → Teste de Animação.")

func protect(action: Callable) -> void:
	playing = false
	if not dirty(): action.call(); return
	confirm.dialog_text = "Há alterações não salvas. Continuar descarta estas alterações. Volte e use Salvar para mantê-las."
	pending_action = action
	confirm.popup_centered()

func tell(text: String) -> void:
	if status: status.text = text; status.tooltip_text = text
	print("[Studio] ",text)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		protect(func():
			if FileAccess.file_exists(_recovery_path()): DirAccess.remove_absolute(_recovery_path())
			get_tree().quit())

func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		if not event.ctrl_pressed or event.keycode in [KEY_Z,KEY_Y]: return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				if event.shift_pressed: save_dialog.popup_centered_ratio(.7)
				else: save_document()
			KEY_Z:
				if event.shift_pressed: redo()
				else: undo()
			KEY_Y: redo()
			KEY_N: protect(new_document)
			KEY_O: protect(func(): open_dialog.popup_centered_ratio(.7))
			KEY_F: filter.grab_focus()
	else:
		match event.keycode:
			KEY_SPACE: toggle_play()
			KEY_K,KEY_P: mark_point()
			KEY_DELETE: delete_point()
			KEY_LEFT: seek(time-1/30.0)
			KEY_RIGHT: seek(time+1/30.0)
			KEY_W: set_mode("position")
			KEY_E: set_mode("rotation")
			KEY_R: set_mode("scale")
			KEY_F: view.frame_selected()
