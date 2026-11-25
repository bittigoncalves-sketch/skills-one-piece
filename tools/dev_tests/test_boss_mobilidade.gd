extends SceneTree
## Área de detecção de projéteis, dash de esquiva e pulo duplo do Boss, com física
## real: desvia de projétil, pula o rasteiro com o dash em recarga, respeita parede e
## buraco, não esquiva no próprio golpe, sobe em bloco e cruza buraco de 10 m.
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
	await create_timer(1.5).timeout
	boss = get_first_node_in_group("boss")
	player = get_first_node_in_group("player")
	ok(boss != null and player != null, "Boss e jogador presentes")
	if boss == null or player == null:
		quit(1)
		return
	player.set_physics_process(false)
	player.health = 99999.0
	var mobility: BossMobility = boss.controller.mobility

	# ---- área de detecção (Boss sem simular: aqui só se mede o sensor, sem reagir)
	var spot := Vector3(-30, 1.12, -30)
	await idle_at(spot)
	boss.set_physics_process(false)
	var incoming := projectile(boss.global_position + Vector3(-8, 0, 0), Vector3(30, 0, 0), player, 0.0)
	var away := projectile(boss.global_position + Vector3(-8, 0, 1), Vector3(-30, 0, 0), player, 0.0)
	var parked := projectile(boss.global_position + Vector3(-5, 0, 0), Vector3.ZERO, player, 0.0)
	var own := projectile(boss.global_position + Vector3(-8, 0, -1), Vector3(30, 0, 0), boss, 0.0)
	await physics_frame
	await physics_frame
	var threat: Dictionary = boss.sensor.most_urgent()
	ok(not threat.is_empty() and threat.node == incoming, "detecta projétil do jogador vindo na direção do Boss")
	var others := 0
	for zone in [away, parked, own]:
		var p: Dictionary = {"position": zone.global_position, "velocity": zone.vel}
		if not BossProjectileSensor.evaluate(boss, p.position, p.velocity, 0.4).is_empty() and zone != own:
			others += 1
	ok(others == 0 and boss.sensor._candidates().filter(func(c): return c.node == own).is_empty(), "ignora projétil que se afasta, hitbox parada e ataque do próprio Boss")
	for zone in [incoming, away, parked, own]:
		zone.queue_free()
	var wave := YoruWave.new()
	current_scene.add_child(wave)
	wave.global_position = boss.global_position + Vector3(-9, 0, 0)
	wave.setup(player, "Z", Vector3.RIGHT, {"damage": 0.0, "speed": 22.0, "range": 16.0, "width": 1.5})
	wave.set_physics_process(false)
	await physics_frame
	ok(boss.sensor._candidates().any(func(c): return c.node == wave), "onda da Yoru entra na área de detecção pelo adaptador")
	wave.queue_free()
	await physics_frame
	await physics_frame
	boss.set_physics_process(true)

	# ---- dash de esquiva
	await idle_at(spot)
	var hp: float = boss.health
	var start: Vector3 = boss.global_position
	var shot := projectile(boss.global_position + Vector3(-9, 0.2, 0), Vector3(30, 0, 0), player, 50.0)
	# Deslocamento MÁXIMO: sem alvo, depois do dash o Boss volta andando para casa.
	var saw_dash: bool = await watch(0.9, BossMobility.DASH, start)
	var moved: Vector3 = _extreme
	print("DASH moveu=", moved, " vida=", hp - boss.health)
	ok(saw_dash and boss.health == hp, "projétil do jogador: Boss usa o dash e não é atingido")
	ok(absf(moved.z) >= 3.0 and absf(moved.x) < 1.0, "dash sai de lado, perpendicular ao voo (%.2f m)" % absf(moved.z))
	ok(mobility.dash_cooldown > 2.0, "dash entra em recarga de 3 s")
	free_if(shot)

	# ---- com o dash em recarga: projétil rasteiro → pulo duplo
	hp = boss.health
	var feet_y: float = boss.global_position.y - boss.definition.height * 0.5
	var low := projectile(Vector3(boss.global_position.x - 9, feet_y + 0.5, boss.global_position.z), Vector3(30, 0, 0), player, 50.0)
	var peak: float = boss.global_position.y
	var max_jumps := 0
	var until := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until:
		await physics_frame
		peak = maxf(peak, boss.global_position.y)
		max_jumps = maxi(max_jumps, boss.jumps_used)
	print("PULO pico=", peak - (feet_y + boss.definition.height * 0.5), " pulos=", max_jumps, " vida=", hp - boss.health)
	ok(max_jumps == 2 and boss.health == hp, "dash em recarga: pula (pulo duplo) por cima do projétil rasteiro")
	ok(boss.is_on_floor() and boss.jumps_used == 0 and boss.mobility == "", "pousa e recupera os dois pulos")
	free_if(low)

	# ---- dash gasto: projétil na altura do peito acerta (dá para enganar a esquiva)
	await idle_at(spot, false)
	mobility.dash_cooldown = 2.5
	hp = boss.health
	var chest := projectile(boss.global_position + Vector3(-9, 0.4, 0), Vector3(30, 0, 0), player, 50.0)
	await create_timer(0.8).timeout
	ok(boss.health < hp and boss.mobility == "", "com o dash em recarga, projétil alto acerta")
	free_if(chest)

	# ---- projétil REAL do jogo: flecha de gelo (55 m/s, a mais rápida)
	await idle_at(spot)
	hp = boss.health
	start = boss.global_position
	IceFX.bullet(current_scene, boss.global_position + Vector3(-10, 0.2, 0), Vector3.RIGHT, 60.0, player)
	var dodged_arrow: bool = await watch(0.8, BossMobility.DASH, start)
	print("FLECHA desviou=", dodged_arrow, " moveu=", _extreme, " vida=", hp - boss.health)
	ok(dodged_arrow and boss.health == hp, "flecha de gelo real (55 m/s): Boss desvia com o dash")

	# ---- não esquiva no meio do próprio golpe
	await idle_at(spot)
	player.global_position = boss.global_position + Vector3(0, -0.3, -1.2)
	boss.rotation = Vector3.ZERO
	await physics_frame
	boss.combat.cooldown_remaining = 0
	boss.combat.begin(player)
	var during := projectile(boss.global_position + Vector3(-6, 0.2, 0), Vector3(30, 0, 0), player, 1.0)
	var dashed_mid_attack := false
	until = Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < until:
		await physics_frame
		dashed_mid_attack = dashed_mid_attack or boss.mobility != ""
	ok(not dashed_mid_attack, "não usa o dash no meio do próprio golpe")
	free_if(during)
	player.global_position = Vector3(60, 0.8, 60)

	# ---- lado seguro: parede de um lado, esquiva para o outro
	await idle_at(spot)
	var wall := block(boss.global_position + Vector3(0, 0.9, 2.2), Vector3(6, 3, 0.4))
	await physics_frame
	start = boss.global_position
	shot = projectile(boss.global_position + Vector3(-9, 0.2, 0.3), Vector3(30, 0, 0), player, 1.0)
	await watch(0.9, BossMobility.DASH, start)
	ok(_extreme.z < -2.5, "parede de um lado: esquiva para o lado livre (%.2f m)" % _extreme.z)
	free_if(shot)
	wall.queue_free()

	# ---- lado seguro: buraco de um lado
	var edge := hole_side_spot()
	ok(not edge.is_empty(), "arena tem borda de buraco para o teste")
	if not edge.is_empty():
		await idle_at(edge.point)
		start = boss.global_position
		shot = projectile(boss.global_position + Vector3(-9, 0.2, 0) , Vector3(30, 0, 0), player, 1.0)
		await watch(0.9, BossMobility.DASH, start)
		print("BURACO lado=", edge.hole_side, " moveu=", _extreme)
		ok(not boss.dead and absf(_extreme.z) > 2.5 and signf(_extreme.z) == -signf(edge.hole_side), "buraco de um lado: esquiva para o chão firme")
		free_if(shot)

	# ---- pulo duplo sobe mais que o simples
	ok(BossMobility.peak_height(boss.definition.gravity, true) > BossMobility.peak_height(boss.definition.gravity, false) + 1.2, "pulo duplo sobe mais que o simples")

	# ---- jogador no alto: sobe no bloco
	await idle_at(spot)
	var top_y := 2.0
	var ledge := block(boss.global_position + Vector3(0, top_y * 0.5 - 1.12, -3.2), Vector3(3, top_y, 3))
	await physics_frame
	player.global_position = Vector3(boss.global_position.x, top_y + 0.8, boss.global_position.z - 3.2)
	boss.controller.brain.target = player
	var climbed := false
	var used_double := false
	until = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until and not climbed:
		await physics_frame
		used_double = used_double or boss.jumps_used == 2
		climbed = boss.is_on_floor() and boss.global_position.y - boss.definition.height * 0.5 > top_y - 0.2
	print("ALTO subiu=", climbed, " duplo=", used_double, " y_pes=", boss.global_position.y - boss.definition.height * 0.5)
	ok(climbed, "jogador em cima de bloco de 2 m: Boss pula e pousa em cima")
	ok(used_double, "bloco mais alto que o pulo simples usa o pulo duplo")
	ledge.queue_free()
	player.global_position = Vector3(60, 0.8, 60)
	boss.controller.brain.target = null

	# ---- buraco de 10 m entre Boss e alvo: cruza; de 20 m: não pula
	var gaps := hole_gaps()
	ok(gaps.has("small") and gaps.has("big"), "arena tem buraco pequeno e grande alinhados para o teste")
	if gaps.has("small"):
		var g: Dictionary = gaps.small
		await idle_at(g.boss)
		player.global_position = g.player
		boss.controller.brain.target = player
		var crossed := false
		var jumped := false
		until = Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < until and not crossed and not boss.dead:
			await physics_frame
			jumped = jumped or boss.mobility == BossMobility.JUMP
			crossed = boss.is_on_floor() and (boss.global_position.x - g.far_edge) * g.sign > 0.3
		print("BURACO10 cruzou=", crossed, " pulou=", jumped, " morto=", boss.dead, " x=", boss.global_position.x)
		ok(jumped and crossed and not boss.dead, "buraco de 10 m: cruza com o pulo duplo e pousa do outro lado")
	if gaps.has("big") and not boss.dead:
		var g: Dictionary = gaps.big
		await idle_at(g.boss)
		player.global_position = g.player
		boss.controller.brain.target = player
		var jumped := false
		until = Time.get_ticks_msec() + 2500
		while Time.get_ticks_msec() < until and not boss.dead:
			await physics_frame
			jumped = jumped or boss.mobility == BossMobility.JUMP
		ok(not jumped and not boss.dead, "buraco de 20 m: não tenta o pulo")
	print("BOSS MOBILIDADE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func idle_at(point: Vector3, reset_cooldown := true) -> void:
	boss.combat.cancel("fixture")
	boss.controller.mobility.cancel(boss)
	boss.controller.brain.target = null
	boss.reaction = ""
	boss.controller.stun_remaining = 0.0
	boss.velocity = Vector3.ZERO
	boss.global_position = point
	boss.home_position = point
	boss.rotation = Vector3.ZERO
	player.global_position = Vector3(60, 0.8, 60)
	for i in 20:
		await physics_frame
	var settle := Time.get_ticks_msec() + 3000
	while (not boss.is_on_floor() or boss.mobility != "") and Time.get_ticks_msec() < settle:
		await physics_frame
	boss.home_position = boss.global_position
	# Depois da espera: sobra de etapa anterior (projétil vivo por um quadro) gasta o
	# dash ou dispara um pulo. Só libera a etapa com o Boss parado no chão.
	boss.controller.mobility.cancel(boss)
	boss.controller.stun_remaining = 0.0
	if reset_cooldown:
		boss.controller.mobility.dash_cooldown = 0.0

func projectile(at: Vector3, velocity: Vector3, caster: Node, damage: float) -> DamageZone:
	var zone := DamageZone.new()
	current_scene.add_child(zone)
	zone.global_position = at
	zone.setup(damage, 0.0, velocity, 1.5, caster, 0.4)
	return zone

func block(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	body.global_position = center
	return body

func free_if(node) -> void:
	if is_instance_valid(node):
		node.queue_free()

var _extreme := Vector3.ZERO

## Observa a janela; guarda em `_extreme` o maior afastamento horizontal de `origin`.
func watch(seconds: float, mode: String, origin: Vector3) -> bool:
	var seen := false
	_extreme = Vector3.ZERO
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		await physics_frame
		seen = seen or boss.mobility == mode
		var offset := boss.global_position - origin
		offset.y = 0.0
		if offset.length() > Vector2(_extreme.x, _extreme.z).length():
			_extreme = offset
	return seen

## Chão firme com buraco a ~4 m de um lado (em Z) e firme do outro.
func hole_side_spot() -> Dictionary:
	for x in range(-85, 86, 2):
		for z in range(-85, 86, 2):
			if MapBuilder.is_hole_area(x, z, 3, 3) or MapBuilder.is_hole_area(x - 9, z, 2, 2):
				continue
			for side in [1.0, -1.0]:
				if MapBuilder.is_hole(x, z + side * 4.0) and not MapBuilder.is_hole_area(x, z - side * 4.0, 2, 2) \
						and not MapBuilder.is_hole_area(x, z + side * 2.0, 1.2, 1.2):
					return {"point": Vector3(x, 1.12, z), "hole_side": side}
	return {}

## Buraco de 1 célula (10 m) e de 2 células (20 m) atravessados em X, com chão dos
## dois lados. Boss na borda de cá, jogador a 3 m da borda de lá.
func hole_gaps() -> Dictionary:
	var result := {}
	var cell := MapBuilder.CELL
	var half := MapBuilder.PLATFORM_SIZE * 0.5
	for gx in range(2, MapBuilder.GRID - 3):
		for gz in range(2, MapBuilder.GRID - 2):
			var cz: float = gz * cell - half + cell * 0.5
			var x0: float = gx * cell - half
			var hole1 := MapBuilder.is_hole(x0 + cell * 0.5, cz)
			if not hole1 or MapBuilder.is_hole(x0 - cell * 0.5, cz):
				continue
			var cells := 1
			if MapBuilder.is_hole(x0 + cell * 1.5, cz):
				cells = 2
			var far: float = x0 + cell * cells
			if MapBuilder.is_hole(far + cell * 0.5, cz) or MapBuilder.is_hole_area(x0 - 2.0, cz, 2, cell * 0.6) or MapBuilder.is_hole_area(far + 3.0, cz, 3, cell * 0.6):
				continue
			var key := "small" if cells == 1 else "big"
			if result.has(key):
				continue
			result[key] = {"boss": Vector3(x0 - 0.8, 1.12, cz), "player": Vector3(far + 3.0, 0.8, cz), "far_edge": far, "sign": 1.0}
	return result
