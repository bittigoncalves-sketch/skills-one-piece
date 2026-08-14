extends Node
## SERVER MANAGER (AUTOLOAD) — a AUTORIDADE de rede.
##
## Cria o servidor ENet. No modelo do Godot o host é servidor + jogador local
## (peer id 1) ao mesmo tempo, então Singleplayer e "Criar Sala" usam ESTE mesmo
## caminho (zero lógica duplicada). Trocar por servidor dedicado no futuro = só
## rodar este host em modo headless; a lógica do jogo não muda.

const NetConf = preload("res://network/NetworkConfig.gd")

signal started
signal stopped
signal peer_joined(id: int)
signal peer_left(id: int)

var is_running: bool = false
var connected_peers: Array[int] = []

func host(port: int = NetConf.DEFAULT_PORT, max_players: int = NetConf.MAX_PLAYERS) -> bool:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		push_error("[Server] create_server falhou (porta %d): %s" % [port, error_string(err)])
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	is_running = true
	started.emit()
	print("[Server] hospedando na porta %d (host id=%d)" % [port, multiplayer.get_unique_id()])
	return true

func host_offline() -> bool:
	stop()
	var peer := OfflineMultiplayerPeer.new()
	multiplayer.multiplayer_peer = peer
	is_running = true
	started.emit()
	print("[Server] hospedando offline (host id=%d)" % [multiplayer.get_unique_id()])
	return true

func stop() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	var peer := multiplayer.multiplayer_peer
	if peer and peer is ENetMultiplayerPeer and is_running:
		peer.close()
	multiplayer.multiplayer_peer = null
	connected_peers.clear()
	if is_running:
		is_running = false
		stopped.emit()

func all_players() -> Array[int]:
	# host (id 1) + todos os conectados
	var ids: Array[int] = [NetConf.SERVER_ID]
	ids.append_array(connected_peers)
	return ids

func _on_peer_connected(id: int) -> void:
	connected_peers.append(id)
	peer_joined.emit(id)
	print("[Server] peer entrou: %d (total=%d)" % [id, connected_peers.size() + 1])

func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	peer_left.emit(id)
	print("[Server] peer saiu: %d" % id)
