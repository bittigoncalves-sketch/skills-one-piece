extends Node3D
const CASA := Vector3(0, 100.82, 0)
var jogador: CharacterBody3D
var alvo: CharacterBody3D
var peer_cliente := 0
var falhas := 0
var checks := 0
var snapshots := 0
var zonas_cliente := 0
var pronto := false
var _host := false

func _ready() -> void:
	get_tree().create_timer(50).timeout.connect(func(): get_tree().quit(2))
	_host = "host" in OS.get_cmdline_user_args()
	var peer := ENetMultiplayerPeer.new()
	var erro: int = peer.create_server(24761, 2) if _host else peer.create_client("127.0.0.1", 24761)
	if erro != OK:
		push_error("Rocket ENet: " + str(erro))
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	if _host:
		multiplayer.peer_connected.connect(func(id: int):
			peer_cliente = id
			_montar(id))
	else:
		multiplayer.connected_to_server.connect(func():
			_montar(multiplayer.get_unique_id())
			await _esperar(0.5)
			_cliente_pronto.rpc_id(1))

func _montar(id: int) -> void:
	var piso := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80,0.6,80)
	col.shape = shape
	piso.add_child(col)
	add_child(piso)
	piso.global_position = Vector3(0,99.7,0)
	jogador = load("res://Player.gd").new()
	jogador.name = "Pilot"
	var main = load("res://Main.gd").new()
	jogador.add_child(main._make_player_sync())
	main.free()
	jogador.set_multiplayer_authority(id)
	add_child(jogador)
	jogador.global_position = CASA
	jogador.equip_fruit("rocket")
	jogador.combat_mode = "fruit"
	alvo = load("res://src/entities/TrainingDummy.gd").new()
	alvo.name = "Target"
	add_child(alvo)
	alvo.set_physics_process(false)
	alvo.global_position = CASA + Vector3.FORWARD * 2
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	if not _host and is_instance_valid(jogador):
		snapshots = maxi(snapshots, jogador._rocket._ultima_sequencia)
		zonas_cliente = maxi(zonas_cliente, get_tree().get_nodes_in_group("rocket_hitbox").size())

@rpc("any_peer", "reliable")
func _cliente_pronto() -> void:
	if not _host or multiplayer.get_remote_sender_id() != peer_cliente or pronto: return
	pronto = true
	await _roteiro()

func _roteiro() -> void:
	var slots := ["Z", "X", "C", "V"]
	var esperas := [0.8, 1.3, 1.7, 8.2]
	var danos := [88.0, 160.0, 320.0, 576.0]
	for i in 4:
		_preparar.rpc(slots[i])
		await _esperar(0.35)
		_agir.rpc_id(peer_cliente, slots[i], 1000+i)
		await _esperar(esperas[i])
		_ok(is_equal_approx(alvo.MAX_HP-alvo.health, danos[i]), "%s dano decidido no servidor: %.1f" % [slots[i], alvo.MAX_HP-alvo.health])
		_ok(not jogador._rocket.ocupado(), "%s termina nas cópias de rede" % slots[i])
		if slots[i] == "X":
			_ok(jogador.global_position.distance_to(CASA) < 12, "posição forjada durante Crash não move trajetória do servidor")
		await _esperar(0.9)
	# Fruta errada não concede técnicas por declarar source_id no RPC.
	_preparar.rpc("Z")
	await _esperar(0.35)
	jogador.current_fruit_id = "ope_ope"
	var energia: float = jogador.energy
	var autorizado: bool = jogador._rocket.autorizar("Z",Vector3.FORWARD,CASA,5000)
	_ok(not autorizado and jogador.energy == energia, "servidor rejeita Rocket quando fruta equipada não coincide")
	_pedir_resultado.rpc_id(peer_cliente)

@rpc("authority", "call_local", "reliable")
func _preparar(slot: String) -> void:
	jogador._rocket.cancelar()
	jogador.equip_fruit("rocket")
	jogador.combat_mode = "fruit"
	jogador.global_position = CASA
	jogador.velocity = Vector3.ZERO
	jogador.health = jogador.max_health
	jogador.energy = jogador.max_energy
	jogador._fruit_cooldowns.clear()
	jogador._server_cast_next_ms.clear()
	jogador._fruit_damage_lock_timer = 0
	jogador._fsm.transition_to("Idle")
	alvo.health = alvo.MAX_HP
	alvo.global_position = CASA + Vector3.FORWARD * float({"Z":2,"X":5,"C":8,"V":0}[slot])
	if slot == "V": alvo.global_position += Vector3.RIGHT * 2

@rpc("authority", "reliable")
func _agir(slot: String, tok: int) -> void:
	jogador.pedir_cast_no_servidor(slot, Vector3.FORWARD, jogador.global_position + Vector3.UP,0,tok)
	# Mesmo pedido retransmitido não cria outro cast/custo/hit.
	jogador.pedir_cast_no_servidor(slot, Vector3.FORWARD, jogador.global_position + Vector3.UP,0,tok)
	if slot == "X":
		await _esperar(0.30)
		jogador.global_position = Vector3(500,500,500)

@rpc("authority", "reliable")
func _pedir_resultado() -> void:
	_resultado.rpc_id(1, snapshots, zonas_cliente)

@rpc("any_peer", "reliable")
func _resultado(total: int, zonas: int) -> void:
	if not _host or multiplayer.get_remote_sender_id() != peer_cliente: return
	_ok(total > 20, "cliente recebeu snapshots autoritativos: %d" % total)
	_ok(zonas == 0, "cliente não cria hitboxes de dano")
	print("ROCKET REDE: %d verificações, %d falhas" % [checks, falhas])
	_encerrar.rpc_id(peer_cliente, falhas)
	await _esperar(0.2)
	get_tree().quit(0 if falhas == 0 else 1)

@rpc("authority", "reliable")
func _encerrar(erros: int) -> void:
	get_tree().quit(0 if erros == 0 else 1)

func _esperar(segundos: float) -> void:
	for _i in ceili(segundos*60): await get_tree().physics_frame

func _ok(condicao: bool, texto: String) -> void:
	checks += 1
	if not condicao: falhas += 1
	print(("✅ " if condicao else "❌ ") + texto)
