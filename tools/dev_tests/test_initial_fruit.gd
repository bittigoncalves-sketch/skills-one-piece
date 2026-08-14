extends SceneTree

func _init() -> void:
	await process_frame
	var gf := get_root().get_node("GameFlow")
	gf.start_singleplayer()
	
	# Esperar a cena instanciar o Player
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 3000:
		await process_frame
		
	var player = null
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			player = p
			break
			
	if not player:
		print("❌ FALHOU - Jogador nao encontrado.")
		quit(1)
		return
		
	if player.current_fruit_id != "gura_gura":
		print("❌ FALHOU - Fruta inicial esperada 'gura_gura', mas obteve '%s'" % player.current_fruit_id)
		quit(1)
		return
		
	print("✅ PASSOU - Jogador nasceu com a Gura Gura no Mi como padrao!")
	quit(0)
