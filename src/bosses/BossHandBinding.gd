class_name BossHandBinding
extends RefCounted
## Malhas derivadas no plano do punho; o GLB original permanece intacto.
var view: Node3D
var attached: MeshInstance3D
var flying: MeshInstance3D
var valid := false
var _bone := -1

func setup(owner_view: Node3D) -> void:
	view = owner_view
	var data = view.actor.definition.detached_part
	if data == null:
		return
	var source := view.model.find_child(str(data.source_mesh), true, false) as MeshInstance3D
	_bone = view.skeleton.find_bone(str(data.bone_name))
	if source == null or _bone < 0 or source.skin == null:
		push_error("Binding da mão direita: malha de origem ausente")
		return
	attached = MeshInstance3D.new()
	attached.name = "RightHandAttached"
	attached.mesh = data.attached_mesh
	attached.skin = source.skin
	source.get_parent().add_child(attached)
	attached.transform = source.transform
	attached.skeleton = attached.get_path_to(view.skeleton)
	source.mesh = data.remaining_mesh
	flying = MeshInstance3D.new()
	flying.name = "RightHandDetached"
	flying.mesh = data.detached_mesh
	view.add_child(flying)
	flying.top_level = true
	flying.visible = false
	valid = true

func wrist_transform() -> Transform3D:
	return view.skeleton.global_transform * view.skeleton.get_bone_global_pose(_bone)

func present() -> void:
	if not valid:
		return
	var actor: Node3D = view.actor
	var separated: bool = actor.part_state != "attached" and not actor.dead
	attached.visible = not separated
	flying.visible = separated
	if separated:
		flying.global_transform = actor.part_transform
