extends SceneTree
func _init() -> void: executar.call_deferred()
func executar() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var cena := Node3D.new()
	root.add_child(cena)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("263746")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("c5d7e4")
	ambiente.environment.ambient_light_energy = .55
	cena.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45,-30,0)
	luz.light_energy = 1.6
	luz.shadow_enabled = true
	cena.add_child(luz)
	var pao: Node3D = load("res://assets/models/alimentacao/pao_rustico.glb").instantiate()
	pao.position = Vector3(-.28,.03,0)
	pao.rotation_degrees.y = 12
	cena.add_child(pao)
	var agua: Node3D = load("res://assets/models/alimentacao/garrafa_agua.glb").instantiate()
	agua.position = Vector3(.25,.10,0)
	cena.add_child(agua)
	var chao := MeshInstance3D.new()
	chao.mesh = PlaneMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("344959")
	chao.material_override = material
	cena.add_child(chao)
	var camera := Camera3D.new()
	cena.add_child(camera)
	camera.position = Vector3(.15,.65,1.15)
	camera.look_at(Vector3(0,.08,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.12
	camera.make_current()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/alimentacao/00_assets.png")
	print("ASSETS_ALIMENTACAO: captura Godot gravada")
	cena.queue_free()
	for i in 3: await process_frame
	quit()
