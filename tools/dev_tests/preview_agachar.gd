extends SceneTree
## Prévia do Player real sem autoridade local: nunca captura mouse.
## Salva comparação em art_src/previews/agachar_{antes,depois,andando}.png.
var p

func _init() -> void:
	call_deferred("_rodar")

func _rodar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("#263342")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color("#b5c8e0")
	ambiente.environment.ambient_light_energy = 0.65
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, -35, 0)
	luz.shadow_enabled = true
	luz.light_energy = 1.5
	mundo.add_child(luz)
	var piso := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(200, 200)
	piso.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#47515d")
	piso.material_override = mat
	mundo.add_child(piso)
	p = load("res://Player.gd").new()
	p.name = "PreviewAgachar"
	p.set_multiplayer_authority(999)
	p.colisor_capsula = true
	mundo.add_child(p)
	p.position = Vector3(0, 0.8, 0)
	p.set_physics_process(false)
	p.set_process_input(false)
	p.set_process_unhandled_input(false)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.3
	mundo.add_child(cam)
	cam.position = Vector3(3.4, 1.8, -4.5)
	cam.look_at(Vector3(0, 0.85, 0))
	cam.make_current()
	p.net_on_floor = true
	for i in 50:
		p._remote_process(1.0 / 60.0)
	await capturar("antes")
	p.net_agachado = true
	for i in 50:
		p._remote_process(1.0 / 60.0)
	await capturar("depois")
	p.net_velocity = Vector3(0, 0, -1.26)
	for i in 25:
		p._remote_process(1.0 / 60.0)
	await capturar("andando")
	quit()

func capturar(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var destino := "res://art_src/previews/agachar_%s.png" % nome
	var erro := root.get_texture().get_image().save_png(destino)
	print("CAPTURA %s: %s" % [destino, erro])
