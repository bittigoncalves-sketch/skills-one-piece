extends SceneTree
# `minecraft:lightning_bolt` (Goro, Mamaragan, Abyss…): ciclo de vida, dano, fogo, desenho. Ver McCorpoDoMod._passo_do_raio.
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_raio_mine_piece.gd
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

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_raio.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var perto := PersonagemMinePiece.new()
	perto.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	perto.position = jogador.global_position + Vector3(0, 0, -4)
	perto.ponto_de_origem = perto.position
	perto.set_meta("mc_sem_ia", true)
	current_scene.add_child(perto)
	var longe := PersonagemMinePiece.new()
	longe.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	longe.position = jogador.global_position + Vector3(0, 0, -30)
	longe.ponto_de_origem = longe.position
	longe.set_meta("mc_sem_ia", true)
	current_scene.add_child(longe)
	await quadros(10)
	var alvo := McEntidade.de(perto)
	var mundo: McMundo = alvo.level()
	var vida0: float = perto.health
	var longe0: float = longe.health
	Mc.pedidos_sem_implementacao.clear()
	var raio = Mc.tipo_entidade(&"minecraft:lightning_bolt").create(mundo)
	ok(raio != null, "create(world) devolve a entidade")
	raio.moveTo(alvo.position())
	mundo.addFreshEntity(raio)
	var corpo: Node3D = raio.no
	await quadros(4)
	ok(perto.health < vida0, "quem está no ponto leva dano de raio, 5 antes da armadura (%.1f → %.1f)" % [vida0, perto.health])
	ok(alvo.getRemainingFireTicks() > 0, "e pega fogo (%d ticks)" % alvo.getRemainingFireTicks())
	ok(longe.health == longe0, "quem está a ~26 blocos NÃO é atingido")
	ok(corpo.get_node_or_null("Desenho") != null and corpo.get_node("Desenho").get_node_or_null("Coluna") != null, "o raio tem desenho (coluna + clarão)")
	ok(not Mc.pedidos_sem_implementacao.has("visual:entidade:minecraft:lightning_bolt"), "deixou de ser falta de visual")
	await quadros(90)                     # 1,5 s: vida 2 + até 3 reclarões de até 10 ticks
	ok(not is_instance_valid(corpo) or corpo.is_queued_for_deletion(), "o raio some sozinho")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
