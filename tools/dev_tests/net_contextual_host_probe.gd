extends SceneTree
## Host de duas instâncias para o ataque contextual. O cliente é quem pede W+M1;
## este processo prova que o servidor recebeu o RPC, criou a DamageZone e feriu
## o host. Rodar antes do cliente, na mesma SOP_PORTA.

var _host: Node = null
var _cliente: Node = null
var _nome_cliente := ""
var _hp_inicial := 0.0
var _menor_hp := INF
var _zonas := {}
var _zonas_cliente := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").create_room()
	_host = await _esperar_corpo("1", 8000)
	if _host == null:
		print("[CTX HOST] ❌ corpo do host ausente")
		quit(2)
		return
	_hp_inicial = float(_host.health)
	_menor_hp = _hp_inicial
	print("[CTX HOST] sala criada; esperando cliente...")
	var limite_cliente := Time.get_ticks_msec() + 18000
	while Time.get_ticks_msec() < limite_cliente and _cliente == null:
		for corpo in get_nodes_in_group("player"):
			if corpo.name != "1":
				_cliente = corpo
		if _cliente == null:
			await process_frame
	if _cliente == null:
		print("[CTX HOST] ❌ cliente não conectou")
		quit(3)
		return
	_nome_cliente = str(_cliente.name)
	print("[CTX HOST] cliente '%s' conectado; observando RPC por 7 s" % _nome_cliente)
	var fim := Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < fim:
		_varrer_zonas()
		_menor_hp = minf(_menor_hp, float(_host.health))
		await process_frame
	var passou := _zonas_cliente > 0 and _menor_hp < _hp_inicial
	print("[CTX HOST] zones_do_cliente=%d hp=%.1f→%.1f => %s" % [
		_zonas_cliente, _hp_inicial, _menor_hp, "✅ OK" if passou else "❌ FALHOU"])
	quit(0 if passou else 1)

func _esperar_corpo(nome: String, timeout_ms: int) -> Node:
	var fim := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < fim:
		for corpo in get_nodes_in_group("player"):
			if corpo.name == nome:
				return corpo
		await process_frame
	return null

func _varrer_zonas() -> void:
	var cena := current_scene
	if cena == null:
		return
	for filho in cena.get_children():
		if filho is DamageZone and not _zonas.has(filho.get_instance_id()):
			_zonas[filho.get_instance_id()] = true
			var caster = filho.get("caster")
			if caster != null and is_instance_valid(caster) and str(caster.name) == _nome_cliente:
				_zonas_cliente += 1
				print("[CTX HOST] DamageZone contextual recebida: %s" % filho.name)
