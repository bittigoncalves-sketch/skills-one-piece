extends SceneTree
const Doc = preload("res://document.gd")
const Main = preload("res://main.gd")
const View = preload("res://view.gd")
var failures := 0
var checks := 0

func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ",text)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var app := Main.new()
	app.testing = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await physics_frame
	await process_frame
	check(app.view.rig.error == "","real GLBs load")
	check(app.view.rig.joints.size() == 127,"126 real joints plus Yoru")
	check(app.view.rig.sword.get_parent() == app.view.rig.joints.Grip_R,"sword attached to actual right grip")
	check(app.view.rig.joints.BigToe2_L.global_position.z < 0,"front is -Z")
	check(app.view.rig.joints.Head.global_position.y > 1,"head above ground")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "/tmp/anim-studio.png"
		check(root.get_texture().get_image().save_png(path) == OK,"screenshot " + path)
	var editor := app.editor_dir
	var count := 0
	for file in DirAccess.get_files_at(editor.path_join("clips")):
		if file.ends_with(".json") and file != "index.json":
			var doc := Doc.new()
			var error := doc.load_file(editor.path_join("clips/"+file))
			check(error == "","legacy import " + file + " " + error)
			count += 1
	check(count == 33,"all 33 legacy clips inspected")
	app.select_bone("UpperArm_R")
	app.set_mode("rotation")
	app.change_value(0,0)
	var before: Vector3 = app.view.rig.sword.global_position
	app.change_value(0,45)
	check(app.view.rig.sword.global_position.distance_to(before) > .02,"moving arm carries the sword")
	check(app.document.point_at(0) == 0,"changing rotation creates point")
	app.seek(.5)
	app.change_value(0,90)
	app.seek(1)
	app.change_value(0,-15)
	check(app.document.data.points.size() == 4,"three authored poses plus the seeded closing point")
	check(absf(app.document.sample(.5)["UpperArm_R:rotation"][0]-PI/2)<.0001,"exact middle boundary uses NEW point")
	check(absf(app.document.sample(.25)["UpperArm_R:rotation"][0]-PI*3/8)<.0001,"a new point interpolates by default")
	app.begin_edit(); app.document.transition(0,true); app.end_edit()
	check(absf(app.document.sample(.49)["UpperArm_R:rotation"][0]-PI/4)<.0001,"hold lasts until middle point")
	app.begin_edit(); app.document.transition(0,false); app.end_edit()
	check(absf(app.document.sample(.25)["UpperArm_R:rotation"][0]-PI*3/8)<.0001,"smooth transition interpolates")
	app.begin_edit(); app.relocate_point(.5,.6); app.end_edit()
	check(app.document.point_at(.6)>=0 and app.document.point_at(.5)<0,"moving point updates time")
	check(not app.document.move_point(.6,1),"point collisions refused")
	app.undo()
	check(app.document.point_at(.5)>=0,"undo restores point time")
	app.redo()
	check(app.document.point_at(.6)>=0,"redo restores move")
	app.seek(1)
	var history_count: int = app.undo_stack.size()
	app.start_drag()
	app.drag_transform(1,.2)
	app.drag_transform(1,.4)
	app.end_edit()
	check(app.undo_stack.size() == history_count+1,"whole drag is one undo operation")
	app.undo()
	app.assembling = true
	app.set_mode("pivot")
	app.refresh()
	var child: Node3D = app.view.rig.joints.ForeArm_R
	var child_before := child.global_transform
	var arm: Node3D = app.view.rig.joints.UpperArm_R
	app.change_value(0,arm.position.x+.05)
	check(child.global_transform.is_equal_approx(child_before),"pivot movement preserves child world transform")
	check(not app.document.data.setup.is_empty(),"rig adjustments stored in document")
	var before_drag: float = app.document.data.tracks["UpperArm_R:position"][0][1][0]
	app.view.free_drag = true
	app.start_drag(); app.drag_transform(0,.01); app.drag_transform(0,.02); app.end_edit()
	app.view.free_drag = false
	check(absf(float(app.document.data.tracks["UpperArm_R:position"][0][1][0])-before_drag-.02)<.00001,"assembly drag rebases keys once, without accumulating intermediate deltas")
	app.undo()
	var montage: Dictionary = app.document.data.setup.duplicate(true)
	app.document_path = "/tmp/studio-roundtrip.json"
	app.save_document()
	var loaded := Doc.new()
	check(loaded.load_file(app.document_path) == "","saved project reloads")
	var same_setup: bool = loaded.data.setup.size() == montage.size()
	for key in montage:
		for prop in montage[key]:
			same_setup = same_setup and Doc.vector(loaded.data.setup[key][prop]).is_equal_approx(Doc.vector(montage[key][prop]))
	check(same_setup,"setup survives round trip")
	check(loaded.data.tracks.size()==381,"all joint and sword position/rotation/scale channels persist")
	var anim := loaded.animation()
	check(anim.get_track_count()==381,"all 127 objects export all transform properties")
	check(anim.has_meta("studio_setup"),"export includes assembly")
	var track := anim.find_track(NodePath("UpperArm_R:rotation"),Animation.TYPE_VALUE)
	var actual: Vector3 = anim.value_track_interpolate(track,.6)
	check(absf(actual.x-PI/2)<.0001,"export exact middle point matches editor")
	check(ResourceSaver.save(anim,"/tmp/studio-roundtrip.tres")==OK,"Godot resource saved")
	var reread := ResourceLoader.load("/tmp/studio-roundtrip.tres","Animation",ResourceLoader.CACHE_MODE_IGNORE) as Animation
	check(reread != null and reread.get_track_count()==381,"Godot resource reloads")
	var world_samples: Dictionary = {}
	for t in [0.0,.2,.599,.6,1.0,1.9]:
		app.view.rig.setup_pose(loaded.data.setup)
		app.view.rig.apply_pose(loaded.sample(t))
		var poses: Dictionary = {}
		for key in app.view.rig.joints:
			var transform: Transform3D = app.view.rig.joints[key].global_transform
			poses[key] = [Doc.array(transform.origin),Doc.array(transform.basis.x),Doc.array(transform.basis.y),Doc.array(transform.basis.z)]
		world_samples[str(t)] = poses
	check(Doc.save_json("/tmp/studio-world.json",world_samples)==OK,"independent editor world poses recorded for runtime comparison")
	app.assembling = false
	app.document.data.loop = false
	app.time = 1.99; app.playing = true
	app._process(.05)
	check(not app.playing and app.time == 2.0,"loop OFF stops at end")
	app.document.data.loop = true
	app.time = 1.99; app.playing = true
	app._process(.05)
	check(app.playing and absf(app.time-.04)<.0001,"loop ON preserves elapsed remainder")
	app.playing = false
	app.filter.text = "mão"
	check(app.bones.get_root().get_child_count()>0,"Portuguese search finds hands")
	app.filter.text = ""
	var dims := app.size
	check(app.view.size.x>=360 and app.view.size.y>=300,"viewport has usable dimensions: %s" % app.view.size)
	check(app.timeline.global_position.y+app.timeline.size.y <= dims.y,"timeline stays inside window")
	app.playing = true
	app.loop_button.button_pressed = false
	check(app.playing and not app.document.data.loop,"loop checkbox changes playback without pausing")
	app.playing = false
	app.seek(.6)
	var x: float = app.timeline.x_at(.6)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = Vector2(x,55)
	app.timeline._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT; motion.position = Vector2(app.timeline.x_at(.8),55)
	app.timeline._gui_input(motion)
	press.pressed = false; press.position = motion.position
	app.timeline._gui_input(press)
	check(app.document.point_at(.8)>=0,"mouse drag on timeline moves full point")
	app.undo()
	app.assembling = true
	app.set_mode("pivot")
	app.select_bone("Yoru")
	var sword_child: Node3D = app.view.rig.sword.get_child(0)
	var sword_before := sword_child.global_transform
	app.change_value(0,app.view.rig.sword.position.x+.1)
	check(sword_child.global_transform.is_equal_approx(sword_before),"Yoru pivot preserves sword geometry")
	app.refresh()
	check(sword_child.global_transform.is_equal_approx(sword_before),"Yoru pivot survives refresh")
	app.assembling = false
	app.select_bone("Torso")
	app.modes.position.pressed.emit()
	check(app.transform_mode=="position","Mover button selects the correct tool")
	await process_frame
	await process_frame
	if app.view.drawn_axes.size() == 3:
		var axis: Array = app.view.drawn_axes[0]
		var grab: Vector2 = axis[1]
		check(app.view._axis_hit(grab)==0,"X handle is selectable")
		var old_position: Vector3 = app.view.rig.joints.Torso.position
		press.pressed = true; press.position = grab
		app.view._gui_input(press)
		motion.position = grab+(Vector2(axis[1])-Vector2(axis[0])).normalized()*20
		app.view._gui_input(motion)
		press.pressed = false; press.position = motion.position
		app.view._gui_input(press)
		check(app.view.rig.joints.Torso.position.x>old_position.x,"mouse drag on 3D X handle moves the joint")
		app.undo()
	else: check(false,"gizmos drawn for interaction test")
	app.modes.rotation.pressed.emit()
	check(app.transform_mode=="rotation","Girar button selects the correct tool")
	app.modes.scale.pressed.emit()
	check(app.transform_mode=="scale","Tamanho button selects the correct tool")
	app.new_document()
	check(app.document.data.points.size() == 2,"a new clip is seeded with two points")
	check(app.document.point_at(0) >= 0,"the seeded clip opens on a point")
	check(app.document.point_at(float(app.document.data.length)) >= 0,"the seeded clip closes on a point")
	var t_rest: Array = app.view.rig.reference["UpperArm_R"]["rotation"]
	var at_start: Array = app.document.sample(0)["UpperArm_R:rotation"]
	var at_end: Array = app.document.sample(float(app.document.data.length))["UpperArm_R:rotation"]
	check(Doc.vector(at_start).is_equal_approx(Doc.vector(t_rest)),"the clip opens on the T pose")
	check(Doc.vector(at_end).is_equal_approx(Doc.vector(t_rest)),"the clip closes on the T pose")
	app.seek(float(app.document.data.length))
	app.select_bone("UpperArm_R"); app.set_mode("rotation")
	app.change_value(0,30)
	check(app.document.data.points.size() == 2,"the closing point is editable like any other")
	check(absf(app.document.sample(float(app.document.data.length))["UpperArm_R:rotation"][0]-Doc.vector(t_rest).x-deg_to_rad(30))<.0001,"editing the closing point keeps it in place")
	app.new_document()
	app.set_duration(1.0)
	check(app.document.point_at(1.0) >= 0 and app.document.data.points.size() == 2,"shortening the clip drags the closing point along")
	app.set_duration(3.0)
	check(app.document.point_at(3.0) >= 0 and app.document.data.points.size() == 2,"lengthening the clip drags the closing point along")
	app.seek(2.0); app.change_value(0,20)
	app.set_duration(1.0)
	check(absf(float(app.document.data.length)-3.0)<.0001,"an authored point after the new end still blocks shortening")
	app.seek(3.0); app.delete_point()
	app.set_duration(2.5)
	check(absf(float(app.document.data.length)-2.5)<.0001,"duration still moves once the closing point is deleted")
	app.new_document()
	# --- a regua: o arraste gruda nos passos, Shift solta, digitar e livre ---
	app.new_document()
	check(not bool(app.document.data.weapon) and not app.view.rig.sword.visible,"a new clip starts without the sword")
	app.weapon_button.set_pressed(true)
	check(bool(app.document.data.weapon) and app.view.rig.sword.visible,"the sword is an option that can be switched on")
	app.new_document()
	app.select_bone("UpperArm_R")
	for probe in [[37.0,30.0],[43.0,45.0],[-8.0,-15.0],[100.0,105.0]]:
		app.set_mode("rotation")
		app.view.free_drag = false
		app.start_drag(); app.drag_transform(0,deg_to_rad(probe[0])); app.end_edit()
		var landed: float = rad_to_deg(app.view.rig.displayed("UpperArm_R","rotation").x)
		check(absf(landed-probe[1])<.001,"dragging %.0f degrees lands on %.0f" % [probe[0],probe[1]])
		app.neutral_pose()
	app.set_mode("rotation")
	app.view.free_drag = true
	app.start_drag(); app.drag_transform(0,deg_to_rad(37.0)); app.end_edit()
	check(absf(rad_to_deg(app.view.rig.displayed("UpperArm_R","rotation").x)-37.0)<.001,"shift frees the ruler")
	app.view.free_drag = false
	app.neutral_pose()
	app.set_mode("position")
	app.start_drag(); app.drag_transform(1,.13); app.end_edit()
	check(absf(app.view.rig.displayed("UpperArm_R","position").y-.15)<.0001,"moving lands on a 5 cm step")
	app.neutral_pose()
	app.set_mode("scale")
	app.start_drag(); app.drag_transform(0,1.23); app.end_edit()
	check(absf(app.view.rig.displayed("UpperArm_R","scale").x-1.25)<.0001,"resizing lands on a 0.05 step")
	app.neutral_pose()
	app.set_mode("rotation")
	app.change_value(0,37.0)
	check(absf(rad_to_deg(app.view.rig.displayed("UpperArm_R","rotation").x)-37.0)<.001,"typing a value is never snapped")
	for tool_name in ["rotation","position","scale","pivot"]:
		check(View.STEPS.has(tool_name) and View.UNITS.has(tool_name),"the ruler covers the %s tool" % tool_name)
	app.new_document()
	# --- a manopla tem de apontar para onde a peca realmente se mexe ---
	# Girar e mover agem em valores locais (espaco do PAI); tamanho estica nos
	# eixos do proprio osso. Os bracos sao o caso critico: a Pose T ja os deixa
	# girados, e desenhar no espaco errado poe o anel verde deitado.
	app.new_document()
	for bone in ["UpperArm_R","UpperArm_L","ForeArm_R","Torso","Thigh_L"]:
		var node: Node3D = app.view.rig.joints[bone]
		for tool_name in ["rotation","scale","position"]:
			var worst := 1.0
			for axis in 3:
				var unit := Vector3.ZERO
				unit[axis] = 1.0
				app.select_bone(bone); app.set_mode(tool_name); app.neutral_pose()
				var drawn: Vector3 = (app.view.tool_basis(node) * unit).normalized()
				var moved := Vector3.ZERO
				if tool_name == "rotation":
					var rest_basis: Basis = node.global_basis.orthonormalized()
					app.change_value(axis,5.0)
					var turn := Quaternion(rest_basis.inverse() * node.global_basis.orthonormalized())
					moved = (rest_basis * Vector3(turn.x,turn.y,turn.z)).normalized()
				elif tool_name == "scale":
					var tip_before: Vector3 = node.global_transform * unit - node.global_position
					app.change_value(axis,2.0)
					moved = ((node.global_transform * unit - node.global_position) - tip_before).normalized()
				else:
					var where: Vector3 = node.global_position
					app.change_value(axis,0.2)
					moved = (node.global_position - where).normalized()
				worst = minf(worst,absf(moved.dot(drawn)))
				app.neutral_pose()
			check(worst > .999,"the %s handle on %s points where the bone actually moves (%.3f)" % [tool_name,bone,worst])
	app.new_document()
	var stepped := Doc.new()
	stepped.data.length = 1.0
	stepped.mark(0.0,{"UpperArm_R:rotation":[0,0,0]})
	stepped.mark(1.0,{"UpperArm_R:rotation":[PI/2,0,0]})
	stepped.transition(0.0,true)
	var stepped_anim := stepped.animation()
	var stepped_track := stepped_anim.find_track(NodePath("UpperArm_R:rotation"),Animation.TYPE_VALUE)
	check(stepped_anim.track_get_key_count(stepped_track)==3,"a held point exports its shadow key instead of merging into the next")
	for probe in [.25,.5,.75,.9]:
		var in_editor: float = stepped.sample(probe)["UpperArm_R:rotation"][0]
		var in_game: float = stepped_anim.value_track_interpolate(stepped_track,probe).x
		check(absf(in_editor-in_game)<.0001,"held pose reads the same mid-segment at %.2fs: editor %.3f, game %.3f" % [probe,in_editor,in_game])
	check(ResourceSaver.save(stepped_anim,"/tmp/studio-stepped.tres")==OK,"held clip saved")
	var stepped_read := ResourceLoader.load("/tmp/studio-stepped.tres","Animation",ResourceLoader.CACHE_MODE_IGNORE) as Animation
	var read_track := stepped_read.find_track(NodePath("UpperArm_R:rotation"),Animation.TYPE_VALUE)
	check(absf(stepped_read.value_track_interpolate(read_track,.5).x)<.0001,"the hold survives the round trip through disk")
	var eased := Doc.new()
	eased.data.length = 1.0
	eased.mark(0.0,{"UpperArm_R:rotation":[0,0,0]})
	eased.mark(1.0,{"UpperArm_R:rotation":[PI/2,0,0]})
	var eased_anim := eased.animation()
	var eased_track := eased_anim.find_track(NodePath("UpperArm_R:rotation"),Animation.TYPE_VALUE)
	check(absf(eased_anim.value_track_interpolate(eased_track,.5).x-PI/4)<.0001,"a default point ramps in the game too")
	var valid_data: String = JSON.stringify(app.document.data)
	Doc.save_json("/tmp/studio-invalid.json",{"name":"bad","length":-1,"tracks":{}})
	check(app.document.load_file("/tmp/studio-invalid.json")!="" and JSON.stringify(app.document.data)==valid_data,"invalid project rejected without losing current work")
	app.queue_free()
	await process_frame
	print("STUDIO TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
