extends Node
## CLIENT MANAGER (AUTOLOAD) — o lado CLIENTE.
##
## Conecta a um servidor por IP/porta. O cliente só ENVIA comandos e REPRODUZE o
## que o servidor decide (autoridade no servidor). Para servidor dedicado no
## futuro, só muda o IP passado aqui — nada mais.

const NetConf = preload("res://network/NetworkConfig.gd")

signal connected
signal connection_failed
signal server_disconnected

var is_connected: bool = false
var target := ""

func join(ip: String = NetConf.LOCAL_IP, port: int = NetConf.DEFAULT_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("[Client] create_client falhou (%s:%d): %s" % [ip, port, error_string(err)])
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	target = "%s:%d" % [ip, port]
	print("[Client] conectando em %s ..." % target)
	return true

func leave() -> void:
	for sig in [
		[multiplayer.connected_to_server, _on_connected],
		[multiplayer.connection_failed, _on_failed],
		[multiplayer.server_disconnected, _on_server_disconnected],
	]:
		if sig[0].is_connected(sig[1]):
			sig[0].disconnect(sig[1])
	var peer := multiplayer.multiplayer_peer
	if peer and peer is ENetMultiplayerPeer and is_connected:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_connected = false

func _on_connected() -> void:
	is_connected = true
	print("[Client] conectado (id=%d) a %s" % [multiplayer.get_unique_id(), target])
	connected.emit()

func _on_failed() -> void:
	push_warning("[Client] conexão falhou: %s" % target)
	is_connected = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	push_warning("[Client] servidor caiu")
	is_connected = false
	server_disconnected.emit()
