class_name GomuGear3Punch
extends Node3D
## Gomu Gomu no Gear 3: Gigant Pistol (Soco Gigante).
## Luffy morde o polegar (Hone Fuusen), infla o osso para proporções colossais
## e arremessa um punho titânico com área de impacto massiva e destruição concussiva.

const FIST_MODEL_PATH := "res://assets/models/gomu_gomu/gomu_gear3_fist.glb"
const RUBBER_COLOR := Color(0.96, 0.58, 0.45, 0.95)
const IMPACT_GOLD := Color(1.0, 0.85, 0.35, 0.95)

enum Phase { INFLATE, EXTEND, HOLD, RETRACT }

var _world: Node
var _caster: Node
var _shoulder: Node3D
var _hidden_arm: Node3D
var _aim := Vector3.FORWARD
var _reach := 15.0
var _damage := 384.0
var _on_recover: Callable
var _spec: DamageSpec

var _phase := Phase.INFLATE
var _t := 0.0
var _len := 0.0
var _fist_scale := 0.2
var _target_fist_scale := 4.2
var _arm_radius := 0.25
var _target_arm_radius := 1.25
var _hit_done := false

var _beam: MeshInstance3D
var _fist_instance: Node3D

const T_INFLATE := 0.38
const T_EXTEND := 0.22
const T_HOLD := 0.25
const T_RETRACT := 0.45

func setup(world: Node, caster: Node, shoulder: Node3D, hidden_arm: Node3D,
		aim: Vector3, damage: float, on_recover: Callable, spec: DamageSpec = null) -> void:
	_world = world
	_caster = caster
	_shoulder = shoulder
	_hidden_arm = hidden_arm
	_aim = aim.normalized()
	_damage = damage
	_on_recover = on_recover
	_spec = spec if spec != null else DamageSpec.avulso(damage)

	if _caster and _caster.has_method("lock_movement"):
		_caster.lock_movement(T_INFLATE + T_EXTEND + T_HOLD + T_RETRACT + 0.15, "C")

	if _caster:
		_caster.set_meta("custom_pose", "gomu_gear3")
		_caster.set_meta("gomu_pose_t", 0.0)

	# Raycast para parar em paredes
	if _caster is Node3D and _caster.is_inside_tree():
		var space = (_caster as Node3D).get_world_3d().direct_space_state
		var from := _shoulder_pos()
		var to := from + _aim * _reach
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1 | 2 | 4 | 8
		if _caster is CollisionObject3D:
			q.exclude = [(_caster as CollisionObject3D).get_rid()]
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			_reach = maxf(4.0, from.distance_to(hit["position"]))

	if _hidden_arm and is_instance_valid(_hidden_arm):
		_hidden_arm.visible = false

	# Braço colossal elástico
	_beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)
	_beam.mesh = bm
	_beam.material_override = _solid_mat(RUBBER_COLOR, 1.4)
	add_child(_beam)

	# Instancia modelo do punho gigante
	var fist_scene = load(FIST_MODEL_PATH) as PackedScene
	if fist_scene:
		_fist_instance = fist_scene.instantiate() as Node3D
	else:
		_fist_instance = MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(1.8, 1.8, 2.2)
		(_fist_instance as MeshInstance3D).mesh = fb
		(_fist_instance as MeshInstance3D).material_override = _solid_mat(IMPACT_GOLD, 2.0)
	_fist_instance.name = "Gear3GigantFist"
	add_child(_fist_instance)

	# Som de inflar os ossos
	GomuAudio.play(_world, _shoulder_pos(), "gear3_inflate", 1.5)

	# Partículas de sucção/ar inflado ao redor do ombro
	_spawn_inflate_vfx()
	_update_geometry()

func _process(delta: float) -> void:
	_t += delta
	if _caster and is_instance_valid(_caster):
		var cur_t: float = float(_caster.get_meta("gomu_pose_t", 0.0))
		_caster.set_meta("gomu_pose_t", cur_t + delta)

	match _phase:
		Phase.INFLATE:
			var p := clampf(_t / T_INFLATE, 0.0, 1.0)
			_fist_scale = lerpf(0.2, _target_fist_scale, _ease_in_out(p))
			_arm_radius = lerpf(0.22, _target_arm_radius, _ease_in_out(p))
			_len = 0.5 + p * 1.5
			if _t >= T_INFLATE:
				_phase = Phase.EXTEND
				_t = 0.0
				_len = 2.0
				GomuAudio.play(_world, _shoulder_pos(), "stretch", 1.0)

		Phase.EXTEND:
			var p := clampf(_t / T_EXTEND, 0.0, 1.0)
			_len = lerpf(2.0, _reach, _ease_out(p))
			_fist_scale = _target_fist_scale
			_arm_radius = _target_arm_radius
			if _t >= T_EXTEND:
				_len = _reach
				_do_colossal_impact()
				_phase = Phase.HOLD
				_t = 0.0

		Phase.HOLD:
			_len = _reach
			_fist_scale = _target_fist_scale
			_arm_radius = _target_arm_radius
			if _t >= T_HOLD:
				_phase = Phase.RETRACT
				_t = 0.0

		Phase.RETRACT:
			var p := clampf(_t / T_RETRACT, 0.0, 1.0)
			_len = lerpf(_reach, 0.0, _ease_in(p))
			_fist_scale = lerpf(_target_fist_scale, 0.2, p)
			_arm_radius = lerpf(_target_arm_radius, 0.2, p)
			if _t >= T_RETRACT:
				_finish()
				return

	_update_geometry()

func _shoulder_pos() -> Vector3:
	if _shoulder and is_instance_valid(_shoulder):
		return _shoulder.global_position
	if _caster and is_instance_valid(_caster) and _caster is Node3D:
		return (_caster as Node3D).global_position + Vector3.UP * 1.2
	return global_position

func _update_geometry() -> void:
	if not is_instance_valid(_beam) or not is_instance_valid(_fist_instance):
		return
	var base := _shoulder_pos()
	var tip := base + _aim * _len
	var mid := (base + tip) * 0.5
	var up := Vector3.UP if absf(_aim.y) < 0.95 else Vector3.RIGHT

	_beam.global_position = mid
	_beam.look_at(mid + _aim, up)
	_beam.scale = Vector3(_arm_radius, _arm_radius, maxf(_len, 0.1))

	_fist_instance.global_position = tip
	_fist_instance.look_at(tip + _aim, up)
	_fist_instance.scale = Vector3.ONE * _fist_scale

func _do_colossal_impact() -> void:
	if _hit_done:
		return
	_hit_done = true
	var tip := _shoulder_pos() + _aim * _reach

	# Som monumental
	GomuAudio.play(_world, tip, "gear3_impact", 3.0)

	# Dano em área maciça (DamageZone com raio e knockback gigantescos)
	var zone := DamageZone.new()
	_world.add_child(zone)
	zone.global_position = tip
	zone.setup(_damage, 55.0, _aim * 42.0, 0.5, _caster, 2.5)
	_spec.marcar(zone, true)

	# Efeitos de câmera no conjurador e impacto visual
	if _caster and _caster.has_method("trigger_recovery_anim"):
		_caster.trigger_recovery_anim("C")

	# Explosão de onda de choque no solo / ar
	_spawn_impact_shockwave(tip)

func _spawn_inflate_vfx() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.4
	pm.scale_max = 1.2
	pm.color_ramp = FxUtil.gradient([Color(1, 1, 1, 0.8), Color(0.9, 0.6, 0.5, 0.3), Color(1, 1, 1, 0)])
	var p := FxUtil.particles(60, 0.5, true, pm, FxUtil.grain(0.2))
	_world.add_child(p)
	p.global_position = _shoulder_pos()
	FxUtil.autofree(p, 0.6)

func _spawn_impact_shockwave(pos: Vector3) -> void:
	# Anel de choque radial
	var pm := ParticleProcessMaterial.new()
	pm.direction = _aim
	pm.spread = 85.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 35.0
	pm.scale_min = 1.5
	pm.scale_max = 4.5
	pm.color_ramp = FxUtil.gradient([IMPACT_GOLD, Color(1, 0.6, 0.2, 0.8), Color(0.9, 0.9, 1.0, 0)])
	var blast := FxUtil.particles(350, 0.7, true, pm, FxUtil.grain(0.6))
	_world.add_child(blast)
	blast.global_position = pos
	FxUtil.autofree(blast, 0.9)

	# Fumaça / poeira pesada
	var pm_smoke := ParticleProcessMaterial.new()
	pm_smoke.direction = Vector3.UP
	pm_smoke.spread = 75.0
	pm_smoke.initial_velocity_min = 6.0
	pm_smoke.initial_velocity_max = 16.0
	pm_smoke.gravity = Vector3(0, -3.0, 0)
	pm_smoke.scale_min = 1.0
	pm_smoke.scale_max = 3.0
	pm_smoke.color_ramp = FxUtil.gradient([Color(0.85, 0.82, 0.78, 0.7), Color(0.7, 0.68, 0.65, 0)])
	var smoke := FxUtil.particles(180, 1.2, true, pm_smoke, FxUtil.grain(0.5))
	_world.add_child(smoke)
	smoke.global_position = pos
	FxUtil.autofree(smoke, 1.4)

func _finish() -> void:
	if _hidden_arm and is_instance_valid(_hidden_arm):
		_hidden_arm.visible = true

	if _caster and is_instance_valid(_caster):
		if _caster.get_meta("custom_pose", "") == "gomu_gear3":
			_caster.set_meta("custom_pose", "")

	if _on_recover.is_valid():
		_on_recover.call()

	queue_free()

func _solid_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _ease_in(x: float) -> float:
	return x * x * x

func _ease_in_out(x: float) -> float:
	return 3.0 * x * x - 2.0 * x * x * x
