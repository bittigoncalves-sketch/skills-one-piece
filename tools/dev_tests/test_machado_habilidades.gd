extends SceneTree
## Machado da história (17/10/2026): corte lateral na horizontal, as duas mãos no cabo, Z (machado
## giratório) e X (corte horizontal lançado), com a janela de técnicas.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_machado_habilidades.gd
var p: Node3D
var arma: Node
var prog: ProgressaoDoPersonagem
var passou := 0
var falhas := 0


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1


func _boneco(pos: Vector3) -> BonecoDeDuelo:
	var b := BonecoDeDuelo.new()
	b.vida_maxima = 30.0
	b.position = pos
	current_scene.add_child(b)
	return b


func _zerar() -> void:
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	arma.habilidades.recarga = {"Z": 0.0, "X": 0.0}
	await frames(5)


func _ang(v: Vector3) -> float:
	var l: Vector3 = p.global_transform.affine_inverse() * v
	return rad_to_deg(atan2(l.x, -l.z))


func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_machado_hab.json"))
	modo.set("progresso_forcado", "user://test_machado_hab.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	prog = current_scene.progressao
	prog.ganhar_equipamento("machado")
	prog.machado_equipado = true
	prog.ativar_item("machado")
	await frames(30)
	arma = p.get_node("MachadoDaHistoria")
	var ex: ExecutorCorpoACorpo = p.combate_direcional
	ok("o machado está na mão e o estilo é o do machado", prog.item_em_uso() == "machado" and arma.ativa and ex.estilo.id == &"machado")

	# ---------------------------------------------------------- corte lateral
	for sentido in [GolpeDirecional.Direcao.PARA_ESQUERDA, GolpeDirecional.Direcao.PARA_DIREITA]:
		await _zerar()
		ex.pedir_ataque(sentido)
		var pior_mao := 0.0
		var fio_a_frente := 0
		var amostras := 0
		var altura_min := 9.0
		var altura_max := -9.0
		var cabo_ant := Vector3.INF
		var ang_ant := 0.0
		var sweep := 0.0
		for i in 60:
			await physics_frame
			var visual: Node3D = arma._visual
			var cabeca := visual.to_global(Vector3(0, 0.72, 0))
			if ex.estado == ExecutorCorpoACorpo.Estado.ATIVO:
				var m: Node3D = p.modelo_visual()
				var seg_a := visual.to_global(Vector3(0, -0.3, 0))
				var seg_b := visual.to_global(Vector3(0, 0.6, 0))
				for lado in ["R", "L"]:
					var g := m.find_child("Weapon_" + lado, true, false) as Node3D
					var q := Geometry3D.get_closest_point_to_segment(g.global_position, seg_a, seg_b)
					pior_mao = maxf(pior_mao, g.global_position.distance_to(q))
				altura_min = minf(altura_min, cabeca.y - p.global_position.y)
				altura_max = maxf(altura_max, cabeca.y - p.global_position.y)
				if cabo_ant != Vector3.INF:
					var v := cabeca - cabo_ant
					var borda := (visual.global_basis * Vector3(1, 0, 0)).normalized()
					if v.length() > 0.01:
						amostras += 1
						if borda.dot(v.normalized()) > 0.8:
							fio_a_frente += 1
					sweep += absf(wrapf(_ang(cabeca) - ang_ant, -180.0, 180.0))
				cabo_ant = cabeca
				ang_ant = _ang(cabeca)
		var nome := "esquerda" if sentido == GolpeDirecional.Direcao.PARA_ESQUERDA else "direita"
		ok("corte para a %s: as duas mãos no cabo durante o golpe (pior desvio %.1f cm)" % [nome, pior_mao * 100.0], pior_mao < 0.06)
		ok("corte para a %s: o fio vai à frente (%d de %d quadros)" % [nome, fio_a_frente, amostras], amostras >= 5 and fio_a_frente >= amostras - 1)
		ok("corte para a %s: a cabeça varre na horizontal (altura %.2f–%.2f m, arco %.0f°)" % [nome, altura_min, altura_max, sweep],
			altura_max - altura_min < 0.15 and sweep > 90.0)
		await frames(60)

	# ------------------------------------------------------------------- UI
	var menu: TecnicasHud = current_scene.get("_hud").get("_tecnicas")
	await frames(5)
	ok("a janela de técnicas mostra Z e X do machado (\"%s\" / \"%s\")" % [menu.texto_da_linha("Z"), menu.texto_da_linha("X")],
		menu.visible and menu.texto_da_linha("Z") == "Machado giratório recarga 6 s" and menu.texto_da_linha("X") == "Corte horizontal recarga 4 s")

	# --------------------------------------------------------------------- X
	await _zerar()
	var perto := _boneco(Vector3(0, 1, -4))
	var longe := _boneco(Vector3(0, 1, -7))
	var lado := _boneco(Vector3(8, 1, -2))
	await frames(20)
	var energia0: float = p.energy
	ok("X começa o corte", arma.habilidades.cortar())
	await frames(75)
	ok("X fere quem está à frente e atravessa (%.0f / %.0f de 30)" % [perto.health, longe.health], perto.health < 30.0 and longe.health < 30.0)
	ok("X fere uma vez só (dano %.0f, esperado 20)" % (30.0 - perto.health), is_equal_approx(30.0 - perto.health, 20.0))
	ok("X não alcança quem está de lado", lado.health == 30.0)
	ok("X gastou energia e entrou em recarga (%.1f → %.1f, faltam %.1f s)" % [energia0, p.energy, arma.habilidades.recarga["X"]],
		p.energy < energia0 and arma.habilidades.recarga["X"] > 2.0)
	await frames(2)
	ok("X em recarga: o segundo aperto não faz nada", not arma.habilidades.cortar())
	ok("a janela mostra o X em recarga (\"%s\")" % menu.texto_da_linha("X"), menu.texto_da_linha("X").begins_with("Corte horizontal faltam "))
	for b in [perto, longe, lado]: b.queue_free()

	# --------------------------------------------------------------------- Z
	await _zerar()
	p.energy = 0.5
	ok("Z sem energia não lança", not arma.habilidades.lancar())
	await _zerar()
	var alvo := _boneco(Vector3(0, 1, -9))
	await frames(20)
	ok("Z começa o arremesso", arma.habilidades.lancar())
	await frames(15)
	ok("durante o arremesso o corpo é do arremesso e o executor espera", p.get_meta("machado_arremesso_ativo", false))
	await frames(30)
	ok("o machado saiu da mão e voa/pousa fora do corpo", is_instance_valid(arma.habilidades.lancado))
	ok("troca IMEDIATA para o combate corpo a corpo (item: %s)" % prog.item_em_uso(), prog.item_em_uso() == "luta" and not arma.visual_na_mao())
	await frames(60)
	ok("o machado giratório derrubou o inimigo (vida %.0f de 30)" % alvo.health, alvo.health <= 0.0)
	var no := arma.habilidades.lancado as MachadoLancado
	var espera := 0
	while is_instance_valid(no) and not no.esta_parado() and espera < 240:
		await physics_frame
		espera += 1
	ok("o machado cai e fica parado no chão (%d quadros)" % espera, is_instance_valid(no) and no.esta_parado())
	ok("sem encostar, o machado fica no chão e o jogador segue no corpo a corpo", prog.item_em_uso() == "luta" and is_instance_valid(no))
	ok("Z em recarga: apertar de novo não lança", not arma.habilidades.lancar())
	# o jogador caminha até ele e ENCOSTA
	p.global_position = no.global_position + Vector3(0, 0.9, 1.0)
	p.velocity = Vector3.ZERO
	await frames(40)
	ok("encostar no machado o devolve à mão (item: %s)" % prog.item_em_uso(), prog.item_em_uso() == "machado" and arma.ativa)
	ok("o machado do chão some e o da mão aparece", not is_instance_valid(arma.habilidades.lancado) and arma.visual_na_mao())

	# mira assistida: inimigo ~10° fora do retículo ainda é acertado
	await _zerar()
	var desviado := _boneco(Vector3(1.6, 1, -9))
	await frames(20)
	ok("Z com o inimigo fora do retículo começa", arma.habilidades.lancar())
	await frames(110)
	ok("mira assistida: o machado acertou o inimigo fora do retículo (vida %.0f de 30)" % desviado.health, desviado.health <= 0.0)
	prog.ativar_item("machado")
	await frames(10)
	desviado.queue_free()

	# escolher o machado na barra com ele no chão também o traz de volta
	await _zerar()
	alvo.queue_free()
	var vazio: bool = arma.habilidades.lancar()
	await frames(75)
	ok("novo arremesso depois da recarga zerada", vazio and prog.item_em_uso() == "luta")
	prog.ativar_item("machado")
	await frames(10)
	ok("escolher o machado na barra recolhe o do chão", prog.item_em_uso() == "machado" and not is_instance_valid(arma.habilidades.lancado) and arma.visual_na_mao())

	print("== %d ok, %d falhas" % [passou, falhas])
	quit(1 if falhas > 0 else 0)
