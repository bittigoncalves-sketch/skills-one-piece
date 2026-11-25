extends SceneTree
## Combo do Boss contra o jogador com física real dos dois: ataca encostado,
## jabs 1-3 sem empurrão, 4º soco arremessa (voa, cai deitado, levanta) sem input
## e sem corte emendado; flash de dano (trama vermelha piscando) no jogador e no Boss.
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
	player.health = 99999.0
	var moves: Array[BossAbility] = boss.definition.moves()
	for m in moves:
		print("MOVE ", m.id, " kb=", m.knockback, " launch=", m.launch_horizontal, "/", m.launch_vertical)
	ok(moves.all(func(m): return m.knockback == 0.0), "nenhum golpe do combo tem knockback")
	ok(moves.slice(0, 3).all(func(m): return not m.launches()) and moves[3].launches() and moves.back() is BossDetachedAbility and moves.back().launches(),
		"arremessam só o punho destacado (5º) e o 4º soco quando o punho não emenda")
	ok(boss.definition.slash.knockback > 0.0, "corte mantém o knockback")

	# ---- encostado de frente: o Boss ataca (antes ficava parado a 1,29 m)
	await place(1.4)
	var started := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500 and not started:
		await physics_frame
		started = boss.combat.busy()
	ok(started, "jogador parado de frente a 1,4 m recebe ataque")

	# ---- na diagonal a ~1,58 m (medido em jogo: os socos passavam ao lado)
	await place(1.2)
	boss.global_position = Vector3(1.03, 1.12, 0)
	boss.combat.detached.cooldown = 30.0
	var diagonal_hp: float = player.health
	var diagonal_launch := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not diagonal_launch:
		await physics_frame
		diagonal_launch = player.esta_arremessado()
	print("DIAGONAL dano=", diagonal_hp - player.health, " arremessado=", diagonal_launch)
	ok(diagonal_launch and is_equal_approx(diagonal_hp - player.health, 288.0), "na diagonal os quatro socos acertam e o 4º arremessa (passo à frente)")
	while player.esta_arremessado() or boss.combat.busy():
		await physics_frame

	# ---- combo com física real: punho disponível (5 golpes) e em recarga (4)
	for detached_ready in [true, false]:
		await combo_case(detached_ready)

	# ---- flash de dano: curva e ciclo de vida da sobreposição
	var peaks := 0
	var previous := 0.0
	var rising := true
	for i in range(1, 201):
		var value := FxUtil.flash_dano_intensidade(i / 200.0)
		if rising and value < previous:
			peaks += 1
			rising = false
		elif value > previous:
			rising = true
		previous = value
	ok(peaks == FxUtil.FLASH_DANO_PISCADAS and FxUtil.flash_dano_intensidade(1.0) < 0.001, "flash pisca 3 vezes e termina apagado")
	boss.set_physics_process(false)
	await wait(0.8)
	var boss_meshes := meshes(boss.presentation.model)
	var player_meshes := meshes(player._char_model)
	var hit := DamageZone.new()
	current_scene.add_child(hit)
	hit.setup(5, 0, Vector3.ZERO, 1, player, 0.3)
	hit.monitoring = false
	hit._on_body(boss)
	boss._physics_process(0.016)
	var boss_mat = boss.presentation.model.get_meta("_flash_dano_mat") if boss.presentation.model.has_meta("_flash_dano_mat") else null
	ok(boss_mat != null and boss_meshes.all(func(m): return m.material_overlay == boss_mat), "Boss recebe a trama vermelha em todas as malhas")
	player.take_damage(5.0, boss.global_position, Vector3.ZERO, 0.1)
	var player_mat = player._char_model.get_meta("_flash_dano_mat") if player._char_model.has_meta("_flash_dano_mat") else null
	ok(player_mat != null and player_meshes.all(func(m): return m.material_overlay == player_mat), "jogador recebe a trama vermelha em todas as malhas")
	await wait(0.3)
	player.take_damage(5.0, boss.global_position, Vector3.ZERO, 0.1)
	await wait(0.35)
	ok(player_meshes.all(func(m): return m.material_overlay == player_mat), "golpe durante a piscada reinicia o ciclo")
	await wait(0.4)
	ok(player_meshes.all(func(m): return m.material_overlay == null) and boss_meshes.all(func(m): return m.material_overlay == null), "flash some e devolve o material original")
	if is_instance_valid(hit):
		hit.queue_free()

	# ---- respawn cancela a derrubada
	player.receber_arremesso(Vector3(0, 6, 8))
	await wait(0.2)
	player.net_force_respawn()
	await physics_frame
	ok(not player.esta_arremessado() and absf(player._char_model.rotation.x) < 0.001, "respawn cancela a derrubada")
	print("BOSS ARREMESSO JOGADOR: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

## Um combo inteiro com física real até o jogador levantar.
func combo_case(detached_ready: bool) -> void:
	var label := "punho disponível" if detached_ready else "punho em recarga"
	await place(1.2)
	boss.combat.slash_cooldown_remaining = 0.0
	boss.combat.detached.reset()
	boss.combat.detached.cooldown = 0.0 if detached_ready else 30.0
	var hp: float = player.health
	var anchor: Vector3 = player.global_position
	var drift := 0.0
	var index_before_launch := -1
	var launched := false
	var launched_by := ""
	var saw_slash := false
	var phases: Array[String] = []
	var lying_pitch := 0.0
	var blocked_input := true
	var blocked_cast := true
	var peak: float = player.global_position.y
	var flash_seen := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000:
		await physics_frame
		if not launched:
			drift = maxf(drift, flat(player.global_position - anchor))
			index_before_launch = maxi(index_before_launch, boss.combo_index)
		if player.esta_arremessado():
			if not launched:
				launched_by = boss.action_id
			launched = true
			var fase: String = player._arremesso.fase
			if phases.is_empty() or phases.back() != fase:
				phases.append(fase)
			peak = maxf(peak, player.global_position.y)
			if fase == PlayerArremesso.KNOCKDOWN and player._arremesso.tempo > 0.5:
				lying_pitch = maxf(lying_pitch, player._char_model.rotation.x)
			player._input_buffer.append({"action": "attack", "time": Time.get_ticks_msec()})
			blocked_input = blocked_input and not player._consume_input("attack")
			player.begin_charge("Z")
			blocked_cast = blocked_cast and not bool(player.get_meta("is_casting", false))
		elif launched:
			break
		saw_slash = saw_slash or boss.action_id == str(boss.definition.slash.id)
		flash_seen = flash_seen or player._char_model.has_meta("_flash_dano_mat")
	var travel: float = flat(player.global_position - anchor)
	var expected_damage := 72.0 * 4 + (112.0 if detached_ready else 0.0)
	print("COMBO[", label, "] drift=", drift, " indice=", index_before_launch, " por=", launched_by, " dano=", hp - player.health, " fases=", phases, " distancia=", travel, " pico=", peak - anchor.y, " deitado=", lying_pitch)
	ok(drift < 0.15, "%s: golpes antes do arremesso não empurram (%.2f m)" % [label, drift])
	ok(is_equal_approx(hp - player.health, expected_damage), "%s: todos os golpes acertam (%.0f)" % [label, expected_damage])
	ok(launched_by == ("detached_fist" if detached_ready else "jab_finish"), "%s: quem arremessa é o último golpe (%s)" % [label, launched_by])
	ok(launched and phases == [PlayerArremesso.LAUNCHED, PlayerArremesso.KNOCKDOWN, PlayerArremesso.GETUP], "%s: voa, cai deitado, levanta" % label)
	ok(travel > 6.0, "%s: arremessado para longe (%.1f m)" % [label, travel])
	ok(peak - anchor.y > 0.8, "%s: voo sobe (%.2f m)" % [label, peak - anchor.y])
	ok(lying_pitch > 1.3, "%s: deitado de costas no chão (%.2f rad)" % [label, lying_pitch])
	ok(blocked_input and blocked_cast, "%s: sem ataque nem habilidade durante a derrubada" % label)
	ok(not saw_slash, "%s: Boss não emenda o corte no jogador arremessado" % label)
	for i in 20:
		await physics_frame
	ok(absf(player._char_model.rotation.x) < 0.01 and player.velocity.length() < 0.5, "%s: volta de pé e parado" % label)
	ok(flash_seen, "%s: jogador recebe o flash de dano" % label)
	while boss.combat.busy() or boss.part_state != "attached":
		await physics_frame

func place(distance: float) -> void:
	boss.combat.cancel("fixture")
	boss.combat.cooldown_remaining = 0
	boss.reaction = ""
	boss.controller.stun_remaining = 0
	boss.controller.brain.target = null
	boss.velocity = Vector3.ZERO
	boss.global_position = Vector3(0, 1.12, 0)
	boss.home_position = boss.global_position
	boss.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.8, -distance)
	for i in 4:
		await physics_frame

func meshes(root_node: Node) -> Array:
	var found: Array = []
	FxUtil._collect_meshes(root_node, found)
	return found

func flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
