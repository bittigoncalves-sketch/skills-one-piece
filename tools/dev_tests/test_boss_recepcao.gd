extends SceneTree
## Recepção de M1 do Boss: 1º e 2º acerto seguidos paralisam sem empurrar, o 3º
## arremessa; voo, queda de costas, levantar. Golpe real (`Melee.golpear`), física real.
var checks := 0
var failures := 0
var boss: CharacterBody3D
var player: CharacterBody3D

func ok(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(1.0).timeout
	boss = get_first_node_in_group("boss")
	player = get_first_node_in_group("player")
	ok(boss != null and player != null, "Boss e jogador presentes")
	if boss == null or player == null:
		quit(1)
		return
	player.set_physics_process(false)
	player.health = 99999.0
	await place()

	# ---- 1º e 2º acerto: paralisia no lugar
	var hp: float = boss.health
	await punch(0)
	var start: Vector3 = boss.global_position
	ok(boss.reaction == BossHitReaction.STAGGER and boss.reaction_count == 1, "1º M1 paralisa o Boss")
	ok(boss.health < hp, "1º M1 causa dano")
	ok(not boss.has_meta(CombatResolver.META_CORPO_A_CORPO), "marca de M1 existe só durante o take_damage")
	await create_timer(0.3).timeout
	ok(flat(boss.global_position - start) < 0.05, "1º M1 não empurra (%.3f m)" % flat(boss.global_position - start))
	ok(not boss.combat.busy() and boss.state == BossHitReaction.STAGGER, "paralisado não ataca com o jogador no alcance")
	await punch(1)
	ok(boss.reaction == BossHitReaction.STAGGER and boss.reaction_count == 2, "2º M1 seguido paralisa de novo")
	await create_timer(0.3).timeout
	ok(flat(boss.global_position - start) < 0.05, "2º M1 não empurra")

	# ---- 3º acerto: arremesso, chão, levantar
	# Posição de partida gravada ANTES do golpe: paralisado, o Boss está parado; depois
	# do golpe a espera em tempo real já o pega uma fração variável de voo adiante.
	var launch_from: Vector3 = boss.global_position
	await punch(2)
	ok(boss.reaction == BossHitReaction.LAUNCHED, "3º M1 seguido arremessa")
	var peak: float = boss.global_position.y
	var pitch_in_air := 0.0
	var attacker_at: Vector3 = player.global_position
	var phases: Array[String] = [boss.reaction]
	var last_phase: String = boss.reaction
	var deadline := Time.get_ticks_msec() + 5000
	while boss.reaction != "" and Time.get_ticks_msec() < deadline:
		await physics_frame
		peak = maxf(peak, boss.global_position.y)
		if boss.reaction == BossHitReaction.LAUNCHED:
			pitch_in_air = maxf(pitch_in_air, float(boss.presentation._reaction_pose.get("body_pitch", 0.0)))
		if last_phase != boss.reaction:
			last_phase = boss.reaction
			phases.append(boss.reaction)
		if boss.reaction == BossHitReaction.KNOCKDOWN and boss.reaction_elapsed > 0.5 and not phases.has("deitado"):
			if float(boss.presentation._reaction_pose.get("body_pitch", 0.0)) > 1.3:
				phases.append("deitado")
	for i in 3:
		await physics_frame
	var travel := flat(boss.global_position - launch_from)
	print("LAUNCH from=", launch_from, " to=", boss.global_position, " attacker=", attacker_at, " phases=", phases, " travel=", travel, " peak=", peak - start.y, " pitch_air=", pitch_in_air)
	ok(phases == [BossHitReaction.LAUNCHED, BossHitReaction.KNOCKDOWN, "deitado", BossHitReaction.GETUP, ""], "voa, cai deitado, levanta e volta")
	ok(travel > 7.0, "arremesso joga para longe (%.1f m)" % travel)
	var away := launch_from - attacker_at
	away.y = 0
	ok((boss.global_position - launch_from).dot(away.normalized()) > 6.0, "voo sai na direção oposta ao atacante")
	ok(peak - launch_from.y > 1.0, "voo sobe acima do chão (%.2f m)" % (peak - launch_from.y))
	ok(pitch_in_air > 0.5, "corpo arqueia de costas no ar")
	ok(boss.reaction == "" and absf(float(boss.presentation._reaction_pose.body_pitch)) < 0.15, "levanta de pé ao fim (%.2f rad)" % float(boss.presentation._reaction_pose.body_pitch))

	# ---- contagem zera depois do arremesso e fora da janela
	await place()
	await punch(0)
	ok(boss.reaction_count == 1, "combo zera depois do arremesso")
	await create_timer(BossHitReaction.CHAIN_WINDOW + 0.3).timeout
	await punch(1)
	ok(boss.reaction == BossHitReaction.STAGGER and boss.reaction_count == 1, "acerto fora da janela recomeça a contagem")

	# ---- outro atacante recomeça a contagem
	var other := Node3D.new()
	current_scene.add_child(other)
	await punch(0)
	CombatResolver.aplicar(boss, 1, 0, 0, other.global_position, Vector3.ZERO, 0.1, 0.0, false, other)
	ok(boss.reaction_count == 1, "acerto de outro atacante recomeça a contagem")
	other.queue_free()

	# ---- golpe que não é M1 continua empurrando
	await create_timer(1.1).timeout
	await place()
	var push := DamageZone.new()
	current_scene.add_child(push)
	push.global_position = boss.global_position + Vector3(0, 0, -1)
	push.setup(10, 12, Vector3.ZERO, 1, player, 0.3)
	push.monitoring = false
	push._on_body(boss)
	ok(boss.reaction == "" and boss.velocity.z > 5, "skill (não M1) mantém o empurrão antigo")
	push.queue_free()

	# ---- acerto no chão não reinicia a reação
	await create_timer(1.2).timeout
	await place()
	for i in 3:
		await punch(i)
	deadline = Time.get_ticks_msec() + 3000
	while boss.reaction != BossHitReaction.KNOCKDOWN and Time.get_ticks_msec() < deadline:
		await physics_frame
	hp = boss.health
	CombatResolver.aplicar(boss, 20, 0, 0, boss.global_position, Vector3(0, 0, -9), 0.3, 0.0, false, player)
	ok(boss.health == hp - 20 and boss.reaction == BossHitReaction.KNOCKDOWN, "M1 no Boss caído causa dano sem reiniciar a queda")

	# ---- espada: a lâmina armada pelo M1 também conta
	while boss.reaction != "":
		await physics_frame
	await create_timer(1.1).timeout
	await place()
	var blade := SwordBlade.new()
	current_scene.add_child(blade)
	blade.dono = player
	blade.armar(30, 8, 0.2, 0, 0, true)
	blade._acertar_corpo(boss, boss.global_position + Vector3(0, 0, -0.5))
	ok(boss.reaction == BossHitReaction.STAGGER, "M1 de espada paralisa")
	blade.queue_free()

	# ---- o bug relatado: andar (W/A/S/D) + clique pelo MeleeController real
	for key in [KEY_W, KEY_S, KEY_A, KEY_D]:
		await create_timer(1.1).timeout
		await place()
		player._melee.cancelar_golpe()
		player._melee._passo = 0
		player._melee._janela = 0.0
		var key_event := InputEventKey.new()
		key_event.keycode = key
		key_event.physical_keycode = key
		key_event.pressed = true
		Input.parse_input_event(key_event)
		await physics_frame
		var stand: Vector3 = boss.global_position
		player._melee.pedir(PI)
		var context_id := String(player._melee.contextual_id())
		key_event = key_event.duplicate()
		key_event.pressed = false
		Input.parse_input_event(key_event)
		var deadline_walk := Time.get_ticks_msec() + 1000
		while boss.reaction == "" and Time.get_ticks_msec() < deadline_walk:
			await physics_frame
		await create_timer(0.25).timeout
		print("ANDAR ", OS.get_keycode_string(key), " contextual='", context_id, "' reaction=", boss.reaction, " moved=", flat(boss.global_position - stand))
		ok(context_id == "" and boss.reaction == BossHitReaction.STAGGER and flat(boss.global_position - stand) < 0.05,
			"%s + clique sai M1 e paralisa o Boss sem empurrar" % OS.get_keycode_string(key))
		player._melee.cancelar_golpe()

	# ---- outras variações de clique contam como M1 no Boss (sem empurrão)
	var variations := [
		["Lançamento", func(): contextual("context_launcher")],
		["chute aéreo", func(): contextual("context_air_kick")],
		["estrelinha (Aú)", func(): spin_kick()],
		["chute Mink", func():
			player._mink_bite_target = boss
			player._mink_bite_dir = Vector3.BACK
			player._executar_chute_mink()],
	]
	for variation in variations:
		await create_timer(1.1).timeout
		await place()
		variation[1].call()
		var deadline_hit := Time.get_ticks_msec() + 1000
		while boss.reaction == "" and Time.get_ticks_msec() < deadline_hit:
			await physics_frame
		# A partir do ACERTO: antes dele o Boss pode ter dado o passo de um jab.
		var before: Vector3 = boss.global_position
		await create_timer(0.25).timeout
		print("VARIACAO ", variation[0], " reaction=", boss.reaction, " moved=", flat(boss.global_position - before), " vy=", boss.velocity.y)
		ok(boss.reaction == BossHitReaction.STAGGER and flat(boss.global_position - before) < 0.05 and absf(boss.velocity.y) < 1.0 \
			and not boss.has_meta(ContextualMelee.META_LANCADO), "%s paralisa o Boss sem empurrar" % variation[0])
	player._encerrar_mordida_mink()

	# ---- buraco: o arremesso pode derrubar o Boss para a morte
	var edge := hole_edge()
	ok(edge.size() == 2, "arena tem borda de buraco para o teste")
	if edge.size() == 2:
		await create_timer(1.1).timeout
		boss.velocity = Vector3.ZERO
		boss.global_position = edge[0] + Vector3(0, 1.12, 0)
		player.global_position = edge[0] - edge[1] * 1.5 + Vector3(0, 0.8, 0)
		await physics_frame
		for i in 3:
			await punch(i, edge[1])
		deadline = Time.get_ticks_msec() + 6000
		while not boss.dead and Time.get_ticks_msec() < deadline:
			await physics_frame
		ok(boss.dead, "arremessado num buraco, o Boss cai e morre")
	print("BOSS RECEPCAO: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func place() -> void:
	boss.reaction = ""
	boss.controller.reaction = BossHitReaction.new()
	boss.controller.stun_remaining = 0
	boss.velocity = Vector3.ZERO
	boss.global_position = Vector3(0, 1.12, 0)
	boss.home_position = boss.global_position
	player.global_position = Vector3(0, 0.8, -1.5)
	for i in 3:
		await physics_frame

## Golpe M1 real do punho, do jogador em direção ao Boss.
func punch(step: int, direction: Vector3 = Vector3.BACK) -> void:
	var origin := player.global_position + Vector3.UP * 0.5
	Melee.golpear(current_scene, player, step, origin, direction)
	await create_timer(Melee.startup(step) + 0.05).timeout
	await physics_frame

## Aú pelo caminho real do Player (Espaço + clique). Chamar SpinKickFX direto não
## compila no harness -s: o script referencia o autoload ScreenFX.
func spin_kick() -> void:
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	player._spin_kick_cooldown = 0.0
	player._yaw = PI
	player.tentar_chute_giratorio()
	space = space.duplicate()
	space.pressed = false
	Input.parse_input_event(space)

## Golpe contextual real, autorizado como o servidor faria para o Player.
func contextual(id: String) -> void:
	player._server_contextual_active_seq += 1
	player._server_contextual_token += 1
	player._server_contextual_deadline_ms = Time.get_ticks_msec() + 5000
	ContextualMelee.golpear(current_scene, player, id, player.global_position + Vector3.UP, Vector3.BACK,
		player._server_contextual_active_seq, player._server_contextual_token)

func flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

## Ponto sólido a 3 m de um buraco, e a direção que leva ao buraco.
func hole_edge() -> Array:
	for x in range(-45, 46, 5):
		for z in range(-45, 46, 5):
			for direction in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
				var point: Vector3 = Vector3(x, 0, z)
				var ahead: Vector3 = point + direction * 6.0
				if not MapBuilder.is_hole_area(point.x, point.z, 3, 3) and not MapBuilder.is_hole_area(point.x - direction.x * 1.5, point.z - direction.z * 1.5, 2, 2) \
						and MapBuilder.is_hole(ahead.x, ahead.z) and MapBuilder.is_hole(point.x + direction.x * 9.0, point.z + direction.z * 9.0):
					return [point, direction]
	return []
