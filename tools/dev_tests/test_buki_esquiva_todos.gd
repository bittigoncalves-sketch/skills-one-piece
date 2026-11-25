extends SceneTree
## Esquiva com dash (recarga 3 s) em TODOS os tipos de inimigo da arena/história, exceto a besta do mar (gigante): Boss, boneco de treino, boneco de duelo.
##   godot --headless --path . --fixed-fps 60 --script tools/dev_tests/test_buki_esquiva_todos.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print("  %s %s" % ["ok " if c else "FALHA", m]); if not c: _f += 1

func _init() -> void:
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(1.5).timeout
	var jogador := get_first_node_in_group("player") as Node3D
	jogador.set_physics_process(false)
	var boss := get_first_node_in_group("boss") as CharacterBody3D
	var treino: Node3D = null
	for n in get_nodes_in_group("enemy"):
		if n is TrainingDummy: treino = n
	var duelo := BonecoDeDuelo.new()
	duelo.vida_maxima = 500.0
	duelo.position = Vector3(30, 1, 30)
	current_scene.add_child(duelo)
	await create_timer(0.8).timeout
	var bib := BibliotecaDeModelos.padrao()
	var besta = preload("res://src/historia/bestas_mar/besta_do_mar.gd").new()
	current_scene.add_child(besta)
	besta.position = Vector3(-30, 1, 30)
	besta.montar(bib, "besta_mar_bovina", {"tamanho": bib.tamanho_padrao("besta_mar_bovina"), "rotacao_graus": Vector3.ZERO})
	await create_timer(0.5).timeout
	for par in [["Boss", boss], ["boneco de treino", treino], ["boneco de duelo", duelo], ["besta do mar", besta]]:
		var c = par[1]
		if c == null:
			ok("%s presente" % par[0], false); continue
		var x0 := (c as Node3D).global_position
		var deu: bool = c.esquivar_de_disparo(Vector3(0, 0, -1))
		for i in 25: await physics_frame
		var d := ((c as Node3D).global_position - x0)
		d.y = 0.0
		print("  %s: deu=%s, deslocou %.2f m" % [par[0], deu, d.length()])
		ok("%s esquiva (dash lateral > 1,5 m)" % par[0], deu and d.length() > 1.5)
		ok("%s: recarga de 3 s recusa o 2º" % par[0], not c.esquivar_de_disparo(Vector3(0, 0, -1)))
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
