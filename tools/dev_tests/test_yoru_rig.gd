extends SceneTree
class Fixture extends Node3D:
	var _char_model: Node3D
	var _yoru_combat: Node

func _init() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var p := Fixture.new()
	world.add_child(p)
	p._char_model = CharacterBuilder.build_character("base").node
	p.add_child(p._char_model)
	var bounds := PlayerModelKit.model_aabb(p._char_model)
	var scale_factor := 1.5 / bounds.size.y
	p._char_model.scale = Vector3.ONE*scale_factor
	var hand: Node3D = p._char_model.find_child("Weapon_R",true,false)
	hand.rotation.x = PI
	var sword := YoruSword.ligar_na_mao(hand)
	var rig := YoruRig.new()
	rig.setup(p,sword)
	var failures := 0
	for id in ["","M1_1","M1_2","Z","X","C","V"]:
		var worst := 0.0
		var worst_right := 0.0
		var lowest := 100.0
		for i in 121:
			var t := YoruMoves.duration(id)*i/120.0
			rig.pose(id,t,Vector3.FORWARD)
			worst = maxf(worst,rig.grip_error)
			var target := p._char_model.to_global(Vector3(YoruRig.sample(id,t).handle))
			worst_right = maxf(worst_right,target.distance_to(sword.global_position))
			lowest = minf(lowest,sword.ponta.global_position.y)
		print("RIG %s left=%.5f right=%.5f tip_min=%.4f" % [id,worst,worst_right,lowest])
		if worst > 0.03 or worst_right > 0.03: failures += 1
	print("YORU RIG failures=",failures)
	quit(0 if failures == 0 else 1)
