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
var _zone: DamageZone = null   # hitbox E sensor de quem está dentro

func setup(radius: float, pull: float, lift: float, dps: float, life: float, caster: Node, move_dir: Vector3 = Vector3.ZERO) -> void:
	_radius = radius
	_pull = pull
	_lift = lift
	_dps = dps
	_life = life
	_caster = caster

	# HITBOX + SENSOR numa peça só.
	# O tornado varria `get_nodes_in_group("enemy")` (era a linha 64) para achar
	# alvos. Na arena PvP isso não encosta em ninguém: os inimigos estão em
	# `disabled/` e os jogadores vivem no grupo "player". Resultado medido: golpe
	# sem hitbox e sem dano em jogador — só o boneco de treino era afetado.
	# A DamageZone filha resolve as duas pontas: é a hitbox que a auditoria exige
	# (dano de entrada, crédito de kill, hit-stop) e é a lista de corpos de dentro
	# para o puxão/levantada, por sobreposição física em vez de grupo.
	_zone = DamageZone.new()
	add_child(_zone)
	# KNOCKBACK ZERO: o tornado SUGA para o centro. Empurrão pra fora brigaria com
	# a mecânica de puxar/levantar, que é a razão de ser deste golpe.
	_zone.setup(dps * _tick, 0.0, Vector3.ZERO, life, caster, radius)

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
	if not is_instance_valid(_zone):
		return
	# Corpos de dentro por SOBREPOSIÇÃO (antes: grupo "enemy", que ignorava jogador).
	for body in _zone.get_overlapping_bodies():
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
