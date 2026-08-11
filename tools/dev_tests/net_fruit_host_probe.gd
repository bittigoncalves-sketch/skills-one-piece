extends SceneTree
# ============================================================================
#  SONDA DE FRUTA — LADO HOST (2 processos).
#  Sobe a sala, espera o cliente entrar, equipa uma fruta DIFERENTE da do cliente
#  e fica publicando `current_fruit_id` dos DOIS corpos, com carimbo de tempo.
#
#    godot --headless --path . --script tools/dev_tests/net_fruit_host_probe.gd
# ============================================================================

const FRUTA_DO_HOST := "mera_mera"

var _player: Node = null
var _t0: float = 0.0

func _init() -> void:
	await process_frame
	_t0 = Time.get_unix_time_from_system()
	var game_flow := get_root().get_node("GameFlow")
	game_flow.create_room()
	print("[HOST] sala criada")
	for i in 600:
		await process_frame
		_player = _meu_corpo()
		if _player != null:
			break
	if _player == null:
		print("[HOST] ❌ meu corpo nunca apareceu")
		quit(3)
		return
	print("[HOST] meu corpo = '%s'" % _player.name)

	# espera o cliente entrar (2 corpos no grupo)
	for i in 3000:
		await process_frame
		if get_nodes_in_group("player").size() >= 2:
			break
	print("[HOST] jogadores na arvore: %d" % get_nodes_in_group("player").size())

	_player.equip_fruit(FRUTA_DO_HOST)
	print("[HOST] equipei '%s' no MEU corpo" % FRUTA_DO_HOST)
	_snapshot("apos equipar")

	var fim := Time.get_ticks_msec() + 60000
	var prox := 0
	while Time.get_ticks_msec() < fim:
		await process_frame
		if Time.get_ticks_msec() >= prox:
			prox = Time.get_ticks_msec() + 500
			_snapshot("tick")
	quit(0)

func _meu_corpo() -> Node:
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null

func _snapshot(rotulo: String) -> void:
	var linhas: Array[String] = []
	for p in get_nodes_in_group("player"):
		var fid: String = p.current_fruit_id
		var conhecida: bool = SkillSystem.get_fruit_skills().has(fid)
		var resolvida: String = fid if conhecida else "gomu_gomu(FALLBACK)"
		linhas.append("'%s'{auth=%s fruit='%s' -> %s}" % [
			p.name, p.is_multiplayer_authority(), fid, resolvida])
	print("[HOST][t=%+.2f] %-16s %s" % [
		Time.get_unix_time_from_system() - _t0, rotulo, " | ".join(linhas)])
