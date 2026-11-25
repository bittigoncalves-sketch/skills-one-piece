extends Node3D
## Kikoku cerimonial: acompanha o dorso e o porte do avatar, sem tocar no combate.
## A âncora pública das mãos usa ossos reais nos skinnados (proxies só rotacionam).

const ASSET := "res://assets/models/ope_ope/kikoku.glb"
var _player: Node3D
var _weapon: Node3D
var _time := 0.0


func setup(player: Node3D) -> void:
	_player = player
	name = "OpeKikoku"
	# Depois do Player/ProceduralAnimator, evitando um quadro de atraso da âncora.
	process_priority = 50
	visible = false


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_time += delta
	var model := _player.get("_char_model") as Node3D
	var equipped := String(_player.get("current_fruit_id")) == "ope_ope"
	visible = equipped and is_instance_valid(model) and model.is_visible_in_tree()
	if not visible:
		return
	if _weapon == null and ResourceLoader.exists(ASSET):
		var scene := load(ASSET) as PackedScene
		if scene:
			_weapon = scene.instantiate() as Node3D
			add_child(_weapon)
	if _weapon == null:
		return
	var anchor := torso_transform(_player)
	# A empunhadura repousa acima do ombro esquerdo; a lâmina desce em diagonal.
	# Rotação composta explícita: no Euler YXZ, Z depois de X não inclina -Z.
	var anim = _player.get("_proc_anim")
	var size := 0.60
	if anim:
		size *= clampf(float(anim._m.get("leg_len", 0.47)) / 0.47, 0.85, 1.15)
	var sway := sin(_time * 2.1) * 0.008
	var diagonal := Basis(Vector3.BACK, 0.60 + sway) * Basis(Vector3.RIGHT, -PI * 0.5)
	global_transform = Transform3D(anchor.basis * diagonal,
		anchor.origin + anchor.basis * Vector3(-0.38, 0.80, 0.35))
	_weapon.scale = Vector3.ONE * size


static func hand_transform(player: Node3D, side: String = "R") -> Transform3D:
	var model := player.get("_char_model") as Node3D
	var anim = player.get("_proc_anim")
	if not is_instance_valid(model) or anim == null:
		return Transform3D(player.global_basis.orthonormalized(), player.global_position + Vector3.UP * 0.45)
	var authored_grip := model.find_child("Grip_" + side, true, false) as Node3D
	if authored_grip:
		return Transform3D(authored_grip.global_basis.orthonormalized(), authored_grip.global_position)
	var role := "ForeArm_" + side
	var nodes: Dictionary = anim._n
	if not nodes.has(role):
		return Transform3D(model.global_basis.orthonormalized(), player.global_position + Vector3.UP * 0.45)
	var forearm := nodes[role] as Node3D
	var driver = anim._driver
	if driver != null and is_instance_valid(driver._skel):
		var skel: Skeleton3D = driver._skel
		var hand := -1
		var label := "RightHand" if side == "R" else "LeftHand"
		for alias in [label, "mixamorig_" + label, "mixamorig:" + label]:
			hand = skel.find_bone(alias)
			if hand >= 0:
				break
		var basis := model.global_basis.orthonormalized()
		for part in ["Torso", "UpperArm_" + side, role]:
			if nodes.has(part):
				basis *= Basis.from_euler((nodes[part] as Node3D).rotation)
		if hand >= 0:
			skel.force_update_all_bone_transforms()
			return Transform3D(basis, skel.global_transform * skel.get_bone_global_pose(hand).origin)
		if driver._bone.has(role):
			var elbow: Vector3 = skel.global_transform * skel.get_bone_global_pose(driver._bone[role]).origin
			return Transform3D(basis, elbow - basis.y * float(anim._m.get("upper_arm", 0.25)))
	var arm_length := float(anim._m.get("upper_arm", 0.25)) * 1.1
	var fore_basis := forearm.global_basis.orthonormalized()
	# Usa o punho nomeado pelo PlayerRig. A esquerda tem a mesma medida local,
	# mas não recebe item_handle porque as armas convencionais usam a direita.
	var right: Node3D = nodes.get("ForeArm_R")
	var grip := right.get_node_or_null("Hand_R") as Node3D if right else null
	if grip:
		return Transform3D(fore_basis, forearm.global_transform * grip.position)
	return Transform3D(fore_basis, forearm.global_position - fore_basis.y * arm_length)


static func torso_transform(player: Node3D) -> Transform3D:
	var model := player.get("_char_model") as Node3D
	var anim = player.get("_proc_anim")
	if not is_instance_valid(model) or anim == null or not anim._n.has("Torso"):
		return Transform3D(player.global_basis.orthonormalized(), player.global_position)
	var torso := anim._n["Torso"] as Node3D
	var driver = anim._driver
	if driver != null and driver._bone.has("Torso"):
		var skel: Skeleton3D = driver._skel
		skel.force_update_all_bone_transforms()
		var origin: Vector3 = skel.global_transform * skel.get_bone_global_pose(driver._bone["Torso"]).origin
		var basis := model.global_basis.orthonormalized() * Basis.from_euler(torso.rotation)
		return Transform3D(basis, origin)
	return Transform3D(torso.global_basis.orthonormalized(), torso.global_position)
