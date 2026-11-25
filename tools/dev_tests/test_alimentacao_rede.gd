extends SceneTree
## Rodar em dois processos: -- --servidor e -- --cliente. Porta exclusiva 29874.
var servidor := false
var controle: Node
var terminou := false
func _init() -> void: executar.call_deferred()
func executar() -> void:
	await process_frame
	servidor = "--servidor" in OS.get_cmdline_user_args()
	if not servidor and not "--cliente" in OS.get_cmdline_user_args():
		print("ALIMENTACAO_REDE: execute tools/dev_tests/test_alimentacao_rede.py")
		quit()
		return
	var peer := ENetMultiplayerPeer.new()
	var erro := peer.create_server(29874, 2) if servidor else peer.create_client("127.0.0.1",29874)
	if erro != OK: quit(1); return
	root.multiplayer.multiplayer_peer = peer
	if not servidor:
		await root.multiplayer.connected_to_server
	var jogador: Node3D = load("res://Player.gd").new()
	jogador.name = "Jogador"
	root.add_child(jogador)
	jogador.set_physics_process(false)
	controle = load("res://src/historia/equipamentos/alimentacao_visual.gd").new()
	controle.name = "AlimentacaoVisual"
	jogador.add_child(controle)
	if servidor:
		print("REDE_PRONTA")
		await create_timer(5).timeout
		print("REDE_PEERS ",root.multiplayer.get_peers())
		controle.equipar("agua",2)
		controle.apresentar("agua")
		await create_timer(5).timeout
		var ok: bool = controle.tipo == "agua" and controle.quantidade == 2
		print("REDE_SERVIDOR: ","OK cliente nao altera apresentacao autorizada" if ok else "FALHOU")
		terminou = true
		quit(0 if ok else 1)
	else:
		var inicio := Time.get_ticks_msec()
		while controle.tempo < 0 and Time.get_ticks_msec() - inicio < 12000:
			await process_frame
		var ok: bool = controle.tipo == "agua" and controle.quantidade == 2 and controle.tempo >= 0 and is_instance_valid(controle.visual) and jogador.has_meta("alimentacao_pose")
		print("REDE_ESTADO ",controle.tipo," ",controle.quantidade," ",controle.tempo," ",jogador.get_meta("custom_pose",""))
		print("REDE_CLIENTE: ", "OK item e animacao recebidos" if ok else "FALHOU")
		controle._net_equipar.rpc_id(1,"comida",999)
		controle._net_consumo.rpc_id(1,"comida")
		await create_timer(2.5).timeout
		terminou = true
		quit(0 if ok else 1)
