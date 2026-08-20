extends "res://src/tests/BaseTest.gd"

func test_step(f: int, delta: float) -> void:
	if f == 5:
		print("[TEST_ANIM] Frame 5: Forçando velocidade horizontal no jogador e equipando espada.")
		player.equipped_weapon = "sword"
		player.velocity.x = 5.0
	
	if f == 10:
		print("[TEST_ANIM] Frame 10: Acionando golpe de espada procedural.")
		player._net_play_melee(0) # Corte Direita para Esquerda
	
	if f == 15:
		print("[TEST_ANIM] Frame 15: Verificando se a velocidade horizontal foi preservada (pernas ativas).")
		if player.velocity.x > 0.0:
			print("[TEST_ANIM] SUCESSO: A velocidade da locomoção não foi travada pelo ataque procedural!")
		else:
			print("[TEST_ANIM] FALHA: A velocidade horizontal zerou!")
