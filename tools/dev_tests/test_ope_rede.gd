extends SceneTree
## Dois processos: rode -- host e depois -- client, mesma SOP_PORTA.
## O bridge apenas coordena a fixture; conjuração, dano e troca usam RPCs Player.
const OPE := preload("res://src/combat/OpeController.gd")
const HOME := Vector3(0, 101, 0)
var _host := false
var _checks := 0
var _failures := 0
var _bridge: ProbeBridge
var _client: Node3D
var _target: Node3D
var _client_checks := -1
var _client_failures := -1

class ProbeBridge extends Node:
	var test: SceneTree
	@rpc("any_peer", "call_local", "reliable")
	func fixture() -> void:
		test.reset_fixture()
	@rpc("any_peer", "reliable")
	func finished(checks: int, failures: int) -> void:
		test._client_checks = checks
		test._client_failures = failures

func _init() -> void:
	await process_frame
	if not "host" in OS.get_cmdline_user_args() and not "client" in OS.get_cmdline_user_args():
		print("PULADO: teste Ope de rede exige dois processos; use tools/validate_ope.py.")
		quit(0)
		return
	_host = "host" in OS.get_cmdline_user_args()
	create_timer(40).timeout.connect(func():
		push_error("OPE rede: timeout")
		quit(2))
	_bridge = ProbeBridge.new()
	_bridge.name = "OpeProbeBridge"
	_bridge.test = self
	root.add_child(_bridge)
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	if _host:
		flow.create_room()
	else:
		if not flow.join_room("127.0.0.1"):
			quit(2)
			return
	while _client == null or _target == null:
		await process_frame
		for actor in get_nodes_in_group("player"):
			if str(actor.name) == "1":
				_target = actor
			else:
				_client = actor
	# Piso idêntico nas duas cópias, sem interferência de buracos da arena.
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 0.6, 60)
	col.shape = shape
	floor_body.add_child(col)
	current_scene.add_child(floor_body)
	floor_body.position = Vector3(0, 99.7, 0)
	_client.set_physics_process(false)
	_target.set_physics_process(false)
	if _host:
		await _observe_host()
	else:
		await _exercise_client()

func reset_fixture() -> void:
	_client.global_position = HOME
	_target.global_position = HOME + Vector3.FORWARD * 5.0
	_client.velocity = Vector3.ZERO
	_target.velocity = Vector3.ZERO
	_client.net_velocity = Vector3.ZERO
	_target.net_velocity = Vector3.ZERO

func _observe_host() -> void:
	var rooms := {}
	var zones := {}
	var maximum_damage := 0.0
	var hp_start := float(_target.health)
	var relocated := false
	while _client_checks < 0:
		await process_frame
		for effect in get_nodes_in_group("ope_effect"):
			if effect.owner_actor == _client and effect.slot == "Z":
				rooms[effect.get_instance_id()] = true
		for zone in get_nodes_in_group("hitbox"):
			if zone.caster == _client and zone.get_script() == preload("res://src/combat/OpeDamageZone.gd"):
				zones[zone.get_instance_id()] = zone.damage
		maximum_damage = maxf(maximum_damage, hp_start - float(_target.health))
		if _client.global_position.z < -4.5 and _target.global_position.z > -0.1:
			relocated = true
	_ok(rooms.size() == 1, "servidor recebeu uma ROOM do cliente e recusou replay")
	_ok(zones.size() == 6, "servidor criou cinco rochas e uma agulha (recebidas %d)" % zones.size())
	_ok(maximum_damage == 896.0, "dano no host veio do cliente: %.0f/896" % maximum_damage)
	_ok(relocated, "host observou ambos os destinos da troca espacial")
	_ok(_client_failures == 0, "cliente reportou %d verificações e %d falhas" % [_client_checks, _client_failures])
	print("OPE REDE HOST: %d verificações, %d falhas" % [_checks, _failures])
	await create_timer(0.3).timeout
	quit(0 if _failures == 0 else 1)

func _exercise_client() -> void:
	_client.equip_fruit("ope_ope")
	_client.combat_mode = "fruit"
	await create_timer(1.0).timeout
	_bridge.fixture.rpc()
	await create_timer(0.3).timeout
	var energy := float(_client.energy)
	_client.pedir_cast_no_servidor("X", Vector3.FORWARD, _client.global_position, 0.0, 1)
	await create_timer(0.3).timeout
	_ok(_client.energy == energy and _client._fruit_cooldowns.get("X", 0.0) == 0.0,
		"rejeição do servidor não cobra X sem ROOM")
	_client.pedir_cast_no_servidor("Z", Vector3.FORWARD, _client.global_position, 0.0, 2)
	await create_timer(1.05).timeout
	var room := OPE.room_for(_client)
	_ok(room != null and room.ready_for_skills(), "aceite do servidor cria apresentação ROOM no cliente")
	_ok(_client.energy == energy - _client.ENERGY_SKILL, "cliente paga Z apenas no aceite remoto")
	var paid := float(_client.energy)
	_client.pedir_cast_no_servidor("Z", Vector3.FORWARD, _client.global_position, 0.0, 2)
	await create_timer(0.2).timeout
	_ok(_client.energy == paid and OPE.room_for(_client) == room, "replay de token não cobra nem duplica ROOM")
	_client.pedir_cast_no_servidor("C", Vector3.FORWARD, _client.global_position, 0.0, 3)
	await create_timer(2.3).timeout
	_ok(_target.max_health - _target.health == 320.0, "cliente vê saúde replicada do host após Takt")
	_client.pedir_cast_no_servidor("V", Vector3.FORWARD, _client.global_position, 0.0, 4)
	await create_timer(1.25).timeout
	_ok(_target.max_health - _target.health == 896.0, "cliente vê saúde replicada após Gamma Knife")
	_bridge.fixture.rpc()
	await create_timer(0.25).timeout
	_client.pedir_cast_no_servidor("X", Vector3.FORWARD, _client.global_position, 0.0, 5)
	await create_timer(0.95).timeout
	_ok(_client.global_position.z < -4.5 and _target.global_position.z > -0.1,
		"dono remoto mantém troca após replicação de posição")
	var damaging := 0
	for zone in get_nodes_in_group("hitbox"):
		if zone.caster == _client:
			damaging += 1
	_ok(damaging == 0, "cliente usa apresentação sem criar hitboxes de dano")
	print("OPE REDE CLIENT: %d verificações, %d falhas" % [_checks, _failures])
	_bridge.finished.rpc_id(1, _checks, _failures)
	await create_timer(0.2).timeout
	quit(0 if _failures == 0 else 1)

func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print(("PASS " if condition else "FAIL ") + message)
