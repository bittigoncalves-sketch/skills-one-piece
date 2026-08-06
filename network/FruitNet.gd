extends Node
## FRUIT NET (AUTOLOAD) — sincroniza a coleta de frutas.
##
## O SERVIDOR decide o pickup (ver TreeAndFruitGenerator.pickup_fruit, gateado por
## is_server) e chama aqui; estes RPCs (`call_local`) refletem em TODOS os clientes:
## a fruta some da árvore e é equipada no player certo. Sem peer (SP puro) aplica
## direto. Assim "pegar fruta reflete em todos", como pede a Fase 6.

func pickup(fruit_id: String, peer_id: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_apply_pickup.rpc(fruit_id, peer_id)     # broadcast + local
	else:
		_apply_pickup(fruit_id, peer_id)         # SP puro

func respawn(fruit_id: String) -> void:
	if multiplayer.has_multiplayer_peer():
		_apply_respawn.rpc(fruit_id)
	else:
		_apply_respawn(fruit_id)

@rpc("any_peer", "call_local", "reliable")
func _apply_pickup(fruit_id: String, peer_id: int) -> void:
	TreeAndFruitGenerator.hide_fruit(fruit_id)   # some em todos
	var p := _find_player(peer_id)
	if p and p.has_method("equip_fruit"):
		p.equip_fruit(fruit_id)                   # equipa no player certo (state replica p/ os demais)

@rpc("any_peer", "call_local", "reliable")
func _apply_respawn(fruit_id: String) -> void:
	TreeAndFruitGenerator.respawn_fruit(fruit_id)

func _find_player(peer_id: int) -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if str(p.name).to_int() == peer_id:
			return p
	return null
