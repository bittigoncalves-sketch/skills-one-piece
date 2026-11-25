extends Control
signal seek(time: float)
signal drag_started()
signal moved(old: float, target: float)
signal drag_finished()
const Doc = preload("res://document.gd")
var document: RefCounted
var time := 0.0
var zoom := 1.0
var offset := 0.0
var selected := -1.0
var dragging := false
var dragging_origin := -1.0
var preview := -1.0
var scrolled := false
const LEFT := 24.0

func _ready() -> void:
	custom_minimum_size.y = 112
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	tooltip_text = "Clique para ir ao tempo. Arraste um ponto para mudar quando a pose começa. Roda: zoom; Shift + roda: navegar."

func x_at(t: float) -> float:
	return LEFT + (t-offset) / float(document.data.length) * maxf(size.x-2*LEFT, 1) * zoom

func time_at(x: float) -> float:
	return clampf(Doc.snap_time(offset + (x-LEFT) / maxf(size.x-2*LEFT,1) / zoom * float(document.data.length)), 0, float(document.data.length))

func nearest(pos: Vector2) -> float:
	var best := 11.0
	var found := -1.0
	if pos.y < 30 or pos.y > 88: return found
	for p in document.data.points:
		var distance := absf(x_at(float(p.time)) - pos.x)
		if distance < best:
			best = distance
			found = float(p.time)
	return found

func _gui_input(event: InputEvent) -> void:
	if document == null: return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			if event.shift_pressed:
				offset = clampf(offset-direction*float(document.data.length)/zoom*.1,0,float(document.data.length)*(1-1/zoom))
			else:
				zoom = clampf(zoom * (1.25 if direction > 0 else .8),1,32)
				offset = minf(offset,float(document.data.length)*(1-1/zoom))
			queue_redraw()
			accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var point := nearest(event.position)
				dragging = point >= 0
				if dragging:
					dragging_origin = point
					preview = point
					selected = point
					drag_started.emit()
				seek.emit(point if dragging else time_at(event.position.x))
			else:
				if dragging:
					moved.emit(dragging_origin, preview)
					drag_finished.emit()
				dragging = false
				preview = -1
			queue_redraw()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if dragging: preview = time_at(event.position.x)
		else: seek.emit(time_at(event.position.x))
		queue_redraw()

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO,size))
	if document == null: return
	var font := ThemeDB.fallback_font
	var duration := float(document.data.length)
	var step := maxf(1.0/30, snappedf(duration / zoom / 12, 1.0/30))
	var t := floorf(offset/step)*step
	while x_at(t) <= size.x:
		var x := x_at(t)
		draw_line(Vector2(x,30),Vector2(x,size.y-10),Color("293343"))
		draw_string(font,Vector2(x+3,20),"%.2fs" % t,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("91a1b8"))
		t += step
	var points: Array = document.data.points
	for i in points.size():
		var p: Dictionary = points[i]
		var start := x_at(float(p.time))
		var end := x_at(float(points[i+1].time) if i+1 < points.size() else duration)
		var active := absf(selected-float(p.time)) < Doc.EPS
		var color := Color("f2b66d") if active else Color("63c8bf")
		if bool(p.hold):
			draw_rect(Rect2(start,48,maxf(end-start,1),20),Color(color,.14))
		else:
			draw_line(Vector2(start,66),Vector2(end,48),Color(color,.6),2)
		draw_rect(Rect2(start-5,45,10,26),color)
		if end-start > 70:
			draw_string(font,Vector2(start+10,93),str(p.label),HORIZONTAL_ALIGNMENT_LEFT,end-start-14,12,Color("bbc6d6"))
	if preview >= 0:
		draw_line(Vector2(x_at(preview),32),Vector2(x_at(preview),100),Color("f2b66d"),3)
	var cursor := x_at(time)
	draw_line(Vector2(cursor,26),Vector2(cursor,104),Color.WHITE,2)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101722")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	return style
