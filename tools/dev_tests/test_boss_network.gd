extends SceneTree
## Execute pelo runner Python: host, cliente durante jab e cliente após morte.
var role := ""
var boss: Node3D
var checks := 0
var failures := 0
var bridge: Probe
var answer: Dictionary = {}
var completed := false

class Probe extends Node:
	var test: SceneTree
	@rpc("any_peer", "call_remote", "reliable")
	func inspect() -> void:
		var actor: Node = test.boss
		snapshot.rpc_id(multiplayer.get_remote_sender_id(), {"health": actor.health, "count": get_tree().get_nodes_in_group("boss").size(), "sequence": actor.action_sequence})
	@rpc("any_peer", "call_remote", "reliable")
	func contact() -> void:
		var peer := multiplayer.get_remote_sender_id()
		var target := get_tree().current_scene.get_node("Players/" + str(peer)) as Node3D
		test.boss.combat.cancel("fixture")
		test.boss.position = Vector3(0, 1.1, 0)
		target.position = Vector3(0, 0.8, -1.2)
		await get_tree().physics_frame
		await get_tree().physics_frame
		test.boss.combat.cooldown_remaining = 0
		test.boss.combat.begin(target)
		test.boss.combat.tick(0.8)
		snapshot.rpc_id(peer, {"contact": true})
	@rpc("any_peer", "call_remote", "reliable")
	func slash() -> void:
		var peer := multiplayer.get_remote_sender_id()
		var target := get_tree().current_scene.get_node("Players/" + str(peer)) as Node3D
		test.boss.combat.cancel("fixture")
		test.boss.position = Vector3(0, 1.1, 0)
		test.boss.rotation = Vector3.ZERO
		target.position = Vector3(0, 0.8, -7)
		await get_tree().physics_frame
		await get_tree().physics_frame
		test.boss.combat.slash_cooldown_remaining = 0
		test.boss.combat.begin_slash(target)
		while test.boss.combat.busy():
			await get_tree().physics_frame
			test.boss.combat.tick(1.0 / 60.0)
		snapshot.rpc_id(peer, {"slash": true, "waves": get_tree().get_nodes_in_group(BossCombat.SLASH_GROUP).size()})
	@rpc("any_peer", "call_remote", "reliable")
	func detached() -> void:
		var peer := multiplayer.get_remote_sender_id()
		var target := get_tree().current_scene.get_node("Players/" + str(peer)) as Node3D
		test.boss.combat.cancel("fixture")
		test.boss.combat.detached.reset()
		test.boss.combat.detached.cooldown = 0
		test.boss.position = Vector3(0, 1.1, 0)
		target.position = Vector3(0, 0.8, -4)
		await get_tree().physics_frame
		await get_tree().physics_frame
		test.boss.combat._target = target
		test.boss.combat._start_move(4)
		# Cópia do SERVIDOR do jogador remoto: anima a derrubada pelo `net_on_floor`.
		var remote_phases: Array[String] = []
		# A vida autoritativa é a desta cópia: aqui ela só muda por dano.
		var server_health: float = target.health
		var until := Time.get_ticks_msec() + 4000
		while (test.boss.combat.busy() or test.boss.part_state != "attached" or target.esta_arremessado()) and Time.get_ticks_msec() < until:
			await get_tree().physics_frame
			test.boss.combat.tick(1.0 / 60.0)
			test.boss.combat.detached.tick(1.0 / 60.0)
			test.boss.presentation.present(1.0 / 60.0)
			var fase: String = target._arremesso.fase
			if fase != "" and (remote_phases.is_empty() or remote_phases.back() != fase):
				remote_phases.append(fase)
		snapshot.rpc_id(peer, {"detached": true, "remote_phases": remote_phases, "server_damage": server_health - target.health})
	@rpc("any_peer", "call_remote", "reliable")
	func mobilidade(kind: String) -> void:
		# Estado de mobilidade decidido no servidor; o cliente só apresenta.
		var actor: Node = test.boss
		actor.controller.reaction.clear(actor)
		actor.controller.mobility.cancel(actor)
		if kind == "dash":
			actor.controller.mobility.start_dash(actor, Vector3.RIGHT)
		else:
			actor.controller.mobility.jump(actor, Vector3.ZERO, false)
			actor.controller.mobility.double_jump(actor)
		snapshot.rpc_id(multiplayer.get_remote_sender_id(), {"mobilidade": actor.mobility, "jumps": actor.jumps_used})
	@rpc("any_peer", "call_remote", "reliable")
	func melee_launch() -> void:
		# Três M1 seguidos do cliente, pela mesma meta do CombatResolver.
		var target := get_tree().current_scene.get_node("Players/" + str(multiplayer.get_remote_sender_id())) as Node3D
		test.boss.combat.cancel("fixture")
		for i in 3:
			CombatResolver.aplicar(test.boss, 1, 0, 0, target.global_position, Vector3(0, 0, -9), 0.5, 0.0, false, target)
		snapshot.rpc_id(multiplayer.get_remote_sender_id(), {"reaction": test.boss.reaction})
	@rpc("authority", "call_remote", "reliable")
	func snapshot(data: Dictionary) -> void:
		test.answer = data
	@rpc("any_peer", "call_remote", "reliable")
	func finish(stage: String, errors: int) -> void:
		test.failures += errors
		if stage == "client":
			test.boss.combat.cancel("fixture")
			test.boss.combat.detached.reset()
			test.boss.combat.detached.cooldown = 0
			test.boss.reaction = ""
			test.boss.position = Vector3(0, 1.1, 0)
			test.boss.combat._target = get_tree().current_scene.get_node("Players/1")
			test.boss.combat._start_move(4)
			test.boss.combat.tick(0.65)
			test.boss.combat.detached.tick(0.65)
			print("BOSS_FLIGHT_READY")
		elif stage == "flight":
			test.boss.take_damage(99999)
			test.boss._physics_process(0.016)
			print("BOSS_DEAD_READY")
		else:
			test.completed = true

func ok(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("PULADO: use tools/dev_tests/test_boss_network.py para ENet real")
		quit()
		return
	role = args[0]
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	OS.unset_environment("SOP_TEST_CHARACTER_VISUAL")
	await process_frame
	create_timer(55).timeout.connect(func(): quit(2))
	bridge = Probe.new()
	bridge.name = "BossNetworkProbe"
	bridge.test = self
	root.add_child(bridge)
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	if role == "host":
		flow.create_room()
	else:
		flow.join_room("127.0.0.1")
	while boss == null:
		await process_frame
		boss = get_first_node_in_group("boss")
	await create_timer(0.3).timeout
	if role == "host":
		var player := get_first_node_in_group("player") as Node3D
		player.set_physics_process(false)
		player.position = Vector3(0, 100, 0)
		boss.set_physics_process(false)
		boss.take_damage(112)
		boss.combat.cooldown_remaining = 0
		boss.combat.begin(player)
		boss.action_elapsed = boss.definition.ability.windup + 0.05
		boss.state = "active"
		print("BOSS_HOST_READY")
		while not completed:
			await process_frame
		print("BOSS NETWORK HOST: %d failures" % failures)
		await create_timer(0.5).timeout
		quit(0 if failures == 0 else 1)
		return
	ok(get_nodes_in_group("boss").size() == 1, "um Boss após entrada " + role)
	ok(boss.actor_id == 10001 and boss.encounter_id == 1, "identidade estável replicada")
	ok(not boss.authoritative() and boss.get_multiplayer_authority() == 1, "cliente sem autoridade de simulação")
	if role == "client":
		ok(boss.health == 3984, "entrada tardia recebe HP já reduzido")
		ok(boss.action_id == "jab" and boss.state == "active" and is_equal_approx(boss.action_elapsed, boss.definition.ability.windup + 0.05), "entrada durante golpe recebe ação, fase e tempo")
		await physics_frame
		ok(boss.presentation.telegraph.visible and boss.presentation.current_move().hand == "L", "cliente exibe a marca do punho em curso")
		ok(boss.action_sequence == 1, "sequência de ataque replicada")
		boss.take_damage(500)
		ok(boss.health == 3984, "take_damage no cliente é ignorado")
		ok(not boss.combat.begin(get_first_node_in_group("player")), "cliente não inicia jab")
		bridge.inspect.rpc_id(1)
		while answer.is_empty():
			await process_frame
		ok(answer.health == 3984 and answer.count == 1 and answer.sequence == 1, "servidor preserva HP e cast após tentativa do cliente")
		var local_player: Node3D
		for candidate in get_nodes_in_group("player"):
			if candidate.is_multiplayer_authority():
				local_player = candidate
		local_player.set_physics_process(false)
		local_player.position = Vector3(0, 0.8, -1.2)
		var health_before: float = local_player.health
		answer = {}
		bridge.contact.rpc_id(1)
		while not answer.has("contact"):
			await process_frame
		await create_timer(0.2).timeout
		ok(is_equal_approx(health_before - local_player.health, 72), "jab do servidor aplica 72 ao jogador remoto real")
		# Corte: linha e frente visual no cliente; dano só pela frente do servidor.
		local_player.position = Vector3(0, 0.8, -7)
		await create_timer(0.5).timeout
		var hp_before_slash: float = local_player.health
		var saw_line := false
		var local_waves := 0
		answer = {}
		bridge.slash.rpc_id(1)
		while not answer.has("slash"):
			await physics_frame
			saw_line = saw_line or (boss.action_id == "corte" and boss.presentation.telegraph.visible)
			local_waves = maxi(local_waves, get_nodes_in_group(BossCombat.SLASH_GROUP).size())
		await create_timer(0.4).timeout
		ok(saw_line, "cliente vê a linha vermelha do corte")
		ok(local_waves == 1 and answer.waves == 1, "cliente e servidor criam uma frente cada")
		ok(is_equal_approx(hp_before_slash - local_player.health, 90), "corte do servidor aplica 90 uma vez ao jogador remoto (%.0f)" % (hp_before_slash - local_player.health))
		answer = {}
		local_player.position = Vector3(0, 0.8, -4)
		var hp_before_part: float = local_player.health
		var saw_part := false
		var saw_return := false
		# O dono do corpo precisa de física para voar, deitar e levantar. A posição é
		# do dono: quem a escreve é o cliente, antes de ligar a física.
		local_player.position = Vector3(0, 0.8, -4)
		local_player.velocity = Vector3.ZERO
		# O knockback do corte (mantido) ficou pendente com a física desligada; ao
		# religar ele seria aplicado e levaria o jogador para fora do alcance do punho.
		local_player._vida._empurrao = Vector3.ZERO
		await create_timer(0.3).timeout
		local_player.set_physics_process(true)
		await physics_frame
		var launch_start: Vector3 = local_player.global_position
		var owner_phases: Array[String] = []
		var owner_travel := 0.0
		bridge.detached.rpc_id(1)
		while not answer.has("detached"):
			await physics_frame
			saw_part = saw_part or (boss.presentation.hand_binding.flying.visible and not boss.presentation.hand_binding.attached.visible)
			saw_return = saw_return or boss.part_state == "returning"
			var fase: String = local_player._arremesso.fase
			if fase != "" and (owner_phases.is_empty() or owner_phases.back() != fase):
				owner_phases.append(fase)
			owner_travel = maxf(owner_travel, Vector2(local_player.global_position.x - launch_start.x, local_player.global_position.z - launch_start.z).length())
		await create_timer(0.2).timeout
		print("ARREMESSO REDE dono=", owner_phases, " viagem=", owner_travel, " servidor=", answer.remote_phases)
		ok(owner_phases == [PlayerArremesso.LAUNCHED, PlayerArremesso.KNOCKDOWN, PlayerArremesso.GETUP] and owner_travel > 6.0, "dono remoto voa, deita e levanta (%.1f m)" % owner_travel)
		ok(PlayerArremesso.KNOCKDOWN in answer.remote_phases, "cópia do servidor anima a derrubada do jogador remoto")
		local_player.set_physics_process(false)
		# Longe do caminho do punho da etapa "flight", como estava antes deste bloco.
		local_player.position = Vector3(0, 0.8, -7)
		# Medido na cópia do servidor: no cliente a regeneração local e a correção
		# autoritativa da vida se misturam com o dano durante os ~3 s de derrubada.
		ok(is_equal_approx(float(answer.server_damage), 112.0), "punho do servidor aplica 112 uma vez no jogador remoto (%.1f)" % float(answer.server_damage))
		ok(saw_part and saw_return and boss.part_state == "attached", "cliente vê separação, retorno e encaixe")
		answer = {}
		bridge.melee_launch.rpc_id(1)
		while not answer.has("reaction"):
			await process_frame
		var until := Time.get_ticks_msec() + 2000
		while boss.reaction != BossHitReaction.LAUNCHED and Time.get_ticks_msec() < until:
			await physics_frame
		for i in 20:
			await physics_frame
		ok(answer.reaction == BossHitReaction.LAUNCHED and boss.reaction == BossHitReaction.LAUNCHED and boss.reaction_count == 3, "3º M1 do cliente arremessa e a fase chega replicada")
		ok(float(boss.presentation._reaction_pose.get("body_pitch", 0.0)) > 0.3, "cliente anima o voo de costas")
		for kind in ["dash", "jump"]:
			answer = {}
			bridge.mobilidade.rpc_id(1, kind)
			while not answer.has("mobilidade"):
				await process_frame
			var until_mob := Time.get_ticks_msec() + 2000
			while boss.mobility != kind and Time.get_ticks_msec() < until_mob:
				await physics_frame
			for i in 15:
				await physics_frame
			if kind == "dash":
				ok(boss.mobility == "dash" and boss.dash_direction.is_equal_approx(Vector3.RIGHT) and boss.presentation._dash_weight > 0.5, "cliente recebe o dash e inclina o corpo")
			else:
				ok(boss.mobility == "jump" and boss.jumps_used == 2 and boss.presentation._tuck_weight > 0.5, "cliente recebe o pulo duplo e recolhe as pernas")
	elif role == "flight":
		ok(boss.part_state == "outbound" and boss.action_id == "detached_fist", "entrada durante voo recebe parte e ação")
		ok(boss.part_transform.origin.is_finite() and boss.part_transform.origin.distance_to(boss.position) > 1, "transform da mão em voo replicado no spawn")
		ok(boss.presentation.hand_binding.flying.visible and not boss.presentation.hand_binding.attached.visible, "entrada tardia não duplica a mão no braço")
		var before: Transform3D = boss.part_transform
		boss.combat.detached.launch(boss.definition.moves().back(), 0)
		ok(boss.part_transform == before, "cliente não lança nem reposiciona a parte")
	else:
		ok(boss.part_state == "attached" and not boss.presentation.hand_binding.flying.visible, "entrada após morte não deixa punho fantasma")
		ok(boss.dead and boss.health == 0, "entrada após morte recebe cadáver sem reset")
		ok(boss.action_id == "" and not boss.is_in_group("enemy"), "cadáver não ataca nem vira alvo")
		ok(boss.combat.get_child_count() == 0, "cliente tardio não recria hitbox")
	print("BOSS NETWORK %s: %d checks, %d failures" % [role, checks, failures])
	bridge.finish.rpc_id(1, role, failures)
	await create_timer(0.5).timeout
	quit(0 if failures == 0 else 1)
