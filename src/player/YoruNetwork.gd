extends Node
## O nó de rede pertence ao servidor mesmo quando o Player pertence ao cliente.
## Só pedidos são any_peer; estado, equipamento e relógio vêm do peer 1.
const REQUESTS := ["M1", "Z", "X", "C", "V"]
const ACTIONS := ["M1_1", "M1_2", "Z", "X", "C", "V"]
const MODES := ["fruit", "style", "sword"]
var player: Node3D
var controller: Node
var _request_sequence := 0
var _last_request := 0
var _action_sequence := 0
var _revision := 0
var _received_revision := -1
var _applying := false
var _snapshot_requested := false
var _m1_buffer := 0.0
var _buffer_direction := Vector3.FORWARD

func setup(owner_player: Node3D, combat: Node) -> void:
	player = owner_player
	controller = combat
	set_multiplayer_authority(1)
	if controller:
		if controller.has_signal("action_cancelled"):
			controller.connect("action_cancelled", _controller_cancelled)
		if controller.has_signal("action_finished"):
			controller.connect("action_finished", _controller_finished)
	if controller and controller.has_signal("guard_confirmed"):
		controller.connect("guard_confirmed", _controller_guard_confirmed)
	request_snapshot.call_deferred()

func _physics_process(delta: float) -> void:
	if _m1_buffer <= 0.0:
		return
	_m1_buffer = maxf(0.0, _m1_buffer - delta)
	if controller and player.combat_mode == "sword" and controller.can_start(controller.next_m1()):
		_m1_buffer = 0.0
		request_action("M1", _buffer_direction)

func _is_server() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func request_snapshot() -> void:
	if not _is_server() and not _snapshot_requested:
		_snapshot_requested = true
		_net_request_snapshot.rpc_id(1)

func request_mode(mode: String) -> void:
	if not player.is_multiplayer_authority() or not mode in MODES:
		return
	_m1_buffer = 0.0
	_request_sequence += 1
	if _is_server():
		_accept_mode(_request_sequence, mode)
	else:
		_net_request_mode.rpc_id(1, _request_sequence, mode)

func request_action(id: String, direction: Vector3) -> void:
	if not player.is_multiplayer_authority() or not id in REQUESTS:
		return
	if player.combat_mode != "sword" or player.equipped_weapon != "sword":
		return
	if not controller:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("is_menu_open") and hud.is_menu_open():
		return
	if id == "M1" and not controller.can_start(controller.next_m1()):
		if not String(controller.action_id).is_empty():
			_m1_buffer = 0.18
			_buffer_direction = direction
		return
	_request_sequence += 1
	if _is_server():
		_accept_action(_request_sequence, id, direction)
	else:
		_net_request_action.rpc_id(1, _request_sequence, id, direction)

func _valid_sender() -> bool:
	return _is_server() and multiplayer.get_remote_sender_id() == player.get_multiplayer_authority()

func _consume_request(serial: int) -> bool:
	if serial <= _last_request or serial <= 0:
		return false
	_last_request = serial
	return true

@rpc("any_peer", "call_remote", "reliable")
func _net_request_mode(serial: int, mode: String) -> void:
	if _valid_sender():
		_accept_mode(serial, mode)

func _accept_mode(serial: int, mode: String) -> void:
	if not _consume_request(serial) or not mode in MODES:
		return
	if player.health <= 0.0 or player._eliminado:
		return
	_applying = true
	player._apply_combat_mode(mode)
	_applying = false
	_publish()

@rpc("any_peer", "call_remote", "reliable")
func _net_request_action(serial: int, id: String, direction: Vector3) -> void:
	if _valid_sender():
		_accept_action(serial, id, direction)

func _accept_action(serial: int, id: String, direction: Vector3) -> void:
	# Uma recusa também consome o serial: replay não vira golpe após a recarga.
	if not _consume_request(serial) or not id in REQUESTS or not controller:
		return
	if player.combat_mode != "sword" or player.equipped_weapon != "sword":
		return
	if player.health <= 0.0 or player._eliminado or player._charging or player._rapid_fire:
		return
	if not direction.is_finite() or absf(direction.y) > 0.001:
		return
	var length_sq := direction.length_squared()
	if not is_finite(length_sq) or length_sq < 0.99 or length_sq > 1.01:
		return
	for key in ["is_frozen", "in_vortex", "in_kurouzu", "in_black_hole", "block_break"]:
		if player.get_meta(key, false):
			return
	if player.esquivando() or player._hitstop_timer > 0.0 or player._fruit_damage_lock_timer > 0.0:
		return
	if player._fsm and player._fsm.state and player._fsm.state.name != "Idle":
		return
	var action: String = controller.next_m1() if id == "M1" else id
	if not action in ACTIONS or not controller.can_start(action):
		return
	_action_sequence += 1
	controller.start_action(action, _action_sequence, direction.normalized())
	_publish()

func cancel_action(reason: String) -> void:
	_m1_buffer = 0.0
	if not controller or String(controller.action_id).is_empty():
		return
	var action_serial: int = controller.sequence
	controller.cancel(reason)
	# Durante snapshot/mode apply, o servidor já decidiu o estado.
	if _applying or _is_server() or not player.is_multiplayer_authority():
		return
	_request_sequence += 1
	_net_request_cancel.rpc_id(1, _request_sequence, action_serial, reason)

@rpc("any_peer", "call_remote", "reliable")
func _net_request_cancel(serial: int, action_serial: int, reason: String) -> void:
	if not _valid_sender() or not _consume_request(serial) or not controller:
		return
	if action_serial != controller.sequence or not reason in ["damage", "dash", "death", "respawn", "mode", "rig", "break"]:
		return
	controller.cancel(reason)

func _controller_cancelled(_reason: String) -> void:
	_m1_buffer = 0.0
	if _is_server() and not _applying:
		_publish()

func _controller_guard_confirmed() -> void:
	if _is_server() and not _applying:
		_publish()

func _controller_finished(_id: String) -> void:
	if _is_server() and not _applying:
		_publish()

func _snapshot() -> Dictionary:
	var state := {"revision": _revision, "mode": player.combat_mode,
		"sequence": _action_sequence, "action": "", "elapsed": 0.0,
		"direction": Vector3.FORWARD, "cooldowns": {}}
	if controller:
		state.penalty = controller._penalty
		state.riposte = controller.riposte
		state.action = controller.action_id
		state.elapsed = controller.elapsed
		state.direction = controller.direction
		for slot in ["Z", "X", "C", "V"]:
			state.cooldowns[slot] = controller.cooldown(slot)
	return state

func _publish() -> void:
	_revision += 1
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		_net_state.rpc(_snapshot())

@rpc("any_peer", "call_remote", "reliable")
func _net_request_snapshot() -> void:
	if not _is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer > 1 and peer in multiplayer.get_peers():
		# Pedido só existe após este Player nascer no cliente: sem corrida de spawn.
		_net_state.rpc_id(peer, _snapshot())

@rpc("authority", "call_remote", "reliable")
func _net_state(state: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_apply_state(state)

func _apply_state(state: Dictionary) -> void:
	var revision := int(state.get("revision", -1))
	if revision <= _received_revision:
		return
	var mode := String(state.get("mode", ""))
	var action := String(state.get("action", ""))
	if not mode in MODES or (not action.is_empty() and not action in ACTIONS):
		return
	_received_revision = revision
	_applying = true
	player._apply_combat_mode(mode)
	if controller:
		var serial := int(state.get("sequence", 0))
		if action.is_empty():
			controller.cancel("snapshot")
		elif serial > controller.sequence:
			controller.start_action(action, serial, state.direction, float(state.elapsed))
		# Duplicatas não reiniciam ação nem recarga; uma revisão nova atualiza
		# recarga absoluta do servidor (também após entrada tardia no meio do golpe).
		controller.restore_cooldowns(state.get("cooldowns", {}))
		controller.riposte = float(state.get("riposte", 0.0))
		controller._penalty = float(state.get("penalty", 0.0))
	_applying = false


func contact(position: Vector3, parry: bool = false) -> void:
	if not _is_server(): return
	_show_contact(position, parry)
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		_net_contact.rpc(position, parry)

@rpc("authority", "call_remote", "unreliable")
func _net_contact(position: Vector3, parry: bool) -> void:
	_show_contact(position, parry)

func _show_contact(position: Vector3, parry: bool) -> void:
	YoruFX.impact(player, position, parry)
	YoruAudio.play(player, "parry" if parry else "impact")
	# O golpe encostou: o resto do avanço morre aqui. Este é o único ponto por
	# onde o contato passa nos três casos (servidor, cliente dono e partida
	# local), e quem precisa da notícia é justamente o cliente, que é quem simula
	# o próprio corpo. Um aparo NÃO conta: lá o golpe inteiro já foi cancelado.
	if not parry and controller and controller.has_method("on_hit_confirmed"):
		controller.on_hit_confirmed()
	if player.is_multiplayer_authority() and player.get("_camera") != null:
		player._camera.pedir_shake(0.16 if parry else 0.10)
