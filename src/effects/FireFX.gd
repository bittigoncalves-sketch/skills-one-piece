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

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, charge: float = 0.0, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _higan(world, origin, dir, damage, caster, spec)
		1: _hiken(world, origin, dir, damage, caster, spec)
		2: var fireflies = load("res://src/effects/FirefliesFX.gd"); fireflies.cast_fireflies(world, caster.global_position, damage, caster, spec)
		_: _entei_sun(world, origin, dir, damage, caster, charge, spec)

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
static func bullet(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	# Uma bala da RAJADA Z. A spec é a mesma do pente inteiro (ver
	# `Player._spec_do_disparo`), então as 16 balas dividem o teto do slot.
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
	if spec != null:
		spec.marcar(zone)

static func _higan(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
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
		
		# Cada dedo dispara um tiro de valor CHEIO; quem limita o total é o teto do
		# slot, não uma fração escrita aqui (era `damage * 0.3`).
		zone.setup(spec.dano, 12.0, dir.normalized() * 35.0, 10.0, caster, 0.6)
		spec.marcar(zone)
		
		zone.set_meta("spawn_time", Time.get_ticks_msec())
		
		var explode = func(b=null):
			if not is_instance_valid(zone) or zone.get_meta("exploded", false): return
			
			if b != null and not b.has_method("take_damage"):
				if Time.get_ticks_msec() - zone.get_meta("spawn_time", Time.get_ticks_msec()) < 100:
					return
					
			zone.set_meta("exploded", true)
			if is_instance_valid(world):
				var pm_exp = _flame_proc(Vector3.UP, 180.0, 2.0, 5.0, Vector3(0, 1.0, 0), 0.5, 1.5, 1.0)
				var fire = FxUtil.particles(25, 0.3, true, pm_exp, FxUtil.grain(0.8), 0.85)
				fire.material_override = FxUtil.particle_material(Color(1, 0.4, 0.1), 4.0, true)
				fire.global_position = zone.global_position
				world.add_child(fire)
				AudioFX.impact(world, zone.global_position, 0.5)
			zone.queue_free()
			
		zone.collided_with_any.connect(explode)
		zone.tree_exiting.connect(explode)
		
		AudioFX.whoosh(world, zone.global_position, 0.5)
		AudioFX.gunshot(world, zone.global_position, randf_range(0.95, 1.15))
	)
	controller.add_child(timer)
	if controller.is_inside_tree():
		timer.start()

# ---------- X: Hiken (Punho de Fogo) ----------
static func _hiken(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	# Subimos 0.5 para não raspar no chão imediatamente, já que a hitbox é grande
	zone.global_position = origin + Vector3.UP * 0.5
	
	# Voxel Fist (Literal Punho de Fogo)
	var blocks = []
	var bs = 0.5
	# Base da mão (Palma e dorso)
	for x in range(-2, 3):
		for y in range(-1, 2):
			for z in range(0, 3):
				blocks.append(Vector3(x, y, z) * bs)
	
	# 4 Dedos dobrados na frente (-z)
	for x in range(-2, 2): # mindinho até indicador
		blocks.append(Vector3(x, 1, -1) * bs)
		blocks.append(Vector3(x, 1, -2) * bs)
		blocks.append(Vector3(x, 0, -2) * bs)
		blocks.append(Vector3(x, -1, -2) * bs)
		blocks.append(Vector3(x, -1, -1) * bs)
		
	# Polegar (na lateral direita, x = 2)
	blocks.append(Vector3(2, 0, -1) * bs)
	blocks.append(Vector3(3, 0, -1) * bs)
	blocks.append(Vector3(2, -1, -1) * bs)
	blocks.append(Vector3(1, -1, -1) * bs)
					
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
	
	# Velocidade e tempo de vida (raio diminuído de 2.5 para 1.5 para não tocar o chão)
	zone.setup(spec.dano, 35.0, d * 25.0, 10.0, caster, 1.5)
	spec.marcar(zone)
	
	zone.set_meta("spawn_time", Time.get_ticks_msec())
	
	var explode = func(b=null):
		if not is_instance_valid(zone) or zone.get_meta("exploded", false): return
		
		# Prevenir explosão instantânea em chão/paredes nos primeiros 100ms
		if b != null and not b.has_method("take_damage"):
			if Time.get_ticks_msec() - zone.get_meta("spawn_time", Time.get_ticks_msec()) < 100:
				return
				
		zone.set_meta("exploded", true)
		if is_instance_valid(world):
			var pm_exp = _flame_proc(Vector3.UP, 180.0, 5.0, 15.0, Vector3(0, 1.0, 0), 2.0, 4.0, 2.0)
			var fire = FxUtil.particles(80, 0.6, true, pm_exp, FxUtil.grain(0.8), 0.85)
			fire.material_override = FxUtil.particle_material(Color(1, 0.4, 0.1), 6.0, true)
			fire.global_position = zone.global_position
			world.add_child(fire)
			AudioFX.impact(world, zone.global_position, 1.0)
		zone.queue_free()
		
	zone.collided_with_any.connect(explode)
	zone.tree_exiting.connect(explode)
	
	# Explosão massiva ao final do trajeto.
	#
	# ⚠️ FALTAVA `is_instance_valid(zone)` (corrigido em 2026-08-21). O `explode`
	# acima faz `zone.queue_free()`, e ele dispara em DOIS gatilhos: contato
	# (`collided_with_any`) e morte da zona (`tree_exiting`). Quando o Hiken
	# ACERTA alguém antes de 1,15 s, a zona já não existe quando este temporizador
	# corre — e a linha lia `zone.global_position` num objeto liberado, o que
	# derrubava o callback com erro de runtime.
	#
	# 📌 DECISÃO EM ABERTO, não corrigida aqui: com a guarda, quem ACERTA perde a
	# explosão final e quem ERRA fica com ela. Ou seja, errar rende mais dano que
	# acertar — 160 do punho contra 160 da explosão. Isso é balanceamento, não
	# defeito de código, e é do dono. O conserto natural seria a explosão nascer
	# TAMBÉM no ponto de impacto (mover a chamada para dentro do `explode`).
	var tree := zone.get_tree()
	if tree:
		var timer := tree.create_timer(1.15)
		timer.timeout.connect(func():
			if is_instance_valid(world) and is_instance_valid(zone):
				FireFXGrande._explosion(world, zone.global_position, damage, caster, spec)
		)

# ---------- C: Dai Enkai: Entei (Invocação e Disparo do Sol) ----------
# O usuário convoca um colossal Sol ardente (modelo do onepiece-voxel) acima de si,
# concentrando chamas intensas, e o dispara em alta velocidade contra os inimigos!
static func _entei_sun(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		charge: float = 0.0, spec: DamageSpec = null) -> void:
	print("☀️ [Mera Mera C - Dai Enkai: Entei] Invocando e disparando o GRANDE SOL!")
	# A classe interna foi junto no corte por tamanho (2026-08-11) — ela é do
	# mesmo bloco do Entei, e o Entei ficou aqui. Qualificar é mais barato que
	# mover a classe de volta e reabrir os 900 linhas.
	var ctrl := FireFXGrande.EnteiSunController.new(caster, origin, dir, damage, spec)
	world.add_child(ctrl)
	
	ctrl.update_charge(charge)
	ctrl.set_meta("fired", true)
	ctrl.shoot(dir, charge)

static func _build_sun_model() -> Node3D:
	var root := Node3D.new()
	root.name = "SunVisual"
	
	var yellow := Color(1.0, 0.82, 0.05)       # Amarelo vibrante
	var yellow_bright := Color(1.0, 0.95, 0.3) # Brilho central
	
	var core_mesh = BoxMesh.new()
	core_mesh.size = Vector3(14.0, 14.0, 14.0)
	var core_mat = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = yellow
	core_mat.emission_enabled = true
	core_mat.emission = yellow
	core_mat.emission_energy_multiplier = 4.0
	
	var core_mi = MeshInstance3D.new()
	core_mi.mesh = core_mesh
	core_mi.material_override = core_mat
	root.add_child(core_mi)
	
	# Detalhamento: criar "erupções" cúbicas menores ao redor do cubo central
	for i in range(24):
		var bump = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(randf_range(3.0, 8.0), randf_range(3.0, 8.0), randf_range(3.0, 8.0))
		bump.mesh = b_mesh
		
		var b_mat = StandardMaterial3D.new()
		b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		b_mat.albedo_color = yellow_bright if (i % 4 == 0) else yellow
		b_mat.emission_enabled = true
		b_mat.emission = b_mat.albedo_color
		b_mat.emission_energy_multiplier = 6.0 if (i % 4 == 0) else 3.0
		bump.material_override = b_mat
		
		bump.position = Vector3(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
		root.add_child(bump)
		
	return root

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
