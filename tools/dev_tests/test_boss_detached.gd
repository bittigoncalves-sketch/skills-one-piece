extends SceneTree
var checks := 0
var failures := 0
var boss: Node3D
var player: Node3D
var data: BossDetachedAbility

func ok(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + label)

func step(dt: float) -> void:
	boss.combat.tick(dt)
	boss.combat.detached.tick(dt)
	boss.presentation.present(dt)

func finish_at(distance: float) -> void:
	boss.combat.cancel("fixture")
	boss.combat.detached.reset()
	boss.combat.detached.cooldown = 0
	boss.combat.cooldown_remaining = 0
	boss.position = Vector3(0, 1.1, 0)
	boss.rotation = Vector3.ZERO
	player.position = Vector3(0, 0.8, -distance)
	player.health = 8192
	player.velocity = Vector3.ZERO
	boss.combat._target = player
	boss.combat._start_move(4)
	boss.presentation.present(0)

func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(1).timeout
	boss = get_first_node_in_group("boss")
	player = get_first_node_in_group("player")
	if boss == null or player == null:
		quit(1)
		return
	boss.set_physics_process(false)
	player.set_physics_process(false)
	boss.position = Vector3(0, 1.1, 0)
	player.position = Vector3(0, 0.8, -1.2)
	player.health = 8192
	data = boss.definition.moves().back()
	ok(boss.definition.valid() and boss.definition.moves().size() == 5, "finalizador configurado depois dos quatro jabs")
	var binding: BossHandBinding = boss.presentation.hand_binding
	ok(binding.valid and binding.attached.mesh.get_surface_count() == 2 and binding.flying.mesh.get_surface_count() == 2, "mão separada com tampas e materiais")
	await physics_frame
	await physics_frame
	boss.combat.begin(player)
	var sequence: Array[String] = []
	var detached_visible := false
	for i in 600:
		if not boss.combat.busy():
			break
		if sequence.is_empty() or sequence.back() != boss.action_id:
			sequence.append(boss.action_id)
		step(1.0 / 60.0)
		if boss.part_state != "attached":
			detached_visible = binding.flying.visible and not binding.attached.visible
	ok(sequence == ["jab", "jab_right", "jab_left", "jab_finish", "detached_fist"], "combo emenda o punho destacado")
	print("COMBO DAMAGE ", 8192 - player.health, " states=", sequence)
	ok(player.health == 8192 - 400, "combo: quatro vezes 72 e finalizador de 112")
	ok(detached_visible, "sem cópia de mão no braço durante voo")
	ok(boss.part_state == "attached" and binding.attached.visible and not binding.flying.visible, "retorno recompõe o corpo")
	for hz in [30, 60, 120]:
		finish_at(4)
		await physics_frame
		await physics_frame
		boss.presentation.present(0.1)
		ok(boss.presentation.telegraph.visible, "aviso vermelho antes da saída a %d Hz" % hz)
		var saw_return := false
		var saw_outbound := false
		for i in 400:
			step(1.0 / hz)
			saw_return = saw_return or boss.part_state == "returning"
			saw_outbound = saw_outbound or boss.part_state == "outbound"
			if not boss.combat.busy() and boss.part_state == "attached":
				break
		print("FLIGHT DAMAGE hz=", hz, " damage=", 8192 - player.health)
		ok(player.health == 8080, "112 uma única vez a %d Hz" % hz)
		ok(saw_outbound and saw_return and boss.part_state == "attached", "ida, retorno e encaixe a %d Hz" % hz)
		ok(not boss.combat.detached.available(), "recarga impede novo finalizador imediato")
	# Interrupção durante a ida: mão retorna, sem atingir o alvo mais à frente.
	finish_at(6)
	await physics_frame
	await physics_frame
	while boss.part_state == "attached":
		step(1.0 / 60.0)
	step(0.05)
	boss.take_damage(5)
	ok(boss.part_state == "returning" and not boss.combat.busy(), "dano interrompe e recolhe a mão")
	for i in 60:
		step(1.0 / 60.0)
	ok(player.health == 8192 and boss.part_state == "attached", "retorno de interrupção sem dano residual")
	# Parede no percurso anunciado e no voo físico.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.4)
	shape.shape = box
	wall.add_child(shape)
	current_scene.add_child(wall)
	wall.position = Vector3(0, 1, -2)
	finish_at(4)
	await physics_frame
	await physics_frame
	boss.presentation.pose_at(data.windup + data.active * 0.6)
	var path := BossDetachedAttack.path(boss, data)
	ok(path[1].z > -1.8, "aviso do punho termina antes da parede")
	var nearest := 0.0
	for i in 180:
		step(1.0 / 60.0)
		if boss.part_state == "outbound":
			nearest = minf(nearest, boss.part_transform.origin.z)
	ok(nearest > -1.8 and player.health == 8192, "mão e dano não atravessam parede")
	wall.queue_free()
	await process_frame
	# Um alvo entrando só na volta não recebe dano.
	finish_at(4)
	player.position.x = 3
	await physics_frame
	await physics_frame
	while boss.part_state != "returning":
		step(1.0 / 60.0)
	player.position = Vector3(0, 0.8, -3)
	await physics_frame
	await physics_frame
	for i in 90:
		step(1.0 / 60.0)
	ok(player.health == 8192, "mão não causa dano na viagem de retorno")
	# Obstáculo criado DEPOIS da saída: a parte também precisa parar nele.
	finish_at(6)
	await physics_frame
	await physics_frame
	while boss.part_state == "attached":
		step(1.0 / 60.0)
	var moving_wall := StaticBody3D.new()
	var moving_shape := CollisionShape3D.new()
	moving_shape.shape = box
	moving_wall.add_child(moving_shape)
	current_scene.add_child(moving_wall)
	moving_wall.position = Vector3(0, 1, -2)
	await physics_frame
	await physics_frame
	nearest = 0
	for i in 180:
		step(1.0 / 60.0)
		if boss.part_state != "attached":
			nearest = minf(nearest, boss.part_transform.origin.z)
	ok(nearest > -1.8 and player.health == 8192, "obstáculo novo bloqueia a parte já em voo")
	moving_wall.queue_free()
	await process_frame
	# Percurso real: IA e relógio da parte pelo _physics_process do Boss.
	boss.combat.cancel("fixture")
	boss.combat.detached.reset()
	boss.combat.detached.cooldown = 0
	boss.combat.cooldown_remaining = 0
	boss.controller.stun_remaining = 0
	boss.controller.brain.target = player
	boss.position = Vector3(0, 1.1, 0)
	boss.home_position = boss.position
	boss.velocity = Vector3.ZERO
	player.position = Vector3(0, 0.8, -1.2)
	player.health = 8192
	boss.set_physics_process(true)
	var saw_real_flight := false
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		saw_real_flight = saw_real_flight or boss.part_state != "attached"
		if saw_real_flight and not boss.combat.busy() and boss.part_state == "attached":
			break
	boss.set_physics_process(false)
	ok(saw_real_flight and boss.part_state == "attached", "IA executa finalizador e recolhe pelo ciclo físico real")
	ok(player.health == 7792, "combo completo da IA aplica 400 com física real")
	# Ao morrer, não pode sobrar parte independente ou cast ativo.
	finish_at(6)
	await physics_frame
	await physics_frame
	while boss.part_state == "attached":
		step(1.0 / 60.0)
	boss.take_damage(99999)
	boss.presentation.present(0)
	await process_frame
	ok(boss.dead and boss.part_state == "attached" and not binding.flying.visible, "morte recolhe parte sem fantasma")
	ok(boss.combat.get_child_count() == 0, "morte libera todas as zonas de dano")
	print("BOSS DETACHED: %d checks, %d failures" % [checks, failures])
	current_scene.queue_free()
	# Deixa os feedbacks assíncronos do último impacto terminarem antes de fechar.
	await create_timer(0.1, true, false, true).timeout
	await process_frame
	quit(0 if failures == 0 else 1)
