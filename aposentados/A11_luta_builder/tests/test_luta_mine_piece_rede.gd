extends SceneTree
## Dois processos ENet: servidor causa dano; cliente apresenta e recebe soltura/som.
## -- servidor | -- cliente. Porta 24683 isolada dos testes da história.
var mundo: Node3D
var corpo: LutadorDeTeste
var alvo: Alvo
var servidor := false

class Alvo extends StaticBody3D:
	var health := 5000.0
	var hits := 0
	func take_damage(d: float, _origem: Vector3, _kb: Vector3, _stun: float) -> void:
		health -= d
		hits += 1

class LutadorDeTeste extends CharacterBody3D:
	var health := 250.0
	var current_fruit_id := "estilo_de_combate_base"
	var exec: ExecutorDeSkill
	var poses := 0
	var sons := 0
	var relatorio := -1
	var poses_remotas := 0
	var sons_remotos := 0
	func _physics_process(_dt: float) -> void:
		if has_meta("pose_de_skill"): poses += 1
		if is_instance_valid(exec):
			sons += exec.find_children("*", "AudioStreamPlayer3D", true, false).size()
	@rpc("authority", "call_local", "reliable")
	func iniciar(tecla: String) -> void:
		exec = ExecutorDeSkill.lancar(get_parent(), self,
			KitDoBuilder.skill(tecla, current_fruit_id), Vector3.FORWARD)
	@rpc("authority", "call_local", "reliable")
	func soltar() -> void:
		if is_instance_valid(exec): exec.soltar()
	@rpc("any_peer", "call_remote", "reliable")
	func relatar(hits: int, nposes: int, nsons: int) -> void:
		if not multiplayer.is_server() or multiplayer.get_remote_sender_id() <= 1: return
		relatorio = hits
		poses_remotas = nposes
		sons_remotos = nsons

func _init() -> void:
	_rodar.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func _rodar() -> void:
	await process_frame
	servidor = OS.get_cmdline_user_args().has("servidor")
	mundo = Node3D.new()
	mundo.name = "Arena"
	root.add_child(mundo)
	current_scene = mundo
	corpo = LutadorDeTeste.new()
	corpo.name = "Ator"
	mundo.add_child(corpo)
	alvo = Alvo.new()
	alvo.name = "Alvo"
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.45
	forma.height = 1.8
	col.shape = forma
	alvo.add_child(col)
	mundo.add_child(alvo)
	alvo.position = Vector3(0, 1, -1.6)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(24683, 1) if servidor else peer.create_client("127.0.0.1", 24683)
	if err != OK:
		push_error("ENet: " + str(err))
		quit(1)
		return
	get_multiplayer().multiplayer_peer = peer
	if servidor:
		for i in 600:
			if not get_multiplayer().get_peers().is_empty(): break
			await physics_frame
		if get_multiplayer().get_peers().is_empty():
			push_error("Cliente não conectou")
			quit(1)
			return
		await frames(15)
		corpo.iniciar.rpc("X")
		await frames(3)
		corpo.soltar.rpc()
		await frames(65)
		var pesado_ok := alvo.hits == 1
		corpo.iniciar.rpc("C")
		await frames(3)
		corpo.soltar.rpc()
		await frames(125)
		for i in 600:
			if corpo.relatorio >= 0: break
			await physics_frame
		var ok := pesado_ok and alvo.hits >= 8 and corpo.relatorio == 0 and corpo.poses_remotas > 20 \
			and corpo.sons_remotos > 0 and not corpo.has_meta("combate_mine_piece")
		print("REDE: servidor hits=%d, cliente hits=%d, poses cliente=%d, áudio cliente=%d, sucesso=%s" %
			[alvo.hits, corpo.relatorio, corpo.poses_remotas, corpo.sons_remotos, ok])
		quit(0 if ok else 1)
	else:
		await frames(380)
		corpo.relatar.rpc_id(1, alvo.hits, corpo.poses, corpo.sons)
		await frames(20)
		quit(0 if alvo.hits == 0 and corpo.poses > 20 else 1)
