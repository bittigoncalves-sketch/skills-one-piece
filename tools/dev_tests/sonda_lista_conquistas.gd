extends SceneTree
func _init() -> void:
	rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lista_conq.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://lista_conq.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	var prog = jogador.get_node("JogadorDoMod").prog
	for fruta in ["gomu_gomu", "mera_mera", "pika_pika", "goro_goro", "hie_hie", "yami_yami"]:
		prog.nivel = 1
		modo.equipar_fruta(jogador, "")
		await quadros(3)
		modo.equipar_fruta(jogador, fruta)
		await quadros(10)
		var c = jogador.get_node("FrutaMinePiece")
		var antes: int = c.estado_das_tecnicas().size()
		prog.nivel = 22
		await quadros(40)
		var depois: int = c.estado_das_tecnicas().size()
		print("LISTA %s: nível 1 → %d golpes | nível 22 (rec %d) → %d golpes" % [fruta, antes, prog.recompensa_total(), depois])
	quit()
