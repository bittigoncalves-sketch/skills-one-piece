class_name FireFX
extends RefCounted
# Geração de FOGO procedural e detalhada (Mera Mera no Mi).
# Reformulada para refletir fielmente as 4 skills: Higan (Z), Hiken (X), Hibashira (C) e Inferno (V).

const FLAME := [
	Color(1.0, 0.95, 0.5, 0.95),  # núcleo quente
	Color(1.0, 0.55, 0.1, 0.8),   # laranja
	Color(0.9, 0.15, 0.05, 0.4),  # vermelho
	Color(0.2, 0.05, 0.0, 0.0),   # fumaça some
]

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _higan(world, origin, dir, damage, caster)
		1: _hiken(world, origin, dir, damage, caster)
		2: _entei_sun(world, origin, dir, damage, caster)
		_: _inferno(world, caster.global_position, damage, caster)

static func _flame_proc(direction: Vector3, spread: float, vmin: float, vmax: float,
		grav: Vector3, smin: float, smax: float, turb: float, radius: float = 0.0) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = direction
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = grav
	pm.scale_min = smin
	pm.scale_max = smax
	pm.color_ramp = FxUtil.gradient(FLAME)
	pm.scale_curve = FxUtil.curve([[0.0, 0.4], [0.3, 1.0], [1.0, 0.0]])
	if radius > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius
	if turb > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = turb
		pm.turbulence_noise_scale = 2.4
	return pm

static func _embers(world_less_pos: Vector3 = Vector3.ZERO) -> GPUParticles3D:
	var pm := _flame_proc(Vector3.UP, 40.0, 2.0, 5.0, Vector3(0, 3.0, 0), 0.15, 0.4, 1.5, 0.4)
	pm.color_ramp = FxUtil.gradient([Color(1.0, 0.8, 0.3, 1.0), Color(1.0, 0.4, 0.1, 0.6), Color(1, 0.2, 0, 0)])
	return FxUtil.particles(50, 1.1, false, pm, FxUtil.grain(0.12))

static func _voxel_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.25, 0.0)
	mat.emission_energy_multiplier = 3.5
	return mat

static func _plasma_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.3)
	mat.emission_energy_multiplier = 6.5
	return mat

static func _magma_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.28, 0.04)
	mat.emission_enabled = true
	mat.emission = Color(0.98, 0.18, 0.01)
	mat.emission_energy_multiplier = 4.5
	return mat

# ---------- Z: Higan (Tiros de Pistola de Fogo) ----------
# BALA DE FOGO (Higan em rajada): parece uma bala de verdade, só que de fogo.
# Cápsula alongada emissiva + miolo branco-quente + rastro; viaja MUITO rápido.
static func bullet(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var fwd := dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	if fwd != Vector3.ZERO:
		zone.look_at(origin + fwd, Vector3.UP)   # -Z da zona aponta pro alvo

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.09
	cap.height = 0.5
	body.mesh = cap
	body.rotation_degrees.x = 90                  # deita a cápsula ao longo do Z (da mira)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.5, 0.1)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.38, 0.05)
	m.emission_energy_multiplier = 4.0
	body.material_override = m
	zone.add_child(body)

	var core := MeshInstance3D.new()              # miolo branco-quente na ponta
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	core.mesh = sm
	core.position.z = -0.26
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1.0, 0.95, 0.8)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.9, 0.6)
	cm.emission_energy_multiplier = 6.0
	core.material_override = cm
	zone.add_child(core)

	var pm := ParticleProcessMaterial.new()       # rastro de fogo (pra trás)
	pm.direction = Vector3(0, 0, 1)               # local +Z = trás (a zona olha -Z)
	pm.spread = 8.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.color_ramp = FxUtil.gradient([Color(1, 0.7, 0.2), Color(1, 0.3, 0.05), Color(0.2, 0.05, 0, 0)])
	zone.add_child(FxUtil.particles(28, 0.35, false, pm, FxUtil.grain(0.25)))

	AudioFX.gunshot(world, origin, randf_range(0.95, 1.1)) # som de tiro potente
	zone.setup(damage, 9.0, fwd * 55.0, 0.7, caster, 0.35)   # bala RÁPIDA + knockback

static func _higan(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	AudioFX.gunshot(world, origin, 1.0) # Som potente de tiro de bala de fogo ao iniciar
	var controller := Node3D.new()
	world.add_child(controller)
	
	# Criação das "Pistolas de Dedo" em voxel
	var hand_blocks = [
		Vector3(0, 0, 0),       # palma
		Vector3(0, 0, -0.2),    # base do indicador
		Vector3(0, 0, -0.4),    # ponta do indicador
		Vector3(0, 0.2, 0)      # polegar para cima
	]
	
	var create_hand = func() -> MultiMeshInstance3D:
		var mmi = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = hand_blocks.size()
		var box = BoxMesh.new(); box.size = Vector3.ONE * 0.2
		mm.mesh = box
		for i in hand_blocks.size():
			mm.set_instance_transform(i, Transform3D(Basis(), hand_blocks[i]))
		mmi.multimesh = mm
		mmi.material_override = _voxel_material()
		return mmi
		
	var hand_r: MultiMeshInstance3D = create_hand.call()
	var hand_l: MultiMeshInstance3D = create_hand.call()
	controller.add_child(hand_r)
	controller.add_child(hand_l)
	
	# Fogo nas mãos
	var pm_r := _flame_proc(Vector3.UP, 10.0, 0.5, 1.5, Vector3(0, 1.0, 0), 0.2, 0.5, 0.5)
	hand_r.add_child(FxUtil.particles(20, 0.5, false, pm_r, FxUtil.grain(0.3)))
	var pm_l := _flame_proc(Vector3.UP, 10.0, 0.5, 1.5, Vector3(0, 1.0, 0), 0.2, 0.5, 0.5)
	hand_l.add_child(FxUtil.particles(20, 0.5, false, pm_l, FxUtil.grain(0.3)))
	
	var timer := Timer.new()
	timer.wait_time = 0.1
	var shots := [0]
	timer.timeout.connect(func():
		shots[0] += 1
		# "dispara até 16 balas de fogo"
		if shots[0] > 16:
			controller.queue_free()
			return
		
		if not is_instance_valid(world): return
		
		# Acompanha o jogador caso ele se mova ou caia
		var current_origin := origin
		if is_instance_valid(caster) and caster is Node3D:
			current_origin = caster.global_position + Vector3.UP * 1.0 + dir * 1.2
			
		controller.global_position = current_origin
		# O controller olha para a direção do tiro
		if dir.length_squared() > 0.01:
			controller.look_at(current_origin + dir, Vector3.UP)
			
		hand_r.position = Vector3(0.5, -0.2, 0)
		hand_l.position = Vector3(-0.5, -0.2, 0)
		
		# Efeito de recuo (recoil) nas mãos
		if shots[0] % 2 == 0:
			hand_r.position.z += 0.2
		else:
			hand_l.position.z += 0.2
		
		var zone := DamageZone.new()
		world.add_child(zone)
		
		var is_right_shot: bool = (shots[0] % 2 == 0)
		zone.global_position = hand_r.global_position if is_right_shot else hand_l.global_position
		
		var mmi := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(0.25, 0.25, 0.6)
		mmi.mesh = box
		mmi.material_override = _voxel_material()
		mmi.look_at(mmi.global_position + dir, Vector3.UP)
		zone.add_child(mmi)
		
		var pm := _flame_proc(Vector3(0,0,1), 10.0, 1.0, 2.0, Vector3(0, 0.5, 0), 0.3, 0.8, 0.5)
		zone.add_child(FxUtil.particles(30, 0.4, false, pm, FxUtil.grain(0.4)))
		
		zone.setup(damage * 0.3, 12.0, dir.normalized() * 35.0, 1.0, caster, 0.6)
		AudioFX.whoosh(world, zone.global_position, 0.5)
		AudioFX.gunshot(world, zone.global_position, randf_range(0.95, 1.15))
	)
	controller.add_child(timer)
	if controller.is_inside_tree():
		timer.start()

# ---------- X: Hiken (Punho de Fogo) ----------
static func _hiken(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	
	# Voxel Fist
	var blocks = []
	var bs = 0.6
	for x in range(-2, 3):
		for y in range(-2, 3):
			for z in range(-2, 3):
				if x*x + y*y <= 5: # Shape circular arredondado
					blocks.append(Vector3(x, y, z) * bs)
					
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = blocks.size()
	var box := BoxMesh.new(); box.size = Vector3.ONE * (bs * 0.95)
	mm.mesh = box
	mmi.multimesh = mm
	mmi.material_override = _voxel_material()
	for i in range(blocks.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), blocks[i]))
		
	# Orientar punho
	var d = dir.normalized()
	if d.length_squared() > 0.1:
		var up = Vector3.UP if abs(d.y) < 0.99 else Vector3.RIGHT
		mmi.transform.basis = Basis.looking_at(d, up)
	zone.add_child(mmi)
	
	var pm := _flame_proc(Vector3(0,0,1), 15.0, 3.0, 6.0, Vector3(0,1,0), 1.0, 3.0, 2.0)
	zone.add_child(FxUtil.particles(200, 1.0, false, pm, FxUtil.grain(0.8)))
	zone.add_child(_embers())
	
	# Velocidade e tempo de vida
	zone.setup(damage, 35.0, d * 25.0, 1.2, caster, 2.5)
	
	# Explosão massiva ao final do trajeto
	var tree := zone.get_tree()
	if tree:
		var timer := tree.create_timer(1.15)
		timer.timeout.connect(func():
			if is_instance_valid(world):
				_explosion(world, zone.global_position, damage, caster)
		)

# ---------- C: Dai Enkai: Entei (Invocação e Disparo do Sol) ----------
# O usuário convoca um colossal Sol ardente (modelo do onepiece-voxel) acima de si,
# concentrando chamas intensas, e o dispara em alta velocidade contra os inimigos!
static func _entei_sun(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	print("☀️ [Mera Mera C - Dai Enkai: Entei] Invocando e disparando o GRANDE SOL!")
	var ctrl := EnteiSunController.new(caster, origin, dir, damage)
	world.add_child(ctrl)

static func _build_sun_model() -> Node3D:
	var path := "res://assets/models/environment/sun.gltf"
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene:
			var container := Node3D.new()
			container.name = "SunVisual"
			var inst := scene.instantiate()
			container.add_child(inst)
			# O centro geométrico do sol no blockbench (0.5, 0.5, 0.703125)
			inst.position = -Vector3(0.5, 0.5, 0.703125) * 6.5
			inst.scale = Vector3.ONE * 6.5
			_make_unshaded_emissive(inst)
			return container
	return _procedural_sun_fallback()

static func _make_unshaded_emissive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for surf in mesh.get_surface_count():
				var src: Material = mesh.surface_get_material(surf)
				var mat := StandardMaterial3D.new()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if src is BaseMaterial3D:
					mat.albedo_texture = (src as BaseMaterial3D).albedo_texture
					mat.albedo_color = (src as BaseMaterial3D).albedo_color
				mat.emission_enabled = true
				mat.emission = mat.albedo_color if mat.albedo_texture == null else Color(1.0, 0.6, 0.1)
				mat.emission_energy_multiplier = 4.0
				mi.set_surface_override_material(surf, mat)
	for child in node.get_children():
		_make_unshaded_emissive(child)

static func _procedural_sun_fallback() -> Node3D:
	var root := Node3D.new()
	root.name = "SunVisual"
	var yellow := Color(1.0, 0.82, 0.05)       # Amarelo vibrante
	var yellow_bright := Color(1.0, 0.95, 0.3) # Brilho central
	var orange := Color(0.98, 0.48, 0.05)      # Laranja chama
	var dark_orange := Color(0.85, 0.3, 0.0)   # Sombra de chama
	var white  := Color(1.0, 0.98, 0.92)       # Dentes / olhos
	var dark   := Color(0.06, 0.03, 0.02)       # Boca / pupilas
	var red_drip := Color(0.85, 0.08, 0.08)    # Gotas da boca
	const S := 1.5

	_box_sun(root, Vector3(0, 0, 0),      Vector3(14, 14, 4.5) * S, yellow)
	_box_sun(root, Vector3(0, 0, -0.4),   Vector3(10, 10, 5.0) * S, yellow_bright)
	_box_sun(root, Vector3(0, 9.0, 0),    Vector3(10, 4, 4) * S,   yellow)
	_box_sun(root, Vector3(0, -9.0, 0),   Vector3(10, 4, 4) * S,   yellow)
	_box_sun(root, Vector3(-9.0, 0, 0),   Vector3(4, 10, 4) * S,   yellow)
	_box_sun(root, Vector3(8.0, 0, 0),    Vector3(4, 10, 4) * S,   yellow)

	var ray_count := 12
	for r_idx in ray_count:
		var angle_rad := float(r_idx) * (TAU / float(ray_count))
		var ray_pivot := Node3D.new()
		ray_pivot.rotation.z = angle_rad
		root.add_child(ray_pivot)
		_box_sun(ray_pivot, Vector3(0, 12.0, 0),    Vector3(4.0, 5.0, 3.2) * S, orange)
		_box_sun(ray_pivot, Vector3(1.8, 16.0, 0),  Vector3(3.2, 4.5, 2.6) * S, orange)
		_box_sun(ray_pivot, Vector3(4.2, 19.5, 0),  Vector3(2.2, 3.8, 2.0) * S, dark_orange)
		_box_sun(ray_pivot, Vector3(7.0, 22.0, 0),  Vector3(1.4, 2.4, 1.4) * S, dark_orange)

	var nose_node := Node3D.new()
	nose_node.position = Vector3(0, 1.2, -3.0)
	root.add_child(nose_node)
	_box_sun(nose_node, Vector3(0, 0, 0),       Vector3(2.6, 2.6, 3.0) * S, yellow)
	_box_sun(nose_node, Vector3(0, -0.4, -2.2), Vector3(2.0, 2.0, 3.2) * S, orange)
	_box_sun(nose_node, Vector3(0, -1.0, -4.4), Vector3(1.4, 1.4, 2.8) * S, orange)
	_box_sun(nose_node, Vector3(0, -1.8, -6.2), Vector3(0.8, 0.8, 2.0) * S, dark_orange)

	_box_sun(root, Vector3(-4.8, 4.8, -2.6), Vector3(4.6, 3.4, 1.2) * S, dark)
	_box_sun(root, Vector3(-4.8, 4.8, -2.8), Vector3(3.6, 2.4, 1.0) * S, white)
	_box_sun(root, Vector3(-4.2, 4.6, -3.0), Vector3(1.6, 1.6, 1.0) * S, dark)
	_box_sun(root, Vector3(4.8, 5.2, -2.6), Vector3(4.8, 3.8, 1.2) * S, dark)
	_box_sun(root, Vector3(4.8, 5.2, -2.8), Vector3(3.8, 2.8, 1.0) * S, white)
	_box_sun(root, Vector3(4.4, 5.0, -3.0), Vector3(1.8, 1.8, 1.0) * S, dark)

	_box_sun(root, Vector3(0, -5.2, -2.6), Vector3(12.0, 5.6, 1.2) * S, dark)
	_box_sun(root, Vector3(-6.5, -3.5, -2.6), Vector3(2.6, 3.2, 1.2) * S, dark)
	_box_sun(root, Vector3(6.5, -3.5, -2.6), Vector3(2.6, 3.2, 1.2) * S, dark)
	for i in 6:
		var tx: float = -5.0 + i * 2.0
		_box_sun(root, Vector3(tx, -3.4, -3.1), Vector3(1.4, 2.2, 0.8) * S, white)
	for i in 5:
		var tx: float = -4.0 + i * 2.0
		_box_sun(root, Vector3(tx, -6.6, -3.1), Vector3(1.4, 2.2, 0.8) * S, white)

	_box_sun(root, Vector3(6.8, -5.5, -3.0), Vector3(1.0, 2.8, 0.8) * S, red_drip)
	_box_sun(root, Vector3(6.8, -7.5, -3.0), Vector3(0.7, 1.6, 0.6) * S, red_drip)
	_box_sun(root, Vector3(-6.8, -5.5, -3.0), Vector3(1.0, 2.0, 0.8) * S, red_drip)
	return root

static func _box_sun(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size * 0.05 # Converte para metros
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos * 0.05
	parent.add_child(mi)

# ---------- C Legado: Hibashira ----------
static func _hibashira_legado(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var ground := Vector3(pos.x, 0.0, pos.z)
	var space = world.get_world_3d().direct_space_state if (world is Node3D and world.is_inside_tree() and world.get_world_3d() != null) else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 40.0, pos + Vector3.DOWN * 80.0)
		q.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty(): ground = hit["position"]
		
	# 1. Ativação da Pose de Entrada Imune (Soca o chão e abre as pernas, imune por toda a duração)
	if is_instance_valid(caster):
		caster.set_meta("damage_immune", true)
		caster.set_meta("custom_pose", "hibashira")
		if caster.has_method("lock_movement"):
			caster.lock_movement(3.5, "C")
		print("🔥 [Mera Mera C - Hibashira] Ativado! Usuário na pose de combate e IMUNE A DANOS por 3.5s!")
		
	var zone := Node3D.new()
	world.add_child(zone)
	zone.global_position = ground
	
	# 2. Luz Térmica Dinâmica e Efeitos de Impacto Inicial (ScreenFX & Shake)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.05)
	light.light_energy = 16.0
	light.omni_range = 30.0
	light.position = Vector3(0, 5.0, 0)
	zone.add_child(light)
	
	var sfx := world.get_node_or_null("/root/ScreenFX") if is_instance_valid(world) else null
	if sfx and sfx.has_method("flash"):
		sfx.flash(Color(1.0, 0.45, 0.1), 0.5)
		
	if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
		caster.add_camera_shake(0.5)
		
	# 3. Onda de Choque de Fogo no Solo (Anel emissivo se expandindo na terra)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.1
	tm.outer_radius = 1.6
	ring.mesh = tm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.4, 0.05)
	ring_mat.emission_energy_multiplier = 4.0
	ring.material_override = ring_mat
	ring.scale = Vector3(0.2, 0.2, 0.2)
	zone.add_child(ring)
	ring.position = Vector3(0, 0.15, 0)
	
	var tw_ring := zone.create_tween()
	tw_ring.set_parallel(true)
	tw_ring.tween_property(ring, "scale", Vector3(8.5, 0.1, 8.5), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(ring_mat, "albedo_color:a", 0.0, 0.45)
	tw_ring.tween_callback(ring.queue_free).set_delay(0.46)
	
	# 4. Vórtex Duplo de Chamas: Núcleo de Plasma Branco-Quente e Hélice de Magma Externa
	var pivot_core := Node3D.new()
	var pivot_vortex := Node3D.new()
	zone.add_child(pivot_core)
	zone.add_child(pivot_vortex)
	
	var core_blocks := []
	var bs_core := 0.65
	for y in range(0, 24):
		var ang := y * 0.5
		var r := 0.4 + (y * 0.02)
		core_blocks.append(Vector3(cos(ang)*r, y * 0.75, sin(ang)*r))
		core_blocks.append(Vector3(cos(ang + PI)*r, y * 0.75, sin(ang + PI)*r))
		
	var mmi_core := MultiMeshInstance3D.new()
	var mm_core := MultiMesh.new()
	mm_core.transform_format = MultiMesh.TRANSFORM_3D
	mm_core.instance_count = core_blocks.size()
	var box_core := BoxMesh.new(); box_core.size = Vector3.ONE * bs_core
	mm_core.mesh = box_core
	mmi_core.multimesh = mm_core
	mmi_core.material_override = _plasma_material()
	for i in range(core_blocks.size()):
		mm_core.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf()*TAU), core_blocks[i]))
	pivot_core.add_child(mmi_core)
	
	var vortex_blocks := []
	var bs_vortex := 0.95
	for y in range(0, 20):
		var ang := -y * 0.6
		var r := 1.6 + (y * 0.05)
		vortex_blocks.append(Vector3(cos(ang)*r, y * 0.85, sin(ang)*r))
		vortex_blocks.append(Vector3(cos(ang + PI*0.66)*r, y * 0.85, sin(ang + PI*0.66)*r))
		vortex_blocks.append(Vector3(cos(ang + PI*1.33)*r, y * 0.85, sin(ang + PI*1.33)*r))
		
	var mmi_vortex := MultiMeshInstance3D.new()
	var mm_vortex := MultiMesh.new()
	mm_vortex.transform_format = MultiMesh.TRANSFORM_3D
	mm_vortex.instance_count = vortex_blocks.size()
	var box_vortex := BoxMesh.new(); box_vortex.size = Vector3.ONE * bs_vortex
	mm_vortex.mesh = box_vortex
	mmi_vortex.multimesh = mm_vortex
	mmi_vortex.material_override = _magma_material()
	for i in range(vortex_blocks.size()):
		mm_vortex.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf()*TAU), vortex_blocks[i]))
	pivot_vortex.add_child(mmi_vortex)
	
	pivot_core.position.y = -24.0
	pivot_vortex.position.y = -26.0
	var tw_erup := zone.create_tween()
	tw_erup.set_parallel(true)
	tw_erup.tween_property(pivot_core, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_erup.tween_property(pivot_vortex, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Rotação Contínua do Furacão de Fogo durante os 3.5 segundos da técnica
	var tw_rot := zone.create_tween()
	tw_rot.set_parallel(true)
	tw_rot.tween_property(pivot_core, "rotation:y", TAU * 7.0, 3.5)
	tw_rot.tween_property(pivot_vortex, "rotation:y", -TAU * 5.5, 3.5)
	
	var pm := _flame_proc(Vector3.UP, 8.0, 18.0, 30.0, Vector3(0, 8.0, 0), 2.0, 6.0, 3.5)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.8, 0.5, 2.8)
	zone.add_child(FxUtil.particles(600, 1.6, false, pm, FxUtil.grain(1.0)))
	zone.add_child(_embers())
	
	if is_instance_valid(world):
		AudioFX.impact(world, ground, 0.9)
		AudioFX.whoosh(world, ground + Vector3.UP * 2.0, 1.35)
		
	# 5. Área do Furacão Gravitacional: suspende inimigos no ar girando sem que consigam se mover ou atacar
	var area := Area3D.new()
	zone.add_child(area)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 8.5
	cyl.height = 22.0
	col.shape = cyl
	col.position = Vector3(0, 11.0, 0)
	area.add_child(col)
	
	var trapped_victims: Dictionary = {}
	var vortex_active := true
	var burn_acc := 0.0
	
	var vortex_timer := Timer.new()
	vortex_timer.wait_time = 0.05   # 20 Hz (controle contínuo de posição, rotação e CC no ar)
	vortex_timer.autostart = true
	zone.add_child(vortex_timer)
	
	vortex_timer.timeout.connect(func():
		if not vortex_active or not is_instance_valid(area):
			return
		burn_acc += 0.05
		var do_burn := (burn_acc >= 0.45)
		if do_burn: burn_acc = 0.0
		
		for body in area.get_overlapping_bodies():
			if body == caster or not is_instance_valid(body):
				continue
			if not body.has_method("take_damage"):
				continue
				
			# Marca a vítima no dicionário e aplica CC (imobiliza e impede ataques)
			trapped_victims[body] = true
			body.set_meta("in_vortex", true)
			StatusFX.aplicar(body, StatusFX.SUGADO, 3.0)
			body.set_meta("is_suppressed", true)
			if body.has_method("suppress_skills_temporarily"):
				body.suppress_skills_temporarily(0.25)
				
			# "Fica voando no furacão": suspender no ar e girar ao redor do pilar flamejante
			if body is CharacterBody3D:
				var rel := (body as CharacterBody3D).global_position - ground
				var flat_rel := Vector3(rel.x, 0.0, rel.z)
				if flat_rel.length() < 0.3:
					flat_rel = Vector3(2.5, 0.0, 0.0)
				var target_y: float = ground.y + 4.2 + sin(rel.x * 2.0 + rel.z) * 0.8
				var vy: float = (target_y - (body as CharacterBody3D).global_position.y) * 6.0
				var pull_dir := -flat_rel.normalized()
				var swirl_dir := Vector3.UP.cross(flat_rel).normalized()
				(body as CharacterBody3D).velocity = swirl_dir * 16.0 + pull_dir * (flat_rel.length() - 2.5) * 5.0 + Vector3.UP * vy
				(body as CharacterBody3D).move_and_slide()
				
			if do_burn:
				body.take_damage(damage * 0.15, ground, Vector3.ZERO) # Queimadura contínua sem knockback de saída
	)
	
	# 6. Encerramento com Explosão Massiva: liberta e espalha qualquer vítima do ataque
	var end_timer := Timer.new()
	end_timer.wait_time = 3.5
	end_timer.one_shot = true
	end_timer.autostart = true
	zone.add_child(end_timer)
	
	end_timer.timeout.connect(func():
		vortex_active = false
		vortex_timer.stop()
		
		# Fim do ataque: usuário sai da pose de entrada e perde a imunidade
		if is_instance_valid(caster):
			caster.set_meta("damage_immune", false)
			caster.set_meta("custom_pose", "")
			print("⚡ [Mera Mera C - Hibashira] Encerrado! Fim da pose e da imunidade ao dano do usuário.")
			
		var final_targets := trapped_victims.duplicate()
		if is_instance_valid(area):
			for b in area.get_overlapping_bodies():
				if b != caster and is_instance_valid(b) and b.has_method("take_damage"):
					final_targets[b] = true
					
		print("💥 [Mera Mera C - Hibashira] EXPLOSÃO FINAL! Espalhando vítimas do furacão!")
		for body in final_targets.keys():
			if not is_instance_valid(body) or not (body is Node3D):
				continue
			body.set_meta("in_vortex", false)
			body.set_meta("is_suppressed", false)
			
			# Vetor explosivo para fora e para cima (scatter total)
			var dir_out: Vector3 = ((body as Node3D).global_position - ground)
			dir_out.y = 0.0
			if dir_out.length_squared() < 0.01:
				dir_out = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			else:
				dir_out = dir_out.normalized()
				
			var scatter_kb: Vector3 = dir_out * 48.0 + Vector3.UP * 24.0
			if body.has_method("take_damage"):
				body.take_damage(damage * 1.6, ground, scatter_kb)
				
		# Efeitos da Supernova / Explosão final de encerramento
		if is_instance_valid(world):
			var exp_sfx := world.get_node_or_null("/root/ScreenFX")
			if exp_sfx and exp_sfx.has_method("flash"):
				exp_sfx.flash(Color(1.0, 0.6, 0.15), 0.7)
			AudioFX.impact(world, ground + Vector3.UP * 2.0, 1.25)
			AudioFX.snap(world, ground + Vector3.UP * 2.0, 1.5)
			
		var exp_mesh := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.6; sm.height = 1.2
		exp_mesh.mesh = sm
		exp_mesh.material_override = _plasma_material()
		exp_mesh.position = Vector3(0, 3.5, 0)
		zone.add_child(exp_mesh)
		var tw_exp := zone.create_tween()
		tw_exp.set_parallel(true)
		tw_exp.tween_property(exp_mesh, "scale", Vector3(25.0, 25.0, 25.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_exp.tween_property(exp_mesh, "transparency", 1.0, 0.45)
		tw_exp.tween_property(light, "light_energy", 0.0, 0.5)
		tw_exp.tween_callback(zone.queue_free).set_delay(0.6)
	)

# ---------- V: Inferno (Dai Enkai: Entei - O Imperador das Chamas) ----------
# A técnica suprema de Ace: convoca um Oceano de Chamas na terra (Enkai) em formato mandala que converge
# no ar e gera uma colossal esfera de sol e magma (Entei), liberando dano sísmico e incineração total.
static func _inferno(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var controller := Node3D.new()
	world.add_child(controller)
	
	var ground := Vector3(pos.x, 0.0, pos.z)
	var space = world.get_world_3d().direct_space_state if (world is Node3D and world.is_inside_tree() and world.get_world_3d() != null) else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 40.0, pos + Vector3.DOWN * 80.0)
		q.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty(): ground = hit["position"]
		
	controller.global_position = ground
	
	# 1. Iluminação Solar de Domínio & Impacto de Atmosfera
	var sun_light := OmniLight3D.new()
	sun_light.light_color = Color(1.0, 0.5, 0.1)
	sun_light.light_energy = 22.0
	sun_light.omni_range = 45.0
	sun_light.position = Vector3(0, 11.0, 0)
	controller.add_child(sun_light)
	
	var sfx := world.get_node_or_null("/root/ScreenFX") if is_instance_valid(world) else null
	if sfx and sfx.has_method("flash"):
		sfx.flash(Color(1.0, 0.38, 0.05), 0.65)
		
	if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
		caster.add_camera_shake(0.65)
		
	# 2. ENKAI: O Oceano de Chamas na Terra (Mandala geométrica em expansão)
	var mandala := Node3D.new()
	controller.add_child(mandala)
	
	var sea_blocks = []
	for ring in range(1, 10):
		var num_blocks = ring * 22
		var r = ring * 2.2
		for j in range(num_blocks):
			var angle = (j * TAU / float(num_blocks)) + (ring * 0.2)
			var h = randf_range(0.2, 0.8) + (cos(angle * 4.0) * 0.3)
			sea_blocks.append(Vector3(cos(angle)*r, h, sin(angle)*r))
			
	var mmi_sea := MultiMeshInstance3D.new()
	var mm_sea := MultiMesh.new()
	mm_sea.transform_format = MultiMesh.TRANSFORM_3D
	mm_sea.instance_count = sea_blocks.size()
	var box_sea := BoxMesh.new(); box_sea.size = Vector3(1.1, 1.4, 1.1)
	mm_sea.mesh = box_sea
	mmi_sea.multimesh = mm_sea
	mmi_sea.material_override = _magma_material()
	for i in range(sea_blocks.size()):
		mm_sea.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf()*TAU), sea_blocks[i]))
	mandala.add_child(mmi_sea)
	
	# Animação do oceano de chamas girando e ondulando no solo
	var tw_sea := controller.create_tween()
	tw_sea.tween_property(mandala, "rotation:y", TAU * 1.5, 12.0)
	
	# 3. DAI ENKAI: ENTEI (A Esfera Solar do Imperador das Chamas no céu)
	var entei := Node3D.new()
	controller.add_child(entei)
	entei.position = Vector3(0, 10.5, 0)
	
	# Esfera Central de Plasma
	var sun_core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.6
	sphere.height = 7.2
	sun_core.mesh = sphere
	sun_core.material_override = _plasma_material()
	entei.add_child(sun_core)
	
	# Anéis de Prominência Solar (Voxels massivos orbitando ao redor do Sol)
	var corona_pivot := Node3D.new()
	entei.add_child(corona_pivot)
	var corona_blocks = []
	for i in range(70):
		var u = randf() * TAU
		var v = acos(randf_range(-1.0, 1.0))
		var rad = randf_range(4.2, 5.8)
		corona_blocks.append(Vector3(rad * sin(v) * cos(u), rad * sin(v) * sin(u), rad * cos(v)))
		
	var mmi_cor := MultiMeshInstance3D.new()
	var mm_cor := MultiMesh.new()
	mm_cor.transform_format = MultiMesh.TRANSFORM_3D
	mm_cor.instance_count = corona_blocks.size()
	var box_cor := BoxMesh.new(); box_cor.size = Vector3.ONE * 1.25
	mm_cor.mesh = box_cor
	mmi_cor.multimesh = mm_cor
	mmi_cor.material_override = _voxel_material()
	for i in range(corona_blocks.size()):
		mm_cor.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf()*TAU), corona_blocks[i]))
	corona_pivot.add_child(mmi_cor)
	
	# Animação de nascimento e órbita da Esfera Entei
	entei.scale = Vector3(0.1, 0.1, 0.1)
	var tw_sun := controller.create_tween()
	tw_sun.tween_property(entei, "scale", Vector3(1.0, 1.0, 1.0), 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	var tw_cor := controller.create_tween()
	tw_cor.set_loops()
	tw_cor.tween_property(corona_pivot, "rotation:y", TAU, 3.5).from(0.0)
	
	# 4. Erupção de Partículas Solares no Ar e No Chão
	var pm := _flame_proc(Vector3.UP, 15.0, 4.0, 9.0, Vector3(0, 3.0, 0), 1.8, 5.0, 4.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22.0, 0.4, 22.0)
	controller.add_child(FxUtil.particles(750, 2.2, false, pm, FxUtil.grain(1.4)))
	
	# 5. Dano inicial de expansão térmica
	var init_zone := DamageZone.new()
	controller.add_child(init_zone)
	init_zone.setup(damage * 0.45, 35.0, Vector3.ZERO, 0.6, caster, 22.0)
	AudioFX.impact(world, ground, 0.7)
	AudioFX.whoosh(world, ground + Vector3(0, 10, 0), 0.5)
	
	# 6. Incineração DPS por 12s + Supernova Final
	var timer := Timer.new()
	timer.wait_time = 1.0
	var ticks := [0]
	timer.timeout.connect(func():
		ticks[0] += 1
		if ticks[0] > 12:
			if is_instance_valid(world):
				var sfx_final := world.get_node_or_null("/root/ScreenFX") if is_instance_valid(world) else null
				if sfx_final and sfx_final.has_method("flash"):
					sfx_final.flash(Color(1.0, 0.9, 0.6), 0.5)
				AudioFX.impact(world, controller.global_position, 0.6)
				_explosion(world, entei.global_position, damage * 0.5, caster)
			controller.queue_free()
			return
		if not is_instance_valid(world): return
		var dps_zone := DamageZone.new()
		controller.add_child(dps_zone)
		dps_zone.setup(damage * 0.16, 6.0, Vector3.ZERO, 0.15, caster, 22.0)
		if is_instance_valid(entei):
			var tw_pulse := entei.create_tween()
			tw_pulse.tween_property(entei, "scale", Vector3(1.15, 1.15, 1.15), 0.15)
			tw_pulse.tween_property(entei, "scale", Vector3(1.0, 1.0, 1.0), 0.25)
	)
	controller.add_child(timer)
	if controller.is_inside_tree():
		timer.start()

# Utilizado pelo Hiken ao final de sua trajetória
static func _explosion(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos + Vector3.UP * 1.0
	var pm := _flame_proc(Vector3.UP, 90.0, 6.0, 14.0, Vector3(0, 1.0, 0), 2.0, 5.0, 4.0, 1.5)
	var fire := FxUtil.particles(700, 1.4, true, pm, FxUtil.grain(1.2), 0.85)
	fire.material_override = FxUtil.particle_material(Color(1, 0.4, 0.1), 4.0, true)
	zone.add_child(fire)
	zone.add_child(_embers())
	zone.setup(damage, 35.0, Vector3.ZERO, 1.6, caster, 6.0)
	AudioFX.impact(world, pos, 0.9)

# ==================== CONTROLADOR DO SOL (DAI ENKAI: ENTEI) ====================
class EnteiSunController extends Node3D:
	var caster: Node
	var dir: Vector3
	var damage: float
	var elapsed := 0.0
	var fired := false
	var sun: Node3D
	var light: OmniLight3D
	var zone: DamageZone

	func _init(c: Node, orig: Vector3, d: Vector3, dmg: float) -> void:
		caster = c
		global_position = orig
		dir = d.normalized()
		damage = dmg

	func _ready() -> void:
		if dir.length_squared() < 0.01:
			dir = Vector3(0, 0, -1)
		sun = FireFX._build_sun_model()
		add_child(sun)
		sun.scale = Vector3(0.1, 0.1, 0.1)

		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.1)
		light.light_energy = 0.0
		light.omni_range = 45.0
		add_child(light)

		# Efeito de chamas orbitando a esfera solar
		var pm := FireFX._flame_proc(Vector3.UP, 180.0, 2.0, 8.0, Vector3(0, 4.0, 0), 0.5, 2.0, 1.0)
		var p_flames := FxUtil.particles(300, 0.8, false, pm, FxUtil.grain(0.8))
		add_child(p_flames)

		if get_tree() and get_tree().current_scene:
			AudioFX.whoosh(get_tree().current_scene, global_position, 0.4)
			var sfx := get_tree().current_scene.get_node_or_null("/root/ScreenFX")
			if sfx and sfx.has_method("flash"):
				sfx.flash(Color(1.0, 0.5, 0.1), 0.5)

		# Anima a invocação do Sol acima do jogador por 1.0s
		var target_pos := global_position + Vector3.UP * 7.5 + dir * 1.5
		if is_instance_valid(caster) and caster is Node3D:
			target_pos = caster.global_position + Vector3.UP * 7.5 + dir * 1.5
		
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sun, "scale", Vector3(1.2, 1.2, 1.2), 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "global_position", target_pos, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(light, "light_energy", 28.0, 0.8)
		if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
			caster.add_camera_shake(0.45)

	func _process(delta: float) -> void:
		elapsed += delta
		if is_instance_valid(sun):
			sun.rotation.y += 4.5 * delta
			sun.rotation.z += 1.8 * delta
		
		if not fired and elapsed >= 1.0:
			fired = true
			_shoot()

		if fired:
			global_position += dir * 28.0 * delta
			if is_instance_valid(zone):
				zone.global_position = global_position
			if elapsed >= 4.5 or _check_impact():
				_explode()

	func _shoot() -> void:
		print("🚀 [Dai Enkai: Entei] DISPARANDO O SOL!")
		if is_instance_valid(caster) and "rotation" in caster:
			if "_cam" in caster and is_instance_valid(caster._cam):
				dir = -caster._cam.global_transform.basis.z.normalized()
		
		zone = DamageZone.new()
		if get_tree() and get_tree().current_scene:
			get_tree().current_scene.add_child(zone)
			zone.global_position = global_position
			AudioFX.impact(get_tree().current_scene, global_position, 0.75)
			AudioFX.whoosh(get_tree().current_scene, global_position, 0.85)
		zone.setup(damage, 7.5, dir * 42.0 + Vector3.UP * 8.0, 3.5, caster, 0.6)

	func _check_impact() -> bool:
		if elapsed < 1.15: return false
		if global_position.y <= 0.9: return true
		return false

	func _explode() -> void:
		set_process(false)
		print("💥 [Dai Enkai: Entei] EXPLOSÃO SOLAR APOCALÍPTICA!")
		var world := get_tree().current_scene if get_tree() else null
		if is_instance_valid(world):
			AudioFX.impact(world, global_position, 0.5)
			AudioFX.snap(world, global_position, 0.7)
			var exp_sfx := world.get_node_or_null("/root/ScreenFX")
			if exp_sfx and exp_sfx.has_method("flash"):
				exp_sfx.flash(Color(1.0, 0.7, 0.2), 0.9)
			if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
				caster.add_camera_shake(0.9)

			# Super Damage Zone da explosão final (raio de 18 metros)
			var exp_zone := DamageZone.new()
			world.add_child(exp_zone)
			exp_zone.global_position = global_position
			exp_zone.setup(damage * 1.6, 18.0, Vector3.UP * 32.0, 0.4, caster, 0.5)

			# Visual da explosão solar (Esfera de plasma de fogo expandindo)
			var exp_mesh := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0
			exp_mesh.mesh = sm
			exp_mesh.material_override = FxUtil.particle_material(Color(1.0, 0.65, 0.1), 8.0, false)
			world.add_child(exp_mesh)
			exp_mesh.global_position = global_position
			var tw_exp := world.create_tween().set_parallel(true)
			tw_exp.tween_property(exp_mesh, "scale", Vector3(30.0, 30.0, 30.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_exp.tween_property(exp_mesh, "transparency", 1.0, 0.55)
			tw_exp.tween_callback(exp_mesh.queue_free).set_delay(0.6)

		if is_instance_valid(zone):
			zone.queue_free()
		queue_free()
