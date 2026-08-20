extends "res://src/tests/BaseTest.gd"

func test_step(f: int, delta: float) -> void:
	if f == 5:
		if not InputMap.has_action("dash"):
			InputMap.add_action("dash")
	
	if f == 10:
		print("[TEST_FSM] Frame 10: Testando Dash Cancel falho (hit_confirmed = false).")
		player._fsm.transition_to("Attacking")
		player.hit_confirmed = false
		Input.action_press("dash")
		# Em Player.gd, dash_bloqueado = combat_state != IDLE and not hit_confirmed
		# Se funcionar, o combat_state deve continuar ATTACK_RECOVERY (ou não mudar para DASH)
	
	if f == 15:
		Input.action_release("dash")
		if player._fsm.state.name == "Attacking":
			print("[TEST_FSM] SUCESSO: Dash cancel foi devidamente BLOQUEADO sem hit_confirmed.")
		else:
			print("[TEST_FSM] FALHA: O Dash ocorreu mesmo sem hit_confirmed!")
			
	if f == 30:
		print("[TEST_FSM] Frame 30: Testando Dash Cancel bem sucedido (hit_confirmed = true).")
		player._fsm.transition_to("Attacking")
		player.hit_confirmed = true
		Input.action_press("dash")
		
	if f == 35:
		Input.action_release("dash")
		# Quando o dash começa, o _etapa_locomocao lida com Input.is_action_just_pressed("dash")
		# Ele pode mudar para o dash se o timer permitir, mas como o test é headless,
		# talvez ele chame o start_dash_se_permitido().
		# Vamos checar se hit_confirmed foi consumido (voltando pra false) ou se a velocity subiu pra > 20
		var planar = Vector2(player.velocity.x, player.velocity.z).length()
		if planar > 10.0 or player.hit_confirmed == false:
			print("[TEST_FSM] SUCESSO: Dash Cancel executado com hit_confirmed!")
		else:
			print("[TEST_FSM] FALHA: Dash Cancel ignorado mesmo com hit_confirmed.")
