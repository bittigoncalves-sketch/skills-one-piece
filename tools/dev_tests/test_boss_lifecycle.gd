extends SceneTree
## Ator real, arena real, dano pela varredura da mão e pelo CombatResolver.
var checks := 0
var failures := 0
var deaths := 0
var boss: Node3D
var player: CharacterBody3D

func ok(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	OS.set_environment("SOP_TEST_CHARACTER_TARGET", "player")
	OS.set_environment("SOP_TEST_CHARACTER_VISUAL", "res://assets/models/bosses/buggy/buggy_boss_visual.tres")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(1.0).timeout
	boss = get_first_node_in_group("boss")
	player = get_first_node_in_group("player")
	ok(boss != null and player != null, "Boss e jogador presentes na arena normal")
	if boss == null or player == null:
		quit(1)
		return
	ok(get_nodes_in_group("boss").size() == 1, "um único Boss")
	ok(boss.authoritative() and boss.get_multiplayer_authority() == 1, "autoridade do servidor")
	ok(not boss.is_in_group("dummy"), "Boss não usa ciclo de vida do Dummy")
	ok(boss.health == boss.definition.max_health and boss.action_id == "", "Boss íntegro e sem aggro no spawn do jogador")
	ok(boss.position.distance_to(player.position) > 11, "encontro fora da zona inicial")
	ok(player.find_child("CharacterTestVisual", true, false) != null, "Buggy temporário no jogador")
	var dummy := get_first_node_in_group("dummy")
	ok(dummy != null and dummy.find_child("CharacterTestVisual", true, false) == null, "filtro player preserva o Dummy original")
	player.set_physics_process(false)
	boss.set_physics_process(false)
	# Região sólida central; retirar outros alvos evita colisão do fixture.
	if dummy:
		dummy.position = Vector3(20, 0.8, 20)
	boss.position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	player.position = Vector3(0, 0.8, -1.20)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	boss.presentation.pose_at(-1)
	for role in ["UpperArm_L", "ForeArm_L", "Hand_L", "Head"]:
		print("BONE ", role, " ", BoxingPose.bone_position(boss.presentation.skeleton, boss.presentation.bones[role]))
	var guard: Vector3 = boss.presentation.hand_position()
	var right: Vector3 = boss.presentation.hand_position("R")
	# Este teste mede o combo de quatro jabs; o finalizador destacado é coberto
	# em test_boss_detached.gd com o relógio da parte e da apresentação integrados.
	boss.definition = boss.definition.duplicate()
	boss.definition.followups = boss.definition.followups.filter(func(move): return not move is BossDetachedAbility)
	var opener: BossAbility = boss.definition.ability
	boss.presentation.pose_at(opener.windup + opener.active * 0.6 + 0.001)
	var contact: Vector3 = boss.presentation.hand_position()
	print("HANDS guard=", guard, " contact=", contact, " right=", right)
	ok(guard.is_finite() and contact.is_finite() and contact.z < guard.z - 0.25, "jab estende a mão esquerda à frente")
	ok(right.distance_to(boss.presentation.hand_position("R")) < 0.03, "mão direita permanece em guarda")
	# Balanço do tórax: o ombro do punho vai à frente no contato, e as curvas não
	# estalam nas trocas de fase (preparação -> contato -> recuperação -> guarda).
	var view: BossVisual = boss.presentation
	for id in ["jab", "jab_right"]:
		boss.action_id = id
		var move: BossAbility = view.current_move()
		var shoulder := "UpperArm_" + move.hand
		view.pose_at(-1)
		var shoulder_guard := BoxingPose.bone_position(view.skeleton, view.bones[shoulder])
		view.pose_at(move.windup + move.active * 0.6)
		var shoulder_contact := BoxingPose.bone_position(view.skeleton, view.bones[shoulder])
		print("TORSO ", id, " shoulder_forward=", shoulder_guard.z - shoulder_contact.z)
		ok(shoulder_guard.z - shoulder_contact.z > 0.06, "tórax leva o ombro %s à frente no contato" % move.hand)
		var jump := 0.0
		for boundary in [move.windup, move.windup + move.active, move.duration()]:
			view.pose_at(boundary - 0.0005)
			var before_basis := view.skeleton.get_bone_global_pose(view.bones["Torso"]).basis.orthonormalized()
			view.pose_at(boundary + 0.0005)
			var after_basis := view.skeleton.get_bone_global_pose(view.bones["Torso"]).basis.orthonormalized()
			jump = maxf(jump, (before_basis.inverse() * after_basis).get_rotation_quaternion().get_angle())
		ok(jump < 0.02, "tórax sem estalo entre fases do %s (%.4f rad)" % [id, jump])
	boss.action_id = ""
	view.pose_at(-1)
	for hz in [30, 60, 120]:
		boss.combat.cooldown_remaining = 0
		player.health = 1024.0
		player.velocity = Vector3.ZERO
		ok(boss.combat.begin(player), "inicia jab a %d Hz" % hz)
		var dt: float = 1.0 / hz
		while boss.action_elapsed + dt < boss.definition.ability.windup:
			boss.combat.tick(dt)
		ok(player.health == 1024, "preparação não causa dano a %d Hz" % hz)
		while boss.action_elapsed < boss.definition.ability.windup + boss.definition.ability.active + 0.01:
			boss.combat.tick(dt)
		print("DAMAGE hz=", hz, " value=", 1024.0 - player.health)
		ok(is_equal_approx(1024.0 - player.health, 72), "contato único de 72 a %d Hz" % hz)
		ok(boss.state == "recovery", "janela de recuperação a %d Hz" % hz)
		while boss.combat.busy():
			boss.combat.tick(dt)
		ok(not boss.combat.begin(player), "cooldown impede novo jab imediato")
		await process_frame
	# Combo: quatro socos alternados, um cast por soco, marca no chão por punho,
	# pausa só depois do último.
	boss.combat.cooldown_remaining = 0
	player.health = 1024.0
	ok(boss.combat.begin(player), "inicia combo")
	var hands: Array[String] = []
	var shown_sequence := -1
	var chain_without_cooldown := true
	var mark_side_ok := true
	var mark_reach_error := 0.0
	var mark: BossTelegraph = boss.presentation.telegraph
	var floor_y: float = boss.global_position.y - boss.definition.height * 0.5
	var frames := 0
	while boss.combat.busy() and frames < 600:
		frames += 1
		var move: BossAbility = boss.presentation.current_move()
		if boss.action_sequence != shown_sequence:
			shown_sequence = boss.action_sequence
			hands.append(move.hand)
			chain_without_cooldown = chain_without_cooldown and boss.combat.cooldown_remaining == 0
			boss.presentation.present(0.0)
			var center := boss.to_local(mark.global_position)
			mark_side_ok = mark_side_ok and mark.visible and (center.x < 0) == (move.hand == "L") and center.z < -0.2 \
				and absf(mark.global_position.y - floor_y) < 0.06
		boss.combat.tick(1.0 / 60.0)
		if boss.combat.busy() and boss.state == "active" and boss.action_elapsed >= move.windup + move.active * 0.6:
			# Ponta da marca = mão real estendida projetada no chão.
			var plane := mark.mesh as PlaneMesh
			var tip: Vector3 = mark.global_position - mark.global_basis.z * (plane.size.y * 0.5 - move.hit_radius)
			var hand: Vector3 = boss.presentation.hand_position(move.hand)
			mark_reach_error = maxf(mark_reach_error, Vector2(tip.x - hand.x, tip.z - hand.z).length())
	print("COMBO hands=", hands, " damage=", 1024.0 - player.health, " reach_error=", mark_reach_error)
	ok(hands == ["L", "R", "L", "R"], "combo alterna esquerda e direita em quatro socos")
	ok(is_equal_approx(1024.0 - player.health, 72.0 * 4), "cada soco do combo acerta uma única vez")
	ok(chain_without_cooldown, "cooldown não interrompe a sequência")
	ok(boss.combat.cooldown_remaining > 0 and not boss.combat.begin(player), "pausa depois do quarto soco")
	ok(mark_side_ok, "marca vermelha no chão, à frente e do lado do punho da vez")
	ok(mark_reach_error < 0.05, "ponta da marca coincide com o alcance real do punho")
	boss.presentation.present(0.0)
	ok(not mark.visible, "marca some fora do golpe")
	# Sair do alcance depois do primeiro soco quebra o combo.
	boss.combat.cooldown_remaining = 0
	player.health = 1024.0
	player.position = Vector3(0, 0.8, -1.20)
	boss.combat.begin(player)
	while boss.combat.busy() and boss.combo_index == 0:
		boss.combat.tick(1.0 / 60.0)
		if boss.state == "recovery":
			player.position = Vector3(0, 0.8, -5)
	ok(not boss.combat.busy() and player.health == 952 and boss.combat.cooldown_remaining > 0, "alvo fora de alcance encerra o combo com pausa")
	player.position = Vector3(0, 0.8, -1.20)
	await process_frame
	boss.combat.cooldown_remaining = 0
	player.health = 1024
	boss.combat.begin(player)
	boss.combat.tick(0.2)
	var hp: float = boss.health
	boss.take_damage(31, player.position, Vector3(2, 0, 0), 0.4)
	ok(boss.health == hp - 31 and not boss.combat.busy(), "dano interrompe preparação")
	boss.combat.tick(1.0)
	ok(player.health == 1024 and boss.velocity.x >= 2, "interrupção remove ataque e mantém impulso recebido")
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	boss.set_meta("is_frozen", true)
	boss.controller.tick(boss, 0.016)
	ok(not boss.combat.busy() and boss.state == "stunned", "congelamento cancela ataque e IA")
	boss.remove_meta("is_frozen")
	boss.position = Vector3(0, 1.1, 0)
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	boss.combat.tick(0.8)
	ok(player.health == 952, "frame longo também resolve contato")
	boss.combat.cancel("test")
	await process_frame
	# Parede física intercepta a varredura e a linha de visão.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.15)
	shape.shape = box
	wall.add_child(shape)
	current_scene.add_child(wall)
	wall.position = Vector3(0, 1, -0.75)
	await physics_frame
	await physics_frame
	player.health = 1024
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	boss.combat.tick(0.8)
	ok(player.health == 1024, "jab não atravessa parede")
	boss.combat.cancel("test")
	wall.queue_free()
	await process_frame
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	player.health = 0
	boss.combat.tick(0.8)
	ok(not boss.combat.busy(), "alvo morto cancela cast")
	# Integração física: a IA precisa chegar ao alcance e acertar sozinha.
	player.health = 1024
	player.position = Vector3(0, 0.8, -4)
	player.velocity = Vector3.ZERO
	boss.position = Vector3(0, 1.1, 0)
	boss.home_position = boss.position
	boss.velocity = Vector3.ZERO
	boss.controller.stun_remaining = 0
	boss.controller.brain.target = null
	boss.combat.cooldown_remaining = 0
	boss.set_physics_process(true)
	var deadline := Time.get_ticks_msec() + 5000
	while player.health == 1024 and Time.get_ticks_msec() < deadline:
		await physics_frame
	boss.set_physics_process(false)
	ok(player.health == 952 and boss.position.z < -1, "IA persegue e acerta com física real")
	boss.combat.cancel("test")
	player.position = Vector3(0, 0.8, -40)
	boss.controller.brain.tick(boss, 1)
	ok(boss.controller.brain.target == null, "alvo além do limite abandona encontro")
	boss.controller.tick(boss, 0.016)
	ok(boss.state == "return", "Boss retorna ao ponto de origem")
	var scoreboard := get_first_node_in_group("scoreboard")
	ok(scoreboard._peer_of(boss) == 0, "Boss não recebe identidade de jogador no placar")
	# Aguarda a liberação adiada do cast usado na perseguição.
	await process_frame
	# Dano de entrada pelo sistema compartilhado, com hitbox do jab já ativa.
	player.health = 1024
	player.position = boss.position + Vector3(0, -0.3, -1.2)
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	boss.combat.tick(opener.windup + opener.active * 0.5)
	ok(boss.combat.get_child_count() == 1, "janela ativa cria a hitbox do jab")
	var incoming := DamageZone.new()
	current_scene.add_child(incoming)
	incoming.setup(19, 2, Vector3.ZERO, 1, player, 0.2)
	incoming.monitoring = false
	var before_incoming: float = boss.health
	incoming._on_body(boss)
	ok(boss.health == before_incoming - 19 and not boss.combat.busy(), "DamageZone do jogador interrompe jab ativo e reduz HP do Boss")
	incoming.queue_free()
	await process_frame
	ok(boss.combat.get_child_count() == 0, "interrupção ativa libera hitbox")
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	boss.combat.tick(0.5)
	boss.died.connect(func(_id: int): deaths += 1)
	# 10/11/2026: chefe tem 10 barras — dano absurdo derruba UMA barra por golpe (a janela de 1 s é zerada entre golpes).
	for i in 9:
		boss.remove_meta(VidaEmBarras.META_IMUNE)
		boss.take_damage(99999)
		boss._physics_process(0.016)
	ok(not boss.dead and boss.health > 0, "9 golpes absurdos não matam o chefe (10 barras)")
	boss.remove_meta(VidaEmBarras.META_IMUNE)
	boss.take_damage(99999)
	boss._physics_process(0.016)
	boss.take_damage(99999)
	boss._physics_process(0.016)
	await process_frame
	ok(boss.dead and boss.health == 0 and deaths == 1, "morte única sem reset de Dummy")
	ok(not boss.is_in_group("enemy") and not boss.combat.busy(), "morte remove alvo e hitbox")
	ok(boss.combat.get_child_count() == 0, "zonas liberadas após cancelamento")
	print("BOSS LIFECYCLE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
