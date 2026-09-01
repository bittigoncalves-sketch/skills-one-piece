extends SceneTree
## Regressão do estilo Mink: corrida -> mordida/agarrão -> chute no próximo M1.
## O teste chama o mesmo ponto de entrada usado pelo MeleeController e garante
## que o M1 normal não precisa travar o movimento para o combo existir.

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.0)
	var p: Node3D = get_first_node_in_group("player")
	var alvo: Node3D = get_first_node_in_group("dummy")
	if p == null or alvo == null or p.get("_char_model") == null:
		print("❌ Mink: jogador, dummy ou modelo ausente")
		quit(1)
		return

	Racas.aplicar(p.get("_char_model"), "mink_lobo")
	p.global_position = Vector3(0, 4, 0)
	# Começa dentro do raio de seleção, mas sai dele logo após o disparo para
	# medir a investida que ERRA por não alcançar ninguém.
	alvo.global_position = Vector3(0, 4, -8)
	var vida_inicial := float(alvo.get("health"))
	var shift := InputEventKey.new()
	shift.keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	p.velocity = Vector3(0, 0, -6)

	var iniciou := bool(p.call("tentar_combo_mink", 0.0))
	var investida := iniciou and bool(p.get("_mink_bite_dash")) \
		and String(p.get_meta("custom_pose", "")) == "mink_bite_dash"
	alvo.global_position = Vector3(0, 4, -30)
	await _esperar(0.48)
	# Errou: não há alvo no alcance, portanto a tentativa seguinte é imediata.
	alvo.global_position = Vector3(0, 4, -8)
	p.velocity = Vector3(0, 0, -6)
	var errou_sem_recarga := float(p.get("_mink_bite_cooldown")) <= 0.0 \
		and bool(p.call("tentar_combo_mink", 0.0))
	# Limpa a segunda investida de teste e monta o alvo para a confirmação real.
	p.call("_encerrar_mordida_mink")
	p.global_position = Vector3(0, 4, 0)
	alvo.global_position = Vector3(0, 4, -5.5)
	p.velocity = Vector3(0, 0, -6)
	var iniciou_acerto := bool(p.call("tentar_combo_mink", 0.0))
	await _esperar(0.48)
	var hud := get_first_node_in_group("hud")
	var indicador := hud.get_node_or_null("MinkBiteHud") if hud else null
	var hud_exibe_recarga: bool = indicador != null and indicador.visible \
		and String(indicador.get_node("Bloco/Tempo").text).contains("s")
	var agarrou: bool = bool(p.get("_mink_hold_timer") > 0.0) \
		and bool(alvo.get_meta("is_frozen", false)) \
		and float(alvo.get("health")) < vida_inicial \
		and float(p.get("_mink_bite_cooldown")) > 2.3 and hud_exibe_recarga

	p.velocity = Vector3(0, 0, -6)
	var chutou := bool(p.call("tentar_combo_mink", 0.0))
	await _esperar(0.42)
	var limpou := not bool(p.get("_mink_bite_dash")) \
		and float(p.get("_mink_hold_timer")) <= 0.0 \
		and not bool(alvo.get_meta("is_frozen", false)) \
		and float(alvo.get("health")) < vida_inicial - 54.0

	print("%s Mink inicia a investida de mordida" % ("✅" if investida else "❌"))
	print("%s erro não arma recarga e permite nova mordida" % ("✅" if errou_sem_recarga else "❌"))
	print("%s Mink agarra, inicia 3 s de recarga e mostra o indicador" % ("✅" if agarrou else "❌"))
	print("%s segundo clique chuta, arremessa e limpa o agarrão" % ("✅" if chutou and limpou else "❌"))
	quit(0 if investida and errou_sem_recarga and iniciou_acerto and agarrou and chutou and limpou else 1)


func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
