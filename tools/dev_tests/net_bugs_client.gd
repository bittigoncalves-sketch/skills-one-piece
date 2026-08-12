extends SceneTree
## Cliente: mede knockback recebido, fruta apos a morte, e cooldown congelado.
func _init() -> void:
	await process_frame
	var gf := get_root().get_node("GameFlow")
	gf.join_room("127.0.0.1")
	var t0 := Time.get_ticks_msec()
	var me: Node = null
	while Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		me = get_root().get_node("Player").local_player(get_root().get_tree()) if false else _meu()
		if me: break
	if me == null: print("❌ nao achei meu corpo"); quit(1); return
	print("[CLIENTE] meu corpo=%s autoridade=%s" % [me.name, me.is_multiplayer_authority()])
	await _esperar(1.5)

	print("\n===== KNOCKBACK (servidor manda empurrao no cliente) =====")
	var antes: Vector3 = me.global_position
	me.velocity = Vector3.ZERO
	me.take_damage(10.0, me.global_position + Vector3(0,0,3), Vector3(0, 6, -40))
	await _esperar(0.8)
	var d: float = antes.distance_to(me.global_position)
	print("  deslocou %.2f m  -> %s" % [d, "EMPURROU ✅" if d > 0.5 else "NAO EMPURROU ❌"])

	print("\n===== FRUTA depois da MORTE =====")
	me.equip_fruit("mera_mera")
	await _esperar(0.4)
	print("  antes da morte: '%s'" % me.current_fruit_id)
	me.global_position = Vector3(0, -80, 0)
	await _esperar(3.0)
	print("  depois da morte: '%s'  (esperado: vazio — larga a fruta)" % me.current_fruit_id)

	print("\n===== COOLDOWN congelado durante habilidade =====")
	me.equip_fruit("gomu_gomu"); await _esperar(0.3)
	me._skill_cooldowns["X"] = 9.0
	me._cast._carregando = true; me._cast._slot = "Z"   # vistas sem setter (6c)
	me.set_meta("is_casting", true)   # sem isso o proprio _physics_process destrava o _charging
	var x0: float = me._skill_cooldowns["X"]
	await _esperar(1.2)
	var x1: float = me._skill_cooldowns["X"]
	me._cast.abortar(); me.set_meta("is_casting", false)
	await _esperar(1.2)
	var x2: float = me._skill_cooldowns["X"]
	print("  X: %.2f -> %.2f (com Z ativo)  -> %.2f (Z solto)" % [x0, x1, x2])
	print("  congelou durante? %s | voltou a correr? %s" % [
		"SIM ✅" if abs(x1-x0) < 0.15 else "NAO ❌", "SIM ✅" if (x1-x2) > 0.5 else "NAO ❌"])
	quit()

func _meu() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority(): return p
	return null

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s*1000.0): await process_frame
