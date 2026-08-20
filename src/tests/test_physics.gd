extends "res://src/tests/BaseTest.gd"

func test_step(f: int, delta: float) -> void:
	if f == 10:
		print("[TEST_PHYSICS] Frame 10: Aplicando dano massivo de Knockback ao Dummy.")
		# Hitstun 0.8s, KB forte pra trás (-z) e para cima (+y)
		dummy.take_damage(50, player.global_position, Vector3(0, 10, -30), 0.8)
	
	if f == 40:
		print("[TEST_PHYSICS] Frame 40: Verificando se Dummy voou.")
		if dummy.global_position.distance_to(Vector3(0, 4, -8)) > 1.0:
			print("[TEST_PHYSICS] SUCESSO: O Dummy foi empurrado pela física!")
		else:
			print("[TEST_PHYSICS] FALHA: O Dummy não se moveu do lugar!")
