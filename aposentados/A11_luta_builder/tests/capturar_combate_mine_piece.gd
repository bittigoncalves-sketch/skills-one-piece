extends SceneTree
## Player real como observador: nunca captura mouse. Renderiza antes/contato/final.
const PASTA := "res://art_src/validation/combate_mine_piece/"
var p: Node3D
var mundo: Node3D

func _init() -> void:
	_rodar.call_deferred()

func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA + nome + ".png")

func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1100, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	mundo = Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("303846")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	mundo.add_child(env)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-40, -25, 0)
	luz.shadow_enabled = true
	mundo.add_child(luz)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(20, 20)
	chao.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("485263")
	chao.material_override = material
	mundo.add_child(chao)
	p = load("res://Player.gd").new()
	p.name = "2"
	p.set_multiplayer_authority(2)
	mundo.add_child(p)
	p.set_physics_process(false)
	p.position = Vector3(0, 0.9, 0)
	p.current_fruit_id = KitDoBuilder.ID_ESTILO_BASE
	p._char_model.rotation.y = 0
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.position = Vector3(4.0, 2.4, -4.5)
	cam.look_at(Vector3(0, 1.0, -0.65))
	cam.current = true
	cam.fov = 42
	for i in 30:
		p._proc_anim.update(Vector3.ZERO, true, false, 1.0/60, 0)
		await process_frame
	await _foto("00_repouso")
	for tecla in ["Z", "X", "C"]:
		var e := ExecutorDeSkill.lancar(mundo, p, KitDoBuilder.skill(tecla, KitDoBuilder.ID_ESTILO_BASE), Vector3.FORWARD)
		e.set_physics_process(false)
		if tecla != "C": e.soltar()
		for i in 190:
			if is_instance_valid(e) and not e.is_queued_for_deletion(): e._physics_process(1.0/60)
			p._proc_anim.update(Vector3.ZERO, true, false, 1.0/60, 0)
			await process_frame
			if (tecla == "Z" and i in [1, 6, 17]) or (tecla == "X" and i in [8, 27, 38]) or (tecla == "C" and i in [36, 60, 158]):
				await _foto(tecla + "_" + str(i).pad_zeros(3))
		await _foto(tecla + "_fim")
	print("Capturas em ", PASTA, "; mouse visível: ", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	quit()
