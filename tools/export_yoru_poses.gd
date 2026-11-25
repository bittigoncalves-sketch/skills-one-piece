extends SceneTree
class Fixture extends Node3D:
	var _char_model: Node3D
func _init() -> void:
	await process_frame
	var p := Fixture.new()
	root.add_child(p)
	p._char_model = CharacterBuilder.build_character("base").node
	p.add_child(p._char_model)
	var factor := 1.5/PlayerModelKit.model_aabb(p._char_model).size.y
	p._char_model.scale = Vector3.ONE*factor
	var hand: Node3D = p._char_model.find_child("Weapon_R",true,false)
	hand.rotation.x = PI
	var sword := YoruSword.ligar_na_mao(hand)
	var rig := YoruRig.new()
	rig.setup(p,sword)
	var source := JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/base_v2/rig_manifest.json")) as Dictionary
	var names: Dictionary = source.bones
	var result := {"fps":30,"actions":{}}
	for id in ["M1_1","M1_2","Z","X","C","V"]:
		var frames: Array = []
		for i in int(ceil(YoruMoves.duration(id)*30))+1:
			var t := minf(float(i)/30.0,YoruMoves.duration(id))
			rig.pose(id,t,Vector3.FORWARD)
			var bones := {}
			for name in names:
				if not rig.nodes.has(name): continue
				var node: Node3D = rig.nodes[name]
				var transform := p._char_model.global_transform.affine_inverse()*node.global_transform
				var b := transform.basis
				var o := transform.origin
				bones[name] = [b.x.x,b.y.x,b.z.x,o.x,b.x.y,b.y.y,b.z.y,o.y,b.x.z,b.y.z,b.z.z,o.z,0,0,0,1]
			var weapon_transform := p._char_model.global_transform.affine_inverse()*sword.global_transform
			var wb := weapon_transform.basis
			var wo := weapon_transform.origin
			bones["__sword"] = [wb.x.x,wb.y.x,wb.z.x,wo.x,wb.x.y,wb.y.y,wb.z.y,wo.y,wb.x.z,wb.y.z,wb.z.z,wo.z,0,0,0,1]
			frames.append(bones)
		result.actions[id] = frames
	DirAccess.make_dir_recursive_absolute("res://art_src/animations")
	var file := FileAccess.open("res://art_src/animations/yoru_poses.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("YORU poses exportadas: ",result.actions.size())
	quit()
