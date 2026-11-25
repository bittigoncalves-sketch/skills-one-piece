extends SceneTree
## Corte do Boss contra alvo em fuga: gatilho, mira travada, linha no chão,
## frente que atravessa e para em parede, interrupção, cooldown e pose de arremesso.
var checks := 0
var failures := 0
var boss: CharacterBody3D
var player: CharacterBody3D
var slash: BossSlashAbility

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
	slash = boss.definition.slash
	ok(slash != null and slash.valid() and is_equal_approx(slash.windup - slash.aim_time, 0.55) and slash.slash_range == 18.0 and slash.speed == 26.0 and slash.damage == 90.0, "perfil agressivo carregado")
	player.set_physics_process(false)
	player.health = 99999.0

	# ---- pose de arremesso (sem física)
	boss.set_physics_process(false)
	await place(Vector3(0, 0.8, -6))
	var view: BossVisual = boss.presentation
	boss.action_id = str(slash.id)
	view.pose_at(slash.windup * 0.8)
	var head: Vector3 = boss.to_local(BoxingPose.bone_position(view.skeleton, view.bones["Head"]))
	var hand: Vector3 = boss.to_local(view.hand_position("R"))
	var foot_l: Vector3 = boss.to_local(BoxingPose.bone_position(view.skeleton, view.bones["Foot_L"]))
	var foot_r: Vector3 = boss.to_local(BoxingPose.bone_position(view.skeleton, view.bones["Foot_R"]))
	print("THROW cocked head=", head, " hand=", hand, " foot_l=", foot_l, " foot_r=", foot_r)
	ok(hand.y > head.y and hand.z > head.z, "carregado: mão direita acima da cabeça e para trás")
	ok(foot_l.y > foot_r.y + 0.25, "carregado: perna esquerda dobrada no ar, apoio numa perna só")
	view.pose_at(slash.windup + slash.active)
	var released: Vector3 = boss.to_local(view.hand_position("R"))
	var planted: Vector3 = boss.to_local(BoxingPose.bone_position(view.skeleton, view.bones["Foot_L"]))
	print("THROW release hand=", released, " foot_l=", planted)
	ok(released.z < head.z - 0.4, "lançamento: mão volta à frente")
	ok(planted.y < foot_l.y - 0.15, "lançamento: perna desce")
	# Continuidade: nenhuma pose-chave dá salto; e a mão não passa da velocidade de
	# um arremesso real (~35 m/s), medida no alvo da IK a 240 Hz.
	var gap := 0.0
	for key in BossThrowPose.keys(slash):
		var left: Dictionary = BossThrowPose.sample(slash, key[0] - 0.0001)
		var right_side: Dictionary = BossThrowPose.sample(slash, key[0] + 0.0001)
		for field in BossThrowPose.NEUTRAL:
			var a = left[field]
			var b = right_side[field]
			gap = maxf(gap, (a - b).length() if a is Vector3 else absf(a - b))
	ok(gap < 0.005, "poses-chave encadeadas sem salto (%.4f)" % gap)
	var top_speed := 0.0
	var previous: Dictionary = BossThrowPose.sample(slash, 0.0)
	var t := 0.0
	while t <= slash.duration():
		var current: Dictionary = BossThrowPose.sample(slash, t)
		var step: Vector3 = current.arm_r - previous.arm_r
		top_speed = maxf(top_speed, step.length() * boss.definition.height * 240.0)
		previous = current
		t += 1.0 / 240.0
	print("THROW top_hand_speed=", top_speed)
	ok(top_speed < 35.0, "mão abaixo da velocidade de um arremesso real (%.1f m/s)" % top_speed)
	boss.action_id = ""
	view.pose_at(-1)
	boss.set_physics_process(true)

	# ---- não foge: persegue, não corta
	await place(Vector3(0, 0.8, -7))
	await run(0.8, Vector3.ZERO)
	ok(boss.action_id != str(slash.id), "alvo parado longe não recebe corte")

	# ---- foge perto demais: sem corte
	await place(Vector3(0, 0.8, -2.2))
	await run(0.3, Vector3(0, 0, -4.5))
	ok(boss.action_id != str(slash.id), "fuga a menos de 4 m não dispara corte")

	# ---- foge além de 4 m: corte com mira acompanhando e depois travada
	await place(Vector3(0, 0.8, -5))
	var started: bool = await run_until(1.0, Vector3(0, 0, -4.5), func(): return boss.action_id == str(slash.id))
	ok(started, "alvo fugindo além de 4 m dispara o corte")
	ok(boss.velocity.length() < 0.5, "Boss para para lançar")
	# Na mira, o alvo desvia de lado; antes de travar a mira acompanha.
	await run_until(1.0, Vector3(3, 0, 0), func(): return boss.action_elapsed >= slash.aim_time)
	var locked_yaw: float = boss.rotation.y
	var to_player: Vector3 = player.global_position - boss.global_position
	to_player.y = 0
	var forward: Vector3 = -boss.global_basis.z
	ok(forward.dot(to_player.normalized()) > 0.97, "mira acompanhou o alvo até travar")
	var mark: BossTelegraph = view.telegraph
	await physics_frame
	ok(mark.visible, "linha vermelha aparece ao travar a mira")
	var path: Array[Vector3] = BossCombat.slash_path(boss, slash)
	var plane := mark.mesh as PlaneMesh
	var along := -mark.global_basis.z
	ok(along.dot(forward) > 0.99 and absf(plane.size.y - path[0].distance_to(path[1])) < 0.05, "linha segue a direção e o comprimento do corte (%.2f m)" % plane.size.y)
	ok(is_equal_approx(plane.size.x, slash.width) and absf(mark.global_position.y - (boss.global_position.y - boss.definition.height * 0.5)) < 0.06, "linha no chão com a largura do corte")
	ok(get_nodes_in_group(BossCombat.SLASH_GROUP).is_empty(), "corte ainda não saiu durante a linha")
	# Parado dentro da faixa: vai levar o corte.
	player.global_position = boss.global_position + forward * 6.0 + Vector3(0, -0.3, 0)
	var hp: float = player.health
	await run_until(1.0, Vector3.ZERO, func(): return boss.action_elapsed >= slash.windup)
	ok(absf(boss.rotation.y - locked_yaw) < 0.001, "mira não mexe depois de travada")
	ok(get_nodes_in_group(BossCombat.SLASH_GROUP).size() == 1, "corte sai no fim da preparação")
	await create_timer(0.6).timeout
	print("SLASH damage=", hp - player.health)
	ok(is_equal_approx(hp - player.health, slash.damage), "alvo na faixa leva 90 uma única vez")
	await create_timer(0.6).timeout
	ok(not boss.combat.begin_slash(player) and boss.combat.slash_cooldown_remaining > 0, "cooldown impede outro corte imediato")

	# ---- desvio lateral depois da trava
	await wait_idle()
	await place(Vector3(0, 0.8, -5))
	await run_until(1.0, Vector3(0, 0, -4.5), func(): return boss.action_id == str(slash.id) and boss.action_elapsed >= slash.aim_time)
	forward = -boss.global_basis.z
	player.global_position = boss.global_position + forward * 7.0 + forward.cross(Vector3.UP) * 2.2 + Vector3(0, -0.3, 0)
	hp = player.health
	await run(1.2, Vector3.ZERO)
	ok(player.health == hp, "sair da faixa depois da linha evita o corte")

	# ---- atravessa jogadores e para em parede
	await wait_idle()
	await place(Vector3(0, 0.8, -5))
	await run_until(1.0, Vector3(0, 0, -4.5), func(): return boss.action_id == str(slash.id) and boss.action_elapsed >= slash.aim_time)
	forward = -boss.global_basis.z
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	shape.shape = box
	wall.add_child(shape)
	current_scene.add_child(wall)
	wall.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), boss.global_position + forward * 9.0 + Vector3(0, 1, 0))
	var dummy := TrainingDummyProbe.new()
	current_scene.add_child(dummy)
	dummy.global_position = boss.global_position + forward * 4.0
	player.global_position = boss.global_position + forward * 7.0 + Vector3(0, -0.3, 0)
	var behind := TrainingDummyProbe.new()
	current_scene.add_child(behind)
	behind.global_position = boss.global_position + forward * 12.0
	for i in 3:
		await physics_frame
	var wall_path: Array[Vector3] = BossCombat.slash_path(boss, slash)
	ok(absf(wall_path[0].distance_to(wall_path[1]) - (9.0 - 0.15 - boss.definition.width * 0.5 - 0.3)) < 0.1, "linha termina na parede (%.2f m)" % wall_path[0].distance_to(wall_path[1]))
	hp = player.health
	await run(1.4, Vector3.ZERO)
	ok(dummy.hits == 1 and player.health == hp - slash.damage, "corte atravessa o primeiro alvo e acerta o de trás")
	ok(behind.hits == 0, "corte para na parede")
	wall.queue_free()
	dummy.queue_free()
	behind.queue_free()

	# ---- dano na preparação cancela sem lançar
	await wait_idle()
	boss.combat.slash_cooldown_remaining = 0
	await place(Vector3(0, 0.8, -5))
	await run_until(1.0, Vector3(0, 0, -4.5), func(): return boss.action_id == str(slash.id))
	boss.take_damage(10, Vector3.ZERO, Vector3.ZERO, 0.3)
	await run(1.2, Vector3.ZERO)
	ok(get_nodes_in_group(BossCombat.SLASH_GROUP).is_empty() and boss.combat.slash_cooldown_remaining > 0, "dano na preparação cancela o corte")
	print("BOSS CORTE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

class TrainingDummyProbe extends StaticBody3D:
	var hits := 0
	func _init() -> void:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.8
		capsule.radius = 0.35
		shape.shape = capsule
		shape.position.y = 0.9
		add_child(shape)
	func take_damage(_amount: float, _origin: Vector3 = Vector3.ZERO, _impulse: Vector3 = Vector3.ZERO, _stun: float = 0.0) -> void:
		hits += 1

func place(player_at: Vector3) -> void:
	boss.combat.cancel("fixture")
	boss.combat.slash_cooldown_remaining = 0
	boss.combat.cooldown_remaining = 0
	boss.reaction = ""
	boss.controller.stun_remaining = 0
	boss.velocity = Vector3.ZERO
	boss.global_position = Vector3(0, 1.12, 0)
	boss.home_position = boss.global_position
	boss.rotation = Vector3.ZERO
	player.global_position = player_at
	boss.controller.brain.target = player
	for i in 3:
		await physics_frame

## Move o jogador com velocidade constante por `seconds`.
func run(seconds: float, velocity: Vector3) -> void:
	await run_until(seconds, velocity, func(): return false)

func run_until(seconds: float, velocity: Vector3, done: Callable) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await physics_frame
		player.global_position += velocity / float(Engine.physics_ticks_per_second)
		if done.call():
			return true
	return false

func wait_idle() -> void:
	while boss.combat.busy():
		await physics_frame
	for wave in get_nodes_in_group(BossCombat.SLASH_GROUP):
		wave.queue_free()
	await physics_frame
