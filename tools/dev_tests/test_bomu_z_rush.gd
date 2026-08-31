extends SceneTree
## Regressão da Bomu Z: carga concluída -> investida -> agarrão -> explosão.

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.0)
	var p: Node3D = get_first_node_in_group("player")
	var alvo: Node3D = get_first_node_in_group("dummy")
	if p == null or alvo == null:
		print("❌ Bomu Z: jogador ou alvo ausente")
		quit(1); return
	p.equip_fruit("bomu_bomu")
	p.global_position = Vector3(0, 4, 0)
	alvo.global_position = Vector3(0, 4, -7)
	var vida := float(alvo.get("health"))
	p.start_bomu_rush(Vector3.FORWARD)
	await _esperar(1.2)
	var acertou := float(alvo.get("health")) < vida
	var limpou := not bool(p.get("_bomu_rush_active")) and not is_instance_valid(p.get("_bomu_hand_charge"))
	print("%s Bomu Z agarrou e detonou" % ("✅" if acertou else "❌"))
	print("%s Bomu Z limpou estado e carga visual" % ("✅" if limpou else "❌"))
	quit(0 if acertou and limpou else 1)

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
