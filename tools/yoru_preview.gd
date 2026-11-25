extends SceneTree
class Fixture extends Node3D:
	var _char_model: Node3D
	var _yoru_combat: Node
func _init() -> void:
	await process_frame
	root.size = Vector2i(1280,900)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101a26")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("adbaca")
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-30,0)
	light.light_energy = 2.3
	light.shadow_enabled = true
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15,145,0)
	fill.light_color = Color("92c5b1")
	fill.light_energy = 1.5
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.4,2.0,-5.2)
	camera.look_at(Vector3(0,1.05,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.2
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(100,100)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("253443")
	floor_mesh.material_override = mat
	world.add_child(floor_mesh)
	var p := Fixture.new()
	world.add_child(p)
	p._char_model = CharacterBuilder.build_character("base").node
	p.add_child(p._char_model)
	var bounds := PlayerModelKit.model_aabb(p._char_model)
	var factor := 1.5/bounds.size.y
	p._char_model.scale = Vector3.ONE*factor
	p._char_model.position.y = -factor*bounds.position.y
	var socket: Node3D = p._char_model.find_child("Weapon_R",true,false)
	socket.rotation.x = PI
	var sword := YoruSword.ligar_na_mao(socket)
	var rig := YoruRig.new()
	rig.setup(p,sword)
	var label := Label.new()
	label.position = Vector2(40,35)
	label.add_theme_font_size_override("font_size",25)
	root.add_child(label)
	DirAccess.make_dir_recursive_absolute("res://art_src/previews/yoru_combat")
	for id in ["","M1_1","M1_2","Z","X","C","V"]:
		var m := YoruMoves.get_move(id)
		var t := float(m.get("startup",0.0))+float(m.get("active",0.0))*0.52
		rig.pose(id,t,Vector3.FORWARD)
		label.text = "YORU  /  " + str(m.get("name","Guarda")) + "\nRig base • duas pegas • sem VFX"
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/previews/yoru_combat/"+(id if id != "" else "guard")+".png")
	quit()
