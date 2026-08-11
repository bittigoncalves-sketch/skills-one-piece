extends SceneTree
# ============================================================================
#  SONDA DE FRUTA — LADO CLIENTE (2 processos).
#  (1) mede o fallback mudo: equipa uma fruta do POOL DE SPAWN que o SkillSystem
#      não conhece e mostra em que fruta o `_fire_skill` cai;
#  (2) mata o cliente (queda no vazio) e mede `current_fruit_id` dos DOIS corpos
#      antes e depois, dentro do processo do CLIENTE.
#
#    godot --headless --path . --script tools/dev_tests/net_fruit_client_probe.gd
# ============================================================================

const FRUTA_DO_CLIENTE := "ope_ope"     # está no pool de árvores, NÃO está no SkillSystem

var _player: Node = null
var _t0: float = 0.0

func _init() -> void:
	await process_frame
	_t0 = Time.get_unix_time_from_system()
	var game_flow := get_root().get_node("GameFlow")
	var ok: bool = game_flow.join_room("127.0.0.1")
	print("[CLI] join_room -> ", ok)
	if not ok:
		quit(2)
		return

	var my_id := 0
	for i in 1800:
		await process_frame
		my_id = root.multiplayer.get_unique_id()
		_player = _find_my_player(my_id)
		if _player != null:
			break
	if _player == null:
		print("[CLI] ❌ meu corpo nunca apareceu (id=%d)" % my_id)
		quit(3)
		return
	print("[CLI] meu corpo = '%s' (peer %d)" % [_player.name, my_id])

	# ---------------------------------------------------------- POOL vs SKILLS
	print("\n[CLI] ===== POOL DE SPAWN x SKILLS =====")
	var conhecidas: Dictionary = SkillSystem.get_fruit_skills()
	# O `TreeAndFruitGenerator` referencia o autoload `FruitNet`, que NÃO compila
	# num script `-s` — então o pool é lido da ÁRVORE DE VERDADE (nós Fruit3D_<id>),
	# que é o que de fato nasce no mapa.
	var pool: Array = []
	_coletar_frutas(root, pool)
	var sem_skill: Array = []
	for fid in pool:
		if not conhecidas.has(fid):
			sem_skill.append(fid)
	print("[CLI] pool de arvores (%d): %s" % [pool.size(), str(pool)])
	print("[CLI] SkillSystem (%d): %s" % [conhecidas.size(), str(conhecidas.keys())])
	print("[CLI] CAEM NO FALLBACK (%d/%d): %s" % [sem_skill.size(), pool.size(), str(sem_skill)])

	await _esperar(1.5)
	_snapshot("estado inicial")

	# ------------------------------------------------------------ BUG 1
	print("\n[CLI] ===== BUG 1: equipar '%s' =====" % FRUTA_DO_CLIENTE)
	_player.equip_fruit(FRUTA_DO_CLIENTE)
	await _esperar(0.5)
	_snapshot("apos equipar")
	print("[CLI] current_fruit_id = '%s' | _fire_skill resolveria '%s'" % [
		_player.current_fruit_id, _resolver(_player.current_fruit_id)])

	# ------------------------------------------------------------ BUG 2
	print("\n[CLI] ===== BUG 2: morte do CLIENTE =====")
	_snapshot("ANTES DA MORTE")
	_player.global_position = Vector3(0, -80, 0)
	print("[CLI] teleportado p/ y=-80")
	for i in 20:
		await _esperar(0.4)
		_snapshot("t=%.1fs y=%.0f" % [(i + 1) * 0.4, _player.global_position.y])
	_snapshot("DEPOIS DA MORTE")
	print("[CLI] meu current_fruit_id='%s' -> _fire_skill resolveria '%s'" % [
		_player.current_fruit_id, _resolver(_player.current_fruit_id)])

	await _esperar(3.0)
	_snapshot("FIM")
	print("\n[CLI] ===== fim =====")
	quit(0)

func _coletar_frutas(n: Node, fora: Array) -> void:
	if String(n.name).begins_with("Fruit3D_"):
		var fid := String(n.name).substr(8)
		if not fora.has(fid):
			fora.append(fid)
	for c in n.get_children():
		_coletar_frutas(c, fora)

func _resolver(fid: String) -> String:
	return fid if SkillSystem.get_fruit_skills().has(fid) else "gomu_gomu(FALLBACK)"

func _snapshot(rotulo: String) -> void:
	var linhas: Array[String] = []
	for p in get_nodes_in_group("player"):
		linhas.append("'%s'{auth=%s fruit='%s' -> %s}" % [
			p.name, p.is_multiplayer_authority(), p.current_fruit_id,
			_resolver(p.current_fruit_id)])
	print("[CLI][t=%+.2f] %-18s %s" % [
		Time.get_unix_time_from_system() - _t0, rotulo, " | ".join(linhas)])

func _find_my_player(my_id: int) -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name).to_int() == my_id:
			return p
	return null

func _esperar(secs: float) -> void:
	var fim := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
