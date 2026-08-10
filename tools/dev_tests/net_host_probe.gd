extends SceneTree
# HOST com player local (igual "Criar Sala"), headless. Roda o MESMO encadeamento
# de skills que o net_client_probe faz, para separar o que é bug de cliente do que
# é bug dos dois lados. Fica no ar até o teste do cliente acabar.
#   godot --headless --path . --script tools/dev_tests/net_host_probe.gd

var _player: Node = null

func _init() -> void:
	await process_frame
	var game_flow := get_root().get_node("GameFlow")
	game_flow.create_room()
	print("[HOST] sala criada")
	for i in 300:
		await process_frame
		_player = get_first_node_in_group("player")
		if _player != null:
			break

	print("\n[HOST] ===== (a) QUEM A HUD ENXERGA =====")
	var todos := get_nodes_in_group("player")
	for p in todos:
		print("[HOST]   grupo[%d]='%s' auth=%s" % [todos.find(p), p.name, p._is_authority])
	print("[HOST]   get_first_node_in_group -> '%s' (meu id=%d) CERTO? %s" % [
		_player.name, root.multiplayer.get_unique_id(),
		"SIM" if _player.is_multiplayer_authority() else "NÃO"])

	print("\n[HOST] ===== ENCADEAR 3 SKILLS (mesmo timing do cliente) =====")
	_player.equip_fruit("gomu_gomu")
	for slot in ["X", "C", "V"]:
		print("[HOST] -> begin_charge('%s')" % slot)
		_player.begin_charge(slot)
		await _esperar(0.15)
		_player.release_charge(slot)
		await _esperar(0.6)
		print("[HOST]    depois de %s: _charging=%s cds=%s is_casting=%s" % [
			slot, _player._charging, str(_player._skill_cooldowns),
			_player.get_meta("is_casting", false)])

	# fica no ar p/ o cliente terminar o teste dele
	var t := 0.0
	while t < 300.0:
		await process_frame
		t += 1.0 / 60.0
	quit(0)

func _esperar(secs: float) -> void:
	var t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0
