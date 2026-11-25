extends SceneTree
## ENet real: host prepara ação; cliente entra depois e exercita os RPCs Player.
## Execute host, aguarde YORU_HOST_READY e execute client, mesma SOP_PORTA.
var host := false
var checks := 0
var failures := 0
var bridge: ProbeBridge
var local_player: Node3D
var host_player: Node3D
var remote_player: Node3D
var answer: Dictionary = {}
var finished := false

class ProbeBridge extends Node:
	var test: SceneTree
	@rpc("any_peer", "call_remote", "reliable")
	func query() -> void:
		var peer := multiplayer.get_remote_sender_id()
		var p: Node = test.remote_player
		reply.rpc_id(peer, {"mode": p.combat_mode, "sequence": p._yoru_combat.sequence,
			"action": p._yoru_combat.action_id, "host_mode": test.host_player.combat_mode,
			"host_sequence": test.host_player._yoru_combat.sequence,
			"host_action": test.host_player._yoru_combat.action_id,
			"floor": p._yoru_combat._has_floor(), "can_v": p._yoru_combat.can_start("V"), "position": p.global_position, "penalty":p._yoru_combat._penalty,
			"elapsed": p._yoru_combat.elapsed, "cooldown_z": p._yoru_combat.cooldown("Z")})
	@rpc("authority", "call_remote", "reliable")
	func reply(state: Dictionary) -> void:
		test.answer = state
	@rpc("any_peer", "call_remote", "reliable")
	func reset_fixture() -> void:
		test.host_player._cancel_yoru_action("mode")
		test.host_player.set_combat_mode("fruit")
		test.host_player._yoru_combat.set_physics_process(true)
		test.place_players()
	@rpc("any_peer", "call_remote", "reliable")
	func arm_host() -> void:
		test.host_player.set_combat_mode("sword")
	@rpc("any_peer", "call_remote", "reliable")
	func respawn_owner() -> void:
		test.remote_player.net_force_respawn.rpc()
	@rpc("any_peer", "call_remote", "reliable")
	func done(client_checks: int, client_failures: int) -> void:
		test.checks = client_checks
		test.failures = client_failures
		test.finished = true

func _init() -> void:
	await process_frame
	if not "host" in OS.get_cmdline_user_args() and not "client" in OS.get_cmdline_user_args():
		print("PULADO: teste exige host/client ENet; use -- host e -- client")
		quit(0)
		return
	host = "host" in OS.get_cmdline_user_args()
	create_timer(70).timeout.connect(func():
		push_error("YORU NETWORK TIMEOUT")
		quit(2))
	bridge = ProbeBridge.new()
	bridge.name = "YoruNetworkProbe"
	bridge.test = self
	root.add_child(bridge)
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	if host:
		flow.create_room()
	else:
		flow.join_room("127.0.0.1")
	while host_player == null or (not host and remote_player == null):
		await process_frame
		find_players()
	if host:
		host_player.set_physics_process(false)
		host_player.global_position = Vector3(0, 101, 0)
		host_player.set_combat_mode("sword")
		host_player.begin_charge("Z")
		host_player._yoru_combat.set_physics_process(false)
		host_player._yoru_combat.elapsed = 0.25
		print("YORU_HOST_READY")
		while remote_player == null:
			await process_frame
			find_players()
		place_players()
		while not finished:
			await process_frame
		print("YORU NETWORK HOST: %d checks, %d failures" % [checks, failures])
		await create_timer(0.25).timeout
		quit(0 if failures == 0 else 1)
	else:
		await exercise_client()

func find_players() -> void:
	for p in get_nodes_in_group("player"):
		if p.get_multiplayer_authority() == 1:
			host_player = p
		else:
			remote_player = p

func place_players() -> void:
	if not root.has_node("YoruTestFloor"):
		var floor_body := StaticBody3D.new()
		floor_body.name = "YoruTestFloor"
		root.add_child(floor_body)
		floor_body.position = Vector3(30,100.1,0)
		var shape := CollisionShape3D.new()
		var resource := BoxShape3D.new()
		resource.size = Vector3(12,0.2,12)
		shape.shape = resource
		floor_body.add_child(shape)
	for p in [host_player, remote_player]:
		p.set_physics_process(false)
		p.global_position = Vector3(0 if p == host_player else 30, 101, 0)
		p.velocity = Vector3.ZERO

func sample() -> Dictionary:
	answer = {}
	bridge.query.rpc_id(1)
	while answer.is_empty():
		await process_frame
	return answer

func raw_action(id: String, direction: Vector3) -> int:
	var net: Node = remote_player._yoru_network
	net._request_sequence += 1
	net._net_request_action.rpc_id(1, net._request_sequence, id, direction)
	return net._request_sequence

func exercise_client() -> void:
	place_players()
	await create_timer(0.15).timeout
	ok(host_player.combat_mode == "sword" and host_player.equipped_weapon == "sword",
		"late join replica modo e espada do host")
	ok(host_player._yoru_combat.action_id == "Z" and host_player._yoru_combat.elapsed >= 0.25,
		"late join retoma ação em elapsed >= 0.25, sem reiniciar startup")
	ok(host_player._yoru_combat.cooldown("Z") > 0.0, "late join recebe cooldown ativo")
	bridge.reset_fixture.rpc_id(1)
	await create_timer(0.15).timeout
	remote_player.set_combat_mode("sword")
	await create_timer(0.15).timeout
	var state := await sample()
	ok(state.mode == "sword" and remote_player.equipped_weapon == "sword", "owner equipa via servidor e recebe arma")
	ok(not remote_player.pode_conjurar(), "cast legado segue bloqueado em sword")
	# Um cliente não escolhe equipamento do outro Player.
	host_player._yoru_network._net_request_mode.rpc_id(1, 1000, "sword")
	state = await sample()
	ok(state.host_mode == "fruit", "pedido de modo forged não equipa Player de outro dono")
	# Recibos usam authority=1; tentativa de forjar recebe erro RPC esperado do Godot.
	remote_player._yoru_network._net_state.rpc_id(1, {"revision": 999, "mode": "fruit"})
	state = await sample()
	ok(state.mode == "sword", "estado forged não altera servidor")
	for invalid in [Vector3(NAN, 0, -1), Vector3(0, 1, 0), Vector3(0, 0, -20)]:
		raw_action("M1", invalid)
	raw_action("M1_2", Vector3.FORWARD)
	state = await sample()
	ok(state.sequence == 0, "direções NaN/vertical/não normalizada e ID escolhido são recusados")
	remote_player._request_melee()
	await create_timer(0.12).timeout
	state = await sample()
	ok(state.sequence == 1 and state.action == "M1_1", "M1 owner vira primeiro corte escolhido pelo servidor")
	var replay := int(remote_player._yoru_network._request_sequence)
	remote_player._yoru_network._net_request_action.rpc_id(1, replay, "M1", Vector3.FORWARD)
	await create_timer(0.1).timeout
	state = await sample()
	ok(state.sequence == 1, "replay não reinicia nem duplica ação")
	# Um snapshot repetido também não pode voltar o relógio de apresentação.
	var net: Node = remote_player._yoru_network
	var elapsed: float = remote_player._yoru_combat.elapsed
	net._apply_state({"revision": net._received_revision, "mode": "sword", "action": "M1_1",
		"sequence": 1, "elapsed": 0.0, "direction": Vector3.FORWARD, "cooldowns": {}})
	ok(remote_player._yoru_combat.elapsed >= elapsed, "snapshot duplicado não rebobina apresentação")
	await create_timer(1.4).timeout
	remote_player._yoru_network._net_request_action.rpc_id(1, replay, "M1", Vector3.FORWARD)
	state = await sample()
	ok(state.sequence == 1, "replay atrasado continua inválido após ação encerrar")
	remote_player.begin_charge("Z")
	await create_timer(0.1).timeout
	state = await sample()
	ok(state.sequence == 2 and state.action == "Z", "Z usa caminho próprio no owner/servidor")
	remote_player.release_charge("Z")
	state = await sample()
	ok(state.action == "Z", "soltar tecla não cancela técnica instantânea")
	remote_player.set_combat_mode("fruit")
	await create_timer(0.12).timeout
	state = await sample()
	ok(state.mode == "fruit" and state.action.is_empty() and remote_player.equipped_weapon.is_empty(),
		"troca de modo cancela ação e guarda espada em ambas cópias")
	remote_player.set_combat_mode("sword")
	await create_timer(0.1).timeout
	remote_player.begin_charge("Z")
	state = await sample()
	ok(state.sequence == 2 and state.cooldown_z > 0.0, "reequipar não apaga cooldown nem libera Z prematuro")
	bridge.arm_host.rpc_id(1)
	await create_timer(0.1).timeout
	state = await sample()
	var host_sequence: int = state.host_sequence
	host_player._yoru_network._net_request_action.rpc_id(1, 1001, "V", Vector3.FORWARD)
	state = await sample()
	ok(state.host_mode == "sword" and state.host_sequence == host_sequence and state.host_action.is_empty(),
		"ação forged é recusada mesmo com outro owner equipado e livre")
	await create_timer(0.4).timeout
	remote_player.begin_charge("V")
	await create_timer(0.1).timeout
	state = await sample()
	if state.action != "V": print("V_STATE ",state," localpos=",remote_player.global_position)
	ok(state.action == "V", "V remoto valida chão físico sem depender de is_on_floor local")
	remote_player.set_combat_mode("fruit")
	await create_timer(0.4).timeout
	remote_player.set_combat_mode("sword")
	await create_timer(0.1).timeout
	remote_player.begin_charge("C")
	await create_timer(0.12).timeout
	state = await sample()
	ok(state.action == "C", "C recebido pelo servidor")
	bridge.respawn_owner.rpc_id(1)
	await create_timer(0.15).timeout
	state = await sample()
	ok(state.cooldown_z == 0.0 and remote_player._yoru_combat.cooldown("C") == 0.0, "respawn limpa recargas Yoru como frutas e estilos")
	print("YORU NETWORK CLIENT: %d checks, %d failures" % [checks, failures])
	bridge.done.rpc_id(1, checks, failures)
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)

func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS " if condition else "FAIL ") + label)
