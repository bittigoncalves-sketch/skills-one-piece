class_name GomuGatling
extends Node3D

var _world: Node
var _caster: Node
var _arm_r: Node3D
var _arm_l: Node3D
var _fwd: Vector3
var _damage: float
var _on_recover: Callable

var _duration := 1.8
var _t := 0.0
var _punch_interval := 0.12
var _next_punch_t := 0.0
var _is_right := true
var _punch_count := 0
var _max_punches := 16

func setup(world: Node, caster: Node, arm_r: Node3D, arm_l: Node3D, fwd: Vector3, damage: float, on_recover: Callable) -> void:
	_world = world
	_caster = caster
	_arm_r = arm_r
	_arm_l = arm_l
	_fwd = fwd.normalized()
	_damage = damage
	_on_recover = on_recover
	
	if _arm_r: _arm_r.visible = false
	if _arm_l: _arm_l.visible = false
	
	if _caster and _caster.has_method("lock_movement"):
		_caster.lock_movement(_duration + 0.3, "C")

func _process(delta: float) -> void:
	_t += delta
	
	if _t >= _next_punch_t and _punch_count < _max_punches:
		_fire_punch()
		# O ritmo acelera: começa mais lento, atinge o máximo e estabiliza
		if _punch_count < 4:
			_punch_interval = maxf(0.05, _punch_interval - 0.02)
		
		_next_punch_t = _t + _punch_interval
		_punch_count += 1
		
	# Termina quando todos os socos saíram e o último teve tempo de retornar
	if _punch_count >= _max_punches and _t > _next_punch_t + 0.3:
		_finish()

func _fire_punch() -> void:
	var is_last = (_punch_count == _max_punches - 1)
	var shoulder = _arm_r if _is_right else _arm_l
	_is_right = not _is_right
	
	var gomu := GomuArm.new()
	_world.add_child(gomu)
	
	# Dispersão direcional
	var spread = Vector3(randf_range(-0.25, 0.25), randf_range(-0.15, 0.15), 0.0)
	# Garante que o último soco vá reto no centro
	if is_last:
		spread = Vector3.ZERO
		
	var up_ref := Vector3.UP if abs(_fwd.y) < 0.95 else Vector3.FORWARD
	var right := _fwd.cross(up_ref).normalized()
	var real_up := right.cross(_fwd).normalized()
	var punch_dir = (_fwd + right * spread.x + real_up * spread.y).normalized()
	
	var punch_len = randf_range(11.0, 15.0)
	
	var knockback = 2.5 if is_last else 0.15 # Golpes prendem o inimigo, o último empurra muito
	var shake = 2.0 if is_last else 0.2 # Shakes curtos, último pesado
	var dmg = _damage * (1.8 if is_last else 0.4) # Divide o dano, concentra no final
	
	# Passa null no hidden_arm para que o próprio GomuArm não o esconda/mostre de forma errada
	# Passa Callable() vazio no on_recover para que cada soco individual não dispare o chicote no rig
	gomu.setup(_world, _caster, shoulder, null, punch_dir, punch_len, 0.22, dmg, Callable(), true, knockback, shake)
	
func _finish() -> void:
	if _arm_r: _arm_r.visible = true
	if _arm_l: _arm_l.visible = true
	
	if _on_recover.is_valid():
		_on_recover.call()
		
	queue_free()
