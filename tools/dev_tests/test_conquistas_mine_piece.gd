extends SceneTree
# CONQUISTAS do Mine Piece ligadas ao jogador (McConquistas + JogadorDoMod).
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_conquistas_mine_piece.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func feita(ej: McEntidade, id: String) -> bool:
	var d = ej.server.getAdvancements().getAdvancement(id)
	return d != null and ej.getAdvancements().getOrStartProgress(d).isDone()

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_conquistas.json"))     # save limpo: o teste mede do zero
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_conquistas.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var ej := McEntidade.de(jogador)
	var prog = jogador.get_node("JogadorDoMod").prog
	ok(McConquistas.definicoes().size() == 123, "123 conquistas carregadas (%d)" % McConquistas.definicoes().size())
	ok(feita(ej, "minepiece:start_mine_piece") and feita(ej, "minepiece:battle_east_blue"), "as 14 conquistas por tick (raízes) já estão concluídas")
	ok(not feita(ej, "minepiece:grade_30_m"), "grade_30_m (recompensa ≥ 30.000) NÃO está concluída no começo")
	ok(not feita(ej, "minepiece:skill_geppo"), "skill_geppo não está concluída no começo")
	var toast_antes := Mc.pedidos_sem_implementacao.size()

	# a recompensa do jogo vira PlayerBounty; ao cruzar 30.000 o UpdateBounty do mod concede a grade
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	prog.nivel = 3
	prog.xp = 0
	await quadros(30)
	ok(float(v.PlayerBounty) == float(prog.recompensa_total()) and not feita(ej, "minepiece:grade_30_m"), "recompensa %d < 30.000: sem grade" % int(prog.recompensa_total()))
	prog.nivel = 8                      # a cadeia `elif` do mod concede a MAIOR grade cruzada: sobe em passos, como no jogo
	await quadros(30)
	var rec := float(prog.recompensa_total())
	ok(float(v.PlayerBounty) == rec, "PlayerBounty = recompensa do jogo (%d)" % int(rec))
	ok(rec >= 30000.0 and rec < 100000.0 and feita(ej, "minepiece:grade_30_m"), "recompensa %d ≥ 30.000 → grade_30_m concedida pelo UpdateBounty do mod" % int(rec))
	ok(not feita(ej, "minepiece:grade_100_m"), "e ainda não a grade_100_m (feitas: %s)" % str(prog.conquistas_mod.keys().filter(func(k): return k.contains("grade") or k.contains("skill"))))
	prog.nivel = 15
	await quadros(30)
	ok(float(prog.recompensa_total()) >= 500000.0 and feita(ej, "minepiece:grade_500_m"), "recompensa %d → grade_500_m (o mod concede a maior cruzada)" % int(prog.recompensa_total()))
	ok(feita(ej, "minepiece:grade_400_m") and feita(ej, "minepiece:grade_300_m") and feita(ej, "minepiece:grade_100_m"), "e o `advancement grant until` do CompletedAdvancement concedeu a cadeia abaixo (400, 300, 100)")
	ok(feita(ej, "minepiece:grade_30_m"), "a grade_30_m continua (conquista não se perde)")

	# award/evento: concluir uma conquista dispara o AdvancementEvent (que concede o que ela libera)
	var d = ej.server.getAdvancements().getAdvancement("minepiece:skill_geppo")
	ok(not feita(ej, "minepiece:skill_geppo") and d != null and ej.getAdvancements().award(d, d.criterios[0]), "award concede o critério")
	ok(not ej.getAdvancements().award(d, d.criterios[0]), "conceder de novo não repete")
	ok(feita(ej, "minepiece:skill_geppo"), "conquista concluída")
	ok(ej.server.getAdvancements().getAdvancement("minepiece:nao_existe") == null, "id desconhecido → nulo (contado como falta)")

	# persistência: sai no dicionário do save e volta pelo desserializador
	var salvo: Dictionary = prog.para_dict()
	ok(salvo.conquistas_mod.has("minepiece:grade_30_m"), "o save leva as conquistas (%d)" % salvo.conquistas_mod.size())
	var lido = load("res://src/historia/serializacao_do_progresso.gd").de_dict(JSON.parse_string(JSON.stringify(salvo)))
	ok(lido.conquistas_mod.has("minepiece:grade_500_m") and lido.conquistas_mod.size() == salvo.conquistas_mod.size(), "o save volta inteiro")
	salvo.conquistas_mod["minepiece:inventada"] = ["x"]
	salvo.conquistas_mod["minepiece:grade_30_m"] = ["criterio_falso"]
	var lido2 = load("res://src/historia/serializacao_do_progresso.gd").de_dict(JSON.parse_string(JSON.stringify(salvo)))
	ok(not lido2.conquistas_mod.has("minepiece:inventada") and not lido2.conquistas_mod.has("minepiece:grade_30_m"), "id e critério inventados à mão são descartados")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
