extends SceneTree
## Regressão local da Suke Suke: Z liga, dano revela e inicia recarga.

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.0)
	var p: Node = get_first_node_in_group("player")
	if p == null:
		print("❌ Suke Suke: jogador ausente"); quit(1); return
	p.equip_fruit("suke_suke")
	p.iniciar_invisibilidade()
	await process_frame
	var ativou := bool(p.get("_invisivel"))
	p.iniciar_invisibilidade() # segunda ativação de Z revela voluntariamente
	await process_frame
	var revelou := not bool(p.get("_invisivel")) and float(p._fruit_cooldowns["Z"]) > 9.8
	print("%s Z ativa invisibilidade" % ("✅" if ativou else "❌"))
	print("%s segundo Z revela e inicia recarga de 10 s" % ("✅" if revelou else "❌"))
	quit(0 if ativou and revelou else 1)

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
