extends SceneTree
## Percurso real Player -> autorização -> cast -> volume varrido -> vida.
const BARA := preload("res://src/combat/BaraController.gd")
const HOME := Vector3(0, 101, 0)
var checks := 0
var failures := 0
var actor: Node3D
var dummy: Node3D
var token := 100

func check(condition: bool, message: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures += 1

func _init() -> void:
	await process_frame
	create_timer(85.0).timeout.connect(func(): quit(2))
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(2).timeout
	actor = get_first_node_in_group("player")
	dummy = get_first_node_in_group("dummy")
	if actor == null or dummy == null:
		check(false, "arena criou Player e dummy")
		quit(1)
		return
	actor.set_physics_process(false)
	dummy.set_physics_process(false)
	actor.equip_fruit("bara_bara")
	actor.combat_mode = "fruit"
	box(Vector3(0, 99.7, 0), Vector3(60, 0.6, 60))
	await reset()
	check(BARA.binding_for(actor).valid, "avatar real possui duas mãos separáveis")
	var paid: float = actor.energy
	request("Z", Vector3(NAN, 0, 0))
	check(actor.energy == paid and BARA.action_for(actor) == null, "NaN recusado sem custo")
	request("Z")
	check(actor.energy == paid - actor.ENERGY_SKILL, "energia cobrada somente no aceite")
	var first := BARA.action_for(actor)
	actor._do_server_cast("Z", Vector3.FORWARD, actor.global_position, 0.0, token, "fruit", "bara_bara")
	check(actor.energy == paid - actor.ENERGY_SKILL and BARA.action_for(actor) == first, "replay não cobra nem duplica")
	await create_timer(1.35).timeout
	check(is_equal_approx(2048.0 - dummy.health, 92), "Z: 92, uma vez na ida")
	check(BARA.action_for(actor) == null and not actor.get_meta("is_casting", false), "Z restaura mão e controle")
	for slot in ["X", "C", "V"]:
		await reset()
		request(slot)
		await create_timer(float(BARA.DURATIONS[slot]) + 0.2).timeout
		var expected: float = {"X": 176.0, "C": 240.0, "V": 576.0}[slot]
		check(is_equal_approx(2048.0 - dummy.health, expected), "%s: dano %.0f, observado %.0f" % [slot, expected, 2048.0 - dummy.health])
		check(BARA.action_for(actor) == null and get_nodes_in_group("hitbox").is_empty(), slot + ": partes e zonas liberadas")
	await reset()
	var wall := box(HOME + Vector3(0, 0, -2.5), Vector3(5, 5, 0.4))
	await physics_frame
	for slot in ["Z", "X", "C", "V"]:
		await reset()
		request(slot)
		await create_timer(float(BARA.DURATIONS[slot]) + 0.2).timeout
		check(is_equal_approx(dummy.health, 2048.0), slot + ": cobertura impede dano atrás da parede")
	wall.queue_free()
	await process_frame
	await reset()
	# C atinge outro alvo perto da explosão, sem exigir contato da bala.
	# A própria fixture real é reposicionada lateralmente: a bala expira no solo.
	dummy.global_position = HOME + Vector3(2, -0.2, -16)
	request("C", Vector3(0, -0.12, -1).normalized())
	await create_timer(2.5).timeout
	check(dummy.health < 2048.0, "C causa dano em área fora da trajetória central")
	for at in [0.10, 0.32, 0.65]:
		await reset()
		dummy.global_position = HOME + Vector3.FORWARD * 20
		request("Z")
		await create_timer(at).timeout
		var effect := BARA.action_for(actor)
		if effect != null: effect.cancel()
		dummy.global_position = HOME + Vector3.FORWARD * 2
		await create_timer(0.65).timeout
		check(dummy.health == 2048.0 and BARA.action_for(actor) == null, "cancelamento em %.2fs recolhe sem dano" % at)
	await reset()
	request("C")
	await create_timer(0.2).timeout
	actor.take_damage(10, Vector3.ZERO, Vector3.ZERO, 0.1)
	await create_timer(2.5).timeout
	check(dummy.health == 2048.0 and BARA.action_for(actor) == null, "dano na preparação impede disparo C")
	await reset()
	request("V")
	await create_timer(0.75).timeout
	actor.equip_fruit("gomu_gomu")
	var hp: float = dummy.health
	await create_timer(0.8).timeout
	check(dummy.health == hp and BARA.action_for(actor) == null, "troca de fruta encerra ataques e recolhe mãos")
	actor.equip_fruit("bara_bara")
	await reset()
	request("Z")
	await create_timer(0.3).timeout
	actor._setup_character_model("base")
	await create_timer(0.5).timeout
	check(BARA.action_for(actor) == null and not actor.has_meta("bara_binding"), "troca do rig encerra ação e libera binding anterior")
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		await reset()
		request("V")
		await create_timer(3.4).timeout
		check(is_equal_approx(2048.0 - dummy.health, 576), "V mantém teto em %d Hz" % hz)
	Engine.physics_ticks_per_second = 60
	for slot in ["Z", "X", "C", "V"]:
		for repeat in 5:
			await reset()
			request(slot)
			await create_timer(0.08).timeout
			actor.clear_spawned_skills()
			await process_frame
		check(get_nodes_in_group("hitbox").is_empty() and BARA.action_for(actor) == null and not actor.get_meta("is_casting", false), slot + ": cinco cancelamentos voltam à base")
	print("BARA COMBAT checks=", checks, " failures=", failures)
	current_scene.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures == 0 else 1)

func reset() -> void:
	actor.clear_spawned_skills()
	await process_frame
	actor.global_position = HOME
	actor.velocity = Vector3.ZERO
	actor.net_velocity = Vector3.ZERO
	actor.health = actor.max_health
	actor.energy = actor.max_energy
	actor._fruit_cooldowns.clear()
	actor._server_cast_next_ms.clear()
	actor._fruit_damage_lock_timer = 0.0
	actor._trava_pos_fruta = 0.0
	actor.set_meta("is_casting", false)
	dummy.global_position = HOME + Vector3.FORWARD * 5
	dummy.velocity = Vector3.ZERO
	dummy.health = 2048.0
	await physics_frame

func request(slot: String, direction: Vector3 = Vector3.FORWARD) -> void:
	token += 1
	actor._do_server_cast(slot, direction, actor.global_position, 0.0, token, "fruit", "bara_bara")

func box(at: Vector3, size: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	current_scene.add_child(body)
	body.global_position = at
	return body
