extends Control
signal selected(name_key: String)
signal selection_extended(name_key: String)
signal edit_started()
signal transformed(axis: int, amount: float)
signal edit_finished()
const Rig = preload("res://rig_scene.gd")
var rig: Node3D
var camera: Camera3D
var viewport: SubViewport
var overlay: Control
var current := "Torso"
var selected_members: Array = ["Torso"]
var mode := "rotation"
var show_joints := true
var yaw := PI+.55
var pitch := .18
var distance := 3.8
var target := Vector3(0,.85,0)
var axis_drag := -1
var mouse_start := Vector2.ZERO
var axis_start := Vector2.ZERO
var rotating := false
var pan := false
var hover_axis := -1
var drawn_axes: Array = []
var drawn_joints: Dictionary = {}
var rings: Array = []
var project := ""
## Shift e a excecao do editor: solta a regua durante o arraste e faz o clique
## pegar a peca exata em vez do membro inteiro.
var free_drag := false
var exact_pick := false
const COLORS := [Color("f08388"),Color("88d49c"),Color("83b2ff")]
## Passos em que a manopla gruda, na unidade que o painel mostra: graus para
## girar, metros para mover e pivo, fator para tamanho. Fonte unica -- a regua
## desenha por estes numeros e main.gd gruda nos mesmos.
const STEPS := {"rotation": 15.0, "position": 0.05, "scale": 0.05, "pivot": 0.01}
const UNITS := {"rotation": "°", "position": " m", "scale": "×", "pivot": " m"}

func build(project_path: String) -> void:
	project = project_path
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(360,300)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("18212e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8c8e2")
	environment.environment.ambient_light_energy = .65
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.5
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20,140,0)
	fill.light_color = Color("8abbd6")
	fill.light_energy = .7
	world.add_child(fill)
	_floor(world)
	rig = Rig.new()
	world.add_child(rig)
	rig.build(project)
	camera = Camera3D.new()
	camera.fov = 42
	camera.near = .01
	world.add_child(camera)
	update_camera()
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	resized.connect(func(): overlay.queue_redraw())

func _floor(world: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(20,20)
	ground.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1c2836")
	ground.material_override = mat
	ground.position.y = -.008
	world.add_child(ground)
	var grid := ImmediateMesh.new()
	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.albedo_color = Color("334052")
	grid.surface_begin(Mesh.PRIMITIVE_LINES,grid_mat)
	for i in range(-20,21):
		grid.surface_add_vertex(Vector3(i*.25,0,-5))
		grid.surface_add_vertex(Vector3(i*.25,0,5))
		grid.surface_add_vertex(Vector3(-5,0,i*.25))
		grid.surface_add_vertex(Vector3(5,0,i*.25))
	grid.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = grid
	world.add_child(lines)

func update_camera() -> void:
	camera.position = target + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)
	if overlay: overlay.queue_redraw()

func frame_selected() -> void:
	if rig.joints.has(current): target = rig.joints[current].global_position
	distance = 1.6 if current != "Yoru" else 2.8
	update_camera()

func frame_all() -> void:
	var box: AABB = rig.bounds()
	target = box.get_center()
	var aspect := maxf(size.x,1)/maxf(size.y,1)
	var half_fov := minf(deg_to_rad(camera.fov)*.5,atan(tan(deg_to_rad(camera.fov)*.5)*aspect))
	distance = maxf(2,box.size.length()*.5/sin(half_fov)*1.08)
	update_camera()

func view_preset(kind: String) -> void:
	match kind:
		"front": yaw = PI; pitch = 0
		"side": yaw = PI/2; pitch = 0
		"top": yaw = 0; pitch = 1.5
		_: yaw = PI+.55; pitch = .18
	update_camera()

## O espaco em que cada ferramenta opera de verdade, medido no rig real:
## girar e mover mexem em valores LOCAIS, que vivem no espaco do PAI; tamanho
## estica ao longo dos eixos do proprio osso. Desenhar a manopla num espaco e
## aplicar noutro faz o anel apontar para um lado e o osso girar para outro --
## visivel nos bracos, que a Pose T ja deixa girados 70,8 graus.
func tool_basis(joint: Node3D) -> Basis:
	if mode == "scale": return joint.global_basis.orthonormalized()
	var parent := joint.get_parent() as Node3D
	return parent.global_basis.orthonormalized() if parent != null else joint.global_basis.orthonormalized()

func _axis_hit(pixel: Vector2) -> int:
	var best := 12.0
	var axis := -1
	if mode == "rotation":
		for i in rings.size():
			var ring: PackedVector2Array = rings[i]
			for j in range(ring.size()-1):
				var d := pixel.distance_to(Geometry2D.get_closest_point_to_segment(pixel,ring[j],ring[j+1]))
				if d < best: best = d; axis = i
	else:
		for i in drawn_axes.size():
			var axis_points: Array = drawn_axes[i]
			var d := pixel.distance_to(Geometry2D.get_closest_point_to_segment(pixel,axis_points[0],axis_points[1]))
			if d < best: best = d; axis = i
	return axis

func _gui_input(event: InputEvent) -> void:
	if camera == null or rig.error != "": return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			distance = clampf(distance*(.87 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15),.2,15)
			update_camera()
			accept_event()
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			rotating = event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not event.shift_pressed
			pan = event.pressed and not rotating
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				axis_drag = _axis_hit(event.position)
				mouse_start = event.position
				if axis_drag >= 0:
					axis_start = drawn_axes[axis_drag][1] - drawn_axes[axis_drag][0]
					free_drag = event.shift_pressed
					edit_started.emit()
				else:
					var found := ""
					var nearest := 9.0
					if show_joints:
						for key in drawn_joints:
							var dist: float = event.position.distance_to(drawn_joints[key])
							if dist < nearest: nearest = dist; found = str(key)
					if found == "": found = rig.pick(camera,event.position)
					if found != "":
						exact_pick = event.shift_pressed
						if event.ctrl_pressed: selection_extended.emit(found)
						else: selected.emit(found)
			else:
				if axis_drag >= 0: edit_finished.emit()
				axis_drag = -1
	if event is InputEventMouseMotion:
		if rotating:
			yaw -= event.relative.x*.008
			pitch = clampf(pitch+event.relative.y*.008,-1.45,1.5)
			update_camera()
		elif pan:
			target += (-camera.global_basis.x*event.relative.x+camera.global_basis.y*event.relative.y)*distance*.0015
			update_camera()
		elif axis_drag >= 0:
			var delta: Vector2 = event.position-mouse_start
			var direction := axis_start.normalized() if axis_start.length() > 8 else Vector2(0,-1)
			var amount := delta.dot(direction)
			if mode == "rotation":
				var center: Vector2 = drawn_axes[axis_drag][0]
				amount = wrapf((event.position-center).angle()-(mouse_start-center).angle(),-PI,PI)
				var axis_vector := Vector3.ZERO
				axis_vector[axis_drag] = 1
				if camera.global_basis.z.dot(tool_basis(rig.joints[current]) * axis_vector) < 0: amount *= -1
			elif mode == "scale": amount = 1.0+amount/100.0
			else:
				var parent_scale: Vector3 = rig.joints[current].get_parent().global_basis.get_scale()
				amount = amount/maxf(axis_start.length(),8)*distance*.12/maxf(parent_scale[axis_drag],.001)
			free_drag = event.shift_pressed
			transformed.emit(axis_drag,amount)
		else:
			hover_axis = _axis_hit(event.position)
			mouse_default_cursor_shape = Control.CURSOR_DRAG if hover_axis >= 0 else Control.CURSOR_ARROW
			overlay.queue_redraw()

func _draw_overlay() -> void:
	if not rig or not rig.joints.has(current): return
	drawn_joints.clear()
	if show_joints:
		for key in rig.joints:
			var node: Node3D = rig.joints[key]
			if camera.is_position_behind(node.global_position): continue
			var pixel := camera.unproject_position(node.global_position)
			drawn_joints[key] = pixel
			var parent := node.get_parent() as Node3D
			if parent and rig.joints.values().has(parent):
				overlay.draw_line(pixel,camera.unproject_position(parent.global_position),Color("f2b66d") if selected_members.has(key) else Color(.45,.8,.8,.3),1)
			overlay.draw_circle(pixel,4 if selected_members.has(key) else 2,Color("f2b66d") if selected_members.has(key) else Color(.5,.9,.87,.65))
	var joint: Node3D = rig.joints[current]
	if camera.is_position_behind(joint.global_position): return
	var center := camera.unproject_position(joint.global_position)
	var length := distance*.12
	drawn_axes.clear()
	rings.clear()
	for i in 3:
		var axis := Vector3.ZERO
		axis[i] = 1
		var basis := tool_basis(joint)
		var tip := camera.unproject_position(joint.global_position+basis*axis*length)
		drawn_axes.append([center,tip])
		var color: Color = COLORS[i].lightened(.3) if i == hover_axis or i == axis_drag else COLORS[i]
		if mode == "rotation":
			var ring := PackedVector2Array()
			for j in 65:
				var v := Vector3.ZERO
				v[(i+1)%3] = cos(j*TAU/64)*length*.8
				v[(i+2)%3] = sin(j*TAU/64)*length*.8
				ring.append(camera.unproject_position(joint.global_position+basis*v))
			rings.append(ring)
			overlay.draw_polyline(ring,color,3 if i == hover_axis else 2,true)
		else:
			overlay.draw_line(center,tip,color,4,true)
			if mode == "scale": overlay.draw_rect(Rect2(tip-Vector2(5,5),Vector2(10,10)),color)
			else:
				var d := (tip-center).normalized()
				var n := Vector2(-d.y,d.x)
				overlay.draw_colored_polygon(PackedVector2Array([tip+d*5,tip-d*9+n*5,tip-d*9-n*5]),color)
		var text_pixel: Vector2 = tip + Vector2(7,-5)
		overlay.draw_string(ThemeDB.fallback_font,text_pixel,["X","Y","Z"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	overlay.draw_circle(center,5,Color("f2b66d"))
	_draw_ruler(joint,center)
	overlay.draw_string(ThemeDB.fallback_font,Vector2(16,26),"%s  ·  %s" % [current,{"position":"Mover","rotation":"Girar","scale":"Tamanho","pivot":"Pivô"}[mode]],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5edf8"))
	overlay.draw_string(ThemeDB.fallback_font,Vector2(16,size.y-14),"Direito: orbitar   ·   Meio: deslocar vista   ·   Roda: zoom   ·   Shift: solta a régua e pega a peça exata",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("9cacc2"))

## Quantos pixels de arraste valem uma unidade do painel, no eixo em edicao.
## Espelha a conta do arraste em _gui_input -- se uma mudar, a outra tem de mudar.
func _pixels_per_unit(joint: Node3D) -> float:
	if mode == "scale": return 100.0
	var parent := joint.get_parent() as Node3D
	if parent == null: return 0.0
	var parent_scale: Vector3 = parent.global_basis.get_scale()
	return maxf(axis_start.length(),8.0)*maxf(parent_scale[axis_drag],.001)/maxf(distance*.12,.0001)

## A regua: aparece durante o arraste, no eixo que esta sendo puxado, marcando
## os valores em que a manopla gruda. Com Shift as marcas somem, porque ali o
## valor e livre.
func _draw_ruler(joint: Node3D, center: Vector2) -> void:
	if axis_drag < 0 or not STEPS.has(mode): return
	var step: float = STEPS[mode]
	var raw: float = rig.displayed(current,mode)[axis_drag]
	var shown := rad_to_deg(raw) if mode == "rotation" else raw
	var tint: Color = COLORS[axis_drag]
	var font := ThemeDB.fallback_font
	if not free_drag:
		if mode == "rotation": _draw_ring_ticks(joint,step,tint)
		else: _draw_axis_ticks(joint,center,step,shown,tint)
	var digits := 1 if mode == "rotation" else (2 if mode == "scale" else 3)
	var text := ("%." + str(digits) + "f%s") % [shown,UNITS[mode]]
	if free_drag: text += "  livre"
	elif absf(shown-snappedf(shown,step)) < step*.02: text += "  ·"
	var box := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18)
	var at := center + Vector2(18,-18)
	overlay.draw_rect(Rect2(at-Vector2(6,box.y-2),box+Vector2(12,8)),Color("101722cc"))
	overlay.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE if free_drag else tint.lightened(.45))

func _draw_ring_ticks(joint: Node3D, step: float, tint: Color) -> void:
	var basis := tool_basis(joint)
	var length := distance*.12
	var angle := 0.0
	while angle < 360.0:
		var strong := absf(angle-snappedf(angle,90.0)) < .01
		var inner := .70 if strong else .76
		var c := cos(deg_to_rad(angle))
		var sn := sin(deg_to_rad(angle))
		var a := Vector3.ZERO
		var b := Vector3.ZERO
		a[(axis_drag+1)%3] = c*length*inner; a[(axis_drag+2)%3] = sn*length*inner
		b[(axis_drag+1)%3] = c*length*.88;   b[(axis_drag+2)%3] = sn*length*.88
		if not camera.is_position_behind(joint.global_position+basis*b):
			overlay.draw_line(camera.unproject_position(joint.global_position+basis*a),
				camera.unproject_position(joint.global_position+basis*b),
				Color(tint,.9 if strong else .5),2.0 if strong else 1.0)
		angle += step

func _draw_axis_ticks(joint: Node3D, center: Vector2, step: float, shown: float, tint: Color) -> void:
	var per_unit := _pixels_per_unit(joint)
	if per_unit <= 0: return
	var direction := (Vector2(drawn_axes[axis_drag][1])-center)
	if direction.length() < 8: return
	direction = direction.normalized()
	var perpendicular := Vector2(-direction.y,direction.x)
	var font := ThemeDB.fallback_font
	for n in range(-5,6):
		var value := snappedf(shown,step) + n*step
		var offset := (value-shown)*per_unit
		if absf(offset) > maxf(size.x,size.y): continue
		var at := center + direction*offset
		var strong := absf(value-snappedf(value,step*4)) < step*.02
		overlay.draw_line(at-perpendicular*(7 if strong else 4),at+perpendicular*(7 if strong else 4),
			Color(tint,.9 if strong else .45),2.0 if strong else 1.0)
		if strong and absf(value) > step*.5:
			overlay.draw_string(font,at+perpendicular*11+Vector2(-10,4),"%.2f" % value,
				HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(tint,.75))
