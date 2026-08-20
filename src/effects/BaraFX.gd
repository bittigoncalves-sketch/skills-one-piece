class_name BaraFX
extends RefCounted
# Geração visual e física procedural da Bara Bara no Mi (Sukuna-inspired).
# VFX Premium: Shaders de alta emissão, heat distortion e tweening dinâmico.

const SLASH_RED    := Color(0.8, 0.1, 0.1, 0.95)
const SLASH_BLACK  := Color(0.05, 0.02, 0.02, 1.0)
const BUGGY_RED    := Color(1.0, 0.05, 0.05, 0.95)
const ORANGE_FIRE  := Color(1.0, 0.5, 0.0, 0.9)
const BONE_WHITE   := Color(0.9, 0.85, 0.8, 1.0)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _bara_corte(world, origin, dir, damage, caster)
		1: _bara_buggy_ball(world, origin, dir, damage, caster)
		2: _bara_area_cortante(world, origin, dir, damage, caster)
		_: _bara_dominio(world, origin, damage, caster)

# ---------- Z: Corte Único (Dismantle) ----------
static func _bara_corte(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
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

	zone.setup(damage, 18.0, fwd * 45.0, 0.6, caster, 1.2)
	AudioFX.hurt(world, origin)

# ---------- X: Buggy Ball (Fuga / Flecha de Fogo) ----------
static func _bara_buggy_ball(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
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
	zone.setup(damage, 18.0, fwd * 25.0, 1.5, caster, 5.0)
	
	var lifetime := 18.0 / 25.0
	var tw := zone.create_tween()
	tw.tween_interval(lifetime)
	tw.tween_callback(func():
		if is_instance_valid(zone):
			var pos := zone.global_position
			var boom_root := Node3D.new()
			boom_root.global_position = pos
			world.add_child(boom_root)
			
			var shock := MeshInstance3D.new()
			shock.mesh = TorusMesh.new()
			shock.scale = Vector3(1.0, 0.1, 1.0)
			var sh_mat := StandardMaterial3D.new()
			sh_mat.albedo_color = BUGGY_RED
			sh_mat.emission_enabled = true
			sh_mat.emission = ORANGE_FIRE
			sh_mat.emission_energy_multiplier = 8.0
			sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shock.material_override = sh_mat
			boom_root.add_child(shock)
			
			var pillar := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.height = 40.0
			cyl.radius = 1.0
			pillar.mesh = cyl
			pillar.position.y = 20.0
			var pil_mat := sh_mat.duplicate() as StandardMaterial3D
			pil_mat.emission = BUGGY_RED
			pil_mat.emission_energy_multiplier = 10.0
			pillar.material_override = pil_mat
			boom_root.add_child(pillar)
			
			if caster and caster.has_method("add_camera_shake"):
				caster.add_camera_shake(3.0)
			
			var bt = boom_root.create_tween()
			bt.set_parallel(true)
			bt.tween_property(shock, "scale", Vector3(20.0, 0.1, 20.0), 0.3)
			bt.tween_property(sh_mat, "albedo_color:a", 0.0, 0.4)
			bt.tween_property(pillar, "scale:x", 8.0, 0.2)
			bt.tween_property(pillar, "scale:z", 8.0, 0.2)
			bt.tween_property(pil_mat, "albedo_color:a", 0.0, 0.6).set_delay(0.2)
			bt.set_parallel(false)
			bt.tween_callback(boom_root.queue_free)
	)

# ---------- C: Área Cortante (Cleave) ----------
static func _bara_area_cortante(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	if not (caster is CharacterBody3D): return
	for child in caster.get_children():
		if child.name == "BaraCleaveController":
			return
			
	var controller := BaraCleaveController.new()
	controller.name = "BaraCleaveController"
	controller.damage = damage
	caster.add_child(controller)

# ---------- V: Expansão de Domínio (Malevolent Shrine) ----------
static func _bara_dominio(world: Node, origin: Vector3, damage: float, caster: Node) -> void:
	var controller := BaraDomainController.new()
	controller.name = "BaraDomainController"
	controller.damage = damage
	controller.caster = caster
	world.add_child(controller)


# ==============================================================================
# BARA CLEAVE CONTROLLER (Hold skill C)
# ==============================================================================
class BaraCleaveController extends Node:
	var damage: float = 0.0
	var timer: float = 0.0
	var tick_timer: float = 0.0
	const MAX_DURATION: float = 7.0
	const CLEAVE_RADIUS: float = 12.0
	
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
		if tick_timer >= 0.25:
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
				col.take_damage(damage * 0.25, caster.global_position, Vector3.ZERO, 0.1)
				if col.has_method("add_camera_shake"):
					col.add_camera_shake(0.5)
				if Engine.has_singleton("ScreenFX"):
					Engine.get_singleton("ScreenFX").flash(Color.WHITE, 0.05)

# ==============================================================================
# BARA DOMAIN CONTROLLER (Skill V)
# ==============================================================================
class BaraDomainController extends Node:
	var damage: float = 0.0
	var caster: Node = null
	var timer: float = 0.0
	var tick_timer: float = 0.0
	const MAX_DURATION: float = 30.0
	
	func _ready() -> void:
		if Engine.has_singleton("ScreenFX"):
			Engine.get_singleton("ScreenFX").chromatic_pulse(2.0)
			# Pisca a tela invertendo cores para ativar o domínio
			Engine.get_singleton("ScreenFX").flash(Color(1.0, 1.0, 1.0, 1.0), 0.1)
		
		if caster and is_instance_valid(caster):
			if caster.has_method("add_camera_shake"):
				caster.add_camera_shake(2.0)
			_spawn_shrine_geometry(caster)
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
			ash.position.y = 20.0
			caster.add_child(ash)

	func _spawn_shrine_geometry(host: Node) -> void:
		# Criação procedural do Santuário de Ossos (Pilares e Chifres negros) nas costas do caster
		var shrine_root := Node3D.new()
		host.add_child(shrine_root)
		shrine_root.position = Vector3(0, 0, 4.0) # Atrás do player
		
		var mat_bone := StandardMaterial3D.new()
		mat_bone.albedo_color = BONE_WHITE
		mat_bone.roughness = 1.0
		
		# Base (Crânio estilizado via box)
		var base := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.0, 3.0, 4.0)
		base.mesh = bm
		base.material_override = mat_bone
		base.position.y = 1.5
		shrine_root.add_child(base)
		
		# Chifres laterais curvados
		for sig in [-1, 1]:
			var horn := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.1
			cm.bottom_radius = 1.0
			cm.height = 8.0
			horn.mesh = cm
			horn.material_override = mat_bone
			horn.position = Vector3(sig * 5.0, 5.0, 0)
			horn.rotation_degrees.z = sig * 30
			shrine_root.add_child(horn)

		# Aura Vermelha do Templo
		var light := OmniLight3D.new()
		light.light_color = SLASH_RED
		light.light_energy = 8.0
		light.omni_range = 25.0
		light.position.y = 4.0
		shrine_root.add_child(light)

		# Fade out após 30s
		var tw := shrine_root.create_tween()
		tw.tween_interval(MAX_DURATION)
		tw.tween_callback(shrine_root.queue_free)

	func _exit_tree() -> void:
		caster = null

	func _process(delta: float) -> void:
		timer += delta
		if timer >= MAX_DURATION:
			queue_free()
			return
			
		tick_timer += delta
		if tick_timer >= 1.0:
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
			
			_spawn_cross_slash_vfx(t.global_position + Vector3.UP)
			t.take_damage(damage * 0.2, t.global_position, Vector3.ZERO, 0.2)
			
	func _spawn_cross_slash_vfx(pos: Vector3) -> void:
		if multiplayer.has_multiplayer_peer():
			_net_spawn_cross_slash.rpc(pos)
		else:
			_net_spawn_cross_slash(pos)
		
	@rpc("any_peer", "call_local", "reliable")
	func _net_spawn_cross_slash(pos: Vector3) -> void:
		var root := Node3D.new()
		root.global_position = pos
		get_tree().current_scene.add_child(root)
		
		# Matriz visual do corte
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SLASH_BLACK
		mat.emission_enabled = true
		mat.emission = SLASH_RED
		mat.emission_energy_multiplier = 8.0
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		# Slash 1
		var s1 := MeshInstance3D.new()
		var q1 := QuadMesh.new()
		q1.size = Vector2(8.0, 0.3)
		s1.mesh = q1
		s1.material_override = mat
		s1.rotation_degrees.z = 45
		root.add_child(s1)
		
		# Slash 2
		var s2 := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(8.0, 0.3)
		s2.mesh = q2
		s2.material_override = mat
		s2.rotation_degrees.z = -45
		root.add_child(s2)
		
		var tw := root.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s1, "scale:y", 2.0, 0.15)
		tw.tween_property(s2, "scale:y", 2.0, 0.15)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.2).set_delay(0.1)
		tw.set_parallel(false)
		tw.tween_callback(root.queue_free)
