extends SceneTree
# ============================================================================
#  MIRA DO JOGADOR NO FLUXO DO MOD (09/11/2026, "o personagem aponta para o lugar errado"): a direção das técnicas (getLookAngle do mod)
#  vem do raio da câmera. Um obstáculo ENTRE a câmera e o jogador (inimigo colado, parede às costas) não pode virar a mira.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_mira_do_jogador.gd
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func q(n: int) -> void:
	for i in n:
		await physics_frame

func _caixa(centro: Vector3, tam: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = tam
	cs.shape = f
	b.add_child(cs)
	current_scene.add_child(b)
	b.global_position = centro
	return b

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_mira.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	modo.equipar_fruta(j, "batto_batto")
	await q(10)
	var c = j.get_node("FrutaMinePiece")
	var frente: Vector3 = -j._cam.global_basis.z
	var cam: Vector3 = j._cam.global_position
	var a_livre: Vector3 = c.olhar()
	ok(a_livre.dot(frente) > 0.9, "campo livre: a mira segue o raio da câmera (cos %.2f)" % a_livre.dot(frente))
	# parede entre a câmera e o jogador (às costas do boneco)
	var parede := _caixa(cam + frente * 1.2, Vector3(8, 8, 0.4))
	await q(3)
	var a_parede: Vector3 = c.olhar()
	ok(a_parede.dot(frente) > 0.8, "parede entre a câmera e o jogador NÃO vira a mira (cos %.2f; este caso já passava antes do conserto — o que reproduzia o defeito é o corpo colado)" % a_parede.dot(frente))
	parede.free()
	# inimigo colado ao lado, na linha da câmera, antes do jogador
	var colado := _caixa(cam + frente * 2.5, Vector3(1.0, 2.0, 1.0))
	await q(3)
	var a_colado: Vector3 = c.olhar()
	ok(a_colado.dot(frente) > 0.8, "corpo colado no jogador, entre ele e a câmera, não vira a mira (cos %.2f)" % a_colado.dot(frente))
	colado.free()
	# alvo À FRENTE do jogador: a mira vai até ele
	var alvo := _caixa(j.global_position + frente * 8.0 + Vector3.UP * 1.0, Vector3(2, 3, 1))
	await q(3)
	var a_alvo: Vector3 = c.olhar()
	var para_alvo: Vector3 = (alvo.global_position - (j.global_position + Vector3.UP * 1.4)).normalized()
	ok(a_alvo.dot(para_alvo) > 0.95, "alvo à frente: a mira vai até ele (cos %.2f)" % a_alvo.dot(para_alvo))
	print("\nmira: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
