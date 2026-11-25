extends SceneTree
## Integração no modo história com mapa/progresso isolados; teclado real e rig real.
var MODO: GDScript
const FICHA = preload("res://src/historia/pets/ficha_montaria.gd")
var falhas := 0
var j: CharacterBody3D
var c: Node
var hud: Node
var companhia: Node

func _init() -> void:
	rodar.call_deferred()

func ok(valor: bool, texto: String) -> void:
	print(("  ✅ " if valor else "  ❌ ") + texto)
	if not valor: falhas += 1

func quadros(n: int) -> void:
	for i in n: await physics_frame

func tecla(k: Key, ligada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = ligada
	Input.parse_input_event(e)

func y() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_Y
	e.physical_keycode = KEY_Y
	e.pressed = true
	hud._unhandled_input(e)

func rodar() -> void:
	MODO = load("res://src/historia/ModoHistoria.gd")
	MODO.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	MODO.progresso_forcado = "user://teste_nado_montaria.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MODO.progresso_forcado))
	root.get_node("GameFlow").start_story()
	await quadros(100)
	j = current_scene.jogador_local()
	c = current_scene.get_node("Montarias")
	hud = current_scene.get_node("HistoriaHud")
	companhia = current_scene.get_node("Companhia")
	var bib := MapaMontador.biblioteca_em_uso()
	for id: String in ["horse", "cavalo_da_vila_leve", "animals__farm__horse_1__base", "caranguejo_grande"]:
		ok(FICHA.classificado(bib, id), "categoria Montarias persistente: " + id)
	ok(not FICHA.classificado(bib, "cow"), "vaca continua não montável")
	for especie: String in ["caranguejo", "horse"]:
		var id: String = especie if especie == "caranguejo" else current_scene.progressao.adicionar_pet(especie, "Cavalo teste")
		ok(companhia.chamar(id), "invocar " + especie)
		await quadros(35)
		var pet: CharacterBody3D = companhia.pet_fora(id)
		j.global_position = pet.global_position + Vector3(2.0, .9, 0)
		j.velocity = Vector3.ZERO
		await quadros(3)
		var camada := j.collision_layer
		var mascara := j.collision_mask
		ok(c.candidato() == pet, "Y encontra " + especie)
		y()
		await quadros(20)
		ok(c.ativa() and j.montaria == c and not pet.is_physics_processing(), "Y monta e suspende IA: " + especie)
		if not c.ativa(): continue
		ok(not j.corpo_livre_para_golpe(), "montado não inicia ataque a pé")
		ok(not companhia.chamar(id), "chamar montaria ocupada não teleporta")
		var origem := pet.global_position
		j._yaw = 0
		tecla(KEY_W, true)
		await quadros(90)
		var andou := pet.global_position.distance_to(origem)
		ok(andou > 3 and andou < 7, "W conduz %s (%.2f m)" % [especie, andou])
		var andar := pet.get_real_velocity().length()
		tecla(KEY_SHIFT, true)
		await quadros(45)
		ok(pet.get_real_velocity().length() > andar * 1.5, "Shift acelera " + especie)
		tecla(KEY_SHIFT, false)
		tecla(KEY_W, false)
		await quadros(35)
		var altura := pet.position.y
		tecla(KEY_SPACE, true)
		await quadros(12)
		tecla(KEY_SPACE, false)
		ok(pet.position.y > altura + .25, "Espaço salta " + especie)
		await quadros(60)
		hud.alternar_status()
		origem = pet.global_position
		tecla(KEY_W, true)
		await quadros(30)
		tecla(KEY_W, false)
		ok(pet.global_position.distance_to(origem) < .1, "menu bloqueia condução")
		y()
		ok(c.ativa(), "menu bloqueia Y")
		hud.alternar_status()
		y()
		await quadros(5)
		ok(not c.ativa() and pet.is_physics_processing() and j.collision_layer == camada and j.collision_mask == mascara, "Y desmonta e restaura física: " + especie)
		j.global_position = pet.global_position + Vector3(2, .9, 0)
		await quadros(3)
		y()
		ok(c.ativa(), "remonta " + especie)
		companhia.recolher(id)
		await quadros(4)
		ok(not c.ativa() and j.montaria == null and j.collision_mask == mascara, "guardar pet desmonta e restaura jogador")
	await editor()
	await obstaculos()
	await nado()
	MODO.mapa_forcado = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MODO.progresso_forcado))
	MODO.progresso_forcado = ""
	print("NADO_MONTARIA_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)

func caixa(pos: Vector3, tamanho: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tamanho
	col.shape = forma
	corpo.add_child(col)
	current_scene.add_child(corpo)
	corpo.position = pos
	return corpo

func obstaculos() -> void:
	j.global_position = Vector3(0, .9, 0)
	companhia.chamar()
	await quadros(10)
	var pet: CharacterBody3D = companhia.invocado
	pet.set_physics_process(false)
	pet.position = Vector3(3, .05, 0)
	j.set_physics_process(false)
	var parede := caixa(Vector3(1.5, 2, 0), Vector3(.3, 4, 8))
	await quadros(3)
	ok(c.candidato() == null, "parede impede montar através dela")
	parede.queue_free()
	await quadros(3)
	j.position = Vector3(20, .9, 0)
	ok(c.candidato() == null, "distância impede montar")
	j.position = Vector3(1, .9, 0)
	var teto := caixa(Vector3(3, 1.9, 0), Vector3(4, .2, 4))
	await quadros(3)
	ok(not c.montar(pet), "teto baixo impede montar")
	teto.queue_free()
	await quadros(3)
	ok(c.montar(pet), "sem teto monta normalmente")
	var obstaculo := caixa(Vector3(3, 2, -3), Vector3(12, 4, .3))
	await quadros(3)
	for i in 120:
		c.conduzir(Vector3.FORWARD, true, false, 1.0/60)
		await physics_frame
	ok(pet.position.z > -2.1, "colisão da montaria impede atravessar parede")
	obstaculo.queue_free()
	await quadros(3)
	var prisao := caixa(pet.position + Vector3.UP, Vector3(14, 5, 14))
	await quadros(3)
	ok(not c.desmontar() and c.ativa(), "sem espaço, desmontagem mantém o vínculo")
	prisao.queue_free()
	await quadros(3)
	j.set_meta("is_frozen", true)
	c.atualizar(1.0/60)
	ok(not c.ativa(), "congelamento desmonta e libera a recuperação do jogador")
	j.set_meta("is_frozen", false)
	j.position = pet.position + Vector3(2, .9, 0)
	ok(c.montar(pet), "remonta após interrupção")
	j.net_force_respawn()
	ok(not c.ativa() and j.montaria == null and j.collision_mask != 0, "renascimento encerra montaria antes de reposicionar")
	j.position = pet.position + Vector3(2, .9, 0)
	ok(c.montar(pet), "remonta após renascimento")
	pet.health = 0
	c.atualizar(1.0 / 60)
	ok(not c.ativa() and j.collision_mask != 0, "morte do pet desmonta")
	companhia.recolher()
	j.set_physics_process(true)

func nado() -> void:
	var nivel := AguaDoMundo.nivel_em(300, 0)
	j.global_position = Vector3(300, nivel - .4, 0)
	j.velocity = Vector3.ZERO
	j._yaw = 0
	await quadros(120)
	ok(j.modo_na_agua == "nadando", "boia parado")
	tecla(KEY_W, true)
	await quadros(90)
	var anim: Node = j._proc_anim
	var torso: Node3D = anim._n.Torso
	var cabeca: Node3D = anim._n.Head
	var frente: Vector3 = -j._char_model.global_basis.z
	ok((cabeca.global_position - torso.global_position).dot(frente) > .3, "crawl inclina cabeça à frente do quadril no rig real")
	var estados := 0
	var minimo := INF
	var maximo := -INF
	var mao_min := INF
	var mao_max := -INF
	var cotovelos := Vector2(-INF, -INF)
	var alternancia := Vector2(INF, -INF)
	for i in 180:
		await physics_frame
		if j.modo_na_agua != "nadando": estados += 1
		minimo = minf(minimo, j.position.y)
		maximo = maxf(maximo, j.position.y)
		var mao: Node3D = anim._n.Hand_L
		var alcance := (mao.global_position - torso.global_position).dot(frente)
		mao_min = minf(mao_min, alcance)
		mao_max = maxf(mao_max, alcance)
		cotovelos.x = maxf(cotovelos.x, (anim._n.ForeArm_L as Node3D).global_position.y - nivel)
		cotovelos.y = maxf(cotovelos.y, (anim._n.ForeArm_R as Node3D).global_position.y - nivel)
		var diferenca: float = ((anim._n.Hand_L as Node3D).global_position - (anim._n.Hand_R as Node3D).global_position).dot(frente)
		alternancia.x = minf(alternancia.x, diferenca)
		alternancia.y = maxf(alternancia.y, diferenca)
	ok(estados == 0 and maximo - minimo < .12, "crawl estável por 3 s: mudanças=%d variação=%.3f m" % [estados, maximo - minimo])
	ok(mao_max - mao_min > .45, "braçada percorre amplitude real: %.3f m" % (mao_max - mao_min))
	ok(cotovelos.x > .04 and cotovelos.y > .04, "ambos cotovelos recuperam acima da água: " + str(cotovelos))
	ok(alternancia.x < -.15 and alternancia.y > .15, "mãos se alternam na frente: " + str(alternancia))
	tecla(KEY_W, false)
	await quadros(90)
	ok(absf(torso.rotation.x) < .2, "parando volta a boiar verticalmente")
	j.position = Vector3(0, 1, 0)
	j.velocity = Vector3.ZERO
	await quadros(50)
	ok(j.modo_na_agua == "" and float(anim._swim_w) < .01, "em terra sai do nado suavemente")

func editor() -> void:
	var bib := MapaMontador.biblioteca_em_uso()
	var pasta := "user://biblioteca_montaria_teste"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(bib.raiz.path_join("catalogo.json")), ProjectSettings.globalize_path(pasta.path_join("catalogo.json")))
	var copia := BibliotecaDeModelos.new(pasta)
	var ids: Array[String] = ["horse"]
	ok(copia.marcar_categoria(ids, "montarias", false) == OK, "editor permite remover classificação")
	copia.recarregar()
	ok(not FICHA.classificado(copia, "horse"), "remoção persiste no catálogo")
	ok(copia.marcar_categoria(ids, "montarias", true) == OK, "editor permite marcar montaria")
	copia.recarregar()
	ok(FICHA.classificado(copia, "horse"), "classificação adicionada persiste")
	var raiz := Node3D.new()
	current_scene.add_child(raiz)
	var pecas: Array[Dictionary] = []
	for id: String in ["caranguejo_grande", "cavalo_da_vila_leve"]:
		var p := {"id": "teste_" + id, "tipo": "modelo", "modelo": id, "posicao": Vector3(30, 1.5, 0), "tamanho": bib.tamanho_padrao(id) * Vector3(1.8, 1.4, 1.2), "rotacao_graus": Vector3(0, 35, 0)}
		var marcador := Node3D.new()
		marcador.name = p.id
		raiz.add_child(marcador)
		pecas.append(p)
	ok(companhia.ligar_no_mapa(raiz, {"pecas": pecas}, bib) == 2, "pets classificados colocados no editor ganham controlador na história")
	for pet in raiz.get_children():
		pet.set_physics_process(false)
		j.set_physics_process(false)
		j.position = pet.position + Vector3(2, .9, 0)
		await quadros(3)
		ok(c.montar(pet), "monta no pet escalado do editor: " + pet.name)
		if c.ativa():
			c.conduzir(Vector3.ZERO, false, false, 1.0/60)
			var visual: Node3D = pet.get("visual") if c.perfil.largo else pet.get("_visual")
			var quadril: Node3D = j._proc_anim._n.Torso
			ok(quadril.global_position.distance_to(visual.to_global(c.perfil.assento)) < .001, "assento acompanha escala do pet sem duplicá-la")
			c.desmontar(true)
		if pet is PetDomado:
			var nativo: Vector3 = bib.info(pet.especie)["tamanho"]
			var esperado: Vector3 = bib.tamanho_padrao(pet.especie) * Vector3(1.8, 1.4, 1.2)
			ok((pet.animador._base_escala * nativo).is_equal_approx(esperado) and pet.scale.is_equal_approx(Vector3.ONE), "escala XYZ de repouso preservada com corpo físico unitário (respiração anima a escala visual)")
		pet.remove_from_group("pets_historia")
	raiz.queue_free()
	j.position = Vector3(0, 1, 0)
	j.set_physics_process(true)
	await quadros(5)
