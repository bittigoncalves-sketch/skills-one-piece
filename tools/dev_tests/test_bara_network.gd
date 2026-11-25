extends SceneTree
## ENet real: RPC Player, custos, duas direções de dano e terceiro peer em voo.
## O bridge altera somente a fixture e coordena observações; não aplica dano.
const BARA := preload("res://src/combat/BaraController.gd")
const HOME := Vector3(0, 101, 0)
var role := ""
var checks := 0
var failures := 0
var bridge: Probe
var local_actor: Node3D
var host_actor: Node3D
var client_peer := 0
var response: Dictionary = {}
var completed := false
var frozen_action: Node
var client_errors := -1
var late_errors := -1
var observed: Dictionary = {}

class Probe extends Node:
	var test: SceneTree
	@rpc("any_peer", "call_local", "reliable")
	func fixture(peer: int, reverse: bool = false) -> void:
		test.client_peer = peer
		test.reset_fixture(reverse)
	@rpc("any_peer", "call_remote", "reliable")
	func inspect() -> void:
		var peer := multiplayer.get_remote_sender_id()
		var actor := get_tree().current_scene.get_node("Players/" + str(peer)) as Node3D
		snapshot.rpc_id(peer, {"hp": test.host_actor.health, "energy": actor.energy,
			"actions": test.observed.size(), "token": actor.get_meta("bara_server_token", 0)})
	@rpc("any_peer", "call_remote", "reliable")
	func counterattack() -> void:
		var peer := multiplayer.get_remote_sender_id()
		test.host_actor.equip_fruit("bara_bara")
		test.host_actor.combat_mode = "fruit"
		test.reset_fixture(true)
		await get_tree().create_timer(0.2).timeout
		test.host_actor.pedir_cast_no_servidor("Z", Vector3.FORWARD, test.host_actor.global_position, 0, 501)
		await get_tree().create_timer(1.3).timeout
		snapshot.rpc_id(peer, {"counter": true})
	@rpc("any_peer", "call_remote", "reliable")
	func stage_done(stage: String, errors: int) -> void:
		if stage == "client":
			test.client_errors = errors
			await test.prepare_late_join()
		elif stage == "cancel":
			if is_instance_valid(test.frozen_action):
				test.frozen_action.cancel()
				test.frozen_action.set_physics_process(true)
		else:
			test.late_errors = errors
			test.completed = true
			shutdown.rpc()
	@rpc("authority", "call_remote", "reliable")
	func snapshot(data: Dictionary) -> void:
		test.response = data
	@rpc("authority", "call_remote", "reliable")
	func shutdown() -> void:
		test.completed = true

func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS " if condition else "FAIL ") + label)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("PULADO: use tools/dev_tests/test_bara_network.py para três processos ENet.")
		quit()
		return
	role = args[0]
	OS.set_environment("SOP_BOSS_ENABLED", "0")
	OS.unset_environment("SOP_TEST_CHARACTER_VISUAL")
	await process_frame
	create_timer(75).timeout.connect(func():
		push_error("Bara rede timeout: " + role)
		quit(2))
	bridge = Probe.new()
	bridge.name = "BaraNetworkProbe"
	bridge.test = self
	root.add_child(bridge)
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	if role == "host": flow.create_room()
	else: flow.join_room("127.0.0.1")
	while local_actor == null or host_actor == null:
		await process_frame
		for actor in get_nodes_in_group("player"):
			if actor.is_multiplayer_authority(): local_actor = actor
			if str(actor.name) == "1": host_actor = actor
	for actor in get_nodes_in_group("player"):
		actor.set_physics_process(false)
	local_actor.position = HOME + Vector3.RIGHT * 30 if role == "late" else HOME
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 0.6, 80)
	col.shape = shape
	floor_body.add_child(col)
	current_scene.add_child(floor_body)
	floor_body.position = Vector3(0, 99.7, 0)
	if role == "host": await run_host()
	elif role == "client": await run_client()
	else: await run_late()
	print("BARA NETWORK %s: %d checks, %d failures" % [role, checks, failures])
	await create_timer(0.25).timeout
	quit(0 if failures == 0 else 1)

func reset_fixture(reverse: bool = false) -> void:
	for actor in get_nodes_in_group("player"):
		actor.set_physics_process(false)
		actor.velocity = Vector3.ZERO
		actor.net_velocity = Vector3.ZERO
		actor.rotation = Vector3.ZERO
		actor._fruit_damage_lock_timer = 0
		actor._trava_pos_fruta = 0
		if actor.has_meta("is_frozen"): actor.remove_meta("is_frozen")
		if actor.has_meta("_dano_pose_t"): actor.remove_meta("_dano_pose_t")
		if str(actor.name) == "1":
			actor.position = HOME if reverse else HOME + Vector3.FORWARD * 4
		elif str(actor.name) == str(client_peer):
			actor.position = HOME + Vector3.FORWARD * 4 if reverse else HOME
		else:
			actor.position = HOME + Vector3.RIGHT * 30

func run_host() -> void:
	print("BARA_HOST_READY")
	while not completed:
		await process_frame
		for actor in get_nodes_in_group("player"):
			actor.set_physics_process(false)
		for action in get_nodes_in_group("bara_effect"):
			if action.owner_actor != host_actor:
				observed[action.get_instance_id()] = action.slot
		if is_instance_valid(frozen_action) and not frozen_action.is_queued_for_deletion() and not frozen_action.is_physics_processing():
			host_actor.bara_snapshot(frozen_action.snapshot())
	ok(client_errors == 0 and late_errors == 0, "clientes concluíram sem falhas")
	var cannons := 0
	for slot in observed.values():
		if slot == "C": cannons += 1
	ok(cannons == 1, "servidor criou um único canhão para press/release C")
	ok(get_nodes_in_group("boss").is_empty(), "fixture de rede sem Boss")
	failures += maxi(client_errors, 0) + maxi(late_errors, 0)

func run_client() -> void:
	local_actor.equip_fruit("bara_bara")
	local_actor.combat_mode = "fruit"
	await create_timer(0.8).timeout
	bridge.fixture.rpc(get_multiplayer().get_unique_id(), false)
	await create_timer(0.25).timeout
	var initial_energy := float(local_actor.energy)
	local_actor.pedir_cast_no_servidor("Z", Vector3.ZERO, local_actor.global_position, 0, 1)
	await create_timer(0.25).timeout
	ok(local_actor.energy == initial_energy and BARA.action_for(local_actor) == null, "pedido inválido não cobra nem cria mãos")
	local_actor.pedir_cast_no_servidor("Z", Vector3.FORWARD, local_actor.global_position, 0, 2)
	ok(local_actor.energy == initial_energy, "energia preservada antes do aceite remoto")
	await create_timer(0.32).timeout
	var first := BARA.action_for(local_actor)
	ok(first != null and first.slot == "Z", "aceite cria apresentação Z no dono remoto")
	ok(local_actor.energy == initial_energy - local_actor.ENERGY_SKILL, "aceite cobra energia uma vez")
	var paid := float(local_actor.energy)
	local_actor.pedir_cast_no_servidor("Z", Vector3.FORWARD, local_actor.global_position, 0, 2)
	await create_timer(0.15).timeout
	ok(local_actor.energy == paid and BARA.action_for(local_actor) == first, "replay não cobra nem duplica ação")
	await create_timer(1.1).timeout
	ok(is_equal_approx(host_actor.max_health - host_actor.health, 92), "Z do cliente causa 92 no host e replica vida")
	response = {}
	bridge.inspect.rpc_id(1)
	while response.is_empty(): await process_frame
	ok(response.token == 2 and response.actions == 1, "servidor mantém um cast e token aceito")
	var hp := float(local_actor.health)
	bridge.fixture.rpc(get_multiplayer().get_unique_id(), true)
	await create_timer(0.25).timeout
	response = {}
	bridge.counterattack.rpc_id(1)
	while not response.has("counter"): await process_frame
	ok(is_equal_approx(hp - local_actor.health, 92), "dono remoto recebe dano autoritativo do punho do host")
	bridge.fixture.rpc(get_multiplayer().get_unique_id(), false)
	await create_timer(0.3).timeout
	# Entrada real do CastController: começa no press, soltar não dispara outro.
	local_actor._cast._token = 10
	local_actor._cam.global_position = local_actor.global_position + Vector3.UP * 0.2
	local_actor._cam.look_at(host_actor.global_position)
	var before_c := float(local_actor.energy)
	local_actor._cast.comecar("C")
	ok(local_actor.energy == before_c, "C no press aguarda aceite antes de cobrar")
	await create_timer(0.2).timeout
	var cannon := BARA.action_for(local_actor)
	ok(cannon != null and cannon.slot == "C", "C dispara com um press sem exigir hold")
	local_actor._cast.soltar("C")
	await create_timer(0.25).timeout
	ok(local_actor.energy == before_c - local_actor.ENERGY_SKILL and BARA.action_for(local_actor) == cannon, "release C não repete custo nem canhão")
	await create_timer(2.2).timeout
	var damaging := 0
	for zone in get_nodes_in_group("hitbox"):
		if zone.caster == local_actor: damaging += 1
	ok(damaging == 0, "cliente apresenta efeitos sem hitboxes autoritativas")
	ok(BARA.action_for(local_actor) == null, "fim remoto remove ação e recompõe mãos")
	bridge.stage_done.rpc_id(1, "client", failures)
	while not completed: await process_frame

func prepare_late_join() -> void:
	reset_fixture(true)
	for actor in get_nodes_in_group("player"):
		if actor != host_actor: actor.position = HOME + Vector3.RIGHT * 30
	host_actor.pedir_cast_no_servidor("V", Vector3.FORWARD, host_actor.global_position, 0, 502)
	while BARA.action_for(host_actor) == null: await process_frame
	frozen_action = BARA.action_for(host_actor)
	while frozen_action.elapsed < 0.67: await physics_frame
	frozen_action.set_physics_process(false)
	ok(frozen_action.hands[0].state == "outbound", "servidor congela mão esquerda em voo para entrada tardia")
	print("BARA_FLIGHT_READY")

func run_late() -> void:
	var until := Time.get_ticks_msec() + 8000
	while BARA.action_for(host_actor) == null and Time.get_ticks_msec() < until: await process_frame
	var action := BARA.action_for(host_actor)
	ok(action != null, "terceiro peer reconstrói ação já em voo")
	if action != null:
		await create_timer(0.35).timeout
		ok(action.slot == "V" and action.cast_token == 502, "entrada tardia conserva técnica e token")
		ok(action.hands.size() == 2 and action.hands[0].state == "outbound", "entrada tardia recebe estados das duas mãos")
		var palm := host_actor._char_model.find_child("Geo_Palm_L_Runtime", true, false) as MeshInstance3D
		var flying := host_actor._char_model.find_child("BaraDetachedHandL", true, false) as Node3D
		ok(palm != null and flying != null and not palm.visible and flying.visible, "peer tardio vê uma mão separada sem duplicação")
		ok(flying != null and flying.global_position.distance_to(action.hands[0].transform.origin) < 0.06, "peer tardio aproxima transform global autoritativo")
		var zones := 0
		for zone in get_nodes_in_group("hitbox"):
			if zone.caster == host_actor: zones += 1
		ok(zones == 0, "peer tardio não recria dano da técnica")
	bridge.stage_done.rpc_id(1, "cancel", 0)
	await create_timer(0.8).timeout
	ok(BARA.action_for(host_actor) == null, "cancelamento e fim confiável removem ação no peer tardio")
	var restored := host_actor._char_model.find_child("Geo_Palm_L_Runtime", true, false) as MeshInstance3D
	ok(restored != null and restored.visible, "cancelamento remoto recompõe mão real")
	bridge.stage_done.rpc_id(1, "late", failures)
	while not completed: await process_frame
