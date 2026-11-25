extends SceneTree
## Cena real da história com quatro peças da loja, água e saves isolados.
const MAPA := "user://test_bestas_comportamento.json"
const SAVE := "user://test_bestas_progresso.json"
var total := 0
var falhas := 0
var jogador: Node
var bestas: Array[Node] = []
var tela := false
var camera: Camera3D


func foto(nome: String, besta: Node3D) -> void:
	if not tela:
		return
	camera.global_position = besta.global_position + besta.global_basis * Vector3(22, 13, -28)
	camera.look_at(besta.global_position + Vector3(0, 5, 0))
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/bestas_mar/comportamento/jogo_" + nome + ".png")


func _init() -> void:
	rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func verificar(sim: bool, texto: String) -> void:
	total += 1
	falhas += 0 if sim else 1
	print(("OK " if sim else "FALHA ") + texto)


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(128, 2, 128)
	for i in 4:
		var tipo: String = ["bovina", "girafa", "javali", "serpente"][i]
		var id := "besta_mar_" + tipo
		var tamanho := bib.tamanho_padrao(id)
		mapa.pecas.append({"id": tipo, "tipo": "modelo", "modelo": id,
			"posicao": Vector3(54 if i < 3 else 90, tamanho.y / 2, -38 + i * 24),
			"tamanho": tamanho, "rotacao_graus": Vector3.ZERO,
			"colisao": true, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0})
	verificar(MapaArquivo.salvar(MAPA, mapa) == OK, "fixture com quatro espécies salva")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	jogador = get_first_node_in_group("player")
	bestas = get_nodes_in_group("bestas_do_mar")
	verificar(bestas.size() == 4, "quatro modelos do editor viram criaturas")
	if bestas.size() != 4:
		quit(1)
		return
	if tela:
		camera = Camera3D.new()
		current_scene.add_child(camera)
		root.size = Vector2i(1280, 720)
		root.content_scale_size = root.size
		await foto("rotina", bestas[0])
	jogador.set_meta("damage_immune", true)
	var boss: Node
	for b in bestas:
		if b.boss():
			boss = b
			continue
		verificar(not b.agressiva and not b.is_in_group("enemy"), "%s: começa pacífica" % b.especie)
		verificar(b.is_in_group(AlvosDeGolpe.GRUPO), "%s: pode receber ataque sem ser hostil" % b.especie)
		# Clips nas quatro peles: pose real e loops independentes entre criaturas.
		var ap: AnimationPlayer = b.animador.player
		for clip in ["dormindo", "nadando_walk", "nadando_run", "idle", "irritado", "atacando", "recebendo_dano", "disparando_ataque", "comendo"]:
			verificar(ap.has_animation(clip) and ap.get_animation(clip).length > .3, "%s: %s importado" % [b.especie, clip])
		verificar(ap.get_animation("nadando_walk").loop_mode == Animation.LOOP_LINEAR and ap.get_animation("atacando").loop_mode == Animation.LOOP_NONE, "loop de nado e ataque único")
	verificar(boss.is_in_group("enemy") and boss.boss(), "Sea Serpent é boss hostil")
	# Proximidade não provoca os pacíficos; dano zero não os irrita.
	var mansa: Node = bestas[0]
	jogador.global_position = mansa.global_position + Vector3(0, .9, -9)
	jogador.velocity = Vector3.ZERO
	await quadros(120)
	verificar(not mansa.agressiva, "aproximar não provoca a besta pacífica")
	mansa.take_damage(0.0, jogador.global_position)
	verificar(not mansa.agressiva, "dano zero não provoca")
	var vida: float = mansa.health
	CombatResolver.aplicar(mansa, 2, 0, 0, jogador.global_position, Vector3.ZERO, .2, 0, false, jogador)
	verificar(mansa.agressiva and mansa.is_in_group("enemy") and mansa.estado == "recebendo_dano" and mansa.health == vida - 2, "dano real acorda, anima reação e ativa revide")
	await foto("reacao", mansa)
	var vistos := {}
	for i in 600:
		if vistos.has("disparando_ataque"): break
		vistos[mansa.estado] = true
		await quadros(1)
	verificar(vistos.has("irritado") and vistos.has("disparando_ataque"), "reação transita para ameaça e ataque")
	jogador.global_position = Vector3(-50, .9, 50)
	jogador.velocity = Vector3.ZERO
	await quadros(400)
	verificar(not mansa.agressiva and not mansa.is_in_group("enemy"), "afastamento acalma o pacífico")
	verificar(mansa.estado in ["nadando_walk", "dormindo", "idle", "comendo"], "volta à rotina na praia")
	# Natação com flutuação: a besta mantém a superfície na parte baixa do tronco.
	mansa.global_position = Vector3(130, -3.85, -35)
	mansa.velocity = Vector3.ZERO
	mansa.mar = Vector3(145, -3.85, -35)
	mansa._banho = true
	mansa._voltando = false
	mansa._destino = mansa.mar
	mansa._rotina = 20.0
	await quadros(90)
	await foto("nadando", mansa)
	verificar(mansa.nadando and mansa.estado == "nadando_walk", "passeio na água usa nadando walk")
	var nivel := AguaDoMundo.superficie_em(mansa.global_position.x, mansa.global_position.z)
	verificar(absf(mansa.global_position.y - (nivel - mansa._calado)) < 1.0, "flutua na superfície real do oceano")
	jogador.global_position = mansa.global_position + Vector3(18, 3.0, 0)
	mansa.take_damage(1, jogador.global_position)
	await quadros(160)
	verificar(mansa.estado == "nadando_run" or mansa.estado == "disparando_ataque", "revide nadando usa run e alcança ataque")
	jogador.global_position = Vector3(-50, .9, 50)
	mansa.global_position = Vector3(125, -3.85, -35)
	mansa.velocity = Vector3.ZERO
	mansa.iniciar_rotina()
	await quadros(1400)
	verificar(not mansa.nadando and mansa.global_position.distance_to(mansa.praia) < 4.0, "retorna do mar à praia sem prender na borda: %s" % mansa.global_position)
	# Preparação da bolha, disparo único e origem na boca.
	boss.global_position = Vector3(103, -3.85, 36)
	boss.velocity = Vector3.ZERO
	boss.iniciar_rotina()
	jogador.global_position = Vector3(55, .9, 36)
	jogador.velocity = Vector3.ZERO
	var tiros: Array[Node3D] = []
	var erros_de_boca: Array[float] = []
	boss.disparou.connect(func(bolha: Node3D):
		tiros.append(bolha)
		erros_de_boca.append(bolha.global_position.distance_to(boss.animador.boca()))
		foto.call_deferred("boss_bolha", boss))
	var estados_boss := {}
	for i in 600:
		if tiros.size() >= 5: break
		estados_boss[boss.estado] = true
		await quadros(1)
	verificar(estados_boss.has("irritado") and estados_boss.has("disparando_ataque"), "boss detecta jogador e prepara disparo sem apanhar")
	verificar(tiros.size() == 5 and erros_de_boca.all(func(v): return v < .01), "cinco bolhas simultâneas nascem na boca")
	# Receber dano durante preparo deve cancelar o projétil futuro.
	boss.alvo = jogador
	boss.mudar("disparando_ataque")
	await quadros(15)
	var tiros_antes := tiros.size()
	boss.take_damage(1.0, jogador.global_position)
	await quadros(30)
	verificar(tiros.size() == tiros_antes and boss.estado == "recebendo_dano", "dano interrompe disparo em preparo")
	# O clipe corporal antigo permanece no asset, mas já não aplica dano.
	jogador.set_physics_process(false)
	for b in bestas:
		b.set_physics_process(false)
	jogador.remove_meta("damage_immune")
	for b in bestas:
		if b.boss(): continue
		b.global_position = Vector3(20, .05, -20)
		b.rotation.y = 0.0
		b.velocity = Vector3.ZERO
		b.alvo = jogador
		b.mudar("atacando")
		b.animador.avancar(b.animador.duracao() * .55)
		var boca: Vector3 = b.animador.boca()
		jogador.global_position = Vector3(boca.x, .9, boca.z)
		jogador._vida.restaurar()
		await quadros(3)
		var vida_antes: float = jogador.health
		b._atualizar_acao()
		verificar(jogador.health == vida_antes, "%s: contato do corpo não dá dano" % b.especie)
		b._atualizar_acao()
		verificar(jogador.health == vida_antes, "atualização repetida não reativa mordida")
		b.global_position = b.origem
		b.iniciar_rotina()
	jogador._vida.restaurar()
	# Colisão contínua: dano único, parede bloqueia e projétil pode ser esquivado.
	for b in bestas:
		b.set_physics_process(false)
	for tiro in tiros:
		if is_instance_valid(tiro): tiro.queue_free()
	jogador.global_position = Vector3(0, .9, 0)
	jogador.velocity = Vector3.ZERO
	await quadros(5)
	var hp: float = jogador.health
	var tiro_teste = load("res://src/historia/bestas_mar/bolha_de_agua.gd").new()
	tiro_teste.atirador = boss
	tiro_teste.rumo = Vector3.BACK
	current_scene.add_child(tiro_teste)
	tiro_teste.global_position = jogador.global_position + Vector3(0, 0, -4)
	await quadros(40)
	verificar(is_equal_approx(hp - jogador.health, 6.0) and not is_instance_valid(tiro_teste), "bolha acerta jogador uma vez e desaparece")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 5, .2)
	shape.shape = box
	wall.add_child(shape)
	current_scene.add_child(wall)
	jogador.global_position = Vector3(0, .9, 0)
	jogador.velocity = Vector3.ZERO
	wall.global_position = Vector3(0, 2, -2)
	await quadros(3)
	hp = jogador.health
	tiro_teste = load("res://src/historia/bestas_mar/bolha_de_agua.gd").new()
	tiro_teste.atirador = boss
	tiro_teste.rumo = Vector3.BACK
	current_scene.add_child(tiro_teste)
	tiro_teste.global_position = Vector3(0, .9, -5)
	await quadros(40)
	verificar(is_equal_approx(hp, jogador.health) and not is_instance_valid(tiro_teste), "parede bloqueia bolha sem dano através dela")
	wall.queue_free()
	await quadros(2)
	tiro_teste = load("res://src/historia/bestas_mar/bolha_de_agua.gd").new()
	tiro_teste.atirador = boss
	tiro_teste.rumo = Vector3.BACK
	current_scene.add_child(tiro_teste)
	tiro_teste.global_position = Vector3(0, .9, -5)
	jogador.global_position.x = 5
	await quadros(45)
	verificar(is_equal_approx(hp, jogador.health), "sair da trajetória esquiva a bolha sem perseguição teleguiada")
	tiro_teste.queue_free()
	# Morte para IA, colisões e projéteis; revive pacífico sem hostilidade antiga.
	mansa.take_damage(10000)
	verificar(not mansa.vivo() and mansa.collision_layer == 0 and not mansa.is_in_group("enemy"), "morte remove combate/colisão")
	mansa.reviver()
	verificar(mansa.health == mansa.max_health and not mansa.agressiva and mansa.global_position == mansa.origem, "reviver restaura spawn e temperamento")
	boss.take_damage(10000)
	await quadros(5)
	var restantes := 0
	for tiro in tiros:
		if is_instance_valid(tiro): restantes += 1
	verificar(restantes == 0, "morte do boss limpa suas bolhas")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAPA))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("COMPORTAMENTO BESTAS: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
