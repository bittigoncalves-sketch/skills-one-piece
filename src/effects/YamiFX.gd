class_name YamiFX
extends RefCounted
# Geração visual e mecânica procedural da Yami Yami no Mi (Trevas / Gravidade Abissal).
# Habilidades reformuladas: Disparo de Pistola (Z), Espiral Negra (X), Black Hole (C) e Liberation (V).

const DARK_PURPLE  := Color(0.18, 0.08, 0.28, 0.95)
const VOID_BLACK   := Color(0.04, 0.02, 0.06, 1.0)
const GLOW_VIOLET  := Color(0.65, 0.25, 0.95, 0.85)
const CONCRETE_GRY := Color(0.42, 0.44, 0.48, 1.0)
const LIB_CYAN     := Color(0.20, 0.75, 1.00, 0.90)
const LIB_BLUE     := Color(0.10, 0.45, 0.95, 0.85)
const LIB_WHITE    := Color(0.95, 0.98, 1.00, 1.00)

# Limites de otimização de performance do abismo
const MAX_ABSORBED_BLOCKS := 30 # Máximo de blocos armazenados na escuridão
const MAX_SPAWN_PER_CAST := 25  # Limite máximo de blocos gerados por conjuração no Liberation
const MAX_SCENE_BLOCKS    := 35 # Limite máximo simultâneo de blocos na cena inteira (evita queda de FPS)

static var _shared_block_mesh: BoxMesh = null
static var _shared_block_mat: StandardMaterial3D = null

static func get_shared_block_mesh() -> BoxMesh:
	if _shared_block_mesh == null:
		_shared_block_mesh = BoxMesh.new()
		_shared_block_mesh.size = Vector3(1.0, 1.0, 1.0)
	return _shared_block_mesh

static func get_shared_block_mat() -> StandardMaterial3D:
	if _shared_block_mat == null:
		_shared_block_mat = StandardMaterial3D.new()
		_shared_block_mat.albedo_color = CONCRETE_GRY
		_shared_block_mat.roughness = 0.9
	return _shared_block_mat

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _pistol_shot(world, origin, dir, damage, caster)
		1: _kurouzu(world, origin, dir, damage, caster)
		2: _black_hole(world, origin, damage, caster)
		_: _liberation(world, origin, dir, damage, caster)

# ---------- Z: Disparo de Pistola (Tiro de Trevas) ----------
# Chamado tanto no clique esquerdo com a pistola empunhada quanto na execução do slot Z.
static func _pistol_shot(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	bullet(world, origin, dir, damage, caster)

static func bullet(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var fwd: Vector3 = dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	if fwd != Vector3.ZERO:
		zone.look_at(origin + fwd, Vector3.UP)

	# Efeito de clarão de disparo (Muzzle Flash) e faísca de pólvora na saída do cano
	var flash_pm := ParticleProcessMaterial.new()
	flash_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flash_pm.emission_sphere_radius = 0.15
	flash_pm.direction = fwd
	flash_pm.spread = 35.0
	flash_pm.initial_velocity_min = 3.0
	flash_pm.initial_velocity_max = 8.0
	flash_pm.scale_min = 0.3
	flash_pm.scale_max = 0.6
	flash_pm.color_ramp = FxUtil.gradient([Color(1.0, 0.9, 0.4, 1.0), Color(0.9, 0.4, 0.1, 0.8), Color(0.5, 0.5, 0.5, 0.3), Color(0, 0, 0, 0)])
	var muzzle := FxUtil.particles(35, 0.25, true, flash_pm, FxUtil.grain(0.45))
	var muzzle_root := Node3D.new()
	muzzle_root.position = origin
	muzzle_root.add_child(muzzle)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 4.0
	light.omni_range = 5.0
	muzzle_root.add_child(light)
	world.add_child(muzzle_root)
	var tw_l := world.create_tween()
	tw_l.tween_property(light, "light_energy", 0.0, 0.08)
	tw_l.tween_interval(0.2)
	tw_l.tween_callback(muzzle_root.queue_free)

	# Projétil: LITERALMENTE bala de arma de fogo (metal latão/chumbo extremamente rápida)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.04
	cap.height = 0.35
	body.mesh = cap
	body.rotation_degrees.x = 90
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.78, 0.3, 1.0) # Latão / Chumbo polido
	m.metallic = 0.9
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.35)
	m.emission_energy_multiplier = 3.0           # Efeito traçante (tracer) de tiro real
	body.material_override = m
	zone.add_child(body)

	# Rastro fino de fumaça clara de pólvora
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1) # para trás em espaço local
	pm.spread = 5.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.scale_min = 0.15
	pm.scale_max = 0.45
	pm.color_ramp = FxUtil.gradient([Color(0.85, 0.85, 0.85, 0.6), Color(0.6, 0.6, 0.6, 0.3), Color(0.4, 0.4, 0.4, 0.0)])
	zone.add_child(FxUtil.particles(20, 0.25, false, pm, FxUtil.grain(0.3)))

	AudioFX.gunshot(world, origin, randf_range(0.95, 1.05)) # Som nítido de disparo de pistola
	zone.setup(damage, 12.0, fwd * 105.0, 0.5, caster, 0.3) # Bala de arma de fogo de altíssima velocidade

# ---------- X: Espiral Negra / Kurouzu ----------
static func _kurouzu(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var fwd := dir.normalized()
	if caster and caster is CharacterBody3D:
		caster.set_meta("custom_pose", "kurouzu")
		if caster.has_method("lock_movement"):
			caster.lock_movement(3.2, "kurouzu")
		# Limpa a pose após o ataque
		var tw_caster := world.create_tween()
		tw_caster.tween_interval(3.2)
		tw_caster.tween_callback(func():
			if is_instance_valid(caster) and caster.get_meta("custom_pose", "") == "kurouzu":
				caster.set_meta("custom_pose", "")
		)

	# Efeito de vórtice negro estendido da mão com Anéis de Disco de Acréscimo (Accretion Disks)
	var vortex_root := Node3D.new()
	world.add_child(vortex_root)
	var palm_pos := origin + fwd * 1.2
	vortex_root.global_position = palm_pos

	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 1.8
	var sphere_inst := MeshInstance3D.new()
	sphere_inst.mesh = sm
	sphere_inst.material_override = FxUtil.particle_material(VOID_BLACK, 6.0, true)
	vortex_root.add_child(sphere_inst)

	# Anel 1 de Gravidade (Disco de Acréscimo Violeta)
	var ring1 := MeshInstance3D.new()
	var tr1 := TorusMesh.new()
	tr1.inner_radius = 1.1
	tr1.outer_radius = 1.5
	tr1.rings = 32
	tr1.ring_segments = 16
	ring1.mesh = tr1
	var m_ring := StandardMaterial3D.new()
	m_ring.albedo_color = GLOW_VIOLET
	m_ring.emission_enabled = true
	m_ring.emission = GLOW_VIOLET
	m_ring.emission_energy_multiplier = 5.0
	ring1.material_override = m_ring
	vortex_root.add_child(ring1)

	# Anel 2 de Gravidade (Inclinado)
	var ring2 := MeshInstance3D.new()
	var tr2 := TorusMesh.new()
	tr2.inner_radius = 1.4
	tr2.outer_radius = 1.8
	tr2.rings = 32
	tr2.ring_segments = 16
	ring2.mesh = tr2
	ring2.material_override = m_ring
	ring2.rotation_degrees = Vector3(45, 0, 30)
	vortex_root.add_child(ring2)

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 45.0
	pm.initial_velocity_min = -6.0
	pm.initial_velocity_max = -14.0 # Puxa para a mão de forma concentrada
	pm.scale_min = 0.2
	pm.scale_max = 0.7 # Tamanho reduzido para manter a visão do jogador clara
	pm.color_ramp = FxUtil.gradient([GLOW_VIOLET, DARK_PURPLE, VOID_BLACK])
	vortex_root.add_child(FxUtil.particles(80, 0.6, true, pm, FxUtil.grain(0.5)))

	AudioFX.whoosh(world, palm_pos, 0.6)

	# Procura jogador / inimigo mais próximo no alcance (~28m)
	var target := _find_closest_entity(world, caster, origin, 28.0)
	if target:
		print("🌑 ESPIRAL NEGRA (Kurouzu)! ", target.name, " atraído para a mão do usuário e com poderes/ataques negados!")
		target.set_meta("in_kurouzu", true)
		target.set_meta("yami_silenced", true)
		if target.has_method("suppress_skills_temporarily"):
			target.suppress_skills_temporarily(4.0)

		var ctrl := KurouzuController.new(caster, target, fwd, damage, vortex_root, ring1, ring2)
		world.add_child(ctrl)
	else:
		# Se não houver alvo, destrói o VFX e libera o movimento rapidamente (0.5s)
		if is_instance_valid(caster):
			if "movement_locked_timer" in caster:
				caster.movement_locked_timer = 0.5
			elif "_movement_locked_timer" in caster:
				caster._movement_locked_timer = 0.5
		var tw := world.create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(func():
			if is_instance_valid(vortex_root):
				vortex_root.queue_free()
			if is_instance_valid(caster) and caster.get_meta("custom_pose", "") == "kurouzu":
				caster.set_meta("custom_pose", "")
		)

# ---------- C: Black Hole ----------
static func _black_hole(world: Node, origin: Vector3, damage: float, caster: Node) -> void:
	if caster and caster is CharacterBody3D:
		caster.set_meta("custom_pose", "black_hole")
		caster.set_meta("yami_black_hole_active", true)
		if caster.has_method("lock_movement"):
			caster.lock_movement(7.0, "black_hole")

	var ground_pos: Vector3 = origin
	if is_instance_valid(caster) and caster is Node3D:
		ground_pos = caster.global_position
	# Raycast ou ajuste compensado acima do piso para eliminar conflito (Z-fighting) com o chão
	var hit_y: float = ground_pos.y
	if world.get_viewport() and world.get_viewport().world_3d:
		var space_state := world.get_viewport().world_3d.direct_space_state
		var query := PhysicsRayQueryParameters3D.create(ground_pos + Vector3(0, 3.0, 0), ground_pos - Vector3(0, 10.0, 0))
		var hit := space_state.intersect_ray(query)
		if hit and hit.has("position"):
			hit_y = hit["position"].y
	ground_pos.y = hit_y + 0.18

	var ctrl := BlackHoleController.new(caster, ground_pos, damage)
	world.add_child(ctrl)

# ---------- V: Liberation (Ribereshon - Repelão & Destruição em Círculo) ----------
static func _liberation(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var fwd := dir.normalized()
	# Posição no chão aos pés do usuário para expansão da onda no plano horizontal sem obstruir a visão!
	var spawn_center := origin
	spawn_center.y = 0.2
	if is_instance_valid(caster) and caster is Node3D:
		spawn_center = Vector3(caster.global_position.x, 0.2, caster.global_position.z)

	var absorbed: int = 0
	if caster and caster.has_meta("yami_absorbed_blocks"):
		absorbed = caster.get_meta("yami_absorbed_blocks", 0)

	# Otimização e Limites: Aplica cap estrito de blocos simultâneos
	var nominal_blocks := 15 + absorbed
	var spawn_count := clampi(nominal_blocks, 12, MAX_SPAWN_PER_CAST)
	
	# Os blocos excedentes além do limite aumentam diretamente o dano de cada escombro para não perder poder de fogo
	var damage_mult := 1.2
	if nominal_blocks > MAX_SPAWN_PER_CAST:
		damage_mult += (nominal_blocks - MAX_SPAWN_PER_CAST) * 0.06

	if is_instance_valid(caster):
		caster.set_meta("yami_absorbed_blocks", 0) # Esvazia a escuridão após liberar

	print("🌊 LIBERATION OTIMIZADO! Onda repulsora ejetando ", spawn_count, " escombros com dano x", snappedf(damage_mult, 0.01), " (Anterior absorvidos: ", absorbed, ")")

	# Onda de Choque Rápida no Solo (Torus 1 - Ciano Brilhante / Branco)
	var burst_root := Node3D.new()
	world.add_child(burst_root)
	burst_root.global_position = spawn_center

	var shock_inst1 := MeshInstance3D.new()
	var shock_mesh1 := TorusMesh.new()
	shock_mesh1.inner_radius = 0.8
	shock_mesh1.outer_radius = 2.0
	shock_mesh1.rings = 64
	shock_mesh1.ring_segments = 16
	shock_inst1.mesh = shock_mesh1
	var sm_mat1 := StandardMaterial3D.new()
	sm_mat1.albedo_color = LIB_CYAN
	sm_mat1.emission_enabled = true
	sm_mat1.emission = LIB_CYAN
	sm_mat1.emission_energy_multiplier = 8.0
	sm_mat1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_inst1.material_override = sm_mat1
	burst_root.add_child(shock_inst1)

	# Onda de Choque Secundária (Torus 2 - Azul Elétrico)
	var shock_inst2 := MeshInstance3D.new()
	var shock_mesh2 := TorusMesh.new()
	shock_mesh2.inner_radius = 0.4
	shock_mesh2.outer_radius = 1.4
	shock_mesh2.rings = 64
	shock_mesh2.ring_segments = 16
	shock_inst2.mesh = shock_mesh2
	var sm_mat2 := StandardMaterial3D.new()
	sm_mat2.albedo_color = LIB_BLUE
	sm_mat2.emission_enabled = true
	sm_mat2.emission = LIB_BLUE
	sm_mat2.emission_energy_multiplier = 6.0
	sm_mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_inst2.material_override = sm_mat2
	shock_inst2.position.y = 0.1
	burst_root.add_child(shock_inst2)

	var tw_s := world.create_tween().set_parallel(true)
	tw_s.tween_property(shock_inst1, "scale", Vector3(50.0, 0.4, 50.0), 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(sm_mat1, "albedo_color:a", 0.0, 0.6)
	tw_s.tween_property(shock_inst2, "scale", Vector3(38.0, 0.6, 38.0), 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(sm_mat2, "albedo_color:a", 0.0, 0.7)

	# Partículas horizontais de expulsão (NÃO SOBEM PARA NÃO CEGAR O JOGADOR - Cor remete à energia repulsora)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 1.5
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 0.2
	pm.direction = Vector3(0, 0.05, 0) # No plano horizontal
	pm.spread = 180.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -2.0, 0) # Mantém próximo ao solo
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = FxUtil.gradient([LIB_WHITE, LIB_CYAN, LIB_BLUE, Color(0, 0, 0, 0)])
	var burst := FxUtil.particles(110, 0.65, true, pm, FxUtil.grain(0.8)) # Contagem otimizada (110)
	burst_root.add_child(burst)

	AudioFX.impact(world, spawn_center, 0.5)
	AudioFX.whoosh(world, spawn_center, 0.4)

	# Limpeza preventiva se a cena inteira estiver próxima do teto de blocos (MAX_SCENE_BLOCKS)
	if world.get_tree():
		var scene_blocks := world.get_tree().get_nodes_in_group("yami_blocks")
		if scene_blocks.size() + spawn_count > MAX_SCENE_BLOCKS:
			var excess: int = (scene_blocks.size() + spawn_count) - MAX_SCENE_BLOCKS
			for idx in range(mini(excess, scene_blocks.size())):
				var b := scene_blocks[idx]
				if is_instance_valid(b) and b.has_method("despawn"):
					b.despawn()
				elif is_instance_valid(b):
					b.queue_free()

	# REPELÃO: Escombros e blocos ejetados com recursos compartilhados (Zero micro-stutters)
	for i in range(spawn_count):
		var blk := YamiBlock.new(damage * damage_mult, caster)
		world.add_child(blk)
		var angle := randf_range(0, TAU)
		var dist := randf_range(0.8, 3.5)
		var offset_start := Vector3(cos(angle) * dist, randf_range(0.2, 1.2), sin(angle) * dist)
		blk.global_position = spawn_center + offset_start
		var throw_dir := Vector3(cos(angle), randf_range(0.15, 0.35), sin(angle)).normalized()
		blk.velocity = throw_dir * randf_range(25.0, 45.0)

	# Aplica Repelão (Extremo Knockback) nos inimigos ao redor do Liberation
	var all_entities := world.get_tree().get_nodes_in_group("enemy")
	for e in all_entities:
		if is_instance_valid(e) and e is Node3D and e != caster:
			var dist_e := spawn_center.distance_to(e.global_position)
			if dist_e <= 25.0:
				var repulse_dir: Vector3 = (e as Node3D).global_position - spawn_center
				repulse_dir.y = 0
				repulse_dir = repulse_dir.normalized() if repulse_dir.length_squared() > 0.01 else fwd
				var kb: Vector3 = repulse_dir * 38.0 + Vector3.UP * 7.0
				if e.has_method("take_damage"):
					e.take_damage(damage * 1.5, spawn_center, kb)
				elif "velocity" in e:
					e.velocity = kb

	var tw := world.create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(burst_root.queue_free)

static func _find_closest_entity(world: Node, ignore_caster: Node, center: Vector3, max_dist: float) -> Node3D:
	var best_target: Node3D = null
	var best_dist := max_dist
	var candidates := world.get_tree().get_nodes_in_group("enemy") + world.get_tree().get_nodes_in_group("player")
	for c in candidates:
		if not (c is Node3D) or c == ignore_caster:
			continue
		var d: float = center.distance_to(c.global_position)
		if d < best_dist and d > 0.2:
			best_dist = d
			best_target = c
	return best_target

# ==================== CLASSES INTERNAS / CONTROLADORES ====================

class KurouzuController extends Node:
	var caster: Node3D
	var target: Node3D
	var fwd: Vector3
	var damage: float
	var vortex_root: Node3D
	var ring1: MeshInstance3D
	var ring2: MeshInstance3D
	var elapsed := 0.0
	const DURATION := 3.0

	func _init(c: Node3D, t: Node3D, f: Vector3, d: float, v: Node3D, r1: MeshInstance3D = null, r2: MeshInstance3D = null) -> void:
		caster = c
		target = t
		fwd = f
		damage = d
		vortex_root = v
		ring1 = r1
		ring2 = r2

	func _unlock_caster() -> void:
		if is_instance_valid(caster):
			if "movement_locked_timer" in caster:
				caster.movement_locked_timer = 0.0
			elif "_movement_locked_timer" in caster:
				caster._movement_locked_timer = 0.0
			if caster.has_meta("custom_pose") and caster.get_meta("custom_pose") == "kurouzu":
				caster.set_meta("custom_pose", "")

	func _process(delta: float) -> void:
		elapsed += delta
		if is_instance_valid(ring1):
			ring1.rotation.y += 14.0 * delta
			ring1.rotation.x += 4.0 * delta
		if is_instance_valid(ring2):
			ring2.rotation.y -= 16.0 * delta
			ring2.rotation.z += 6.0 * delta

		if elapsed >= DURATION or not is_instance_valid(target) or not is_instance_valid(caster):
			_unlock_caster()
			if is_instance_valid(target):
				target.set_meta("in_kurouzu", false)
				target.set_meta("yami_silenced", false)
				if target.has_method("take_damage"):
					target.take_damage(damage, caster.global_position if is_instance_valid(caster) else Vector3.ZERO, fwd * 18.0 + Vector3.UP * 4.0)
				if get_tree() and get_tree().current_scene:
					AudioFX.impact(get_tree().current_scene, target.global_position, 0.8)
			if is_instance_valid(vortex_root):
				vortex_root.queue_free()
			queue_free()
			return

		# Posição na palma da mão do usuário
		var palm_pos: Vector3 = caster.global_position + fwd * 1.4 + Vector3.UP * 1.1
		target.global_position = target.global_position.lerp(palm_pos, 1.0 - exp(-15.0 * delta))
		if is_instance_valid(vortex_root):
			vortex_root.global_position = palm_pos

		# Garante anulação de habilidades e imersão na atração
		target.set_meta("in_kurouzu", true)
		target.set_meta("yami_silenced", true)

		# Arremessar o inimigo com UM GRANDE KNOCKBACK ao clicar com o botão esquerdo do mouse!
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and elapsed > 0.25 and is_instance_valid(target):
			var throw_dir: Vector3 = fwd
			if is_instance_valid(caster) and "_cam" in caster and is_instance_valid(caster._cam):
				throw_dir = -caster._cam.global_transform.basis.z.normalized()
			elif is_instance_valid(caster) and "rotation" in caster:
				throw_dir = -caster.global_transform.basis.z.normalized()
			
			_unlock_caster() # <--- LIBERA O JOGADOR IMEDIATAMENTE PARA SE MOVER!
			target.set_meta("in_kurouzu", false)
			target.set_meta("yami_silenced", false)
			var mega_kb: Vector3 = throw_dir * 45.0 + Vector3.UP * 10.0
			if target.has_method("take_damage"):
				target.take_damage(damage * 1.5, palm_pos, mega_kb)
			elif "velocity" in target:
				target.velocity = mega_kb
			
			if get_tree() and get_tree().current_scene:
				AudioFX.impact(get_tree().current_scene, target.global_position, 0.6)
				AudioFX.whoosh(get_tree().current_scene, target.global_position, 0.7)
				var pm := ParticleProcessMaterial.new()
				pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
				pm.emission_sphere_radius = 0.8
				pm.direction = throw_dir
				pm.spread = 20.0
				pm.initial_velocity_min = 15.0
				pm.initial_velocity_max = 28.0
				pm.scale_min = 0.4
				pm.scale_max = 0.9
				pm.color_ramp = FxUtil.gradient([YamiFX.GLOW_VIOLET, YamiFX.DARK_PURPLE, YamiFX.VOID_BLACK, Color(0, 0, 0, 0)])
				var burst := FxUtil.particles(150, 0.5, true, pm, FxUtil.grain(0.7))
				var root_fx := Node3D.new()
				root_fx.position = target.global_position
				root_fx.add_child(burst)
				get_tree().current_scene.add_child(root_fx)
			
			print("💥 KURUOZU RELEASE: Inimigo arremessado com MEGA KNOCKBACK e jogador liberado para mover!")
			if is_instance_valid(vortex_root):
				vortex_root.queue_free()
			queue_free()
			return


class BlackHoleController extends Node:
	var caster: Node3D
	var center: Vector3
	var damage: float
	var elapsed := 0.0
	var tick := 0.0
	var pool: MeshInstance3D
	const MAX_DURATION := 7.0
	const RADIUS := 32.0

	func _init(c: Node3D, pos: Vector3, d: float) -> void:
		caster = c
		center = pos
		damage = d

	func _ready() -> void:
		pool = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = RADIUS
		cyl.bottom_radius = RADIUS
		cyl.height = 0.12
		pool.mesh = cyl
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = YamiFX.VOID_BLACK
		p_mat.emission_enabled = true
		p_mat.emission = YamiFX.VOID_BLACK
		p_mat.emission_energy_multiplier = 3.0
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p_mat.render_priority = 10 # Prioridade de render acima do chão para eliminar Z-fighting!
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pool.material_override = p_mat
		add_child(pool)
		pool.global_position = center

		# Anel de Horizonte de Eventos no solo ao redor do pântano (ligeiramente mais alto que o pool)
		var horizon := MeshInstance3D.new()
		var h_mesh := TorusMesh.new()
		h_mesh.inner_radius = RADIUS - 0.5
		h_mesh.outer_radius = RADIUS + 0.5
		h_mesh.rings = 64
		h_mesh.ring_segments = 16
		horizon.mesh = h_mesh
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = YamiFX.GLOW_VIOLET
		h_mat.emission_enabled = true
		h_mat.emission = YamiFX.GLOW_VIOLET
		h_mat.emission_energy_multiplier = 5.0
		h_mat.render_priority = 15 # Renderiza acima do pântano e do piso
		h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		horizon.material_override = h_mat
		horizon.position.y = 0.08 # Elevação sobre o cilindro para evitar sobreposição de vértices
		pool.add_child(horizon)
		horizon.name = "HorizonRing"

		# Anel interno concêntrico (sucção e profundidade visual sem ocupar altura)
		var inner_ring := MeshInstance3D.new()
		var i_mesh := TorusMesh.new()
		i_mesh.inner_radius = RADIUS * 0.5 - 0.4
		i_mesh.outer_radius = RADIUS * 0.5 + 0.4
		i_mesh.rings = 48
		i_mesh.ring_segments = 16
		inner_ring.mesh = i_mesh
		var i_mat := h_mat.duplicate()
		i_mat.albedo_color = YamiFX.DARK_PURPLE
		i_mat.emission = YamiFX.GLOW_VIOLET
		i_mat.emission_energy_multiplier = 4.0
		i_mat.render_priority = 18 # Top render priority
		inner_ring.material_override = i_mat
		inner_ring.position.y = 0.12 # Elevação camada 2
		pool.add_child(inner_ring)
		inner_ring.name = "InnerRing"

		# Partículas RENTAS AO SOLO para NÃO OBSTRUIR A VISÃO do jogador
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(RADIUS - 2.0, 0.1, RADIUS - 2.0)
		pm.direction = Vector3.UP
		pm.spread = 70.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.5 # Velocidade mínima para não subir na frente da câmera!
		pm.gravity = Vector3(0, -0.1, 0) # Mantém no chão como um pântano
		pm.scale_min = 0.4
		pm.scale_max = 1.2
		pm.color_ramp = FxUtil.gradient([YamiFX.VOID_BLACK, YamiFX.DARK_PURPLE, YamiFX.GLOW_VIOLET, Color(0, 0, 0, 0)])
		var smoke := FxUtil.particles(140, 1.5, false, pm, FxUtil.grain(0.8))
		add_child(smoke)
		smoke.global_position = center + Vector3.UP * 0.1
		AudioFX.whoosh(get_tree().current_scene, center, 0.45)

	func _process(delta: float) -> void:
		elapsed += delta
		tick += delta
		if is_instance_valid(pool):
			var hr := pool.get_node_or_null("HorizonRing")
			if hr and is_instance_valid(hr):
				hr.rotation.y += 1.8 * delta
			var ir := pool.get_node_or_null("InnerRing")
			if ir and is_instance_valid(ir):
				ir.rotation.y -= 2.5 * delta

		var holding := true
		if is_instance_valid(caster) and caster.has_meta("yami_black_hole_active"):
			holding = caster.get_meta("yami_black_hole_active", true)
		elif not is_instance_valid(caster):
			holding = false

		if elapsed >= MAX_DURATION or not holding:
			_terminate()
			return

		# A cada 0.05s (20Hz) processa sucção, afundo e bloqueio de poderes
		if tick >= 0.05 and get_tree():
			tick = 0.0
			var all_entities := get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
			for e in all_entities:
				if not (e is Node3D) or e == caster:
					continue
				if center.distance_to(e.global_position) <= RADIUS + 0.5:
					e.set_meta("in_black_hole", true)
					e.set_meta("yami_silenced", true)
					if e.has_method("suppress_skills_temporarily"):
						e.suppress_skills_temporarily(10.0)
					# Puxa para o centro do pântano
					var pull_dir: Vector3 = (center - e.global_position)
					pull_dir.y = 0
					e.global_position += pull_dir.normalized() * minf(pull_dir.length(), 3.5 * delta)
					# Efeito AFUNDO: puxa levemente para baixo (presos e afundando no chão)
					if e.global_position.y > -0.5 and not ("is_player" in e and e.is_player):
						e.global_position.y = maxf(-0.5, e.global_position.y - 1.5 * delta)

			# Anula ataques de Akuma no Mi e DamageZones externos
			if get_tree().current_scene:
				for child in get_tree().current_scene.get_children():
					if child is DamageZone and child.global_position.distance_to(center) <= RADIUS:
						child.queue_free()
						print("🛡️ ATAQUE E DANO DE AKUMA NO MI ANULADO PELO BLACK HOLE!")

			# Absorve blocos cinza gerados pelo Liberation
			for blk in get_tree().get_nodes_in_group("yami_blocks"):
				if blk is Node3D and blk.get("landed") == true and blk.global_position.distance_to(center) <= RADIUS + 1.0:
					blk.position.y -= 3.0 * delta
					if blk.position.y < -0.5:
						blk.queue_free()
						if is_instance_valid(caster):
							var cnt: int = caster.get_meta("yami_absorbed_blocks", 0)
							var new_cnt := mini(cnt + 1, YamiFX.MAX_ABSORBED_BLOCKS)
							caster.set_meta("yami_absorbed_blocks", new_cnt)
							print("🌑 Bloco cinza absorvido no pântano! Total guardado: ", new_cnt, "/", YamiFX.MAX_ABSORBED_BLOCKS)

	func _terminate() -> void:
		if is_instance_valid(caster):
			if caster.get_meta("custom_pose", "") == "black_hole":
				caster.set_meta("custom_pose", "")
			if "movement_locked_timer" in caster:
				caster.movement_locked_timer = 0.0
			elif "_movement_locked_timer" in caster:
				caster._movement_locked_timer = 0.0
			if caster.has_meta("yami_black_hole_active"):
				caster.set_meta("yami_black_hole_active", false)

		if get_tree():
			var all_entities := get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
			for e in all_entities:
				if is_instance_valid(e) and e.has_meta("in_black_hole") and e.get_meta("in_black_hole"):
					e.set_meta("in_black_hole", false)
					if e is Node3D and e.global_position.y < 0.1:
						e.global_position.y = 0.1

		if get_tree() and get_tree().current_scene:
			AudioFX.impact(get_tree().current_scene, center, 0.6)
		queue_free()


class YamiBlock extends Node3D:
	var velocity := Vector3.ZERO
	var rot_spd := Vector3.ZERO
	var damage := 15.0
	var landed := false
	var caster: Node
	var hit_targets := []
	var mesh_inst: MeshInstance3D

	func _init(d: float, c: Node) -> void:
		damage = maxf(d * 0.25, 12.0)
		caster = c
		rot_spd = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))

	func _ready() -> void:
		add_to_group("yami_blocks")
		mesh_inst = MeshInstance3D.new()
		# Otimização: Reutiliza o MESMO BoxMesh e StandardMaterial3D em memória (zero alocação de malha/material)
		mesh_inst.mesh = YamiFX.get_shared_block_mesh()
		mesh_inst.material_override = YamiFX.get_shared_block_mat()
		mesh_inst.scale = Vector3(randf_range(0.5, 1.3), randf_range(0.5, 1.3), randf_range(0.5, 1.3))
		add_child(mesh_inst)

	func despawn() -> void:
		if get_tree() == null or not is_inside_tree():
			queue_free()
			return
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(queue_free)

	func _physics_process(delta: float) -> void:
		if landed:
			return
		velocity.y -= 26.0 * delta
		position += velocity * delta
		rotation += rot_spd * delta

		# Dano e knockback enquanto voa/cai
		if get_tree():
			for e in get_tree().get_nodes_in_group("enemy"):
				if not (e is Node3D) or e in hit_targets or e == caster:
					continue
				if global_position.distance_to(e.global_position + Vector3.UP * 0.8) < 1.8:
					hit_targets.append(e)
					if e.has_method("take_damage"):
						var kb := velocity.normalized() * 14.0 + Vector3.UP * 3.0
						e.take_damage(damage, global_position, kb)
					if get_tree() and get_tree().current_scene:
						AudioFX.snap(get_tree().current_scene, global_position, 0.8)

		# Queda definitiva no solo
		if position.y <= 0.35:
			position.y = 0.35
			velocity = Vector3.ZERO
			rot_spd = Vector3.ZERO
			landed = true
			rotation = Vector3(0, rotation.y, 0)
			
			# OTIMIZAÇÃO CRÍTICA: Desativa processamento de física quando atinge o chão!
			set_physics_process(false)
			if get_tree():
				# Auto-despawn suave caso não seja absorvido pelo Black Hole após 20 segundos
				get_tree().create_timer(20.0).timeout.connect(func(): if is_instance_valid(self): despawn())

			# Otimização de áudio e poeira: aciona efeitos de queda em apenas ~35% dos blocos para evitar sobrecarga de som/partícula
			if get_tree() and get_tree().current_scene and randf() < 0.35:
				AudioFX.impact(get_tree().current_scene, global_position, randf_range(0.95, 1.2))
				var pm := ParticleProcessMaterial.new()
				pm.direction = Vector3.UP
				pm.spread = 70.0
				pm.initial_velocity_min = 1.0
				pm.initial_velocity_max = 3.5
				pm.scale_min = 0.2
				pm.scale_max = 0.45
				pm.color = YamiFX.CONCRETE_GRY
				var dust := FxUtil.particles(6, 0.2, true, pm, FxUtil.grain(0.35))
				var d_root := Node3D.new()
				d_root.position = global_position
				d_root.add_child(dust)
				get_tree().current_scene.add_child(d_root)
