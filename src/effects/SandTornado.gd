class_name SandTornado
extends Node3D
## X — Sables: comportamento do TORNADO de areia (a ref pede: puxa, levanta e causa
## dano CONTÍNUO na área). O visual (malha/partículas girando) roda em todos os
## clientes; a FÍSICA (puxão/levantar) e o DANO só no SERVIDOR (autoridade). Sem
## peer (SP puro) aplica normalmente. Some sozinho ao fim da duração.

var _radius := 3.0
var _pull := 9.0          # força do puxão horizontal p/ o centro
var _lift := 6.0          # velocidade de subida imposta a quem está dentro
var _dps := 12.0          # dano por segundo (aplicado em ticks)
var _tick := 0.4          # intervalo entre ticks de dano
var _life := 3.0
var _caster: Node = null

var _t := 0.0
var _tick_t := 0.0

var _velocity := Vector3.ZERO

func setup(radius: float, pull: float, lift: float, dps: float, life: float, caster: Node, move_dir: Vector3 = Vector3.ZERO) -> void:
	_radius = radius
	_pull = pull
	_lift = lift
	_dps = dps
	_life = life
	_caster = caster
	
	var flat_dir := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat_dir.length_squared() > 0.01:
		_velocity = flat_dir.normalized() * 10.0 # Velocidade mediana

func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
		
	# Movimentação física do furacão (roda em todos os clientes p/ manter sync visual)
	_velocity.y -= 25.0 * delta # Gravidade
	var step := _velocity * delta
	
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + step + Vector3(0, -1.0, 0))
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			global_position.x += step.x
			global_position.z += step.z
			global_position.y = hit["position"].y
			_velocity.y = 0.0
		else:
			global_position += step

	# Autoridade: só o servidor puxa/levanta/dana os corpos (sem peer = SP -> aplica).
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_tick_t += delta
	var do_damage := _tick_t >= _tick
	if do_damage:
		_tick_t = 0.0
	var center := global_position
	for body in get_tree().get_nodes_in_group("enemy"):
		if body == _caster or not (body is Node3D):
			continue
		var to_center := center - (body as Node3D).global_position
		var horiz := Vector3(to_center.x, 0.0, to_center.z)
		if horiz.length() > _radius:
			continue                                   # fora do raio do tornado
		if body is CharacterBody3D:
			var b := body as CharacterBody3D
			var pull_v := horiz.normalized() * _pull   # suga p/ o centro
			b.velocity.x = lerpf(b.velocity.x, pull_v.x, 0.35)
			b.velocity.z = lerpf(b.velocity.z, pull_v.z, 0.35)
			b.velocity.y = _lift                        # levanta
		if do_damage and body.has_method("take_damage"):
			body.take_damage(_dps * _tick, center, Vector3.ZERO)
