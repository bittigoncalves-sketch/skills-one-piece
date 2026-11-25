extends SceneTree
## Checks imported geometry, axes, skin/node equivalence and existing combat clips.
var failures := 0

func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _init() -> void:
	await process_frame
	var model := CharacterBuilder.build_character("base")["node"] as Node3D
	root.add_child(model)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/base_v2/rig_manifest.json"))
	var definitions: Dictionary = manifest.bones
	var box := PlayerModelKit.model_aabb(model)
	check(absf(box.size.y - 1.9775) < .015, "reference height and ground plane: %s" % box)
	check(box.position.y >= -.001 and box.position.y < .02, "feet above ground at rest")
	var rigged := load("res://assets/models/base_v2/base_v2_rigged.glb").instantiate() as Node3D
	root.add_child(rigged)
	var skeleton := BodyScanner._find_skeleton(rigged)
	check(skeleton != null and skeleton.get_bone_count() == 134, "134 imported skeleton bones")
	var max_rest_error := 0.0
	var max_axis_error := 0.0
	for name in definitions:
		var joint := model.find_child(name, true, false) as Node3D
		if joint == null:
			check(false, "missing joint " + name)
			continue
		var p: Array = definitions[name].head
		var expected := Vector3(p[0], p[2], -p[1])
		max_rest_error = maxf(max_rest_error, joint.global_position.distance_to(expected))
		max_axis_error = maxf(max_axis_error, joint.global_basis.x.distance_to(Vector3.RIGHT))
		max_axis_error = maxf(max_axis_error, joint.global_basis.y.distance_to(Vector3.UP))
		var index := skeleton.find_bone(name)
		if index < 0:
			check(false, "missing skeleton bone " + name)
		if index >= 0:
			var actual := skeleton.global_transform * skeleton.get_bone_global_rest(index).origin
			max_rest_error = maxf(max_rest_error, actual.distance_to(expected))
	check(max_rest_error < .0001, "both exports match authored pivots, max error %.7f m" % max_rest_error)
	check(max_axis_error < .0001, "runtime joint axes match game axes")
	var profile := BodyScanner.scan(model)
	var missing_legacy: Array = []
	for role in BodyScanner.ROLES:
		if not profile.nodes.has(role):
			missing_legacy.append(role)
	check(missing_legacy.is_empty(), "all 13 legacy animation roles resolved: %s" % [missing_legacy])
	# The detailed chain (spine, shoulder girdle, wrist/hand/fingers, forefoot)
	# has to reach the animator as roles, or RigDetalhado silently does nothing.
	var missing_detail: Array = []
	for role in RigDetalhado.PAPEIS:
		if not profile.nodes.has(role):
			missing_detail.append(role)
	check(missing_detail.is_empty(), "%d detailed rig roles resolved: %s" % [RigDetalhado.PAPEIS.size(), missing_detail])
	check(profile.nodes.size() == BodyScanner.ROLES.size() + RigDetalhado.PAPEIS.size(),
		"profile carries exactly the legacy plus the detailed roles: %d" % profile.nodes.size())
	# A legacy voxel body must stay on 13 - the detailed layer is opt-in by anatomy.
	var legacy := CharacterBuilder.build_character("buggy")["node"] as Node3D
	root.add_child(legacy)
	check(BodyScanner.scan(legacy).nodes.size() == 13, "legacy voxel rig still resolves 13 roles only")
	legacy.free()
	var legacy_ap := CharacterBuilder._find_anim_player(model)
	check(legacy_ap.has_animation("idle") and legacy_ap.has_animation("run") and legacy_ap.has_animation("punching"),
		"training dummy animation library preserved")
	check((profile.nodes.UpperArm_R as Node3D).global_position.x > 0, "right arm on +X")
	check((profile.nodes.Foot_L as Node3D).global_position.x < 0, "left foot on -X")
	# Independently apply the demonstration pose in game axes. The GLB animation
	# was baked through bone rest matrices in Blender; compare all joint positions.
	for side in ["L", "R"]:
		for digit in ["Index", "Middle", "Ring", "Little"]:
			for j in range(1, 4):
				(model.find_child("%s%d_%s" % [digit, j, side], true, false) as Node3D).rotation.x = .95 if j == 1 else 1.2
	var pose := {"UpperArm_R": Vector3(.7, 0, .2), "ForeArm_R": Vector3(1.3, 0, 0),
		"Wrist_R": Vector3(0, -.25, 0), "Clavicle_R": Vector3(0, 0, .1),
		"SpineMid": Vector3(0, -.18, 0), "Head": Vector3(0, .18, 0)}
	for name in pose:
		(model.find_child(name, true, false) as Node3D).rotation = pose[name]
	var ap := CharacterBuilder._find_anim_player(rigged)
	check(ap != null, "GLB includes demonstration AnimationPlayer")
	if ap:
		var demo := ""
		for name in ap.get_animation_list():
			if "Rig_Demonstracao" in name:
				demo = name
		check(not demo.is_empty(), "demonstration clip imported")
		if not demo.is_empty():
			ap.play(demo)
			# Export keeps Blender's frame-1 time at 1/30 s (no negative-time slide).
			ap.seek(41.0 / 30.0, true)
			skeleton.force_update_all_bone_transforms()
			var error := 0.0
			for name in definitions:
				var idx := skeleton.find_bone(name)
				if idx < 0:
					continue
				var point := skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin
				var proxy := model.find_child(name, true, false) as Node3D
				if point.distance_to(proxy.global_position) > .002:
					print("POSE DIFFERENCE ", name, " ", point.distance_to(proxy.global_position))
				error = maxf(error, point.distance_to(proxy.global_position))
			check(error < .002, "posed skeleton matches runtime FK, max error %.7f m" % error)
	for name in definitions:
		(model.find_child(name, true, false) as Node3D).rotation = Vector3.ZERO
	var finger := model.find_child("Index3_R", true, false) as Node3D
	var before := finger.global_position
	(model.find_child("Index1_R", true, false) as Node3D).rotation.x = 1.1
	check(finger.global_position.distance_to(before) > .025, "finger curls independently")
	(model.find_child("Index1_R", true, false) as Node3D).rotation = Vector3.ZERO
	var animator := ProceduralAnimator.new()
	model.add_child(animator)
	animator.setup(profile)
	var wrist := model.find_child("Grip_R", true, false) as Node3D
	before = wrist.global_position
	for i in 45:
		animator.update(Vector3(0, 0, -4.2), true, false, 1.0/60.0, 0, false)
	check(wrist.global_position.distance_to(before) > .03, "walking moves the actual hand/socket")
	animator.play_baked(load("res://assets/animations/kicking.res"))
	var foot := model.find_child("Foot_R", true, false) as Node3D
	before = foot.global_position
	var travel := 0.0
	for i in 60:
		animator.update(Vector3.ZERO, true, false, 1.0/60.0, 0, false)
		travel = maxf(travel, foot.global_position.distance_to(before))
	check(travel > .1, "existing kicking clip moves the actual foot")
	check(PlayerModelKit.model_aabb(model).size.length() < 4, "animated body remains finite and bounded")
	model.free()
	rigged.free()
	print("BASE V2: %d failures" % failures)
	quit(1 if failures else 0)
