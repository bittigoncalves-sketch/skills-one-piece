extends SceneTree
const Main = preload("res://main.gd")
const Doc = preload("res://document.gd")
const Selection = preload("res://selection.gd")
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
	var rig: Node3D = app.view.rig
	var zero := true
	for key in rig.joints:
		zero = zero and rig.displayed(key,"rotation").is_zero_approx()
		zero = zero and rig.displayed(key,"position").is_zero_approx()
		zero = zero and rig.displayed(key,"scale").is_equal_approx(Vector3.ONE)
	check(zero,"T pose has zero rotation/distance and unit scale for every joint and sword")
	for side in ["L","R"]:
		var shoulder: Vector3 = rig.joints["UpperArm_"+side].global_position
		var elbow: Vector3 = rig.joints["ForeArm_"+side].global_position
		var wrist: Vector3 = rig.joints["Wrist_"+side].global_position
		check(absf(shoulder.y-elbow.y)<.0001 and absf(shoulder.y-wrist.y)<.0001,"T arm "+side+" is actually horizontal, not only labelled zero")
	app.select_parts(["#arm_R"],true)
	check(app.selected_roots==["UpperArm_R"],"whole arm transforms at shoulder root")
	check(app.view.selected_members.has("Index3_R") and app.view.selected_members.has("Yoru"),"arm group includes fingers and attached sword")
	check(not app.view.selected_members.has("Thigh_R"),"arm group excludes the leg")
	var hand_before: Vector3 = rig.joints.Hand_R.global_position
	var foot_before: Vector3 = rig.joints.Foot_R.global_position
	var elbow_local: Transform3D = rig.joints.ForeArm_R.transform
	app.set_mode("rotation")
	app.change_value(2,90)
	check(absf(app.values[2].value-90)<.001,"+90 degrees shown relative to T")
	check(rig.joints.Hand_R.global_position.distance_to(hand_before)>.2,"rotating arm group moves whole hand")
	check(rig.joints.ForeArm_R.transform.is_equal_approx(elbow_local),"child is not rotated twice")
	check(rig.joints.Foot_R.global_position.is_equal_approx(foot_before),"unselected leg remains still")
	app.seek(.5)
	app.change_value(2,-90)
	check(absf(app.values[2].value+90)<.001,"-90 degrees shown and retained")
	app.seek(0)
	check(absf(app.values[2].value-90)<.001,"first point retains +90")
	app.seek(.5)
	check(absf(app.values[2].value+90)<.001,"second point retains -90")
	app.set_mode("position")
	app.change_value(0,-.125)
	check(absf(app.values[0].value+.125)<.0001,"negative distance entered in metres")
	app.set_mode("scale")
	app.change_value(1,1.5)
	check(absf(app.values[1].value-1.5)<.0001,"size uses explicit 1.5x factor")
	app.document_path = "/tmp/studio-selection.json"
	app.save_document()
	app.new_document()
	app.load_document("/tmp/studio-selection.json")
	app.select_parts(["#arm_R"],true)
	app.seek(.5)
	check(absf(app.values[1].value-1.5)<.0001,"size survives save and reload")
	app.set_mode("position")
	check(absf(app.values[0].value+.125)<.0001,"negative distance survives save and reload")
	app.set_mode("rotation")
	check(absf(app.values[2].value+90)<.001,"negative degrees survive save and reload")
	var exported := app.document.animation()
	var track := exported.find_track(NodePath("UpperArm_R:rotation"),Animation.TYPE_VALUE)
	var expected: Vector3 = rig.joints.UpperArm_R.rotation
	check((exported.value_track_interpolate(track,.5) as Vector3).is_equal_approx(expected),"export retains actual rotations for game compatibility")
	app.new_document()
	app.select_parts(["#arms","ForeArm_R"],true)
	check(app.selected_roots.size()==2 and not app.selected_roots.has("ForeArm_R"),"mixed parent/child selection is deduplicated")
	app.set_mode("position")
	app.change_value(2,.2)
	check(absf(rig.displayed("UpperArm_R","position").z-.2)<.0001 and absf(rig.displayed("UpperArm_L","position").z-.2)<.0001,"both arms move in one operation")
	app.undo()
	check(rig.displayed("UpperArm_R","position").is_zero_approx() and rig.displayed("UpperArm_L","position").is_zero_approx(),"undo restores both arms together")
	app.select_parts(["#leg_L"],true)
	check(app.view.selected_members.has("BigToe2_L") and not app.view.selected_members.has("Foot_R"),"whole leg includes its foot and toes")
	app.select_parts(["#head"],true)
	check(app.view.selected_members.has("Head") and app.view.selected_members.has("Jaw"),"head group includes neck and facial parts")
	app.filter.text = "braço"
	check(app.bone_items.has("#arms") and app.bone_items.has("#arm_R"),"body-part groups are searchable")
	app.group_filter.select(2)
	app.populate_bones()
	app.select_bone("Foot_R")
	await process_frame
	await process_frame
	check(app.filter.text=="" and app.group_filter.selected==0,"selecting a foot by name clears filters that would hide it")
	var item: TreeItem = app.bone_items.Foot_R
	check(item.is_selected(0),"the named foot is selected in left tree")
	var rect := app.bones.get_item_area_rect(item)
	check(rect.position.y>=0 and rect.end.y<=app.bones.size.y,"tree automatically scrolls to reveal the foot")
	app.bone_items.Torso.collapsed = true
	app.select_bone("BigToe2_L")
	await process_frame
	await process_frame
	item = app.bone_items.BigToe2_L
	var parent := item.get_parent()
	var expanded := true
	while parent:
		expanded = expanded and not parent.collapsed
		parent = parent.get_parent()
	check(expanded,"hidden ancestors expand to reveal selected toe")
	app.select_parts(["#arms"],true)
	app.set_mode("rotation")
	app.change_value(2,25)
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("/tmp/anim-selection.png")==OK,"group selection screenshot")
	# --- o clique no 3D pega o membro inteiro; a arvore e o Shift pegam a peca ---
	app.filter.set_text(""); app.group_filter.select(0); app.populate_bones()
	app.view.exact_pick = false
	for pair in [["ForeArm_R","#arm_R","Braço direito inteiro"],
			["Index2_R","#arm_R","Braço direito inteiro"],
			["Hand_L","#arm_L","Braço esquerdo inteiro"],
			["Shin_L","#leg_L","Perna esquerda inteira"],
			["BigToe2_R","#leg_R","Perna direita inteira"],
			["Head","#head","Cabeça e pescoço"]]:
		app.view.selected.emit(pair[0])
		check(app.selected_tokens == [pair[1]] and app.selection_label.text == pair[2],
			"clicking %s in 3D selects %s" % [pair[0],pair[2]])
	app.view.selected.emit("Torso")
	check(app.selected_tokens == ["Torso"],"a bone outside any limb selects itself")
	app.view.selected.emit("Yoru")
	check(app.selected_tokens == ["Yoru"],"clicking the sword selects the sword, not the right arm")
	app.view.exact_pick = true
	app.view.selected.emit("ForeArm_R")
	check(app.selected_tokens == ["ForeArm_R"],"shift-clicking in 3D selects the exact piece")
	app.view.exact_pick = false
	app.select_bone("ForeArm_R")
	check(app.selected_tokens == ["ForeArm_R"],"the tree always selects the exact piece")
	app.view.selected.emit("ForeArm_R")
	check(app.view.rig.joints.has(app.selected_roots[0]) and app.selected_roots == ["UpperArm_R"],
		"the whole-limb selection roots at the upper arm")
	app.queue_free()
	await process_frame
	print("SELECTION TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
