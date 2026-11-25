extends SceneTree
## Z (corte) e X (meia-lua) das lâminas EF de MADEIRA (21/11/2026). Ferro NÃO tem (decisão do dono: só madeira por enquanto).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_lamina_madeira_habilidades.gd
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
	b.vida_maxima = 200.0
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
	arma.habilidades_da_lamina.recarga = {"Z": 0.0, "X": 0.0}
	await frames(10)

func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_lamina_madeira.json"))
	modo.set("progresso_forcado", "user://test_lamina_madeira.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	prog = current_scene.progressao
	arma = p.get_node("EspadaDaHistoria")
	var ex: ExecutorCorpoACorpo = p.combate_direcional
	var hab = arma.habilidades_da_lamina
	ok("a espada da história tem o nó das habilidades da lâmina", hab != null)
	# ferro: sem Z/X
	var ferro := "ef_iron_longsword"
	if LaminasEpicFight.existe(ferro):
		prog.ganhar_equipamento(ferro)
		prog.equipar_lamina(ferro, true)
		await frames(30)
		ok("lâmina de FERRO: sem habilidades Z/X (só madeira)", not hab.disponivel())
		prog.equipar_lamina(ferro, false)
		await frames(10)
	var madeira := "ef_wooden_longsword"
	ok("a espada longa de madeira existe no catálogo", LaminasEpicFight.existe(madeira))
	prog.ganhar_equipamento(madeira)
	prog.equipar_lamina(madeira, true)
	await frames(30)
	ok("lâmina de MADEIRA na mão: habilidades disponíveis", arma.ativa and hab.disponivel())
	var menu = current_scene.get("_hud").get("_tecnicas")
	await frames(5)
	ok("janela de técnicas: \"%s\" / \"%s\"" % [menu.texto_da_linha("Z"), menu.texto_da_linha("X")],
		menu.visible and menu.texto_da_linha("Z").begins_with("Corte") and menu.texto_da_linha("X").begins_with("Meia-lua"))

	# X: meia-lua atravessa quem está à frente, não alcança o lado
	await _zerar()
	var perto := _boneco(Vector3(0, 1, -4))
	var longe := _boneco(Vector3(0, 1, -7))
	var lado := _boneco(Vector3(8, 1, -2))
	await frames(20)
	var e0: float = p.energy
	ok("X começa o corte", hab.lancar_meia_lua())
	var e_apos: float = p.energy
	await frames(80)
	ok("X fere quem está à frente e atravessa (%.0f / %.0f de 200)" % [perto.health, longe.health], perto.health < 200.0 and longe.health < 200.0)
	ok("X não alcança quem está de lado", lado.health == 200.0)
	ok("X gastou energia e entrou em recarga (%.0f → %.0f)" % [e0, e_apos], e_apos < e0 and hab.recarga["X"] > 1.0)
	await frames(2)
	ok("X em recarga: o segundo aperto não faz nada", not hab.lancar_meia_lua())
	for b in [perto, longe, lado]: b.queue_free()

	# Z: corte pesado — ferido de perto; sem energia recusa; multiplicador volta ao normal
	await _zerar()
	p.energy = 0.5
	ok("Z sem energia não corta", not hab.cortar())
	await _zerar()
	var alvo := _boneco(Vector3(0, 1, -1.4))
	var mult0 := ex.multiplicador_de_dano
	await frames(20)
	ok("Z começa o corte", hab.cortar())
	ok("durante o Z o dano está majorado (×%.2f)" % (ex.multiplicador_de_dano / mult0), ex.multiplicador_de_dano > mult0 * 1.3)
	await frames(90)
	ok("Z feriu o alvo à frente (vida %.0f de 200)" % alvo.health, alvo.health < 200.0)
	ok("depois do corte o multiplicador voltou (%.3f)" % ex.multiplicador_de_dano, is_equal_approx(ex.multiplicador_de_dano, mult0))
	ok("Z em recarga", not hab.cortar())
	# guardar a lâmina no meio de um Z devolve o multiplicador
	await _zerar()
	hab.cortar()
	prog.equipar_lamina(madeira, false)
	await frames(10)
	ok("guardar a lâmina no meio do Z não deixa dano majorado preso", is_equal_approx(ex.multiplicador_de_dano, 1.0) or is_equal_approx(ex.multiplicador_de_dano, mult0))
	print("\n%d ok, %d falha(s)" % [passou, falhas])
	quit(1 if falhas > 0 else 0)
