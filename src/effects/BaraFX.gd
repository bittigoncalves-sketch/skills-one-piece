class_name BaraFX
extends RefCounted
# Geração visual e física procedural da Bara Bara no Mi (Sukuna-inspired).
# VFX Premium: Shaders de alta emissão, heat distortion e tweening dinâmico.

const SLASH_RED    := Color(0.8, 0.1, 0.1, 0.95)
const SLASH_BLACK  := Color(0.05, 0.02, 0.02, 1.0)
const BUGGY_RED    := Color(1.0, 0.05, 0.05, 0.95)
const ORANGE_FIRE  := Color(1.0, 0.5, 0.0, 0.9)
const BONE_WHITE   := Color(0.9, 0.85, 0.8, 1.0)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _bara_corte(world, origin, dir, damage, caster, spec)
		1: _bara_buggy_ball(world, origin + Vector3.UP * 1.2, dir, damage, caster, spec)
		2: _bara_area_cortante(world, origin, dir, damage, caster, spec)
		_: _bara_dominio(world, origin, damage, caster, spec)

# ---------- Z: Corte Único (Dismantle) ----------
static func _bara_corte(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin + Vector3.UP * 1.0

	var fwd := dir.normalized()
	zone.look_at(zone.global_position + fwd, Vector3.UP)

	# Lâmina de distorção (Dismantle)
	var slash := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.4
	slash.mesh = tm
	slash.scale = Vector3(1.2, 0.05, 0.5)
	slash.rotation_degrees.x = 90
	
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
	shader_type spatial;
	render_mode unshaded, cull_disabled;
	uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
	void fragment() {
		vec2 ref_uv = SCREEN_UV + (NORMAL.xy * 0.05);
		ALBEDO = texture(screen_tex, ref_uv).rgb + vec3(0.5, 0.0, 0.0) * UV.y;
		ALPHA = 0.8;
	}
	"""
	mat.shader = sh
	slash.material_override = mat
	zone.add_child(slash)

	# Flash branco no Leading Edge
	var flash := MeshInstance3D.new()
	var fm := TorusMesh.new()
	fm.inner_radius = 1.3
	fm.outer_radius = 1.4
	flash.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1, 1, 1, 1)
	fmat.emission_enabled = true
	fmat.emission = Color(1, 1, 1, 1)
	fmat.emission_energy_multiplier = 10.0
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.material_override = fmat
	slash.add_child(flash)

	# Partículas de sangue/faíscas
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 15.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 12.0
	pm.scale_min = 0.2
	pm.scale_max = 0.8
	pm.color_ramp = FxUtil.gradient([SLASH_RED, SLASH_BLACK, Color(0, 0, 0, 0)])

	var trail := FxUtil.particles(150, 0.4, true, pm, FxUtil.grain(0.4))
	trail.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	trail.process_material.emission_box_extents = Vector3(1.0, 0.1, 0.2)
	zone.add_child(trail)

	var tw := zone.create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "scale:x", 3.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(fmat, "albedo_color:a", 0.0, 0.2)
	tw.set_parallel(false)

	zone.setup(spec.dano, 18.0, fwd * 45.0, 0.6, caster, 1.2)
	spec.marcar(zone)
	zone.derruba = 1.2
	AudioFX.hurt(world, origin)

# ---------- X: Buggy Ball (Fuga / Flecha de Fogo) ----------
static func _bara_buggy_ball(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin + Vector3.UP * 1.0

	var fwd := dir.normalized()
	zone.look_at(zone.global_position + fwd, Vector3.UP)

	# Ponta de flecha de fogo
	var arrow := MeshInstance3D.new()
	var am := PrismMesh.new()
	am.size = Vector3(1.0, 2.0, 0.2)
	arrow.mesh = am
	arrow.rotation_degrees.x = -90 # aponta para frente
	
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
	shader_type spatial;
	render_mode unshaded, blend_add;
	void fragment() {
		ALBEDO = vec3(1.0, 0.3, 0.0);
		ALPHA = 1.0;
	}
	"""
	mat.shader = sh
	arrow.material_override = mat
	zone.add_child(arrow)

	# Fogo volumétrico/pulsante via Esfera com shader Voronoi simples
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.8
	sm.height = 1.6
	ball.mesh = sm
	var mat_f := StandardMaterial3D.new()
	mat_f.albedo_color = SLASH_BLACK
	mat_f.emission_enabled = true
	mat_f.emission = ORANGE_FIRE
	mat_f.emission_energy_multiplier = 8.0
	ball.material_override = mat_f
	zone.add_child(ball)

	# Fumaça preta escapando
	var pm := ParticleProcessMaterial.new()
	pm.direction = -fwd
	pm.spread = 20.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.color = Color(0.1, 0.1, 0.1, 0.8)
	var smoke := FxUtil.particles(200, 1.0, true, pm, FxUtil.grain(0.5))
	zone.add_child(smoke)

	# Velocidade lenta (Flecha de Fogo)
	zone.setup(spec.dano, 18.0, fwd * 25.0, 1.5, caster, 0.6)
	spec.marcar(zone)
	zone.derruba = 1.5
	
	var explode_fn = func(pos: Vector3):
		var boom_root := Node3D.new()
		world.add_child(boom_root)
		boom_root.global_position = pos
		
		# 1. Esfera de Fogo Expansiva (A Explosão Principal Volumétrica)
		var sphere := MeshInstance3D.new()
		var exp_sm := SphereMesh.new()
		exp_sm.radius = 1.0
		exp_sm.height = 2.0
		sphere.mesh = exp_sm
		var exp_mat := StandardMaterial3D.new()
		exp_mat.albedo_color = Color(1.0, 0.8, 0.2)
		exp_mat.emission_enabled = true
		exp_mat.emission = Color(1.0, 0.4, 0.0)
		exp_mat.emission_energy_multiplier = 16.0
		exp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Adicionar algum noise para não ser apenas uma esfera lisa
		var noise_tex = NoiseTexture2D.new()
		var fn = FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise_tex.noise = fn
		exp_mat.albedo_texture = noise_tex
		sphere.material_override = exp_mat
		boom_root.add_child(sphere)
		
		# 2. Núcleo branco intenso da explosão
		var core := MeshInstance3D.new()
		var core_sm := SphereMesh.new()
		core_sm.radius = 0.5
		core_sm.height = 1.0
		core.mesh = core_sm
		var core_mat := StandardMaterial3D.new()
		core_mat.albedo_color = Color(1.0, 1.0, 1.0)
		core_mat.emission_enabled = true
		core_mat.emission = Color(1.0, 1.0, 1.0)
		core_mat.emission_energy_multiplier = 20.0
		core.material_override = core_mat
		boom_root.add_child(core)
		
		# 3. Partículas de explosão (Fogo/Fumaça)
		var exp_pm := ParticleProcessMaterial.new()
		exp_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		exp_pm.emission_sphere_radius = 2.0
		exp_pm.direction = Vector3(0, 1, 0)
		exp_pm.spread = 180.0
		exp_pm.initial_velocity_min = 15.0
		exp_pm.initial_velocity_max = 30.0
		exp_pm.damping_min = 10.0
		exp_pm.damping_max = 20.0
		exp_pm.scale_min = 3.0
		exp_pm.scale_max = 7.0
		
		var grad := GradientTexture1D.new()
		var g := Gradient.new()
		g.add_point(0.0, Color(1.0, 0.8, 0.1, 1.0)) # Amarelo/Branco
		g.add_point(0.1, Color(1.0, 0.3, 0.0, 1.0)) # Laranja
		g.add_point(0.4, Color(0.1, 0.1, 0.1, 0.9)) # Fumaça preta
		g.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0)) # Invisivel
		grad.gradient = g
		exp_pm.color_ramp = grad
		
		var fire_part = FxUtil.particles(200, 1.5, true, exp_pm, FxUtil.grain(0.5), 1.0)
		boom_root.add_child(fire_part)
		
		AudioFX.hurt(world, pos)
		if caster and caster.has_method("add_camera_shake"):
			caster.add_camera_shake(5.0)
		
		var bt = boom_root.create_tween()
		bt.set_parallel(true)
		
		# Esfera principal cresce agressivamente
		bt.tween_property(sphere, "scale", Vector3(12.0, 12.0, 12.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		bt.tween_property(exp_mat, "emission_energy_multiplier", 0.0, 0.6)
		bt.tween_property(exp_mat, "albedo_color:a", 0.0, 0.6)
		
		# Núcleo cresce rápido e some logo
		bt.tween_property(core, "scale", Vector3(5.0, 5.0, 5.0), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		bt.tween_property(core_mat, "emission_energy_multiplier", 0.0, 0.3)
		bt.tween_property(core_mat, "albedo_color:a", 0.0, 0.3)
		
		bt.set_parallel(false)
		bt.tween_interval(1.5)
		bt.tween_callback(boom_root.queue_free)

	zone.collided_with_any.connect(func(_body):
		if not (_body.has_method("take_damage") or _body is StaticBody3D or _body is CSGShape3D or _body is GridMap):
			return
		if is_instance_valid(zone) and not zone.is_queued_for_deletion():
			explode_fn.call(zone.global_position)
			zone.queue_free()
	)
	
	var lifetime := 18.0 / 25.0
	var tw := zone.create_tween()
	tw.tween_interval(lifetime)
	tw.tween_callback(func():
		if is_instance_valid(zone) and not zone.is_queued_for_deletion():
			explode_fn.call(zone.global_position)
			zone.queue_free()
	)

# ---------- C: Área Cortante (Cleave) ----------
static func _bara_area_cortante(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	if not (caster is CharacterBody3D): return
	for child in caster.get_children():
		if child.name == "BaraCleaveController":
			return
			
	var controller := BaraCleaveController.new()
	controller.name = "BaraCleaveController"
	controller.damage = damage
	controller.spec = spec
	caster.add_child(controller)

# ---------- V: Expansão de Domínio (Malevolent Shrine) ----------
static func _bara_dominio(world: Node, origin: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	if caster.get_meta("bara_v_active", false):
		return # Prevents duplicate casts just in case

	var controller := BaraDomainController.new()
	controller.name = "BaraDomainController"
	controller.damage = damage
	controller.spec = spec
	controller.caster = caster
	world.add_child(controller)
	caster.set_meta("bara_v_active", true)


# ==============================================================================
# BARA CLEAVE CONTROLLER (Hold skill C)
# ==============================================================================
class BaraCleaveController extends Node:
	var damage: float = 0.0
	var spec: DamageSpec = null
	var timer: float = 0.0
	var tick_timer: float = 0.0
	const MAX_DURATION: float = 7.0
	const CLEAVE_RADIUS: float = 12.0
	# ⚠️ REDESENHO DE CADÊNCIA (2026-08-21), junto com o rebalanceamento.
	#
	# Era 0,25 s — 28 acertos de dano CRU em 7 s, 175 de dano total, num raio de
	# 12 m. Só reescalar o número daria 28 tiques de 14 cada: uma névoa que tira
	# lascas, que não lê como "área cortante" e ainda ocupa a arena o tempo todo.
	#
	# A 1,4 s são 5 cortes pesados de 80 nos mesmos 7 s. O teto do slot C (384)
	# continua sendo a rede de segurança por cima disso.
	const INTERVALO_CLEAVE: float = 1.4
	
	var vfx_root: Node3D
	var _mat_domain: StandardMaterial3D
	
	func _ready() -> void:
		vfx_root = Node3D.new()
		add_child(vfx_root)
		
		# Quad no chão simulando o domínio de sangue/cortes
		var floor_quad := MeshInstance3D.new()
		# Partículas de destroços (debris)
		var pm_deb := ParticleProcessMaterial.new()
		pm_deb.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm_deb.emission_sphere_radius = CLEAVE_RADIUS
		pm_deb.direction = Vector3.UP
		pm_deb.initial_velocity_min = 2.0
		pm_deb.initial_velocity_max = 8.0
		pm_deb.color = Color(0.2, 0.2, 0.2, 1.0)
		var debris := FxUtil.particles(200, 1.5, true, pm_deb, FxUtil.grain(0.2))
		vfx_root.add_child(debris)
		var plane := PlaneMesh.new()
		plane.size = Vector2(CLEAVE_RADIUS*2, CLEAVE_RADIUS*2)
		floor_quad.mesh = plane
		_mat_domain = StandardMaterial3D.new()
		_mat_domain.albedo_color = Color(0.4, 0.0, 0.0, 0.4)
		_mat_domain.emission_enabled = true
		_mat_domain.emission = SLASH_RED
		_mat_domain.emission_energy_multiplier = 0.8
		_mat_domain.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		floor_quad.material_override = _mat_domain
		vfx_root.add_child(floor_quad)
		


	func _process(delta: float) -> void:
		var caster := get_parent() as CharacterBody3D
		if not caster: 
			queue_free()
			return
			
		if not caster.has_meta("bara_cleave_active") or not caster.get_meta("bara_cleave_active"):
			queue_free()
			return
			
		timer += delta
		if timer >= MAX_DURATION:
			if caster.has_method("pedir_cancelar_hold"):
				caster.pedir_cancelar_hold("C", "bara_bara")
			caster.set_meta("bara_cleave_active", false)
			queue_free()
			return
			
		vfx_root.global_position = caster.global_position + Vector3.UP * 0.1
		vfx_root.rotation.y += delta * 2.0
		
		# Ticks rápidos de VFX no ar (fatiando invisível)
		if randf() < 0.4:
			_spawn_cleave_slash(vfx_root.global_position)
		
		tick_timer += delta
		if tick_timer >= INTERVALO_CLEAVE:
			tick_timer = 0.0
			_apply_cleave(caster)

	func _spawn_cleave_slash(center: Vector3) -> void:
		var slash := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(randf_range(2.0, 5.0), 0.1)
		slash.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_color = SLASH_BLACK
		m.emission_enabled = true
		m.emission = SLASH_RED
		m.emission_energy_multiplier = 6.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		slash.material_override = m
		
		var offset := Vector3(randf_range(-CLEAVE_RADIUS, CLEAVE_RADIUS), randf_range(0.5, 3.0), randf_range(-CLEAVE_RADIUS, CLEAVE_RADIUS))
		slash.global_position = center + offset
		slash.rotation_degrees.z = randf_range(0, 360)
		
		get_tree().current_scene.add_child(slash)
		var tw := slash.create_tween()
		tw.tween_property(m, "albedo_color:a", 0.0, 0.15)
		tw.tween_callback(slash.queue_free)

	func _apply_cleave(caster: CharacterBody3D) -> void:
		if not multiplayer.is_server(): return
		
		var space := caster.get_world_3d().direct_space_state
		var par := PhysicsShapeQueryParameters3D.new()
		var shape := SphereShape3D.new()
		shape.radius = CLEAVE_RADIUS
		par.shape = shape
		par.transform = Transform3D(Basis(), caster.global_position)
		par.collide_with_areas = false
		par.collide_with_bodies = true
		par.exclude = [caster.get_rid()]
		
		var hits = space.intersect_shape(par)
		for h in hits:
			var col = h.get("collider")
			if col and col != caster and col.has_method("take_damage"):
				if col.has_method("lock_movement"):
					col.lock_movement(0.5, "bara_cleave")
				# ⚠️ ERA `take_damage(damage * 0.25)` DIRETO — fora do funil, portanto
				# sem o corte de 0,12 que o resto do jogo levava. Agora passa pelo
				# `CombatResolver` e divide o teto do golpe com os outros cortes.
				CombatResolver.aplicar(col, spec.dano, spec.cast_id, spec.teto,
					caster.global_position, Vector3.ZERO, 0.1)
				if col.has_method("add_camera_shake"):
					col.add_camera_shake(0.5)
				if Engine.has_singleton("ScreenFX"):
					Engine.get_singleton("ScreenFX").flash(Color.WHITE, 0.05)

# ==============================================================================
# BARA DOMAIN CONTROLLER (Skill V)
# ==============================================================================
class BaraDomainController extends Node:
	var spec: DamageSpec = null
	# ⚠️ REDESENHO DE CADÊNCIA (2026-08-21). Era 1 tique por segundo com TRÊS
	# cortes cada — 90 acertos de dano cru em 30 s, 810 de dano total, num raio
	# de 40 m sem linha de visão e sem chance de esquiva. Era a segunda skill
	# mais forte do jogo por acidente.
	#
	# Agora é UM corte a cada 3,5 s: ~8 acertos de 96 nos mesmos 30 s. O domínio
	# continua durando o que durava e continua sendo controle de área — o que
	# ele deixou de ser é um moedor que tira 40% da vida de quem estiver na
	# metade da arena.
	const INTERVALO_DOMINIO: float = 3.5
	const CORTES_POR_TIQUE: int = 1
	var damage: float = 0.0
	var caster: Node = null
	var timer: float = 0.0
	var tick_timer: float = 0.0
	const MAX_DURATION: float = 30.0
	const DOMAIN_RADIUS: float = 40.0
	
	var center_position: Vector3
	
	func _ready() -> void:
		if Engine.has_singleton("ScreenFX"):
			Engine.get_singleton("ScreenFX").chromatic_pulse(2.0)
			# Pisca a tela invertendo cores para ativar o domínio
			Engine.get_singleton("ScreenFX").flash(Color(1.0, 1.0, 1.0, 1.0), 0.1)
		
		if caster and is_instance_valid(caster):
			if caster.has_method("add_camera_shake"):
				caster.add_camera_shake(2.0)
			
			center_position = _spawn_shrine_geometry(caster)
			
			# Alteração de ambiente Global (Domínio)
			var we := caster.get_viewport().get_camera_3d().get_world_3d().environment
			if we:
				we.ambient_light_color = Color(0.3, 0.0, 0.0)
				we.background_color = Color(0.2, 0.0, 0.0)
			
			# Partículas de Cinzas Globais
			var pm_ash := ParticleProcessMaterial.new()
			pm_ash.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm_ash.emission_box_extents = Vector3(40.0, 20.0, 40.0)
			pm_ash.direction = Vector3.DOWN
			pm_ash.initial_velocity_min = 1.0
			pm_ash.initial_velocity_max = 3.0
			pm_ash.color = Color(0.1, 0.1, 0.1, 0.8)
			var ash := FxUtil.particles(500, 5.0, true, pm_ash, FxUtil.grain(0.1))
			add_child(ash)
			ash.global_position = center_position + Vector3(0, 20.0, 0)

	func _spawn_shrine_geometry(caster: Node3D) -> Vector3:
		# Criação procedural altamente detalhada do Santuário de Ossos e Sangue
		var shrine_root := Node3D.new()
		add_child(shrine_root)
		
		var cast_transform = caster.global_transform
		var back_dir = cast_transform.basis.z.normalized()
		var base_pos = cast_transform.origin + back_dir * 5.0
		
		# Corpo estático para colisões
		var static_body := StaticBody3D.new()
		shrine_root.add_child(static_body)
		
		# Raycast para achar o chão
		var space_state = caster.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(base_pos + Vector3(0, 2.0, 0), base_pos + Vector3(0, -100.0, 0))
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if caster is CollisionObject3D:
			query.exclude = [caster.get_rid()]
		
		var hit = space_state.intersect_ray(query)
		if hit and hit.has("position"):
			base_pos.y = hit.position.y
		
		shrine_root.global_position = base_pos
		
		var look_pos = shrine_root.global_position - back_dir
		if look_pos.distance_squared_to(shrine_root.global_position) > 0.001:
			shrine_root.look_at(look_pos, Vector3.UP)
			
		shrine_root.scale = Vector3(0.5, 0.5, 0.5)
		
		# Materiais
		var mat_blood := StandardMaterial3D.new()
		mat_blood.albedo_color = Color(0.1, 0.0, 0.0)
		mat_blood.emission_enabled = true
		mat_blood.emission = SLASH_RED
		mat_blood.emission_energy_multiplier = 0.5
		mat_blood.roughness = 0.1 # Reflexivo
		
		var mat_bone := StandardMaterial3D.new()
		mat_bone.albedo_color = BONE_WHITE
		mat_bone.roughness = 0.9
		
		var mat_wood := StandardMaterial3D.new()
		mat_wood.albedo_color = Color(0.1, 0.05, 0.05) # Madeira bem escura
		
		var mat_torii := StandardMaterial3D.new()
		mat_torii.albedo_color = Color(0.4, 0.05, 0.05) # Madeira pintada de vermelho
		
		var mat_tent := ShaderMaterial.new()
		var sh_tent := Shader.new()
		sh_tent.code = """
		shader_type spatial;
		void fragment() {
			float stripe = step(0.5, fract(UV.x * 8.0 + UV.y * 2.0));
			vec3 col_red = vec3(0.8, 0.05, 0.05);
			vec3 col_white = vec3(0.9, 0.9, 0.9);
			ALBEDO = mix(col_red, col_white, stripe);
		}
		"""
		mat_tent.shader = sh_tent
		
		# 1. Mar de Sangue (Disco gigante no chão)
		var blood_pool := MeshInstance3D.new()
		var cyl_blood := CylinderMesh.new()
		cyl_blood.top_radius = DOMAIN_RADIUS
		cyl_blood.bottom_radius = DOMAIN_RADIUS
		cyl_blood.height = 0.2
		blood_pool.mesh = cyl_blood
		blood_pool.material_override = mat_blood
		blood_pool.position.y = 0.1
		# Sangue fica no centro exato da habilidade
		add_child(blood_pool)
		blood_pool.global_position = base_pos
		
		# 2. Base em Pirâmide de Degraus (3 andares)
		var steps_sizes = [Vector3(14, 1.0, 14), Vector3(11, 1.0, 11), Vector3(8, 1.0, 8)]
		for i in range(3):
			var step_mesh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = steps_sizes[i]
			step_mesh.mesh = bm
			step_mesh.material_override = mat_wood
			step_mesh.position.y = 0.5 + float(i) * 1.0
			shrine_root.add_child(step_mesh)
			
			var col := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = steps_sizes[i]
			col.shape = box_shape
			col.position.y = step_mesh.position.y
			static_body.add_child(col)
			
		# Edícula central (Tenda de Circo)
		var core := MeshInstance3D.new()
		var core_bm := CylinderMesh.new()
		core_bm.top_radius = 2.5
		core_bm.bottom_radius = 2.5
		core_bm.height = 4.0
		core.mesh = core_bm
		core.material_override = mat_tent
		core.position.y = 4.5
		shrine_root.add_child(core)
		
		var core_col := CollisionShape3D.new()
		var core_shape := CylinderShape3D.new()
		core_shape.radius = 2.5
		core_shape.height = 4.0
		core_col.shape = core_shape
		core_col.position.y = core.position.y
		static_body.add_child(core_col)
		
		# Teto da Edícula (Tenda de Circo)
		var roof := MeshInstance3D.new()
		var roof_pm := CylinderMesh.new()
		roof_pm.top_radius = 0.0
		roof_pm.bottom_radius = 3.2
		roof_pm.height = 3.0
		roof.mesh = roof_pm
		roof.material_override = mat_tent
		roof.position.y = 8.0
		shrine_root.add_child(roof)
		
		var roof_col := CollisionShape3D.new()
		var roof_shape := CylinderShape3D.new()
		roof_shape.radius = 3.2
		roof_shape.height = 3.0
		roof_col.shape = roof_shape
		roof_col.position.y = roof.position.y
		static_body.add_child(roof_col)
		
		# 3. Costelas Gigantes (Caixa torácica saindo do chão)
		for i in range(4):
			for sig in [-1, 1]:
				var rib := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 6.0
				tm.outer_radius = 6.5
				rib.mesh = tm
				rib.material_override = mat_bone
				rib.rotation_degrees.x = 90
				rib.rotation_degrees.y = 15 * sig
				rib.position = Vector3(sig * 5.0, -1.0, -4.0 + i * 2.5)
				shrine_root.add_child(rib)
				
		# 4. Portão Torii frontal
		var torii_root := Node3D.new()
		torii_root.position = Vector3(0, 0, 10.0) # Frente aos degraus
		shrine_root.add_child(torii_root)
		
		for sig in [-1, 1]:
			var pillar := MeshInstance3D.new()
			# ⚠️ ERA `pm.radius = 0.4` (corrigido em 2026-08-21). `CylinderMesh` não
			# tem a propriedade `radius` — só `top_radius` e `bottom_radius`. A linha
			# estourava em runtime ("Invalid assignment of property or key 'radius'
			# with value of type 'float' on a base object of type 'CylinderMesh'"),
			# o `height = 8.0` logo abaixo ainda era aplicado, e o pilar acabava
			# nascendo com o raio PADRÃO da malha (0.5) em vez dos 0.4 pedidos —
			# colunas 25% mais gordas do que o portão Torii foi desenhado para ter.
			# Pilar de Torii é reto, então os dois raios recebem o mesmo valor.
			var pm := CylinderMesh.new()
			pm.top_radius = 0.4
			pm.bottom_radius = 0.4
			pm.height = 8.0
			pillar.mesh = pm
			pillar.material_override = mat_torii
			pillar.position = Vector3(sig * 4.0, 4.0, 0)
			torii_root.add_child(pillar)
			
		var beam1 := MeshInstance3D.new()
		var bm1 := BoxMesh.new()
		bm1.size = Vector3(10.0, 0.6, 0.6)
		beam1.mesh = bm1
		beam1.material_override = mat_torii
		beam1.position = Vector3(0, 7.5, 0)
		torii_root.add_child(beam1)
		
		var beam2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(11.0, 0.8, 0.8)
		beam2.mesh = bm2
		beam2.material_override = mat_torii
		beam2.position = Vector3(0, 8.5, 0)
		torii_root.add_child(beam2)
		
		# 5. Crânios espalhados pela base
		for i in range(20):
			var skull := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.3
			sm.height = 0.6
			skull.mesh = sm
			skull.material_override = mat_bone
			var angle = randf() * PI * 2
			var rad = randf_range(8.0, 15.0)
			skull.position = Vector3(cos(angle)*rad, 0.3, sin(angle)*rad)
			shrine_root.add_child(skull)
			
			var eye := OmniLight3D.new()
			eye.light_color = SLASH_RED
			eye.light_energy = 2.0
			eye.omni_range = 1.0
			skull.add_child(eye)
		
		# Aura Vermelha do Templo
		var light := OmniLight3D.new()
		light.light_color = SLASH_RED
		light.light_energy = 15.0
		light.omni_range = 50.0
		light.position.y = 8.0
		shrine_root.add_child(light)

		# Fade out após o término
		var tw := shrine_root.create_tween()
		tw.tween_interval(MAX_DURATION)
		tw.tween_callback(shrine_root.queue_free)
		var tw2 := blood_pool.create_tween()
		tw2.tween_interval(MAX_DURATION)
		tw2.tween_callback(blood_pool.queue_free)
		
		return base_pos

	func _exit_tree() -> void:
		if is_instance_valid(caster):
			caster.set_meta("bara_v_active", false)
			if caster.has_method("trigger_skill_cooldown"):
				caster.trigger_skill_cooldown("V")
		caster = null

	func _process(delta: float) -> void:
		timer += delta
		if timer >= MAX_DURATION:
			queue_free()
			return
			
		tick_timer += delta
		if tick_timer >= INTERVALO_DOMINIO:
			tick_timer = 0.0
			_apply_domain_slash()
			
	func _apply_domain_slash() -> void:
		if not is_instance_valid(caster) or not multiplayer.is_server():
			return
			
		var tree := get_tree()
		var targets = tree.get_nodes_in_group("player") + tree.get_nodes_in_group("enemy")
		for t in targets:
			if t == caster or not is_instance_valid(t): continue
			if not t.has_method("take_damage"): continue
			
			# Valida se o alvo está dentro do raio do domínio de 40 metros
			var dist = center_position.distance_to(t.global_position)
			if dist > DOMAIN_RADIUS:
				continue
			
			_sequence_slashes(t)
			
	func _sequence_slashes(target: Node3D) -> void:
		for i in range(CORTES_POR_TIQUE):
			# Intervalos super rápidos: 0.0, 0.15, 0.3
			var delay = float(i) * 0.15
			get_tree().create_timer(delay).timeout.connect(func():
				if not is_instance_valid(self): return
				if not is_instance_valid(target): return
				if multiplayer.has_multiplayer_peer():
					_net_spawn_single_slash.rpc(target.global_position + Vector3.UP)
				else:
					_net_spawn_single_slash(target.global_position + Vector3.UP)
				# ⚠️ ERA `take_damage(damage * 0.15)` DIRETO, três vezes por segundo.
				# Agora é um corte cheio pelo funil, com hitstun (paralisia) alto —
				# o golpe prende mais do que fere, que é o que um domínio deve fazer.
				CombatResolver.aplicar(target, spec.dano, spec.cast_id, spec.teto,
					target.global_position, Vector3.ZERO, 0.8)
			)
			
	@rpc("any_peer", "call_local", "reliable")
	func _net_spawn_single_slash(pos: Vector3) -> void:
		var root := Node3D.new()
		add_child(root)
		root.global_position = pos
		
		# Barulho de dano a cada corte
		AudioFX.hurt(root, root.global_position)
		
		# Corte menor e usando QuadMesh + Shader procedural de meia lua (arco raso/quase reto)
		var slash := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(3.5, 0.8)
		slash.mesh = qm
		
		# Angulação procedural para formar um retalhamento caótico
		slash.rotation_degrees.y = randf_range(0, 360)
		slash.rotation_degrees.z = randf_range(0, 360)
		
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = """
		shader_type spatial;
		render_mode unshaded, cull_disabled;
		uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
		uniform float opacity = 1.0;
		void fragment() {
			float curve = 4.0 * UV.x * (1.0 - UV.x);
			// 0.2 faz com que seja um arco bem raso ("quase reto")
			float dist = abs(UV.y - (0.35 + curve * 0.3));
			
			// Máscara com fade nas pontas e nas bordas
			float alpha = smoothstep(0.12, 0.01, dist);
			alpha *= smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
			
			vec2 ref_uv = SCREEN_UV + vec2(0.03 * alpha);
			ALBEDO = texture(screen_tex, ref_uv).rgb + vec3(0.8, 0.0, 0.0) * alpha;
			ALPHA = alpha * 0.85 * opacity;
		}
		"""
		mat.shader = sh
		mat.set_shader_parameter("opacity", 1.0)
		slash.material_override = mat
		root.add_child(slash)
		
		# Flash (Núcleo brilhante do corte)
		var flash := MeshInstance3D.new()
		flash.mesh = qm
		var fmat := ShaderMaterial.new()
		var fsh := Shader.new()
		fsh.code = """
		shader_type spatial;
		render_mode unshaded, cull_disabled, blend_add;
		uniform float opacity = 1.0;
		void fragment() {
			float curve = 4.0 * UV.x * (1.0 - UV.x);
			float dist = abs(UV.y - (0.35 + curve * 0.3));
			// Flash é mais fino que o corte base
			float alpha = smoothstep(0.05, 0.0, dist);
			alpha *= smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
			ALBEDO = vec3(1.0, 1.0, 1.0);
			ALPHA = alpha * opacity;
		}
		"""
		fmat.shader = fsh
		fmat.set_shader_parameter("opacity", 1.0)
		flash.material_override = fmat
		slash.add_child(flash)
		
		var tw := root.create_tween()
		tw.set_parallel(true)
		# O Quad expande levemente pra dar sensação de impacto rápido
		tw.tween_property(slash, "scale:x", 1.5, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(slash, "scale:y", 0.1, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mat, "shader_parameter/opacity", 0.0, 0.2)
		tw.tween_property(fmat, "shader_parameter/opacity", 0.0, 0.15)
		tw.set_parallel(false)
		tw.tween_callback(root.queue_free)
