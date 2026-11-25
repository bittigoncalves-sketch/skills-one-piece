extends Node
## Authored studio clips use real node properties, isolated from legacy baked rotations.
## Plays one preview cycle, as Player.play_style_anim always has; loop is stored
## in the resource for consumers that explicitly choose continuous playback.
var animation: Animation
var actor: Node3D
var nodes: Dictionary = {}
var originals: Dictionary = {}
var sword: Node3D
var existing_sword: Node3D
var existing_visible := true
var elapsed := 0.0
var finished := false
var initial_mode: Variant

static func play(player: Node3D, clip: Animation) -> bool:
	if int(clip.get_meta("studio_version",0)) != 2: return false
	var old := player.get_node_or_null("StudioPlayback")
	if old:
		old.finish()
		player.remove_child(old)
	var playback = load("res://src/anim/StudioPlayback.gd").new()
	playback.name = "StudioPlayback"
	playback.actor = player
	playback.animation = clip
	player.add_child(playback)
	return true

func _ready() -> void:
	process_physics_priority = 1000
	initial_mode = actor.get("combat_mode")
	var model := actor.find_child("GLBModel_base",true,false) as Node3D
	if model == null:
		push_warning("StudioPlayback: este clipe requer o corpo base_v2.")
		finish()
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/base_v2/rig_manifest.json"))
	if not manifest is Dictionary:
		finish(); return
	for key in manifest.bones:
		var node := model.find_child(str(key),true,false) as Node3D
		if node: nodes[key] = node
	var setup: Dictionary = animation.get_meta("studio_setup",{})
	for key in setup:
		if str(key).begins_with("@"):
			var node := model.get_node_or_null(NodePath(str(key).substr(1))) as Node3D
			if node: nodes[key] = node
	if nodes.has("Grip_R"):
		sword = Node3D.new()
		sword.name = "StudioYoru"
		nodes.Grip_R.add_child(sword)
		var scene := load("res://assets/models/weapons/yoru_v2.glb") as PackedScene
		if scene: sword.add_child(scene.instantiate())
		sword.rotation.x = PI
		sword.scale = Vector3.ONE / maxf((nodes.Grip_R as Node3D).global_basis.get_scale().x,.001)
		sword.visible = bool(animation.get_meta("studio_weapon",true))
		nodes["Yoru"] = sword
		var candidate = actor.get("_yoru")
		if is_instance_valid(candidate):
			existing_sword = candidate
			existing_visible = existing_sword.visible
			existing_sword.visible = false
	for key in setup:
		if str(key).begins_with("$") and sword:
			var node := sword.get_node_or_null(NodePath(str(key).substr(1))) as Node3D
			if node: nodes[key] = node
	for key in nodes: originals[key] = nodes[key].transform
	actor.set_meta("studio_animation_active",true)
	apply_at(0)

func apply_at(time: float) -> void:
	var setup: Dictionary = animation.get_meta("studio_setup",{})
	for key in setup:
		if not nodes.has(key): continue
		for property in ["position","rotation","scale"]:
			if setup[key].has(property): nodes[key].set(property,_vector(setup[key][property]))
	for i in animation.get_track_count():
		var path := str(animation.track_get_path(i))
		var key := path.get_slice(":",0)
		var property := path.get_slice(":",1)
		if not nodes.has(key) or not property in ["position","rotation","scale"]: continue
		var value = animation.value_track_interpolate(i,time)
		if value is Vector3: nodes[key].set(property,value)

func _physics_process(delta: float) -> void:
	if finished: return
	if actor.get("combat_mode") != initial_mode or float(actor.get("health")) <= 0:
		finish(); return
	elapsed += delta
	apply_at(minf(elapsed,animation.length))
	if elapsed >= animation.length: finish()

static func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func finish() -> void:
	if finished: return
	finished = true
	for key in originals:
		if is_instance_valid(nodes.get(key)): nodes[key].transform = originals[key]
	if is_instance_valid(sword): sword.queue_free()
	if is_instance_valid(existing_sword): existing_sword.visible = existing_visible
	if is_instance_valid(actor): actor.remove_meta("studio_animation_active")
	queue_free()

func _exit_tree() -> void:
	if not finished: finish()
