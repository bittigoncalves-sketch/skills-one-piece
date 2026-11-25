extends SceneTree
## História real, salva/raio das quatro espécies e colisões com jogador/cenário.
const PASTA := "res://art_src/validation/bestas_mar/ataques_agua/"
var total := 0
var falhas := 0
var jogador: Node3D
var camera: Camera3D
var tela := false
var registros: Array[Dictionary] = []


func _init() -> void:
	rodar.call_deferred()


func ok(sim: bool, texto: String) -> void:
	total += 1
	falhas += 0 if sim else 1
	print(("OK " if sim else "FALHA ") + texto)


func quadros(n: int) -> void:
	for i in n: await physics_frame


func registrar(tiro: Node3D, besta: Node3D) -> void:
	registros.append({"tipo": "compressor" if tiro.get("alcance") != null else "bolha",
		"frame": Engine.get_physics_frames(), "rumo": tiro.rumo,
		"boca": tiro.global_position.distance_to(besta.animador.boca()), "no": tiro})


func foto(nome: String, besta: Node3D) -> void:
	if not tela: return
	camera.global_position = besta.global_position + Vector3(22, 10, -15)
	camera.look_at(besta.global_position + Vector3(0, 3, -11))
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA + nome + ".png")


func limpar() -> void:
	for no in get_nodes_in_group("efeitos_agua_bestas"): no.queue_free()
	await quadros(3)


func rodar() -> void:
	await process_frame
	tela = OS.get_cmdline_user_args().has("--tela")
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json").mapa
	mapa.pecas[0].tamanho = Vector3(180, 2, 180)
	for i in 4:
		var id: String = "besta_mar_" + ["bovina", "girafa", "javali", "serpente"][i]
		var tam := bib.tamanho_padrao(id)
		mapa.pecas.append({"id": id, "tipo": "modelo", "modelo": id,
			"posicao": Vector3(-65 + i * 40, tam.y * .5, 45), "tamanho": tam,
			"rotacao_graus": Vector3.ZERO, "colisao": true, "cor": Color.WHITE, "material": "liso"})
	ok(MapaArquivo.salvar("user://agua_bestas.json", mapa) == OK, "fixture isolada salva")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "user://agua_bestas.json")
	modo.set("progresso_forcado", "user://agua_bestas_save.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var barras_novas = current_scene.find_child("BarrasDeCriaturas", true, false)
	if barras_novas != null: barras_novas.free()
	jogador = get_first_node_in_group("player")
	jogador.set_physics_process(false)
	jogador.set_meta("damage_immune", true)
	var bestas := get_nodes_in_group("bestas_do_mar")
	ok(bestas.size() == 4, "quatro criaturas reais montadas")
	if bestas.size() != 4: quit(1); return
	for b in bestas:
		b.set_physics_process(false)
		b.disparou.connect(registrar.bind(b))
	if tela:
		root.size = Vector2i(1600, 900)
		root.content_scale_size = root.size
		camera = Camera3D.new()
		current_scene.add_child(camera)
	for b in bestas:
		await limpar()
		registros.clear()
		b.global_position = Vector3(0, .02, 0)
		b.origem = b.global_position
		b.praia = b.global_position
		b.rotation = Vector3.ZERO
		b.velocity = Vector3.ZERO
		b.iniciar_rotina()
		b._recarga = 0
		jogador.global_position = Vector3(0, .9, -25)
		b.set_physics_process(true)
		await quadros(30)
		if not b.boss():
			ok(not b.agressiva and registros.is_empty(), b.especie + ": proximidade não provoca")
			b.take_damage(1, jogador.global_position)
		var corporal := false
		var fotos := {}
		for i in 900:
			await physics_frame
			corporal = corporal or b.estado == "atacando"
			if tela and b.estado == "disparando_ataque":
				var nome: String = b.ataque_atual + ("_preparo" if b.animador.tempo < 1.08 else "_disparo")
				if b.animador.tempo > .7 and not fotos.has(nome) and (b.animador.tempo < 1.08 or b.animador.tempo > 1.32):
					fotos[nome] = true
					await foto(b.especie + "_" + nome, b)
			if registros.size() >= 6 and b.estado == "idle": break
		if registros.size() != 6:
			print("DIAG ", b.especie, " estado=", b.estado, " pos=", b.global_position, " alvo=", b.alvo, " agressiva=", b.agressiva, " visivel=", b._visivel(jogador), " hp=", jogador.health, " yaw=", b.rotation.y, " perdido=", b._perdido)
		ok(registros.size() == 6, b.especie + ": IA alterna cinco bolhas e um raio (%d)" % registros.size())
		ok(not corporal, b.especie + ": IA não usa ataques corporais")
		if registros.size() >= 6:
			var simultaneas := true
			for i in 5:
				simultaneas = simultaneas and registros[i].tipo == "bolha" and registros[i].frame == registros[0].frame
			ok(simultaneas, b.especie + ": salva realmente simultânea")
			ok(registros[5].tipo == "compressor", b.especie + ": segundo ataque é compressor")
			ok(registros.all(func(r): return r.boca < .01), b.especie + ": ataques saem da boca animada")
			ok((registros[0].rumo as Vector3).angle_to(registros[4].rumo) > .3, "bolhas abrem em leque")
		b.set_physics_process(false)
		b.mudar("idle")
		b.global_position = Vector3(70, 0, 70)
	await limpar()
	var b: Node = bestas[0]
	b.global_position = Vector3(0, .02, 0)
	b.rotation = Vector3.ZERO
	b.alvo = jogador
	jogador.remove_meta("damage_immune")
	var Raio = load("res://src/historia/bestas_mar/raio_compressor.gd")
	var Bolha = load("res://src/historia/bestas_mar/bolha_de_agua.gd")
	# Projétil real mede impulso no controlador do jogador, não só o argumento.
	jogador.global_position = Vector3(0, .9, -15)
	jogador._vida.restaurar()
	jogador._vida._empurrao = Vector3.ZERO
	var hp: float = jogador.health
	var bolha = Bolha.new()
	bolha.atirador = b
	bolha.rumo = Vector3.FORWARD
	current_scene.add_child(bolha)
	bolha.global_position = Vector3(0, 1.2, -10)
	await quadros(45)
	ok(is_equal_approx(hp - jogador.health, 6), "bolha dá um acerto de dano")
	ok(jogador._vida._empurrao.length() >= 10, "bolha aplica knockback real no jogador")
	ok(not is_instance_valid(bolha), "bolha desaparece após impacto")
	# Colisão do jato: comprimento visível termina no primeiro obstáculo.
	b.ataque_atual = "compressor"
	b.mudar("disparando_ataque")
	b.animador.avancar(1.1)
	var boca: Vector3 = b.animador.boca()
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 20, .1)
	cs.shape = box
	parede.add_child(cs)
	current_scene.add_child(parede)
	parede.global_position = boca + Vector3(0, 0, -7)
	jogador.global_position = boca + Vector3(0, -.5, -15)
	await quadros(3)
	hp = jogador.health
	var raio = Raio.new()
	raio.atirador = b
	raio.rumo = Vector3.FORWARD
	current_scene.add_child(raio)
	await quadros(10)
	ok(jogador.health == hp and raio.comprimento < 7, "parede bloqueia dano e extensão visual do compressor")
	await quadros(45)
	ok(not is_instance_valid(raio), "raio expira sem alvo atingido")
	parede.queue_free()
	await quadros(3)
	raio = Raio.new()
	raio.atirador = b
	raio.rumo = Vector3.FORWARD
	current_scene.add_child(raio)
	await quadros(25)
	ok(is_equal_approx(hp - jogador.health, 12), "compressor atinge uma única vez durante todo o jato")
	ok(raio.global_position.distance_to(b.animador.boca()) < .01, "raio permanece preso à boca")
	await quadros(25)
	ok(not is_instance_valid(raio), "raio termina após duração configurada")
	# Sair da linha antes de atirar é uma esquiva válida.
	hp = jogador.health
	jogador.global_position.x += 5
	await quadros(3)
	raio = Raio.new()
	raio.atirador = b
	raio.rumo = Vector3.FORWARD
	current_scene.add_child(raio)
	await quadros(45)
	ok(jogador.health == hp, "compressor não persegue alvo que saiu da linha")
	# Repetição, interrupção e limpeza não dependem de timers soltos.
	for i in 5:
		b.mudar("idle")
		b.mudar("disparando_ataque")
		raio = Raio.new()
		raio.atirador = b
		raio.rumo = Vector3.FORWARD
		current_scene.add_child(raio)
		await quadros(3)
		b.take_damage(1, jogador.global_position)
		await quadros(3)
		ok(not is_instance_valid(raio), "dano interrompe raio ativo, repetição %d" % i)
	await limpar()
	ok(get_nodes_in_group("efeitos_agua_bestas").is_empty(), "sem nós de água após cinco interrupções")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	current_scene.queue_free()
	current_scene = null
	await quadros(5)
	print("ATAQUES AGUA: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
