class_name BurnStatus
extends Node

var _target: Node3D
var _duration: float = 3.0
var _dps: float = 5.0
var _t: float = 0.0
var _tick_timer: float = 0.0
# A conjuração que acendeu a queimadura. Passar por ela mantém o dano por tempo
# dentro do orçamento do golpe que o causou, em vez de somar por fora.
var _spec: DamageSpec = null

func setup(target: Node3D, duration: float, dps: float, spec: DamageSpec = null) -> void:
	_target = target
	_duration = duration
	_dps = dps
	_spec = spec if spec != null else DamageSpec.avulso(dps)
	
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
		
		# Indicador de estado: precisa sobreviver aos perfis menores para que o
		# jogador continue reconhecendo queimadura, mesmo sem adornos hero.
		var fire = FxUtil.particles(50, 0.8, false, pm, FxUtil.grain(0.5), 0.0, "essencial")
		fire.name = "BurnVFX"
		_target.add_child(fire)

func _process(delta: float) -> void:
	_t += delta
	_tick_timer += delta
	
	if _tick_timer >= 0.5:
		_tick_timer = 0.0
		if _target:
			# ⚠️ ERA `take_damage()` DIRETO. Como todo o resto do jogo, agora passa
			# pelo funil — ver src/combat/CombatResolver.gd.
			CombatResolver.aplicar(_target, _dps * 0.5, _spec.cast_id, _spec.teto,
				_target.global_position)
			
	if _t >= _duration:
		if _target and _target.has_node("BurnVFX"):
			_target.get_node("BurnVFX").emitting = false
			FxUtil.autofree(_target.get_node("BurnVFX"), 1.0)
		queue_free()
