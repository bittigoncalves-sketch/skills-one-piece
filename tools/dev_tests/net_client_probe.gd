extends SceneTree
# ============================================================================
#  SONDA DE CLIENTE (2 processos) — mede, do lado do CLIENTE que ENTRA na sala:
#    - _is_authority do próprio corpo
#    - regeneração de energia
#    - encadeamento de skills (skill 1 -> skill 2)
#    - energia depois de morrer (queda no vazio)
#
#  Rodar (com o ./servidor.sh já no ar em outro terminal):
#    godot --headless --path . --script tools/dev_tests/net_client_probe.gd
# ============================================================================

var _player: Node = null

func _init() -> void:
	await process_frame
	# Num script `-s` os autoloads existem na árvore mas NÃO viram identificador
	# de compilação -> acesso por nó.
	var game_flow := get_root().get_node("GameFlow")
	print("[PROBE] conectando em 127.0.0.1 ...")
	var ok: bool = game_flow.join_room("127.0.0.1")
	print("[PROBE] join_room -> ", ok)
	if not ok:
		quit(2)
		return

	# espera o meu corpo aparecer (spawnado pelo servidor)
	var my_id := 0
	for i in 900:
		await process_frame
		my_id = root.multiplayer.get_unique_id()
		_player = _find_my_player(my_id)
		if _player != null:
			break
	if _player == null:
		print("[PROBE] ❌ meu player NUNCA apareceu (id=%d). Nós no grupo player: %s"
			% [my_id, str(get_nodes_in_group("player").map(func(n): return n.name))])
		quit(3)
		return

	print("\n===== (a) QUEM A HUD ENXERGA =====")
	var todos := get_nodes_in_group("player")
	for p in todos:
		print("   grupo[%d] = '%s'  auth=%s  authority_id=%d  fruit='%s' energy=%.0f"
			% [todos.find(p), p.name, p._is_authority, p.get_multiplayer_authority(),
				p.current_fruit_id, p.energy])
	var primeiro := get_first_node_in_group("player")
	print("   get_first_node_in_group('player') -> '%s'  (o MEU é '%s')"
		% [primeiro.name if primeiro else "<null>", str(my_id)])
	print("   get_first_node_in_group('player') (o jeito ANTIGO) -> '%s'" % primeiro.name)
	var alvo_hud = load("res://Player.gd").local_player(self)
	print("   Player.local_player() (o jeito NOVO, usado pela HUD) -> '%s'"
		% (alvo_hud.name if alvo_hud else "<null>"))
	print("   >>> A HUD está no MEU corpo? ",
		"SIM" if alvo_hud == _player else "NÃO — CORPO ERRADO")

	print("\n===== (b) AUTORIDADE =====")
	print("  peer id do cliente ............ ", my_id)
	print("  nome do nó .................... ", _player.name)
	print("  get_multiplayer_authority() ... ", _player.get_multiplayer_authority())
	print("  is_multiplayer_authority() .... ", _player.is_multiplayer_authority())
	print("  _is_authority (capturado) ..... ", _player._is_authority)
	var sync := _player.get_node_or_null("Sync")
	if sync:
		print("  Sync.authority ................ ", sync.get_multiplayer_authority())

	await _medir_energia("(1) REGEN INICIAL")

	print("\n===== (2) ENCADEAR SKILLS =====")
	_player.equip_fruit("gomu_gomu")
	await _dump("antes da skill 1")
	print("  -> begin_charge('X')")
	_player.begin_charge("X")
	await _esperar(0.15)
	print("  -> release_charge('X')")
	_player.release_charge("X")
	await _esperar(0.6)
	await _dump("depois da skill 1")

	print("  -> begin_charge('C')")
	_player.begin_charge("C")
	await _esperar(0.15)
	print("  -> release_charge('C')")
	_player.release_charge("C")
	await _esperar(0.6)
	await _dump("depois da skill 2")

	print("  -> begin_charge('V')")
	_player.begin_charge("V")
	await _esperar(0.15)
	_player.release_charge("V")
	await _esperar(1.0)
	await _dump("depois da skill 3")

	print("\n===== (2b) TECLADO DE VERDADE PELA HUD =====")
	# Empurra a tecla pelo Viewport: passa por Hud._unhandled_input igual ao jogo.
	for slot in ["X", "C"]:
		_player._skill_cooldowns[slot] = 0.0     # zera p/ o teste não bater na recarga
		var antes: float = _player._skill_cooldowns[slot]
		_tecla(slot, true)
		await _esperar(0.15)
		_tecla(slot, false)
		await _esperar(0.6)
		var depois: float = _player._skill_cooldowns[slot]
		print("  tecla %s -> cooldown do MEU corpo: %.2f -> %.2f  => %s" % [
			slot, antes, depois, "SKILL SAIU" if depois > 0.5 else "SKILL NÃO SAIU"])

	await _medir_energia("(3) REGEN DEPOIS DAS SKILLS")

	print("\n===== (4) MORTE (queda no vazio) =====")
	_player.energy = 500.0
	_player.global_position = Vector3(0, -80, 0)
	print("  teleportado p/ y=-80, energy forçada p/ 500")
	for i in 12:
		await _esperar(0.25)
		print("    t=%.2fs y=%.1f energy=%.0f hp=%.0f" % [
			(i + 1) * 0.25, _player.global_position.y, _player.energy, _player.health])
	await _dump("depois da morte")
	await _medir_energia("(5) REGEN DEPOIS DA MORTE")

	print("\n===== fim =====")
	quit(0)

func _tecla(letra: String, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = int(letra.unicode_at(0))
	ev.physical_keycode = ev.keycode
	ev.pressed = pressionada
	root.push_unhandled_input(ev)

func _find_my_player(my_id: int) -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name).to_int() == my_id:
			return p
	return null

func _esperar(secs: float) -> void:
	# TEMPO REAL: em headless os process_frame correm bem mais rápido que 1/60,
	# então contar quadros mede errado (a 1ª rodada desta sonda caiu nessa).
	var fim := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame

func _medir_energia(titulo: String) -> void:
	print("\n===== %s =====" % titulo)
	var e0: float = _player.energy
	print("  energy inicial = %.1f / %.1f" % [e0, _player.max_energy])
	if e0 >= _player.max_energy:
		_player.energy = _player.max_energy * 0.25
		print("  (estava cheia; forcei p/ 25%% = %.1f)" % _player.energy)
		e0 = _player.energy
	for i in 4:
		await _esperar(0.5)
		print("    t=%.1fs energy=%.1f" % [(i + 1) * 0.5, _player.energy])
	var delta: float = _player.energy - e0
	print("  DELTA em 2s = %+.1f  (esperado ~ +%.0f)" % [delta, _player.ENERGY_REGEN * 2.0])
	print("  REGENEROU? ", "SIM" if delta > 1.0 else "NÃO")

func _dump(rotulo: String) -> void:
	await process_frame
	print("  [%s] energy=%.0f _charging=%s _charge_slot='%s' _rapid_fire=%s "
		% [rotulo, _player.energy, _player._charging, _player._charge_slot, _player._rapid_fire]
		+ "fsm=%s suppressed=%s is_casting=%s cds=%s frozen=%s vortex=%s kurouzu=%s bh=%s"
		% [_estado_fsm(), _player.is_suppressed,
			_player.get_meta("is_casting", false), str(_player._skill_cooldowns),
			_player.get_meta("is_frozen", false), _player.get_meta("in_vortex", false),
			_player.get_meta("in_kurouzu", false), _player.get_meta("in_black_hole", false)])

# A trava de movimento virou estado da FSM; LER o `_movement_locked_timer`
# aposentado era um `get` inválido, e o erro matava esta corrotina de log — a
# sonda parava de imprimir no meio. Ver docs/erros.md, 2026-08-25.
func _estado_fsm() -> String:
	if _player and _player.get("_fsm") and _player._fsm.state:
		return String(_player._fsm.state.name)
	return "?"
