extends Node3D
const Doc = preload("res://document.gd")
var joints: Dictionary = {}
var categories: Dictionary = {}
var rest: Dictionary = {}
var reference: Dictionary = {}
var visuals: Dictionary = {}
var body: Node3D
var sword: Node3D
var error := ""

func build(project: String) -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(project.path_join("assets/models/base_v2/rig_manifest.json")))
	if not manifest is Dictionary or not manifest.has("bones"):
		error = "Não foi possível ler o inventário do corpo atual."
		return
	body = load_glb(project.path_join("assets/models/base_v2/base_v2_runtime.glb"))
	if body == null: return
	add_child(body)
	# Same 1.5 m player height; the sword remains in world metres.
	body.scale = Vector3.ONE * (1.5 / 1.9775)
	for name_key in manifest.bones:
		var joint := body.find_child(str(name_key), true, false) as Node3D
		if joint == null:
			error = "O corpo atual não contém a articulação " + str(name_key)
			return
		joints[name_key] = joint
		categories[name_key] = manifest.bones[name_key].get("category", "body")
	var weapon_model := load_glb(project.path_join("assets/models/weapons/yoru_v2.glb"))
	if weapon_model == null: return
	sword = Node3D.new()
	sword.name = "Yoru"
	joints.Grip_R.add_child(sword)
	sword.add_child(weapon_model)
	sword.rotation.x = PI
	sword.scale = Vector3.ONE / body.scale.x
	joints["Yoru"] = sword
	categories["Yoru"] = "weapon"
	_collect_visuals(body)
	for key in joints: rest[key] = transform_data(joints[key])
	for key in visuals: rest[key] = transform_data(visuals[key])
	_build_t_reference()
	_add_collisions(body)

func _build_t_reference() -> void:
	# The source GLB has an A pose. Derive a horizontal T from its actual joints.
	# Keep the source rest and exported values intact; only the inspector's zero changes.
	for side in ["L","R"]:
		var direction := Vector3.LEFT if side == "L" else Vector3.RIGHT
		for pair in [["UpperArm_","ForeArm_"],["ForeArm_","Wrist_"],["Wrist_","Hand_"]]:
			var joint: Node3D = joints[pair[0]+side]
			var child: Node3D = joints[pair[1]+side]
			_aim(joint,child,joint.global_position+direction)
	for key in joints: reference[key] = transform_data(joints[key])
	setup_pose({})

func t_pose() -> void:
	for key in joints:
		for prop in ["position","rotation","scale"]:
			joints[key].set(prop,Doc.vector(reference[key][prop]))

func displayed(key: String, property: String) -> Vector3:
	var prop := "position" if property == "pivot" else property
	var actual: Vector3 = joints[key].get(prop)
	var base := Doc.vector(reference[key][prop])
	return actual/base if prop == "scale" else actual-base

func absolute_value(key: String, property: String, value: Vector3) -> Vector3:
	var prop := "position" if property == "pivot" else property
	var base := Doc.vector(reference[key][prop])
	return value*base if prop == "scale" else value+base

func load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var code := doc.append_from_file(path, state)
	if code != OK:
		error = "Não foi possível carregar " + path.get_file() + " (erro %d)" % code
		return null
	return doc.generate_scene(state) as Node3D

func _collect_visuals(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D and not joints.values().has(child):
			var key := "$" + str(sword.get_path_to(child)) if sword.is_ancestor_of(child) else "@" + str(body.get_path_to(child))
			visuals[key] = child
		_collect_visuals(child)

func guard_pose() -> void:
	# Same two-bone geometry and grip targets as the game's YoruRig guard.
	var desired := body.global_basis.orthonormalized() * Basis(Vector3.RIGHT,-.644)
	var handle := body.to_global(Vector3(.04,1.4,-.36))
	_arm("R",handle,desired*Basis(Vector3.RIGHT,PI))
	sword.global_basis = desired
	sword.global_position = joints.Grip_R.global_position
	_arm("L",sword.global_position+desired*Vector3(0,-.17,0),desired*Basis(Vector3.RIGHT,PI))
	for side in ["L","R"]:
		for finger in ["Index","Middle","Ring","Little"]:
			for i in range(1,4): joints["%s%d_%s" % [finger,i,side]].rotation.x = -.65

func _arm(side: String, target: Vector3, wrist_basis: Basis) -> void:
	var upper: Node3D = joints["UpperArm_"+side]
	var lower: Node3D = joints["ForeArm_"+side]
	var wrist: Node3D = joints["Wrist_"+side]
	var grip: Node3D = joints["Grip_"+side]
	var scale_before := wrist.global_basis.get_scale()
	var wrist_target := target-wrist_basis*(wrist.to_local(grip.global_position)*scale_before)
	var origin := upper.global_position
	var l1 := origin.distance_to(lower.global_position)
	var l2 := lower.global_position.distance_to(wrist.global_position)
	var axis := (wrist_target-origin).normalized()
	var distance := clampf(origin.distance_to(wrist_target),absf(l1-l2)+.00001,l1+l2-.00001)
	var projection := (l1*l1-l2*l2+distance*distance)/(2*distance)
	var pole := body.global_basis.orthonormalized()*Vector3(-1 if side == "L" else 1,-.65,.15)
	var bend := (pole-axis*pole.dot(axis)).normalized()
	var elbow := origin+axis*projection+bend*sqrt(maxf(0,l1*l1-projection*projection))
	_aim(upper,lower,elbow)
	_aim(lower,wrist,origin+axis*distance)
	wrist.global_basis = wrist_basis.scaled(scale_before)

func _aim(parent: Node3D, child: Node3D, target: Vector3) -> void:
	var a := (child.global_position-parent.global_position).normalized()
	var b := (target-parent.global_position).normalized()
	if a.length_squared() > .5 and b.length_squared() > .5:
		parent.global_basis = Basis(Quaternion(a,b))*parent.global_basis

func _add_collisions(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		node.create_trimesh_collision()
	for child in node.get_children():
		if not child is StaticBody3D: _add_collisions(child)

static func transform_data(node: Node3D) -> Dictionary:
	return {"position": Doc.array(node.position), "rotation": Doc.array(node.rotation), "scale": Doc.array(node.scale)}

func resolve(key: String) -> Node3D:
	return joints.get(key, visuals.get(key))

func setup_pose(overrides: Dictionary) -> void:
	for key in rest:
		var node := resolve(key)
		var info: Dictionary = overrides.get(key, rest[key])
		for prop in ["position", "rotation", "scale"]:
			if info.has(prop): node.set(prop, Doc.vector(info[prop]))

func apply_pose(values: Dictionary) -> void:
	for path in values:
		var name_key := str(path).get_slice(":", 0)
		var property := str(path).get_slice(":", 1)
		if joints.has(name_key) and property in ["position", "rotation", "scale"]:
			joints[name_key].set(property, Doc.vector(values[path]))

func capture() -> Dictionary:
	var pose: Dictionary = {}
	for key in joints:
		for prop in ["position", "rotation", "scale"]:
			pose[str(key)+":"+prop] = Doc.array(joints[key].get(prop))
	return pose

func capture_setup() -> Dictionary:
	var result: Dictionary = {}
	for key in rest: result[key] = transform_data(resolve(key))
	return result

func move_pivot(key: String, position: Vector3) -> void:
	var node: Node3D = joints[key]
	var shift := node.basis.inverse() * (position - node.position)
	for child in node.get_children():
		if child is Node3D: child.position -= shift
	node.position = position

func pick(camera: Camera3D, pixel: Vector2) -> String:
	var origin := camera.project_ray_origin(pixel)
	var end := origin + camera.project_ray_normal(pixel) * 100
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return ""
	var current: Node = hit.collider
	while current and current != self:
		for key in joints:
			if joints[key] == current: return str(key)
		current = current.get_parent()
	return ""

func bounds() -> AABB:
	var result := AABB()
	var first := true
	for node in find_children("*","MeshInstance3D",true,false):
		if not node.is_visible_in_tree(): continue
		var box: AABB = node.global_transform * node.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
