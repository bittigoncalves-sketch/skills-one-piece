extends SceneTree
# ============================================================================
#  SONDA DO CANAL DE CAST — LADO CLIENTE (2 processos). É quem AGE.
#
#  Roteiro: equipa uma fruta, cola no corpo do host e conjura os 4 slots.
#  Quem conta o resultado é o processo do HOST — aqui só se registra o que foi
#  ENVIADO, para dar para comparar "pedi N, virou M".
#
#  ⚠️ Headless não captura mouse nem tecla (`MOUSE_MODE_CAPTURED` é sempre
#  falso), então nada aqui passa por `Input`: chama-se `cast_skill_slot` direto,
#  que é o mesmo ponto de entrada do input.
#
#  Rode DEPOIS do host estar no ar:
#    godot --headless --path . --script tools/dev_tests/net_cast_client_probe.gd
# ============================================================================

const RPCS_DO_CAST := ["_net_cast", "_net_play_cast", "_net_bullet_req", "_net_bullet_play"]
const FRUTA := "mera_mera"      # Hiken (Z) nasce hitbox e é barato de conjurar

var _p: Node = null
var _host: Node = null
var _t0 := 0.0
var _casts := 0

func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	var gf := get_root().get_node("GameFlow")
	print("[CLI] conectando em 127.0.0.1 ...")
	if not gf.join_room("127.0.0.1"):
		print("[CLI] ❌ join_room falhou"); quit(2); return

	var meu_id := 0
	for i in 1800:
		await process_frame
		meu_id = root.multiplayer.get_unique_id()
		_p = _corpo(str(meu_id))
		if _p != null:
			break
	if _p == null:
		print("[CLI] ❌ meu corpo nunca apareceu (id=%d)" % meu_id); quit(3); return
	for i in 600:
		await process_frame
		_host = _corpo("1")
		if _host != null:
			break
	if _host == null:
		print("[CLI] ❌ nao achei o corpo do host — sem alvo nao da pra medir dano")
		quit(3); return
	print("[CLI] meu corpo='%s' (peer %d)  |  corpo do host='%s'" % [_p.name, meu_id, _host.name])

	# `_do_server_cast` exige a fruta certa NA CÓPIA DO SERVIDOR, e lá o
	# `current_fruit_id` só chega pelo MultiplayerSynchronizer. Sem esperar essa
	# replicação o servidor recusa em silêncio — falha que 1 processo nunca mostra.
	_p.combat_mode = "fruit"
	_p.equip_fruit(FRUTA)
	await _esperar(2.5)
	print("[CLI][t=%6.2f] fruta='%s' combat_mode='%s'" % [_t(), _p.current_fruit_id, _p.combat_mode])

	print("\n[CLI] ===== os RPCs do cast estao configurados? =====")
	var cfg = _p.get_script().get_rpc_config()
	for nome in RPCS_DO_CAST:
		var modo := "<sem config>"
		if cfg is Dictionary and cfg.has(nome):
			var c: Dictionary = cfg[nome]
			modo = "rpc_mode=%s call_local=%s" % [str(c.get("rpc_mode", "?")), str(c.get("call_local", "?"))]
		print("   %-20s has_method=%s  %s" % [nome, _p.has_method(nome), modo])

	# Cola no host e olha pra ele: golpe que erra nao prova nada sobre a rede.
	_p.global_position = _host.global_position + Vector3(0, 0, 3.0)
	_p._yaw = 0.0
	_p._pitch = 0.0
	await _esperar(0.5)
	print("[CLI] eu=%s  alvo=%s  dist=%.2f m" % [
		str(_p.global_position), str(_host.global_position),
		_p.global_position.distance_to(_host.global_position)])

	print("\n[CLI] ===== conjurando os 4 slots =====")
	for slot in ["Z", "X", "C", "V"]:
		_p.energy = _p.max_energy      # energia cheia: o teste e de REDE, nao de custo
		_p.cast_skill_slot(slot)
		_casts += 1
		print("   [t=%6.2f] cast_skill_slot('%s') enviado" % [_t(), slot])
		await _esperar(6.0)            # deixa o golpe nascer, viajar e sumir

	print("\n[CLI] ===== resumo do que EU mandei =====")
	print("   casts enviados ao servidor: %d" % _casts)
	print("   (quantos viraram DamageZone e quanto dano deram, quem diz e o HOST)")
	await _esperar(1.0)
	quit(0)

func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null

func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
