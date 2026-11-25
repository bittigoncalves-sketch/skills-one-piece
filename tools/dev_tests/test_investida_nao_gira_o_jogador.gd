extends SceneTree
# ============================================================================
#  B DO BATTO BATTO (09/11/2026, log da partida do dono): a investida acertava alguém, o `StepBlock` do mod chamava
#  `connection.teleport(..., getYRot(), getXRot())` e a tradução GIRAVA O NÓ do jogador (pai da câmera) — câmera, mira e WASD
#  ficavam desalinhados para sempre. Reenviar a visão atual não pode girar nada.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_investida_nao_gira_o_jogador.gd
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

func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_investida.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.max_health = 100000.0
	j.health = 100000.0
	j._yaw = 0.7                       # câmera já virada (como na partida real)
	j._update_pivot()
	await q(5)
	var yaw0: float = j._yaw
	var frente: Vector3 = -j._cam.global_basis.z
	frente.y = 0.0
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = j.global_position + frente.normalized() * 7.0     # exatamente na trajetória do B
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await q(10)
	modo.equipar_fruta(j, "batto_batto")
	await q(10)
	var c = j.get_node("FrutaMinePiece")
	j.energy = j.max_energy
	var saiu_do_lugar := false
	var pos0: Vector3 = j.global_position
	c.usar_tecla("B", true)
	await q(3)
	c.usar_tecla("B", false)
	var maior_giro := 0.0
	var maior_desvio := 0.0
	for i in 150:
		await physics_frame
		maior_giro = maxf(maior_giro, absf(j.rotation.y))
		maior_desvio = maxf(maior_desvio, absf(wrapf(j._cam.global_rotation.y - j._yaw, -PI, PI)))
		saiu_do_lugar = saiu_do_lugar or j.global_position.distance_to(pos0) > 3.0
	ok(saiu_do_lugar, "a investida do B aconteceu (o teste mede o caso certo)")
	ok(maior_giro < 0.001, "o nó raiz do jogador NÃO gira (maior |rotation.y| = %.3f)" % maior_giro)
	ok(maior_desvio < 0.01, "a câmera segue o _yaw (maior desvio %.3f rad; no log do dono chegou a 0,869)" % maior_desvio)
	ok(absf(j._yaw - yaw0) < 0.001, "_yaw intacto pela técnica (%.3f → %.3f)" % [yaw0, j._yaw])
	# reorientação REAL (teleport com outro yaw) vira o _yaw, não o nó
	var mc := McEntidade.de(j)
	mc.connection.teleport(j.global_position.x / MundoMinePiece.METROS_POR_BLOCO, j.global_position.y / MundoMinePiece.METROS_POR_BLOCO, j.global_position.z / MundoMinePiece.METROS_POR_BLOCO, 90.0, 0.0)
	ok(absf(j.rotation.y) < 0.001 and absf(wrapf(j._yaw - deg_to_rad(90.0), -PI, PI)) < 0.001, "teleport com outro yaw reorienta o _yaw (%.3f rad), não o nó (%.3f)" % [j._yaw, j.rotation.y])
	print("\ninvestida: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
