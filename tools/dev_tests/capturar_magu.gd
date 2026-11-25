extends SceneTree
var mundo: Node3D
var camera: Camera3D
func _init() -> void: _rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	root.size=Vector2i(1280,720)
	mundo=Node3D.new()
	root.add_child(mundo)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("242936")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("e5ddcf")
	env.environment.ambient_light_energy=.7
	mundo.add_child(env)
	var luz:=DirectionalLight3D.new()
	luz.rotation_degrees=Vector3(-45,-35,0)
	luz.light_energy=1.5
	mundo.add_child(luz)
	var piso:=MeshInstance3D.new()
	var malha:=PlaneMesh.new()
	malha.size=Vector2(80,80)
	piso.mesh=malha
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("504941")
	piso.material_override=mat
	mundo.add_child(piso)
	camera=Camera3D.new()
	mundo.add_child(camera)
	camera.position=Vector3(9,7,12)
	camera.look_at(Vector3(0,1.3,0))
	camera.current=true
	var visual=load("res://src/effects/magu/visual_magu.gd")
	for tipo in ["punho","onda","cao","vulcao"]:
		var no: Node3D=visual.call(tipo,visual.material())
		mundo.add_child(no)
		if tipo=="punho": no.position.y=2
		for i in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/validation/magu/%s.png" % tipo)
		no.queue_free()
		await process_frame
	quit()
