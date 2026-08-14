class_name GuraFX
extends RefCounted
## Gura Gura no Mi (Tremor) — o foco é KNOCKBACK massivo (jogar pra fora do mapa).
## Visual: ondas de choque (anéis que expandem), "bolha" de ar rachado branco-azulada,
## destroços e poeira. Reaproveita FxUtil/DamageZone/AudioFX. Knockback altíssimo.

const QUAKE := Color(0.85, 0.94, 1.0)   # branco-azulado (o ar rachando)
const DEBRIS := Color(0.55, 0.5, 0.45)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node, charge: float = 0.0) -> void:
	match variant:
		0: _punch(world, origin, dir.normalized(), damage, caster, charge)
		1: _shockwave(world, dir, damage, caster, charge) # `dir` agora carrega a posição absoluta do alvo (captura sísmica)
		2: _eruption(world, _ground(caster, dir, 5.0), damage, caster, charge)
		_: _seaquake(world, _self_pos(caster), damage, caster, charge)

# ---------- helpers ----------
static func _self_pos(caster: Node) -> Vector3:
	return (caster as Node3D).global_position + Vector3.UP * 1.0 if caster is Node3D else Vector3.ZERO

static func _ground(caster: Node, dir: Vector3, dist: float) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = Vector3.FORWARD if flat.length_squared() < 0.001 else flat.normalized()
	var s: Vector3 = (caster as Node3D).global_position if caster is Node3D else Vector3.ZERO
	return s + flat * dist

# Anel de choque (torus deitado no chão) que expande e some.
static func _ring(parent: Node, start_r: float, end_r: float, color: Color, life: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.scale = Vector3(start_r, 1.0, start_r)
	parent.add_child(mi)
	var tw := (parent as Node).create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(end_r, 1.0, end_r), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)

# Bolha de "ar rachado" (esfera translúcida que incha e some).
static func _bubble(parent: Node, radius: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(QUAKE.r, QUAKE.g, QUAKE.b, 0.22)
	mat.emission_enabled = true
	mat.emission = QUAKE
	mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	mi.scale = Vector3.ONE * 0.2
	parent.add_child(mi)
	var tw := (parent as Node).create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, life).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)

static func _debris(parent: Node, up_bias: float, amount: int) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, up_bias, 0)
	pm.spread = 65.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0, -22.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	pm.color_ramp = FxUtil.gradient([DEBRIS, QUAKE, Color(1, 1, 1, 0)])
	var p := FxUtil.particles(amount, 0.9, true, pm, FxUtil.grain(0.5), 1.0)
	parent.add_child(p)

# ---------- Z: Gura Punch — soco do tremor (onda pra frente) ----------
static func _punch(world: Node, origin: Vector3, fwd: Vector3, damage: float, caster: Node, charge: float = 0.0) -> void:
	var mult: float = 1.0 + clampf(charge / 1.5, 0.0, 3.0)
	
	if is_instance_valid(caster) and caster.has_method("get_node"):
		var proc = caster.get_node_or_null("ProceduralAnimator")
		if proc and proc.has_method("play_baked"):
			var anim_res = load("res://assets/animations/right_upper_hook_from_guard.res")
			if anim_res:
				# Toca a animação nativa (sem distorções procedurais e sem espelhamentos acidentais).
				# A animação é estritamente direita (mixamorig_RightArm).
				proc.play_baked(anim_res, 0.4 / mult, 0.0) # Animação muito lenta com o charge
		elif caster.has_method("trigger_recovery_anim"):
			caster.trigger_recovery_anim("Z")
			
	var delay: float = 0.25 * mult
	var tw := world.create_tween()
	tw.tween_interval(delay)
	
	tw.tween_callback(func():
		if not is_instance_valid(world): return
		var atq_pos = origin if not is_instance_valid(caster) else (caster as Node3D).global_position + Vector3.UP * 1.0 + fwd * 1.5
		var zone := DamageZone.new()
		world.add_child(zone)
		zone.global_position = atq_pos
		_bubble(zone, 2.2 * mult, 0.4)
		_ring(zone, 0.6, 6.0 * mult, QUAKE, 0.5)
		_debris(zone, 0.4, int(40 * mult))
		GuraShatterMesh.spawn(zone, zone.global_position, 1.2 * mult)
		if Engine.has_singleton("ScreenShatterFX"):
			Engine.get_singleton("ScreenShatterFX").shatter(0.3 * mult, 0.5 * mult)
		elif world.get_node_or_null("/root/ScreenShatterFX"):
			world.get_node("/root/ScreenShatterFX").shatter(0.3 * mult, 0.5 * mult)
		AudioFX.impact(world, atq_pos, 0.7 * mult)
		
		# PASSO 5: Efeitos de Câmera (Leve zoom in no impacto, Desfoque Radial)
		var cam = world.get_viewport().get_camera_3d()
		if cam:
			var orig_fov = cam.fov
			cam.fov -= 12.0 # Leve zoom in
			var tw_cam = cam.create_tween()
			tw_cam.tween_property(cam, "fov", orig_fov, 0.4).set_trans(Tween.TRANS_EXPO)
			
		var sfx := world.get_node_or_null("/root/ScreenFX")
		if sfx and sfx.has_method("chromatic_pulse"):
			sfx.chromatic_pulse(1.5 * mult)
		if sfx and sfx.has_method("set_borrao"):
			sfx.set_borrao(0.8 * mult)
			var tw_fx = sfx.create_tween()
			tw_fx.tween_method(sfx.set_borrao, 0.8 * mult, 0.0, 0.4)
			
		zone.override_kb_dir = Vector3.UP
		zone.setup(damage * mult, 30.0 * mult, fwd * 22.0, 0.5, caster, 1.8 * mult)   # viaja + knockback ALTO
	)

# ---------- X: Shockwave — onda de choque radial ----------
static func _shockwave(world: Node, pos: Vector3, damage: float, caster: Node, charge: float = 0.0) -> void:
	if is_instance_valid(caster) and caster.has_method("get_node"):
		var proc = caster.get_node_or_null("ProceduralAnimator")
		if proc and proc.has_method("play_baked"):
			var anim_res = load("res://assets/animations/smash.res")
			if not anim_res:
				anim_res = load("res://assets/animations/punching.res")
			if anim_res:
				proc.play_baked(anim_res, 0.5, 0.0)
		elif caster.has_method("trigger_recovery_anim"):
			caster.trigger_recovery_anim("X")

	var mult: float = 1.0 + clampf(charge / 1.5, 0.0, 3.0)
	var delay: float = 0.3
	var tw := world.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if not is_instance_valid(world): return
		var zone := DamageZone.new()
		world.add_child(zone)
		zone.global_position = pos
		
		# PASSO 5: Zoom OUT na Explosão e Tremor Forte
		var cam = world.get_viewport().get_camera_3d()
		if cam:
			var orig_fov = cam.fov
			cam.fov += 10.0 # Zoom out (expande a visão pra mostrar a enorme área)
			var tw_cam = cam.create_tween()
			tw_cam.tween_property(cam, "fov", orig_fov, 0.6).set_trans(Tween.TRANS_EXPO)
			
		var sfx := world.get_node_or_null("/root/ScreenFX")
		if sfx and sfx.has_method("chromatic_pulse"):
			sfx.chromatic_pulse(1.2 * mult)
			
		_ring(zone, 0.8 * mult, 9.0 * mult, QUAKE, 0.55)
		_ring(zone, 0.4 * mult, 6.0 * mult, Color(1, 1, 1), 0.4)
		_debris(zone, 0.6, int(60 * mult)) # Detritos massivos da explosão
		GuraShatterMesh.spawn(zone, zone.global_position, 1.5 * mult)
		if Engine.has_singleton("ScreenShatterFX"):
			Engine.get_singleton("ScreenShatterFX").shatter(0.5 * mult, 0.6)
		elif world.get_node_or_null("/root/ScreenShatterFX"):
			world.get_node("/root/ScreenShatterFX").shatter(0.5 * mult, 0.6)
		AudioFX.impact(world, pos, 0.85 * mult)
		zone.override_kb_dir = Vector3.UP
		zone.setup(damage * mult, 34.0 * mult, Vector3.ZERO, 0.4, caster, 6.0 * mult)  # estático, raio grande, KB enorme
	)

# ---------- C: Eruption — o chão racha e ergue os inimigos ----------
static func _eruption(world: Node, pos: Vector3, damage: float, caster: Node, charge: float = 0.0) -> void:
	if is_instance_valid(caster) and caster.has_method("get_node"):
		var proc = caster.get_node_or_null("ProceduralAnimator")
		if proc and proc.has_method("play_baked"):
			var anim_res = load("res://assets/animations/left_uppercut_from_guard.res")
			if not anim_res:
				anim_res = load("res://assets/animations/punching.res")
			if anim_res:
				proc.play_baked(anim_res, 0.3, 0.0)
		elif caster.has_method("trigger_recovery_anim"):
			caster.trigger_recovery_anim("C")

	var delay: float = 0.4
	var tw := world.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if not is_instance_valid(world): return
		var zone := DamageZone.new()
		world.add_child(zone)
		zone.global_position = Vector3(pos.x, 0.2, pos.z)
		_bubble(zone, 3.0, 0.5)
		_ring(zone, 0.6, 7.0, QUAKE, 0.5)
		_debris(zone, 1.2, 90)                                    # muitos destroços PRA CIMA
		GuraShatterMesh.spawn(zone, zone.global_position, 1.8)
		if Engine.has_singleton("ScreenShatterFX"):
			Engine.get_singleton("ScreenShatterFX").shatter(0.6, 0.7)
		elif world.get_node_or_null("/root/ScreenShatterFX"):
			world.get_node("/root/ScreenShatterFX").shatter(0.6, 0.7)
		AudioFX.impact(world, zone.global_position, 0.9)
		zone.override_kb_dir = Vector3.UP
		zone.setup(damage, 30.0, Vector3.ZERO, 0.5, caster, 5.0) # Erupção joga MUITO para cima
	)

# ---------- V: Seaquake / Tsunamis Duplos (ultimate) ----------
static func _seaquake(world: Node, pos: Vector3, damage: float, caster: Node, charge: float = 0.0) -> void:
	var v_node = load("res://src/effects/GuraVNode.gd").new(caster, damage)
	world.add_child(v_node)
	v_node.global_position = pos

# Removido: _exagerar_soco (Euler * escalar causava inversão de eixos (gimbal) e afetava o braço esquerdo acidentalmente)
