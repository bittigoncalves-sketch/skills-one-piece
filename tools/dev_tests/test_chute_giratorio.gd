extends SceneTree
## Espaço + clique: variação giratória, dano frontal e rastro preto/branco.

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.0)
	var p: Node3D = get_first_node_in_group("player")
	var alvo: Node3D = get_first_node_in_group("dummy")
	if p == null or alvo == null:
		print("❌ Giro: jogador ou dummy ausente")
		quit(1)
		return
	p.global_position = Vector3(0, 4, 0)
	alvo.global_position = Vector3(0, 4, -2.3)
	var vida := float(alvo.get("health"))
	var espaco := InputEventKey.new()
	espaco.keycode = KEY_SPACE
	espaco.pressed = true
	Input.parse_input_event(espaco)
	var iniciou: bool = bool(p.call("tentar_chute_giratorio", 0.0))
	var pose: bool = iniciou and bool(p.get("_spin_kick_active")) \
		and String(p.get_meta("custom_pose", "")) == "spin_kick"
	await _esperar(0.24)
	var mundo := get_root().get_node_or_null("Main")
	var vfx: Node = mundo.get_node_or_null("ChuteGiratorio") if mundo else null
	var rastro := p.get_node_or_null("RastroChuteGiratorio")
	var modelo: Node3D = p.get("_char_model")
	var hud := get_first_node_in_group("hud")
	var recarga := hud.get_node_or_null("SpinKickHud") if hud else null
	var lado_esperado := float(p.get("_spin_kick_yaw")) + PI * 0.5
	var esta_de_lado := absf(wrapf(modelo.rotation.y - lado_esperado, -PI, PI)) < 0.12
	print("[giro] dano=%s rastro=%s angulo=%.2f au_z=%.2f lado=%s" % [str(float(alvo.get("health")) < vida), str(rastro != null), float(p.get("_spin_kick_angle")), modelo.rotation.z, str(esta_de_lado)])
	var acertou: bool = float(alvo.get("health")) < vida and vfx != null \
		and rastro != null and rastro.get_parent() == p and float(p.get("_spin_kick_angle")) > 0.1 \
		and absf(modelo.rotation.z) > 0.1 and esta_de_lado \
		and float(p.get("_spin_kick_cooldown")) > 4.3 and recarga != null and recarga.visible
	await _esperar(0.28)
	var limpou: bool = not bool(p.get("_spin_kick_active")) and is_zero_approx(modelo.rotation.z)
	print("%s espaço + clique inicia o chute giratório" % ("✅" if pose else "❌"))
	print("%s jogador gira e o rastro preto/branco fica preso ao corpo" % ("✅" if acertou else "❌"))
	print("%s giro limpa a pose ao terminar" % ("✅" if limpou else "❌"))
	quit(0 if pose and acertou and limpou else 1)

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
