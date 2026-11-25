extends SceneTree
## Run after studio/test_studio.gd, which exports a round-trip fixture to /tmp.
const Playback = preload("res://src/anim/StudioPlayback.gd")
var failures := 0

class Actor extends Node3D:
	var _yoru: Node3D
	var combat_mode := "style"
	var health := 100.0

func check(value: bool, text: String) -> void:
	print("PASS " if value else "FAIL ",text)
	if not value: failures += 1

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	var model: Node3D = CharacterBuilder.build_character("base").node
	actor.add_child(model)
	model.scale = Vector3.ONE*(1.5/1.9775)
	var existing := Node3D.new()
	actor.add_child(existing)
	actor._yoru = existing
	var clip := ResourceLoader.load("/tmp/studio-roundtrip.tres","Animation",ResourceLoader.CACHE_MODE_IGNORE) as Animation
	check(clip != null,"studio export loads in GAME project")
	if not clip: quit(1); return
	var toe := model.find_child("BigToe2_L",true,false) as Node3D
	var before := toe.transform
	check(Playback.play(actor,clip),"tagged animation selects dedicated playback")
	var playback := actor.get_node("StudioPlayback")
	playback.set_physics_process(false)
	check(playback.nodes.size() >= 127,"all 126 bones and Yoru resolve")
	check(not existing.visible,"original weapon hidden during preview")
	check(playback.sword.get_parent() == model.find_child("Grip_R",true,false),"preview sword attached to actual grip")
	var setup: Dictionary = clip.get_meta("studio_setup")
	var missing: Array = []
	for key in setup:
		if not playback.nodes.has(key): missing.append(key)
	check(missing.is_empty(),"all assembly and weapon mesh paths resolve: %s" % [missing])
	var worst := 0.0
	for t in [0.0,.2,.599,.6,1.0,1.9]:
		playback.apply_at(t)
		for i in clip.get_track_count():
			var path := str(clip.track_get_path(i))
			var node: Node3D = playback.nodes[path.get_slice(":",0)]
			var actual: Vector3 = node.get(path.get_slice(":",1))
			var expected: Vector3 = clip.value_track_interpolate(i,t)
			worst = maxf(worst,actual.distance_to(expected))
	check(worst < .0001,"game applies position/rotation/scale literally, max error %.8f" % worst)
	var samples: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/studio-world.json"))
	var world_error := 0.0
	for key_time in samples:
		playback.apply_at(float(key_time))
		for key in samples[key_time]:
			var node: Node3D = playback.nodes[key]
			var transform := node.global_transform
			var actual := [transform.origin,transform.basis.x,transform.basis.y,transform.basis.z]
			for i in 4:
				var expected := Playback._vector(samples[key_time][key][i])
				world_error = maxf(world_error,actual[i].distance_to(expected))
	check(world_error < .0001,"GAME world poses match independently loaded EDITOR body and sword: %.8f" % world_error)
	playback.finish()
	check(toe.transform.is_equal_approx(before),"extra bone restored after preview")
	check(existing.visible,"original weapon visibility restored")
	check(not actor.has_meta("studio_animation_active"),"preview state cleared")
	await process_frame
	check(not Playback.play(actor,Animation.new()),"legacy animation stays on original playback path")
	check(Playback.play(actor,clip),"another authored preview starts after cleanup")
	var next := actor.get_node("StudioPlayback")
	actor.combat_mode = "sword"
	next._physics_process(.01)
	check(next.finished and existing.visible,"changing combat mode cancels preview and restores weapon")
	await process_frame
	actor.queue_free()
	await process_frame
	print("STUDIO RUNTIME: %d failures" % failures)
	quit(1 if failures else 0)
