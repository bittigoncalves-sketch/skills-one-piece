extends SceneTree
# Zona de morte por queda: -40 na arena, -150 no Modo História (fundo do mar a -80).

var _falhas := 0

func _ok(c: bool, m: String) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c:
		_falhas += 1

func _initialize() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	var corpo := CharacterBody3D.new()
	root.add_child(corpo)
	await process_frame
	corpo.global_position = Vector3(0, -70, 0)   # fundo da fossa é ~-80
	_ok(Scoreboard.void_y_de(corpo) == Scoreboard.VOID_Y, "arena: void em -40")
	_ok(SkillSystem.process_void_check(corpo), "arena: -70 mata")
	corpo.global_position = Vector3(0, -70, 0)
	var hist := Node.new()
	hist.add_to_group("modo_historia")
	root.add_child(hist)
	_ok(Scoreboard.void_y_de(corpo) == Scoreboard.VOID_Y_HISTORIA, "historia: void em -150")
	_ok(not SkillSystem.process_void_check(corpo), "historia: -70 (fundo do mar) NÃO mata")
	corpo.global_position = Vector3(0, -80, 0)
	_ok(not SkillSystem.process_void_check(corpo), "historia: -80 (fossa) NÃO mata")
	_ok(Scoreboard.VOID_Y_HISTORIA < RelevoMarinho.FOSSA, "void abaixo da fossa")
	_ok(Scoreboard.VOID_Y_HISTORIA < RelevoMarinho.BORDA_DO_MUNDO, "void abaixo do abismo")
	corpo.global_position = Vector3(0, -160, 0)
	_ok(SkillSystem.process_void_check(corpo), "historia: -160 mata (vazio real)")
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)
