class_name GuraVNode
extends Node3D
# Nó gerenciador da Ultimate (Skill V) da Gura Gura no Mi: Tsunamis Duplos.
# Congela o jogador por 4 segundos, toca efeitos sonoros/visuais progressivos,
# aplica poses procedurais via meta "custom_pose", e ao final lança 2 tsunamis.

var _caster: Node
var _damage: float
var _timer := 0.0
const CHARGE_DUR := 4.0

func _init(c: Node, d: float) -> void:
	_caster = c
	_damage = d
	name = "GuraVNode"

func _ready() -> void:
	if is_instance_valid(_caster):
		if _caster.has_method("congelar_para_cast"):
			_caster.congelar_para_cast()
		if _caster.has_method("set_meta"):
			_caster.set_meta("custom_pose", "gura_v_prep")
			_caster.set_meta("is_casting", true)

func _process(delta: float) -> void:
	if not is_instance_valid(_caster):
		queue_free()
		return
		
	var old_t := _timer
	_timer += delta
	
	if old_t < 1.0 and _timer >= 1.0:
		_caster.set_meta("custom_pose", "gura_v_squat")
		if _caster.has_method("add_camera_shake"):
			_caster.add_camera_shake(0.3)
	elif old_t < 2.0 and _timer >= 2.0:
		_caster.set_meta("custom_pose", "gura_v_gather")
		if _caster.has_method("add_camera_shake"):
			_caster.add_camera_shake(0.6)
		# Efeitos visuais no chão
		GuraFX._ring(self, 1.0, 8.0, GuraFX.QUAKE, 2.0)
		GuraFX._debris(self, 0.5, 40)
	elif old_t < 3.0 and _timer >= 3.0:
		_caster.set_meta("custom_pose", "gura_v_lift")
		if _caster.has_method("add_camera_shake"):
			_caster.add_camera_shake(0.9)
	elif old_t < 4.0 and _timer >= 4.0:
		_caster.set_meta("custom_pose", "gura_v_tpose")
		if _caster.has_method("add_camera_shake"):
			_caster.add_camera_shake(1.5)
		
		# Dispara!
		_liberar_tsunamis()
		
		# Limpeza após 0.5s de T-pose
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_caster):
				_caster.remove_meta("custom_pose")
				_caster.set_meta("is_casting", false)
				if _caster.has_method("pausar_animacao"):
					_caster.pausar_animacao(false)
			queue_free()
		)

func _liberar_tsunamis() -> void:
	if not is_instance_valid(_caster) or not (_caster is Node3D): return
	var c3d := _caster as Node3D
	var world := get_parent()
	var origin := c3d.global_position
	
	# Direção frontal baseada na rotação do corpo (ou mira, mas V é AoE lateral)
	var fwd = -c3d.global_transform.basis.z.normalized()
	var right = c3d.global_transform.basis.x.normalized()
	
	AudioFX.impact(world, origin, 1.3)
	if Engine.has_singleton("ScreenShatterFX"):
		Engine.get_singleton("ScreenShatterFX").shatter(1.5, 1.5)
	
	GuraShatterMesh.spawn(world, origin + Vector3.UP * 1.5, 4.0)
	GuraFX._bubble(world, 8.0, 0.8)
	GuraFX._debris(world, 1.0, 200)
	
	for i in 3:
		GuraFX._ring(world, 1.0 + i * 2.0, 20.0, GuraFX.QUAKE if i % 2 == 0 else Color.WHITE, 0.8 + i * 0.1)
		
		
	# TSUNAMI DIREITO
	var zone_r := DamageZone.new()
	world.add_child(zone_r)
	zone_r.global_position = origin + right * 6.0
	_spawn_tsunami_vfx(zone_r, right * 15.0 + fwd * 30.0)
	zone_r.setup(_damage, 35.0, right * 15.0 + fwd * 30.0, 0.8, _caster, 15.0)
	
	# TSUNAMI ESQUERDO
	var zone_l := DamageZone.new()
	world.add_child(zone_l)
	zone_l.global_position = origin - right * 6.0
	_spawn_tsunami_vfx(zone_l, -right * 15.0 + fwd * 30.0)
	zone_l.setup(_damage, 35.0, -right * 15.0 + fwd * 30.0, 0.8, _caster, 15.0)

func _spawn_tsunami_vfx(parent: Node, vel: Vector3) -> void:
	# Partículas de onda de choque gigante
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 40.0
	pm.scale_min = 3.0
	pm.scale_max = 6.0
	pm.color_ramp = FxUtil.gradient([Color.WHITE, GuraFX.QUAKE, Color(0, 0.5, 1.0, 0.5), Color(1, 1, 1, 0)])
	
	var wave = FxUtil.particles(400, 0.8, false, pm, FxUtil.grain(1.2), 2.5)
	parent.add_child(wave)
	
	# Rastro de detritos e água no chão
	var pm2 := ParticleProcessMaterial.new()
	pm2.direction = -vel.normalized() + Vector3.UP * 0.2
	pm2.spread = 45.0
	pm2.initial_velocity_min = 10.0
	pm2.initial_velocity_max = 20.0
	pm2.scale_min = 1.0
	pm2.scale_max = 3.0
	pm2.color = Color(0.8, 0.9, 1.0, 0.8)
	
	var trail = FxUtil.particles(200, 0.8, false, pm2, FxUtil.grain(0.8), 2.5)
	parent.add_child(trail)

func _exit_tree() -> void:
	if is_instance_valid(_caster) and _caster.has_meta("is_casting"):
		_caster.remove_meta("custom_pose")
		_caster.set_meta("is_casting", false)
		if _caster.has_method("pausar_animacao"):
			_caster.pausar_animacao(false)
