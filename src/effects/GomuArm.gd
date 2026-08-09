class_name GomuArm
extends Node3D
## Braço ELÁSTICO da Gomu Gomu (estilo Luffy). O OMBRO é a origem FIXA: o braço
## cresce apenas na direção da mira. O feixe é desenhado ENTRE dois pontos
## (ombro -> punho) recalculados a cada frame — nada de scale.z no nó do braço
## (que cresceria para os dois lados e moveria o ombro).
##
## Fases: EXTEND (dispara rápido) -> HOLD (esticado no alcance máx) -> RETRACT
## (retrai violento). Ao retornar chama `on_recover` para a animação de recepção.

const EXTEND_TIME := 0.09
const HOLD_TIME := 0.06
const RETRACT_TIME := 0.15

const RUBBER := Color(0.96, 0.60, 0.47)
const IMPACT_GOLD := Color(1.0, 0.85, 0.35)

enum Ph { EXTEND, HOLD, RETRACT }

var _shoulder: Node3D
var _hidden_arm: Node3D
var _aim := Vector3.FORWARD
var _max_len := 12.0
var _radius := 0.22
var _damage := 25.0
var _caster: Node
var _world: Node
var _on_recover := Callable()
var _is_main_arm := true
var _knockback_mult := 1.0
var _shake_mult := 1.0

var _ph := Ph.EXTEND
var _t := 0.0
var _len := 0.0
var _hit := false

var _beam: MeshInstance3D
var _fist: MeshInstance3D

func setup(world: Node, caster: Node, shoulder: Node3D, hidden_arm: Node3D,
		aim: Vector3, max_len: float, radius: float, damage: float, on_recover: Callable, is_main_arm: bool = true, knockback_mult: float = 1.0, shake_mult: float = 1.0) -> void:
	_world = world
	_caster = caster
	_shoulder = shoulder
	_hidden_arm = hidden_arm
	_aim = aim.normalized()
	_max_len = max_len
	_radius = radius
	_damage = damage
	_on_recover = on_recover
	_is_main_arm = is_main_arm
	_knockback_mult = knockback_mult
	_shake_mult = shake_mult

	if _caster is Node3D and _caster.is_inside_tree():
		var space = (_caster as Node3D).get_world_3d().direct_space_state
		var from := _shoulder_pos()
		var to := from + _aim * _max_len
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.hit_from_inside = false
		q.collision_mask = 1 | 2 | 4 | 8 # Checa chão, paredes, inimigos, etc.
		if _caster is CollisionObject3D:
			q.exclude = [(_caster as CollisionObject3D).get_rid()]
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			_max_len = from.distance_to(hit["position"])

	if _hidden_arm and is_instance_valid(_hidden_arm):
		_hidden_arm.visible = false   # o braço real some; o feixe elástico o substitui

	_beam = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(_radius, _radius, 1.0)   # 1 no Z -> escalado p/ o comprimento
	_beam.mesh = bm
	_beam.material_override = _solid_mat(RUBBER, 1.3)
	add_child(_beam)

	_fist = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(_radius * 3.4, _radius * 3.4, _radius * 3.8)
	_fist.mesh = fm
	_fist.material_override = _solid_mat(IMPACT_GOLD, 2.0)
	add_child(_fist)

	if _is_main_arm:
		AudioFX.whoosh(_world, _shoulder_pos(), 1.1)   # "fiu" do disparo
	_update_beam()

func _process(delta: float) -> void:
	_t += delta
	match _ph:
		Ph.EXTEND:
			_len = _max_len * _ease_out(clampf(_t / EXTEND_TIME, 0.0, 1.0))
			if _t >= EXTEND_TIME:
				_len = _max_len
				_do_hit()          # alcance máx -> aplica tudo
				_ph = Ph.HOLD
				_t = 0.0
		Ph.HOLD:
			_len = _max_len
			if _t >= HOLD_TIME:
				_ph = Ph.RETRACT
				_t = 0.0
		Ph.RETRACT:
			_len = _max_len * (1.0 - _ease_in(clampf(_t / RETRACT_TIME, 0.0, 1.0)))
			if _t >= RETRACT_TIME:
				_finish()
				return
	_update_beam()

# ---- elasticidade: feixe entre ombro (fixo) e punho ----
func _shoulder_pos() -> Vector3:
	if _shoulder and is_instance_valid(_shoulder):
		return _shoulder.global_position
	return global_position

func _update_beam() -> void:
	var visible_now := _len > 0.3
	_beam.visible = visible_now
	_fist.visible = visible_now
	if not visible_now:
		return
	var base := _shoulder_pos()
	var tip := base + _aim * _len
	var mid := (base + tip) * 0.5
	var up := Vector3.UP if absf(_aim.y) < 0.95 else Vector3.RIGHT
	# Orienta o feixe com -Z na direção da mira e escala o COMPRIMENTO no eixo LOCAL Z
	# (Node3D.scale é LOCAL) — funciona em qualquer direção, sem a distorção do eixo
	# global que o Basis.scaled() causava. Como "base" = ombro é recalculado por frame,
	# a ponta de trás NUNCA sai do ombro.
	_beam.global_position = mid
	_beam.look_at(mid + _aim, up)
	_beam.scale = Vector3(1.0, 1.0, _len)
	_fist.global_position = tip
	_fist.look_at(tip + _aim, up)
	_fist.scale = Vector3.ONE

func _do_hit() -> void:
	if _hit:
		return
	_hit = true
	var tip := _shoulder_pos() + _aim * _max_len

	if _is_main_arm:
		# dano + knockback (DamageZone segue um pouco à frente)
		var zone := DamageZone.new()
		_world.add_child(zone)
		zone.global_position = tip
		zone.setup(_damage, 35.0 * _knockback_mult, _aim * (28.0 * _knockback_mult), 0.35, _caster, 1.3 * _shake_mult)

		_spawn_speed_lines()
		AudioFX.impact(_world, tip, 1.0)

	# partículas de impacto no punho (para ambos os braços)
	var pm := ParticleProcessMaterial.new()
	pm.direction = _aim
	pm.spread = 40.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 15.0
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color_ramp = FxUtil.gradient([IMPACT_GOLD, Color(0.9, 0.95, 1.0, 0.5), Color(1, 1, 1, 0)])
	var burst := FxUtil.particles(120, 0.45, true, pm, FxUtil.grain(0.4), 1.0)
	_world.add_child(burst)
	burst.global_position = tip
	FxUtil.autofree(burst, 0.7)

# Linhas de velocidade: estrias brancas disparando na direção da mira (sensação de força).
func _spawn_speed_lines() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = _aim
	pm.spread = 5.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 44.0
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color_ramp = FxUtil.gradient([Color(1, 1, 1, 0.9), Color(0.8, 0.9, 1.0, 0)])
	var streaks := FxUtil.particles(26, 0.26, true, pm, FxUtil.grain(0.14), 1.0)
	_world.add_child(streaks)
	streaks.global_position = _shoulder_pos() + _aim * 1.2
	FxUtil.autofree(streaks, 0.5)

func _finish() -> void:
	if _hidden_arm and is_instance_valid(_hidden_arm):
		_hidden_arm.visible = true
	
	if _is_main_arm:
		AudioFX.snap(_world, _shoulder_pos(), 1.2)   # estalo do retorno ao corpo
		if _on_recover.is_valid():
			_on_recover.call()
			
	queue_free()

# ---- helpers ----
func _solid_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _ease_in(x: float) -> float:
	return x * x
