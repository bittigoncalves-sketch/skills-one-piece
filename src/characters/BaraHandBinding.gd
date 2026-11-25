extends RefCounted
## Partes visuais do Player. O combate fornece somente lado e transform global.
## Não recorta geometria em runtime e não depende de componentes do Boss.
const BUGGY_LEFT := "res://assets/models/bara_bara/hands/buggy_left/"
const BUGGY_RIGHT := "res://assets/models/bosses/buggy/detached/"

var valid := false
var reason := "Binding ainda não preparado."
var model: Node3D
var _actor: Node3D
var _skeleton: Skeleton3D
var _parts: Array[Dictionary] = []

func setup(actor: Node3D) -> bool:
	var current := actor.get("_char_model") as Node3D if is_instance_valid(actor) else null
	if valid and actor == _actor and is_instance_valid(model) and current == model:
		return true
	dispose()
	_actor = actor
	model = current
	if not is_instance_valid(model):
		reason = "O avatar ainda não possui modelo."
		return false
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
	if _skeleton and _skeleton.find_bone("L_Hand") >= 0 and model.find_child("tripo_part_9", true, false):
		for side in 2:
			if not _bind_buggy(side):
				var failure := reason
				dispose()
				reason = failure
				return false
	else:
		for side in 2:
			if not _bind_node_hand(side):
				var failure := reason
				dispose()
				reason = failure
				return false
	valid = true
	reason = ""
	return true

func socket(side: int) -> Transform3D:
	if not _usable(side):
		return Transform3D.IDENTITY
	var part := _parts[side]
	if part.has("bone"):
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(part.bone)
	return (part.socket as Node3D).global_transform

func present(side: int, detached: bool, world_transform: Transform3D) -> void:
	if not _usable(side):
		return
	var part := _parts[side]
	var flying := part.flying as Node3D
	# Nunca deixar transforms não finitos contaminarem o renderer inteiro.
	if detached and not world_transform.is_finite():
		detached = false
	for original in part.originals:
		var mesh := original.node as MeshInstance3D
		if is_instance_valid(mesh):
			mesh.visible = bool(original.visible) and not detached
	flying.visible = detached
	if not detached:
		return
	flying.global_transform = world_transform
	if part.has("copies"):
		# A hierarquia original continua recebendo animação e fornece o encaixe.
		# Só as geometrias autoradas da mão voam; armas/itens não são duplicados.
		var local_from_world := socket(side).affine_inverse()
		for pair in part.copies:
			var original := pair.source as MeshInstance3D
			var copy := pair.copy as MeshInstance3D
			copy.transform = local_from_world * original.global_transform
			copy.material_override = original.material_override
			copy.material_overlay = original.material_overlay

func restore() -> void:
	for part in _parts:
		for original in part.originals:
			if is_instance_valid(original.node):
				(original.node as MeshInstance3D).visible = bool(original.visible)
		if is_instance_valid(part.flying):
			(part.flying as Node3D).visible = false

func dispose() -> void:
	restore()
	for part in _parts:
		if part.has("source") and is_instance_valid(part.source):
			(part.source as MeshInstance3D).mesh = part.source_mesh
		for created in part.created:
			if is_instance_valid(created) and not created.is_queued_for_deletion():
				created.queue_free()
	_parts.clear()
	valid = false
	model = null
	_actor = null
	_skeleton = null
	reason = "Binding liberado."

func _usable(side: int) -> bool:
	return valid and side >= 0 and side < _parts.size() and is_instance_valid(model) \
		and not model.is_queued_for_deletion() and is_instance_valid(_parts[side].flying)

func _new_flying(side: int) -> Node3D:
	var flying := Node3D.new()
	flying.name = "BaraDetachedHandL" if side == 0 else "BaraDetachedHandR"
	model.add_child(flying)
	flying.top_level = true
	flying.visible = false
	return flying

func _bind_node_hand(side: int) -> bool:
	var suffix := "L" if side == 0 else "R"
	var hand := model.find_child("Hand_" + suffix, true, false) as Node3D
	# Um socket de arma com nome Hand_R não é uma mão anatômica separável.
	if hand == null or hand.find_child("Geo_Palm_" + suffix + "_Runtime", true, false) == null:
		reason = "O avatar não possui malhas de mão separáveis preparadas para Bara Bara."
		return false
	var flying := _new_flying(side)
	var originals: Array[Dictionary] = []
	var copies: Array[Dictionary] = []
	for node in hand.find_children("Geo_*_Runtime", "MeshInstance3D", true, false):
		var source := node as MeshInstance3D
		if source.mesh == null or source.skin != null:
			continue
		var copy := MeshInstance3D.new()
		copy.name = source.name
		copy.mesh = source.mesh
		copy.material_override = source.material_override
		copy.material_overlay = source.material_overlay
		copy.cast_shadow = source.cast_shadow
		for surface in source.mesh.get_surface_count():
			copy.set_surface_override_material(surface, source.get_surface_override_material(surface))
		flying.add_child(copy)
		copy.transform = hand.global_transform.affine_inverse() * source.global_transform
		copy.visible = source.visible
		originals.append({"node": source, "visible": source.visible})
		copies.append({"source": source, "copy": copy})
	_parts.append({"socket": hand, "originals": originals, "copies": copies,
		"flying": flying, "created": [flying]})
	return not copies.is_empty()

func _bind_buggy(side: int) -> bool:
	var left := side == 0
	var source := model.find_child("tripo_part_9" if left else "tripo_part_8", true, false) as MeshInstance3D
	var bone := _skeleton.find_bone("L_Hand" if left else "R_Hand")
	if source == null or source.skin == null or bone < 0:
		reason = "Binding do Buggy sem malha ou osso da mão."
		return false
	var prefix := (BUGGY_LEFT + "left") if left else (BUGGY_RIGHT + "right")
	var remaining := load(prefix + "_arm.res") as ArrayMesh
	var attached_mesh := load(prefix + "_hand_attached.res") as ArrayMesh
	var detached_mesh := load(prefix + "_hand_rigid.res") as ArrayMesh
	if remaining == null or attached_mesh == null or detached_mesh == null:
		reason = "Malhas derivadas do Buggy indisponíveis."
		return false
	var attached := MeshInstance3D.new()
	attached.name = "BaraAttachedHandL" if left else "BaraAttachedHandR"
	attached.mesh = attached_mesh
	attached.skin = source.skin
	attached.material_override = source.material_override
	attached.cast_shadow = source.cast_shadow
	source.get_parent().add_child(attached)
	attached.transform = source.transform
	attached.skeleton = attached.get_path_to(_skeleton)
	attached.visible = source.visible
	var flying := _new_flying(side)
	var rigid := MeshInstance3D.new()
	rigid.mesh = detached_mesh
	rigid.material_override = source.material_override
	rigid.cast_shadow = source.cast_shadow
	flying.add_child(rigid)
	var original_mesh := source.mesh
	source.mesh = remaining
	_parts.append({"bone": bone, "source": source, "source_mesh": original_mesh,
		"originals": [{"node": attached, "visible": attached.visible}],
		"flying": flying, "created": [attached, flying]})
	return true
