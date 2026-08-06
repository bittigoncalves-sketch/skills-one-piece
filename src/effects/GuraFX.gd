class_name GuraFX
extends RefCounted
## Gura Gura no Mi (Tremor) — o foco é KNOCKBACK massivo (jogar pra fora do mapa).
## Visual: ondas de choque (anéis que expandem), "bolha" de ar rachado branco-azulada,
## destroços e poeira. Reaproveita FxUtil/DamageZone/AudioFX. Knockback altíssimo.

const QUAKE := Color(0.85, 0.94, 1.0)   # branco-azulado (o ar rachando)
const DEBRIS := Color(0.55, 0.5, 0.45)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _punch(world, origin, dir.normalized(), damage, caster)
		1: _shockwave(world, origin + dir.normalized() * 2.5, damage, caster)
		2: _eruption(world, _ground(caster, dir, 5.0), damage, caster)
		_: _seaquake(world, _self_pos(caster), damage, caster)

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
static func _punch(world: Node, origin: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	_bubble(zone, 2.2, 0.4)
	_ring(zone, 0.6, 6.0, QUAKE, 0.5)
	_debris(zone, 0.4, 40)
	AudioFX.impact(world, origin, 0.7)
	zone.setup(damage, 30.0, fwd * 22.0, 0.5, caster, 1.8)   # viaja + knockback ALTO

# ---------- X: Shockwave — onda de choque radial ----------
static func _shockwave(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos
	_ring(zone, 0.8, 9.0, QUAKE, 0.55)
	_ring(zone, 0.4, 6.0, Color(1, 1, 1), 0.4)
	_debris(zone, 0.2, 60)
	AudioFX.impact(world, pos, 0.85)
	zone.setup(damage, 34.0, Vector3.ZERO, 0.4, caster, 6.0)  # estático, raio grande, KB enorme

# ---------- C: Eruption — o chão racha e ergue os inimigos ----------
static func _eruption(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = Vector3(pos.x, 0.2, pos.z)
	_bubble(zone, 3.0, 0.5)
	_ring(zone, 0.6, 7.0, QUAKE, 0.5)
	_debris(zone, 1.2, 90)                                    # muitos destroços PRA CIMA
	AudioFX.impact(world, zone.global_position, 0.9)
	zone.setup(damage, 30.0, Vector3.ZERO, 0.5, caster, 5.0)

# ---------- V: Seaquake — abalo massivo (ultimate) ----------
static func _seaquake(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos
	_bubble(zone, 6.0, 0.7)
	for i in 3:
		_ring(zone, 0.8 + i * 1.5, 16.0, QUAKE if i % 2 == 0 else Color(1, 1, 1), 0.7 + i * 0.1)
	_debris(zone, 0.5, 160)
	AudioFX.impact(world, pos, 1.1)
	zone.setup(damage, 46.0, Vector3.ZERO, 0.6, caster, 12.0) # abalo GIGANTE, KB devastador
