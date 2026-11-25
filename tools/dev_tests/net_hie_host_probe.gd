extends SceneTree
# ============================================================================
#  HIE REFEITA EM REDE — LADO HOST (2 processos). É quem ATACA (07/10/2026).
#
#  "Todos os golpes da Hie congelam 0,7 s" precisa valer contra OUTRO jogador: o acerto é
#  do servidor, mas o corpo do cliente é movido pelo próprio cliente. O host:
#    1. congela pelo servidor a cópia do cliente (`IceFX.congelar`) — o caminho da rede;
#    2. come a Hie e acerta o cliente com o Z novo (Builder) de verdade.
#  Quem mede é o CLIENTE (`net_hie_client_probe.gd`), no próprio corpo.
#
#    godot --headless --path . --script tools/dev_tests/net_hie_host_probe.gd
#    (5 s depois) godot --headless --path . --script tools/dev_tests/net_hie_client_probe.gd
# ============================================================================

var _eu: Node3D = null
var _cli: Node3D = null


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").create_room()
	for i in 1200:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	for d in get_nodes_in_group("enemy"):
		if d is Node3D:
			(d as Node3D).global_position = Vector3(0, -1000, 0)
			d.set_physics_process(false)
	var esperou := 0
	while _cli == null and esperou < 3000:
		await process_frame
		esperou += 1
		for n in get_nodes_in_group("player"):
			if n.name != "1":
				_cli = n
	if _cli == null:
		print("[HOST] ❌ o cliente nunca conectou"); quit(3); return
	await _esperar(3.0)                       # o cliente se posiciona
	# 1. Congela pela rede (o servidor decide).
	print("[HOST] congelando a cópia do cliente pelo servidor")
	IceFX.congelar(_cli)
	await _esperar(3.0)                       # 0,7 congelado + 0,5 imune + folga
	# 2. O Z novo de verdade contra o cliente.
	get_root().get_node("FruitNet").pickup("hie_hie", 1)
	await _esperar(1.0)
	_eu.set("combat_mode", "fruit")
	_eu.global_position = _cli.global_position + Vector3(0, 0, 9.0)
	_eu.velocity = Vector3.ZERO
	await _esperar(0.5)
	var cam: Camera3D = _eu.get("_cam")
	for i in 30:
		var d := (_cli.global_position + Vector3.UP * 0.3 - cam.global_position).normalized()
		_eu.set("_yaw", atan2(-d.x, -d.z))
		_eu.set("_pitch", asin(clampf(d.y, -1.0, 1.0)))
		_eu.call("_update_pivot")
		await process_frame
	_eu.set("energy", float(_eu.get("max_energy")))
	(_eu.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	_eu.set("_intervalo_golpe", 0.0)
	print("[HOST] Z da Hie em %s, mirando o cliente em %s" % [_eu.global_position.snapped(Vector3.ONE * 0.1), _cli.global_position.snapped(Vector3.ONE * 0.1)])
	_eu.begin_charge("Z")
	await process_frame
	_eu.release_charge("Z")
	await _esperar(6.0)
	print("✅ HOST terminou")
	quit(0)


func _corpo(nome: String) -> Node3D:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
