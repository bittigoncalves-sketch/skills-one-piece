extends SceneTree
## Cliente de duas instâncias do ataque contextual. Deve ser iniciado depois de
## net_contextual_host_probe.gd, usando a mesma SOP_PORTA.

const RPCS := ["_net_contextual_melee", "_net_play_contextual_melee"]

var _meu: Node = null
var _host: Node = null

func _init() -> void:
	await process_frame
	var fluxo := get_root().get_node("GameFlow")
	if not fluxo.join_room("127.0.0.1"):
		print("[CTX CLI] ❌ não conectou")
		quit(2)
		return
	var meu_id := 0
	var fim := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < fim and (_meu == null or _host == null):
		meu_id = root.multiplayer.get_unique_id()
		for corpo in get_nodes_in_group("player"):
			if corpo.name == str(meu_id):
				_meu = corpo
			elif corpo.name == "1":
				_host = corpo
		await process_frame
	if _meu == null or _host == null:
		print("[CTX CLI] ❌ corpos não sincronizaram")
		quit(3)
		return
	# ⚠️ TIPADO À MÃO. `get_rpc_config()` devolve Variant, e `:=` não infere dele —
	# o script inteiro deixava de compilar, então esta sonda de rede nunca chegou
	# a rodar. É a mesma armadilha de GDScript que já mordeu meia dúzia de vezes
	# neste projeto.
	var config: Variant = _meu.get_script().get_rpc_config()
	for rpc in RPCS:
		print("[CTX CLI] %s configurado=%s" % [rpc, str(config is Dictionary and config.has(rpc))])
	# Posição e orientação chegam ao servidor pela mesma autoridade do jogador.
	# A distância deixa o host dentro da esfera frontal do golpe.
	_meu.global_position = _host.global_position + Vector3(0.0, 0.0, 2.55)
	_meu.velocity = Vector3.ZERO
	_meu._yaw = 0.0
	var espera_chao := Time.get_ticks_msec() + 4500
	while not _meu.is_on_floor() and Time.get_ticks_msec() < espera_chao:
		await process_frame
	await _esperar(0.70)
	# A cotovelada (W + clique) foi apagada em 2026-09-13; o Lançamento é a
	# variação de solo que resta e percorre o mesmo caminho de rede.
	var iniciou = _meu.iniciar_ataque_contextual("context_launcher", 0.0)
	# ⚠️ MEDIR DENTRO DA JANELA DO GOLPE: o Lançamento dura 0,53 s (0,18 startup +
	# 0,09 ativo + 0,26 recuperação). 0,18 s cai no fim do startup: pose e VFX
	# estão no ar. Medir depois do fim reprovaria a limpeza, que é o correto.
	await _esperar(0.18)
	var apresentou := String(_meu.get("_contextual_attack_id")) == "context_launcher" \
		or _meu.get_node_or_null("ContextualMeleeFX_context_launcher") != null

	# E o inverso, para a asserção não passar com uma apresentação que nunca sai:
	# depois do fim, ela TEM de ter sido limpa.
	await _esperar(0.55)
	var limpou := String(_meu.get("_contextual_attack_id")) == "" \
		and _meu.get_node_or_null("ContextualMeleeFX_context_launcher") == null
	print("[CTX CLI] limpou depois do fim=%s" % str(limpou))
	var rpc_ok: bool = config is Dictionary and config.has(RPCS[0]) and config.has(RPCS[1])
	print("[CTX CLI] iniciou=%s on_floor=%s apresentação=%s => %s" % [
		str(iniciou), str(_meu.is_on_floor()), str(apresentou), "✅ pedido enviado" if iniciou and apresentou and rpc_ok and limpou else "❌ falhou"])
	quit(0 if iniciou and apresentou and rpc_ok and limpou else 1)

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
