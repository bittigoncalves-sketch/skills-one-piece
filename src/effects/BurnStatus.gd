class_name BurnStatus
extends Node

var _target: Node3D
var _duration: float = 3.0
var _dps: float = 5.0
var _t: float = 0.0
var _tick_timer: float = 0.0

func setup(target: Node3D, duration: float, dps: float) -> void:
	_target = target
	_duration = duration
	_dps = dps
	
	# Efeito visual de fogo no alvo
	if _target:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 1.0
		pm.direction = Vector3.UP
		pm.spread = 15.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 5.0
		pm.scale_min = 0.8
		pm.scale_max = 1.5
		pm.color_ramp = FxUtil.gradient([Color(1.0, 0.4, 0.05), Color(1.0, 0.1, 0.0, 0.5), Color(0,0,0,0)])
		
		var fire = FxUtil.particles(50, 0.8, false, pm, FxUtil.grain(0.5))
		fire.name = "BurnVFX"
		_target.add_child(fire)

func _process(delta: float) -> void:
	_t += delta
	_tick_timer += delta
	
	if _tick_timer >= 0.5:
		_tick_timer = 0.0
		if _target and _target.has_method("take_damage"):
			_target.take_damage(_dps * 0.5, _target.global_position, Vector3.ZERO)
			
	if _t >= _duration:
		if _target and _target.has_node("BurnVFX"):
			_target.get_node("BurnVFX").emitting = false
			FxUtil.autofree(_target.get_node("BurnVFX"), 1.0)
		queue_free()
