extends SceneTree
## (virou teste em 25/11/2026) Mede QUANTO a fruta empurra: para cada `knockback` do mod (0,1 … 2,5) aplica o empurrão da camada do Mine Piece (`MundoMinePiece.empurrao`) num
## alvo no chão e mede o recuo horizontal máximo e a altura. Referência: o que o Minecraft faria (atrito do chão 0,546/tick).
##   "$(./find_godot.sh)" --headless --fixed-fps 60 --path . --script tools/dev_tests/test_empurrao_das_frutas.gd
func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	await process_frame
	var raiz := Node3D.new()
	root.add_child(raiz)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(400, 1, 400)
	cs.shape = caixa
	chao.add_child(cs)
	chao.position.y = -0.5
	raiz.add_child(chao)
	var B := load("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
	var falhas := 0
	print("knockback_mod | empurrão m/s | recuo máx (m) | altura máx (m) | recuo do Minecraft (m)")
	for k: float in [0.1, 0.5, 1.0, 1.5, 2.0, 2.5]:
		var b := BonecoDeDuelo.new()
		raiz.add_child(b)
		b.global_position = Vector3(0, 0.1, 0)
		for i in 20: await physics_frame
		var origem := Vector3(-1.0, 0.1, 0)
		var v: Vector3 = B.empurrao(origem, b, k)
		var x0 := b.global_position.x
		b.take_damage(10.0, origem, v, 0.0)
		var rec := 0.0
		var alt := 0.0
		for i in 300:
			await physics_frame
			rec = maxf(rec, b.global_position.x - x0)
			alt = maxf(alt, b.global_position.y - 0.1)
		var mc: float = k * 3.0 * 0.88 / (1.0 - 0.546)
		print("%5.1f | %6.1f | %7.2f | %6.2f | %6.2f" % [k, Vector3(v.x, 0, v.z).length(), rec, alt, mc])
		# Pedido do dono (25/11/2026): ~7 a 8 blocos (6,2–7,0 m) nas técnicas fortes; antes 100 m (valor 1,0) e 485 m (2,5).
		var esperado := 2.65 * k
		var bom := absf(rec - esperado) < 0.35 + 0.1 * esperado
		if not bom:
			falhas += 1
			print("  ❌ valor %.1f recuou %.2f m (esperado ≈ %.2f m)" % [k, rec, esperado])
		b.queue_free()
	var forte := 6.74
	print("EMPURRAO_DAS_FRUTAS %s (valor 2,5 ≈ %.1f blocos do jogo)" % ["OK" if falhas == 0 else "FALHOU", forte / 0.88])
	quit(1 if falhas > 0 else 0)
