extends SceneTree
## Arena real com a Phoenix equipada; não altera a fruta inicial nem o save da história.
func _init() -> void: _abrir.call_deferred()
func _abrir() -> void:
	await process_frame
	var fluxo := root.get_node("GameFlow")
	fluxo.dummies["TrainingDummy"] = true
	fluxo.dummies["AutoDummy"] = false
	fluxo.start_singleplayer()
	var prazo := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<prazo:
		await process_frame
		for p in get_nodes_in_group("player"):
			if p.is_multiplayer_authority() and p.is_node_ready():
				p.equip_fruit("tori_tori_phoenix")
				p.combat_mode = "fruit"
				var hud := get_first_node_in_group("hud")
				if hud: hud.update_combat_mode("fruit",p.estilo_atual(),"tori_tori_phoenix")
				print("PHOENIX — Z transformação | X chama | C investida | V cura/explosão | F voo (após Z)")
				return
	push_error("Phoenix: o jogador da arena não nasceu.")
	quit(1)
