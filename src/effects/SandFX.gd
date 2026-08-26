class_name SandFX
extends RefCounted
# Geração de AREIA procedural e detalhada para a Suna Suna no Mi.
# 4 golpes (Z/X/C/V): lâmina, tornado, areia movediça e tempestade.
# Cada golpe = DamageZone (raiz móvel/estática) + partículas de grão + poeira +
# malha procedural de areia. Sem texturas: cor/curvas geradas em código.

const SAND := [
	Color(0.95, 0.82, 0.48, 0.95),
	Color(0.85, 0.68, 0.34, 0.75),
	Color(0.66, 0.52, 0.26, 0.0),
]

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _blade(world, origin, dir, damage, caster, spec)
		1: _tornado(world, origin + dir * 4.0, damage, caster, dir, spec)
		2: _quicksand(world, origin + dir * 4.0, damage, caster, spec)
		_: _desert(world, _ground_target(caster, dir, 11.0), damage, caster, spec)

static func _ground_target(caster: Node, dir: Vector3, distance: float) -> Vector3:
	# O ataque de área não usa pitch: olhar para cima/baixo nunca pode fazer o
	# deserto nascer no céu ou enterrado sob o mapa.
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	if flat_dir.length_squared() < 0.001:
		flat_dir = Vector3.FORWARD
	else:
		flat_dir = flat_dir.normalized()
	var start: Vector3 = (caster as Node3D).global_position if caster is Node3D else Vector3.ZERO
	return start + flat_dir * distance

# ---------- material de processo de areia (grãos que caem/voam) ----------
static func _proc(direction: Vector3, spread: float, vmin: float, vmax: float,
		gravity: Vector3, smin: float, smax: float, turb: float,
		shape_radius: float = 0.0) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = direction
	pm.spread = spread
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = gravity
	pm.scale_min = smin
	pm.scale_max = smax
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.color_ramp = FxUtil.gradient(SAND)
	pm.scale_curve = FxUtil.curve([[0.0, 0.2], [0.25, 1.0], [1.0, 0.0]])
	if shape_radius > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = shape_radius
	if turb > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = turb
		pm.turbulence_noise_scale = 1.8
	return pm

static func _dust(radius: float) -> GPUParticles3D:
	# Poeira suave e larga ao redor.
	var pm := _proc(Vector3.UP, 60.0, 0.3, 1.2, Vector3(0, -1.0, 0), 1.5, 3.0, 0.6, radius)
	var p := FxUtil.particles(60, 1.3, false, pm, FxUtil.grain(0.5))
	return p

# Disco emissivo baixo: dá leitura imediata de impacto e mantém o efeito bonito
# mesmo quando há poucas partículas visíveis na câmera.
static func _sand_halo(radius: float, color: Color) -> MeshInstance3D:
	var halo := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	halo.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FxUtil.brilho(Color(color.r, color.g, color.b, 0.48), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = mat
	return halo

static func _pulse(node: Node3D, target_scale: Vector3, duration: float) -> void:
	node.scale = Vector3(0.08, 1.0, 0.08)
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation:y", TAU * 1.5, duration)

static func _voxel_multimesh(blocks: Array, size: float, color: Color) -> MultiMeshInstance3D:
	var mmi = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = blocks.size()
	var box = BoxMesh.new()
	box.size = Vector3.ONE * size
	mm.mesh = box
	for i in blocks.size():
		mm.set_instance_transform(i, Transform3D(Basis(), blocks[i]))
	mmi.multimesh = mm
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mmi.material_override = mat
	return mmi

# ---------- Z: Desert Spada — lâmina de areia projétil ----------
static func _blade(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	if dir != Vector3.ZERO:
		zone.look_at(origin + dir, Vector3.UP)

	# Lâmina feita de blocos (voxel)
	var blocks := []
	var bs := 0.4
	for z in range(20):
		var thick := 1.0 - (z / 20.0) # Afina para a ponta
		for y in range(-2, 3):
			for x in range(-1, 2):
				if abs(y) + abs(x) <= thick * 4.0:
					blocks.append(Vector3(x * bs, y * bs, -z * bs))
	
	var blade := _voxel_multimesh(blocks, bs * 0.95, Color(0.95, 0.8, 0.45))
	zone.add_child(blade)
	
	# Efeito de flash/poeira na ponta
	var tip_halo := _sand_halo(1.2, Color(1.0, 0.8, 0.4))
	tip_halo.position.z = -20 * bs
	tip_halo.rotation_degrees.x = 90
	zone.add_child(tip_halo)
	_pulse(tip_halo, Vector3(1.5, 1.0, 1.5), 0.3)

	# Rastro de partículas quadradas
	var trail := _proc(Vector3(0, 0, -1), 25.0, 1.0, 3.0, Vector3(0, -2.0, 0), 0.6, 1.6, 1.2, 0.4)
	zone.add_child(FxUtil.particles(120, 0.7, false, trail, FxUtil.grain(0.28)))

	zone.setup(spec.dano, 30.0, dir.normalized() * 22.0, 1.45, caster, 3.0)
	spec.marcar(zone)
	AudioFX.whoosh(world, origin, 0.9)   # "fiu" da lâmina cortando o ar
	var tw := zone.create_tween()
	tw.tween_property(blade, "scale", Vector3(1.2, 1.2, 0.5), 1.2)

# ---------- X: Sables — tornado de areia (puxa, levanta, dano contínuo) ----------
static func _tornado(world: Node, pos: Vector3, damage: float, caster: Node, dir: Vector3 = Vector3.ZERO,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	# Raiz = comportamento (puxão/levantar/dano contínuo, autoridade do servidor).
	var tornado := SandTornado.new()
	world.add_child(tornado)
	tornado.global_position = pos
	# O 4º argumento deixou de ser "dps" e passou a ser o dano POR TIQUE, que é
	# o que a tabela declara. Ver `SandTornado.setup`.
	tornado.setup(3.4, 11.0, 7.5, spec.dano, 3.2, caster, dir, spec)   # raio, puxão, lift, dano/tique, vida

	# Espiral voxel ascendente (mais alta e afunilada) girando.
	var blocks := []
	var bs := 0.5
	for i in range(320):
		var h := i * 0.05
		var radius := 0.5 + h * 0.32
		var angle := i * 0.85
		blocks.append(Vector3(cos(angle), 0, sin(angle)) * radius + Vector3(0, h, 0))
		if i % 3 == 0:
			blocks.append(Vector3(cos(angle) * radius + randf_range(-0.4, 0.4), h + randf_range(-0.3, 0.3), sin(angle) * radius + randf_range(-0.4, 0.4)))
	var mesh := _voxel_multimesh(blocks, bs * 0.9, Color(0.9, 0.72, 0.35))
	tornado.add_child(mesh)
	var spin := tornado.create_tween().set_loops()
	spin.tween_property(mesh, "rotation:y", TAU, 0.4).as_relative()

	# Grãos SUBINDO em espiral -> vende a sensação de puxar e levantar.
	var pm := _proc(Vector3.UP, 22.0, 4.0, 9.0, Vector3(0, 1.5, 0), 0.8, 2.0, 3.0, 3.2)
	pm.angular_velocity_min = 220.0
	pm.angular_velocity_max = 420.0
	tornado.add_child(FxUtil.particles(240, 1.4, false, pm, FxUtil.grain(0.5)))

	tornado.add_child(_dust(3.0))
	var halo := _sand_halo(3.2, Color(0.95, 0.69, 0.25))
	tornado.add_child(halo)
	_pulse(halo, Vector3(1.35, 1.0, 1.35), 0.55)
	AudioFX.whoosh(world, pos, 0.65)

# ---------- C: Desert Girasole — areia movediça (armadilha de chão) ----------
static func _spawn_single_quicksand(world: Node, pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	# Garante que gruda no chão do cenário
	var ground := _ground_position(world, pos)
	zone.global_position = ground

	# Areia movediça no chão (formato de ralo/buraco raso)
	var blocks := []
	var bs := 0.6
	for x in range(-5, 6):
		for z in range(-5, 6):
			var dist_sq = x*x + z*z
			if dist_sq <= 25:
				# Centro fica quase rente ao chão (0.05), bordas sobem um pouco (0.4) criando a ilusão de um ralo
				var depth = 0.05 + (dist_sq / 25.0) * 0.35
				blocks.append(Vector3(x*bs, depth*bs, z*bs))

	var pit := _voxel_multimesh(blocks, bs * 0.95, Color(0.85, 0.65, 0.25))
	zone.add_child(pit)
	
	# Animação da armadilha se abrindo horizontalmente no chão
	pit.scale = Vector3(0.01, 1.0, 0.01)
	var tw := zone.create_tween()
	tw.tween_property(pit, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var halo := _sand_halo(3.5, Color(0.62, 0.38, 0.12))
	halo.position.y = 0.05 # Garante que o disco não sofra Z-fighting com o chão
	zone.add_child(halo)
	_pulse(halo, Vector3(1.3, 1.0, 1.3), 0.4)

	# Fica no chão, como uma armadilha. Sem knockback (0.0). Duração de 8.5s. Raio da área de dano de 3.5.
	zone.setup(spec.dano, 5.0, Vector3.ZERO, 8.5, caster, 3.5)
	spec.marcar(zone)
	AudioFX.impact(world, zone.global_position, 0.5)

static func _quicksand(world: Node, pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var caster_pos: Vector3 = (caster as Node3D).global_position if caster is Node3D else pos
	
	var valid_positions := [pos]
	_spawn_single_quicksand(world, pos, damage, caster, spec)
	
	# Gerar 4 armadilhas extras aleatórias ao redor do jogador sem encostar
	for i in range(4):
		for attempt in range(50):
			var angle := randf() * TAU
			var dist := randf_range(6.0, 16.0)
			var candidate := caster_pos + Vector3(cos(angle), 0, sin(angle)) * dist
			
			var ok := true
			for vp in valid_positions:
				# Raio da armadilha é 3.5. Então distância mínima segura é 7.0 + margem
				if candidate.distance_to(vp) < 7.5:
					ok = false
					break
			
			if ok:
				valid_positions.append(candidate)
				_spawn_single_quicksand(world, candidate, damage, caster, spec)
				break

# ---------- V: Suna no Sabaku — deserto procedural persistente ----------
static func _dune_height(x: float, z: float) -> float:
	var h := 0.0
	# Altura BAIXA (ref): dunas suaves sobre base plana; amplitudes reduzidas.
	for dune in [[-10.0, -8.0, 7.0, 1.4], [12.0, -14.0, 8.0, 1.1], [6.0, 12.0, 9.0, 1.6], [-15.0, 12.0, 6.0, 1.0]]:
		var dx: float = x - dune[0]
		var dz: float = z - dune[1]
		var radius: float = dune[2]
		h += dune[3] * exp(-(dx * dx + dz * dz) / (2.0 * radius * radius))
	return h

static func _ground_position(world: Node, desired: Vector3) -> Vector3:
	if world is Node3D:
		var space := (world as Node3D).get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(desired + Vector3.UP * 40.0, desired + Vector3.DOWN * 80.0)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"] as Vector3
	return Vector3(desired.x, 0.0, desired.z)

static func _desert(world: Node, pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var previous: Node = world.get_tree().get_first_node_in_group("suna_procedural_desert")
	if previous:
		previous.queue_free()
		
	var desert_mmi := MultiMeshInstance3D.new()
	desert_mmi.name = "SunaNoSabaku"
	desert_mmi.add_to_group("suna_procedural_desert")
	var ground := _ground_position(world, pos)
	desert_mmi.position = ground
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var max_blocks := 4000
	mm.instance_count = max_blocks
	var box := BoxMesh.new()
	var bs := 1.2 # Tamanho do bloco
	box.size = Vector3.ONE * bs
	mm.mesh = box
	
	var idx := 0
	var grid_size := 25 # Raio do deserto em blocos
	for z in range(-grid_size, grid_size):
		for x in range(-grid_size, grid_size):
			if x*x + z*z > grid_size*grid_size:
				continue # Formato circular
			if idx >= max_blocks: break
			
			var h := _dune_height(x * bs, z * bs)
			# Quantização voxel: achata em escadas
			var step_h: float = floor(h / bs) * bs
			# Cria chão liso base onde não há dunas
			if step_h < bs:
				step_h = 0.0
			
			mm.set_instance_transform(idx, Transform3D(Basis(), Vector3(x * bs, step_h + (bs/2.0), z * bs)))
			idx += 1
			
	mm.visible_instance_count = idx
	desert_mmi.multimesh = mm
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.82, 0.4)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	desert_mmi.material_override = mat
	
	world.add_child(desert_mmi)
	FxUtil.autofree(desert_mmi, 20.0)   # DURAÇÃO: 20s (ref) — some sozinho
	AudioFX.impact(world, ground, 0.6)
	print("🏜️ Suna no Sabaku criado em ", desert_mmi.global_position, " com ", idx, " blocos voxel (20s)!")

	# 1. Adiciona colisão física no deserto (chão sólido para rolar mato e pisar)
	var static_body := StaticBody3D.new()
	var desert_col := CollisionShape3D.new()
	var desert_cyl := CylinderShape3D.new()
	desert_cyl.radius = 25.0
	desert_cyl.height = 1.2
	desert_col.shape = desert_cyl
	desert_col.position = Vector3(0, 0.6, 0)
	static_body.add_child(desert_col)
	desert_mmi.add_child(static_body)
	
	# 2. Área de areia grossa (Reduz velocidade dos inimigos e empurra todos pra cima da areia)
	var sand_area := Area3D.new()
	var area_col := CollisionShape3D.new()
	var area_cyl := CylinderShape3D.new()
	area_cyl.radius = 25.0
	area_cyl.height = 10.0
	area_col.shape = area_cyl
	area_col.position = Vector3(0, 5.0, 0)
	sand_area.add_child(area_col)
	desert_mmi.add_child(sand_area)
	
	var caster_ref = weakref(caster)
	var ticker := Timer.new()
	ticker.wait_time = 0.05
	ticker.autostart = true
	ticker.timeout.connect(func():
		var c = caster_ref.get_ref() if caster_ref else null
		if not is_instance_valid(sand_area): return
		for body in sand_area.get_overlapping_bodies():
			if body is CharacterBody3D:
				# Reduz severamente a velocidade de quem NÃO for o conjurador
				if body != c:
					body.velocity.x *= 0.6
					body.velocity.z *= 0.6
				
				# Se estiver afundado na areia (Y local menor que 1.2), sobe até a superfície
				var local_y = body.global_position.y - ground.y
				if local_y < 1.2:
					body.global_position.y = move_toward(body.global_position.y, ground.y + 1.25, 0.4)
	)
	sand_area.add_child(ticker)

	# 3. Spawna matos vagantes característicos do deserto (Tumbleweeds)
	if ResourceLoader.exists("res://src/effects/Tumbleweed.gd"):
		var TumbleweedClass = load("res://src/effects/Tumbleweed.gd")
		for i in range(4):
			var weed = TumbleweedClass.new()
			# Visual do mato (bola seca esburacada)
			var m := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 8
			m.mesh = s
			var w_mat := StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.65, 0.55, 0.3)
			w_mat.roughness = 1.0
			m.material_override = w_mat
			weed.add_child(m)
			world.add_child(weed)
			weed.setup(ground, 20.0)
			FxUtil.autofree(weed, 20.0)

	# A malha fica no mundo (20s); a tempestade leve acompanha o deserto inteiro.
	_storm(world, ground, damage, caster, spec)

# ---------- tempestade temporária que acompanha a criação do deserto ----------
static func _storm(world: Node, pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos + Vector3.UP * 1.5

	# Tempestade leve: partículas sutis espalhadas por toda a área do deserto
	var pm := _proc(Vector3(1.0, 0.1, 0.5), 15.0, 4.0, 8.0, Vector3.ZERO, 2.0, 6.0, 1.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(25.0, 5.0, 25.0) # Cobre todo o raio do deserto (grid_size=25)
	pm.color = Color(0.85, 0.65, 0.35, 0.25) # Opacidade baixa (leve e sutil)
	
	var parts := FxUtil.particles(400, 4.0, false, pm, FxUtil.grain(0.7))
	# Aumentar a AABB das partículas para que não sumam ao virar a câmera
	parts.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
	zone.add_child(parts)
	
	# Sem anéis, apenas a névoa ambiente para não atrapalhar o combate
	zone.setup(spec.dano, 40.0, Vector3.ZERO, 6.0, caster, 20.0)
	spec.marcar(zone)
