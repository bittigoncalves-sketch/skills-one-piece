extends SceneTree
## Regressão: M1 no ar com alvo abaixo = chute de queda, 3x descida, impacto e HUD.

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.0)
	var p: Node3D = get_first_node_in_group("player")
	var alvo: Node3D = get_first_node_in_group("dummy")
	if p == null or alvo == null:
		print("❌ Queda: jogador ou dummy ausente")
		quit(1)
		return
	# Abaixo dos 4,25 m do impacto de queda, o clique continua sendo M1 comum.
	var chao_y := p.global_position.y
	p.global_position = Vector3(0, chao_y + 2.0, 0)
	alvo.global_position = Vector3(0, chao_y, 0)
	await _esperar(0.03)
	var bloqueou_baixo: bool = not bool(p.call("tentar_ataque_aereo", 0.0))
	p.global_position = Vector3(0, 12, 0)
	p.velocity = Vector3.ZERO
	alvo.global_position = Vector3(0, 4, 0)
	var vida := float(alvo.get("health"))
	await _esperar(0.08) # deixa `is_on_floor` refletir que o corpo está no ar
	# O dummy também tem física própria; fixa-o de novo no instante do clique.
	alvo.global_position = Vector3(0, 4, 0)
	var iniciou: bool = bool(p.call("tentar_ataque_aereo", 0.0))
	var mergulhou: bool = iniciou and bool(p.get("_air_slam_active")) \
		and float(p.velocity.y) <= -3.0 and String(p.get_meta("custom_pose", "")) == "air_slam_dive"
	await _esperar(0.45)
	var hud := get_first_node_in_group("hud")
	var marcador := hud.get_node_or_null("AirSlamHud") if hud else null
	var impacto: bool = not bool(p.get("_air_slam_active")) \
		and float(alvo.get("health")) < vida \
		and float(p.get("_air_slam_cooldown")) > 2.2 \
		and marcador != null and marcador.visible \
		and String(marcador.get_node("Bloco/Tempo").text).contains("s")
	print("%s chute aéreo inicia queda triplicada" % ("✅" if mergulhou else "❌"))
	print("%s altura abaixo do impacto de queda bloqueia o chute aéreo" % ("✅" if bloqueou_baixo else "❌"))
	print("%s impacto cria explosão de ar, dano, recarga e quadrado de bigorna" % ("✅" if impacto else "❌"))
	quit(0 if bloqueou_baixo and mergulhou and impacto else 1)

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
