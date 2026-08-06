class_name BaraFX
extends RefCounted
# Geração visual e física procedural da Bara Bara no Mi (Buggy / Partes Flutuantes).
# 4 variantes estilizadas (Z/X/C/V): Bara Bara Ho, Bara Senbei, Bara Car e Festival.

const BUGGY_PINK   := Color(0.92, 0.35, 0.65, 0.95)
const BUGGY_BLUE   := Color(0.2, 0.45, 0.85, 0.9)
const SLASH_YELLOW := Color(1.0, 0.85, 0.3, 0.85)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _bara_ho(world, origin, dir, damage, caster)
		1: _bara_senbei(world, origin, dir, damage, caster)
		2: _bara_car(world, origin, dir, damage, caster)
		_: _bara_festival(world, origin + dir * 3.5, damage, caster)

# ---------- Z: Bara Bara Ho — Punho Voador Desmembrado ----------
static func _bara_ho(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var fwd := dir.normalized()

	# Punho voador voxel 3D
	var fist := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.7, 1.2)
	fist.mesh = box
	fist.material_override = FxUtil.particle_material(BUGGY_PINK, 2.5, true)
	zone.add_child(fist)

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd   # segue a mira (-Z), não o eixo Z do mundo
	pm.spread = 25.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 9.0
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.color_ramp = FxUtil.gradient([BUGGY_PINK, BUGGY_BLUE, Color(0, 0, 0, 0)])

	var trail := FxUtil.particles(140, 0.5, true, pm, FxUtil.grain(0.4))
	zone.add_child(trail)

	zone.setup(damage, 12.0, fwd * 26.0, 1.0, caster, 1.0)

# ---------- X: Bara Bara Senbei — Lâminas Voadoras nos Pés ----------
static func _bara_senbei(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var fwd := dir.normalized()

	# Disco giratório de sapatos com lâminas
	var disc := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.6
	tm.outer_radius = 1.4
	disc.mesh = tm
	disc.material_override = FxUtil.particle_material(SLASH_YELLOW, 3.0, true)
	zone.add_child(disc)

	var spin := zone.create_tween().set_loops()
	spin.tween_property(disc, "rotation:y", TAU, 0.25)

	zone.setup(damage, 16.0, fwd * 24.0, 1.2, caster, 1.2)

# ---------- C: Bara Bara Car — Investida em Forma de Veículo Desmembrado ----------
static func _bara_car(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var fwd := dir.normalized()

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd   # segue a mira (-Z), não o eixo Z do mundo
	pm.spread = 35.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 14.0
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.color_ramp = FxUtil.gradient([BUGGY_BLUE, BUGGY_PINK, Color(0, 0, 0, 0)])

	var dust := FxUtil.particles(220, 0.6, true, pm, FxUtil.grain(0.6))
	zone.add_child(dust)

	if caster is CharacterBody3D:
		(caster as CharacterBody3D).velocity += fwd * 28.0

	zone.setup(damage, 14.0, fwd * 30.0, 1.4, caster, 1.5)

# ---------- V: Bara Bara Festival — Tempestade de Partes Flutuantes em Área ----------
static func _bara_festival(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos + Vector3.UP * 1.0

	# Furacão de pedaços de corpo desmembrados girando em leque
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 18.0
	pm.angular_velocity_min = 300.0
	pm.angular_velocity_max = 600.0
	pm.scale_min = 0.8
	pm.scale_max = 2.2
	pm.color_ramp = FxUtil.gradient([BUGGY_PINK, BUGGY_BLUE, SLASH_YELLOW, Color(0, 0, 0, 0)])

	var storm := FxUtil.particles(650, 1.6, true, pm, FxUtil.grain(0.9))
	zone.add_child(storm)

	zone.setup(damage, 24.0, Vector3.ZERO, 3.2, caster, 6.0)
