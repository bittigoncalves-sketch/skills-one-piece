extends SceneTree
## Dois processos e Player real; confirma que só o servidor pode encerrar o C remoto.
var p: Node3D
var host := false
func _init() -> void: _rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	host=OS.get_cmdline_user_args().has("host")
	p=load("res://Player.gd").new()
	p.name="1"
	root.add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	p.current_fruit_id="magu_magu"
	p.combat_mode="fruit"
	p.global_position=Vector3(0,2,0)
	for i in 5: await process_frame
	var peer:=ENetMultiplayerPeer.new()
	var erro:=peer.create_server(24913,1) if host else peer.create_client("127.0.0.1",24913)
	if erro!=OK: quit(2); return
	root.multiplayer.multiplayer_peer=peer
	if host:
		while root.multiplayer.get_peers().is_empty(): await process_frame
	else:
		while peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: await process_frame
	p.set("_is_authority",host)
	p._fire_skill("C",Vector3.FORWARD,p.global_position,0.0,771,"fruit","magu_magu")
	var efeito: Node3D=p.get_meta("magu_acao")
	var inicio:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-inicio<900: await process_frame
	if not p.get_meta("magu_cao_ativo",false):
		print("FALHA: C não iniciou")
		quit(1)
		return
	if host:
		efeito._explodir(5.0)
		var espera:=Time.get_ticks_msec()
		while Time.get_ticks_msec()-espera<700: await process_frame
		print("MAGU_REDE_HOST: fim publicado")
		quit()
	else:
		while Time.get_ticks_msec()-inicio<2200 and p.get_meta("magu_cao_ativo",false): await process_frame
		var ok: bool=not p.get_meta("magu_cao_ativo",false) and Time.get_ticks_msec()-inicio<2200
		print("MAGU_REDE_CLIENTE: ","OK" if ok else "FALHA")
		quit(0 if ok else 1)
