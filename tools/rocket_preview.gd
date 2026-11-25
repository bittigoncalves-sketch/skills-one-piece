extends SceneTree
## Sem --capture: arena jogável com a Rocket equipada e controles originais.
const SAIDA := "res://art_src/validation/rocket"
const CASA := Vector3(0,100.82,0)
var ator: Node3D
var alvo: Node3D
var camera: Camera3D
var identidade := 9000

func _init() -> void:
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	var prazo := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < prazo:
		await process_frame
		for p in get_nodes_in_group("player"):
			if p.is_multiplayer_authority(): ator = p
		if is_instance_valid(ator) and ator.get("_proc_anim") != null: break
	if not is_instance_valid(ator):
		push_error("Rocket: jogador não nasceu")
		quit(2)
		return
	await _esperar(0.7)
	ator.equip_fruit("rocket")
	ator.combat_mode = "fruit"
	var hud := get_first_node_in_group("hud")
	if hud: hud.update_combat_mode("fruit", ator.estilo_atual(), "rocket")
	print("ROCKET — Z Punch | X Crash | C Barrage | V Overdrive")
	if not "--capture" in OS.get_cmdline_user_args(): return
	create_timer(70).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(SAIDA)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for p in get_nodes_in_group("dummy"):
		p.set_physics_process(false)
		p.global_position = CASA + Vector3(40,0,0)
		if alvo == null: alvo = p
	var piso := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(65,0.6,65)
	col.shape = box
	piso.add_child(col)
	var malha := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	malha.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16,0.19,0.22)
	mat.roughness = 0.85
	malha.material_override = mat
	piso.add_child(malha)
	current_scene.add_child(piso)
	piso.global_position = Vector3(0,99.7,0)
	camera = Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 52
	camera.current = true
	await _reset()
	await _foto("00_repouso")
	_cast("Z")
	await _esperar(0.08)
	await _foto("01_z_preparacao")
	await _esperar(0.09)
	await _foto("02_z_impacto")
	await _esperar(0.20)
	await _foto("03_z_recuperacao")
	await _reset()
	alvo.global_position = CASA + Vector3.FORWARD * 8
	_cast("X")
	await _esperar(0.35)
	_enquadrar(ator.global_position)
	await _foto("04_x_propulsao")
	await _esperar(0.18)
	_enquadrar(ator.global_position)
	await _foto("05_x_impacto")
	await _reset()
	alvo.global_position = CASA + Vector3.FORWARD * 6
	_enquadrar(CASA + Vector3.FORWARD * 2.0, 1.5)
	_cast("C")
	await _esperar(0.38)
	await _foto("06_c_barragem")
	await _esperar(0.40)
	await _foto("07_c_barragem")
	await _reset()
	alvo.global_position = CASA + Vector3.RIGHT * 3
	_cast("V")
	await _esperar(0.22)
	await _foto("08_v_carga")
	await _esperar(0.5)
	await _foto("09_v_overdrive")
	while ator._rocket.fase != "subida": await physics_frame
	await _esperar(0.20)
	_enquadrar(ator.global_position)
	await _foto("10_v_subida")
	while ator._rocket.fase != "queda": await physics_frame
	_enquadrar(CASA + Vector3.UP * 3, 1.9)
	await _foto("11_v_queda")
	while ator._rocket.fase != "pouso": await physics_frame
	_enquadrar(CASA, 2.2)
	await _esperar(0.12)
	await _foto("12_v_explosao")
	await _esperar(1.6)
	await _foto("13_limpeza")
	print("ROCKET CAPTURAS: ", SAIDA)
	quit()

func _reset() -> void:
	ator._rocket.cancelar()
	await _esperar(0.9)
	ator.global_position = CASA
	ator.velocity = Vector3.ZERO
	ator.energy = ator.max_energy
	ator._fruit_cooldowns.clear()
	ator._server_cast_next_ms.clear()
	ator._yaw = 0
	ator._pitch = 0
	ator._fruit_damage_lock_timer = 0
	ator._fsm.transition_to("Idle")
	alvo.global_position = CASA + Vector3.FORWARD * 2
	alvo.health = alvo.MAX_HP
	_enquadrar(CASA)
	await _esperar(0.12)

func _enquadrar(centro: Vector3, distancia := 1.0) -> void:
	camera.global_position = centro + Vector3(4.5,2.8,-5.0) * distancia
	camera.look_at(centro + Vector3.UP * 0.4)

func _cast(slot: String) -> void:
	identidade += 1
	ator._do_server_cast(slot,Vector3.FORWARD,ator.global_position+Vector3.UP,0,identidade,"fruit","rocket")

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var imagem := root.get_texture().get_image()
	var erro := imagem.save_png(SAIDA.path_join(nome+".png"))
	print("CAPTURA ",nome," erro=",erro," nodes=",get_node_count())

func _esperar(segundos: float) -> void:
	for _i in ceili(segundos*60): await physics_frame
