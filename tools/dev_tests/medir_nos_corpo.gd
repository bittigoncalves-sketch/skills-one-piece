extends SceneTree
const Corpo := preload("res://src/player/corpo_historia.gd")
func _init() -> void:
	var c: Node3D = Corpo.construir("masculino", "medio", {})["node"]
	root.add_child(c)
	for n in ["Head", "Chest", "Torso", "UpperArm_L", "ForeArm_L", "Hand_L", "Thigh_L", "Shin_L", "Foot_L"]:
		var no := c.find_child(n, true, false) as Node3D
		if no == null:
			print(n, " ausente"); continue
		var ab := AABB(); var primeiro := true
		for m: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
			if m.get_parent() != no and not (m.get_parent().get_parent() == no): continue
			var a := (no.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
			ab = a if primeiro else ab.merge(a); primeiro = false
		print(n, " global=", no.global_position, " aabb_local=", ab)
	quit()
