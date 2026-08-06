class_name GoroFX
extends RefCounted
# Geração visual e física procedural da Goro Goro no Mi (Trovão / Raios / El Thor).
# 4 variantes estilizadas (Z/X/C/V): Sango, El Thor, Shunshin e Mamaragan.

const ELECTRIC_YELLOW := Color(1.0, 0.95, 0.35, 0.95)
const LIGHTNING_CYAN  := Color(0.65, 0.95, 1.0, 0.9)
const FLASH_WHITE     := Color(1.0, 1.0, 1.0, 1.0)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _sango(world, origin, dir, damage, caster)
		1: _el_thor(world, origin + dir * 5.0, damage, caster)
		2: _shunshin(world, origin, dir, damage, caster)
		_: _mamaragan(world, origin + dir * 4.0, damage, caster)

# ---------- Z: Sango — Feixe de Raio Projétil Acelerado ----------
static func _sango(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var fwd := dir.normalized()
	
	# Raio laser elétrico procedural (Cilindro emissivo brilhante)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.25
	cyl.height = 12.0
	beam.mesh = cyl
	beam.material_override = FxUtil.particle_material(ELECTRIC_YELLOW, 5.0, true)
	if abs(fwd.y) < 0.99:
		beam.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3.ZERO)
		beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	zone.add_child(beam)

	# Fagulhas voltaicas
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd   # segue a mira (-Z), não o eixo Z do mundo
	pm.spread = 40.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 16.0
	pm.scale_min = 0.3
	pm.scale_max = 0.9
	pm.color_ramp = FxUtil.gradient([FLASH_WHITE, ELECTRIC_YELLOW, Color(0, 0, 0, 0)])

	var sparks := FxUtil.particles(180, 0.4, true, pm, FxUtil.grain(0.3))
	zone.add_child(sparks)

	zone.setup(damage, 14.0, fwd * 32.0, 1.1, caster, 1.0)

# ---------- X: El Thor — Coluna Gigante de Raio dos Céus ----------
static func _el_thor(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = Vector3(pos.x, 0.2, pos.z)

	# Coluna vertical caindo dos céus (30m de altura)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.8
	cyl.bottom_radius = 3.5
	cyl.height = 40.0
	pillar.mesh = cyl
	pillar.position.y = 20.0
	pillar.material_override = FxUtil.particle_material(LIGHTNING_CYAN, 6.0, true)
	zone.add_child(pillar)

	# Explosão de faíscas e anel elétrico no solo
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 90.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 24.0
	pm.scale_min = 0.8
	pm.scale_max = 2.5
	pm.color_ramp = FxUtil.gradient([FLASH_WHITE, ELECTRIC_YELLOW, Color(0.2, 0.8, 1.0, 0)])

	var explosion := FxUtil.particles(500, 1.2, true, pm, FxUtil.grain(0.8))
	zone.add_child(explosion)

	var tw := zone.create_tween()
	tw.tween_property(pillar, "scale", Vector3(0.01, 1.0, 0.01), 0.8).set_trans(Tween.TRANS_QUAD)

	zone.setup(damage, 22.0, Vector3.UP * 15.0, 3.2, caster, 3.5)

# ---------- C: Shunshin — Dash / Teleporte Elétrico Instantâneo ----------
static func _shunshin(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var fwd := dir.normalized()

	# Rastro instantâneo de faíscas
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd   # segue a mira (-Z), não o eixo Z do mundo
	pm.spread = 20.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 14.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = FxUtil.gradient([FLASH_WHITE, LIGHTNING_CYAN, Color(0, 0, 0, 0)])

	var flash := FxUtil.particles(200, 0.4, true, pm, FxUtil.grain(0.4))
	zone.add_child(flash)

	# Se o invocador for o jogador, projeta o corpo 12m pra frente
	if caster is CharacterBody3D:
		(caster as CharacterBody3D).global_position += fwd * 12.0

	zone.setup(damage, 10.0, fwd * 25.0, 0.6, caster, 1.2)

# ---------- V: Mamaragan — Tempestade Elétrica em Área ----------
static func _mamaragan(world: Node, pos: Vector3, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos + Vector3.UP * 0.5

	# Tempestade de partículas caindo dos céus
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.DOWN
	pm.spread = 70.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 30.0
	pm.scale_min = 1.2
	pm.scale_max = 3.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 8.0
	pm.color_ramp = FxUtil.gradient([FLASH_WHITE, ELECTRIC_YELLOW, LIGHTNING_CYAN, Color(0, 0, 0, 0)])

	var storm := FxUtil.particles(750, 1.8, true, pm, FxUtil.grain(0.9))
	storm.position.y = 12.0
	zone.add_child(storm)

	zone.setup(damage, 25.0, Vector3.ZERO, 3.5, caster, 8.0)
