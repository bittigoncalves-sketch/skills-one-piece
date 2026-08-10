extends SceneTree
# Prova, quadro a quadro, POR QUE a 2ª skill some: o temporizador de 0.3 s do
# _fire_skill da skill ANTERIOR limpa `is_casting`, e o bloco do _physics_process
# (Player.gd:446) lê isso como "cast interrompido" e zera `_charging` da skill NOVA.
#   godot --headless --path . --script tools/dev_tests/probe_cast_chain.gd

var _p: Node = null

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	for i in 300:
		await process_frame
		_p = get_first_node_in_group("player")
		if _p != null:
			break
	_p.equip_fruit("gomu_gomu")
	await _esperar(0.5)

	print("\n===== SKILL 1 (X) =====")
	_p.begin_charge("X")
	await _esperar(0.10)
	_p.release_charge("X")
	print("  release X feito. is_casting=%s _charging=%s" % [
		_p.get_meta("is_casting", false), _p._charging])

	# Encadeia a 2ª skill DENTRO da janela de 0.3 s do temporizador da 1ª.
	await _esperar(0.10)
	print("\n===== SKILL 2 (C), 0.10 s depois =====")
	_p.begin_charge("C")
	print("  logo apos begin_charge: _charging=%s is_casting=%s" % [
		_p._charging, _p.get_meta("is_casting", false)])
	# Segura a tecla por 0.5 s REAIS — mais que os 0.3 s do temporizador da skill 1.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 500:
		await process_frame
		if not _p._charging:
			print("   >>> _charging FOI ZERADO em %d ms (Player.gd:447), is_casting=%s"
				% [Time.get_ticks_msec() - t0, _p.get_meta("is_casting", false)])
			break
	print("  fim do hold: _charging=%s is_casting=%s" % [
		_p._charging, _p.get_meta("is_casting", false)])
	_p.release_charge("C")
	await _esperar(0.4)
	print("  cooldown de C depois do release = %.2f  (0.00 = A SKILL NAO SAIU)"
		% _p._skill_cooldowns["C"])
	quit(0)

func _esperar(secs: float) -> void:
	# TEMPO REAL: em headless os process_frame correm muito mais rápido que 1/60,
	# então contar quadros mediria errado (foi assim que a 1ª medição enganou).
	var fim := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
