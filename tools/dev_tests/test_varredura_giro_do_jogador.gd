extends SceneTree
# ============================================================================
#  VARREDURA (09/11/2026): NENHUMA técnica de NENHUMA fruta do mod pode girar o nó do jogador (pai da câmera) nem desalinhar a câmera do
#  `_yaw` (que move o WASD e a mira). Cada técnica roda com alvos na trajetória e ao lado, câmera já virada.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_varredura_giro_do_jogador.gd [-- fruta …]
# ============================================================================
const QUADROS_POR_TECNICA := 100
var total := 0
var falhas := 0
var ofensores: Array = []

func _init() -> void:
	rodar.call_deferred()

func q(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var so: PackedStringArray = OS.get_cmdline_user_args()      # `-- aro_aro batto_batto …` limita as frutas (rodar várias instâncias em paralelo)
	modo.set("progresso_forcado", "user://test_varredura_giro_%s.json" % (so[0] if not so.is_empty() else "todas"))
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.max_health = 1.0e7
	j.health = 1.0e7
	j._yaw = 0.7
	j._update_pivot()
	await q(5)
	var frente: Vector3 = -j._cam.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lado := frente.cross(Vector3.UP).normalized()
	var origem: Vector3 = j.global_position
	var alvos: Array = []
	for pos in [origem + frente * 7.0, origem + frente * 3.0 + lado * 2.0]:
		var a := PersonagemMinePiece.new()
		a.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
		a.position = pos
		a.ponto_de_origem = pos
		current_scene.add_child(a)
		a.max_health = 1.0e9
		alvos.append(a)
	await q(10)
	var testadas := 0
	var puladas: Array = []
	for fruta in (FrutasDoMod.FRUTAS if so.is_empty() else Array(so)):
		modo.equipar_fruta(j, "")
		await q(3)
		modo.equipar_fruta(j, fruta)
		await q(8)
		var c = j.get_node_or_null("FrutaMinePiece")
		if c == null or not c.has_method("mapa_de_teclas"):
			puladas.append(fruta)
			continue
		var teclas: Array = c.mapa_de_teclas().keys()
		for tecla: String in teclas:
			# estado limpo a cada técnica: reequipa, volta ao ponto de partida e à mesma câmera
			modo.equipar_fruta(j, "")
			await q(2)
			modo.equipar_fruta(j, fruta)
			await q(6)
			c = j.get_node_or_null("FrutaMinePiece")
			if c == null:
				continue
			j.global_position = origem
			j.velocity = Vector3.ZERO
			j.rotation = Vector3.ZERO      # cada técnica independente: o giro de uma não contamina a próxima
			j._yaw = 0.7
			j._pitch = -0.2
			j._update_pivot()
			j.energy = j.max_energy
			for a in alvos:
				a.health = a.max_health
			await q(3)
			var yaw0: float = j._yaw
			c.usar_tecla(tecla, true)
			await q(4)
			c.usar_tecla(tecla, false)
			var giro := 0.0
			var desvio := 0.0
			var dist := 0.0
			for i in QUADROS_POR_TECNICA:
				await physics_frame
				if not is_instance_valid(j):
					break
				giro = maxf(giro, absf(j.rotation.y))
				desvio = maxf(desvio, absf(wrapf(j._cam.global_rotation.y - j._yaw, -PI, PI)))
				dist = maxf(dist, j.global_position.distance_to(origem))
			testadas += 1
			total += 1
			var mexeu_yaw := absf(wrapf(j._yaw - yaw0, -PI, PI)) > 0.001
			var ruim := giro > 0.001 or desvio > 0.01
			if ruim:
				falhas += 1
				ofensores.append("%s %s: giro do nó %.3f, câmera×_yaw %.3f" % [fruta, tecla, giro, desvio])
			print("  %s %-28s %s  deslocou %.1f m | giro nó %.3f | câmera×yaw %.3f%s" % ["❌" if ruim else "✅", fruta, tecla, dist, giro, desvio, " | _yaw mudou" if mexeu_yaw else ""])
	print("\nvarredura: %d técnicas testadas, %d falhas; puladas (sem controlador do mod): %s" % [testadas, falhas, str(puladas)])
	for o in ofensores:
		print("  OFENSOR ", o)
	quit(1 if falhas > 0 else 0)
