extends SceneTree
## Integração do vendaval com corpos/controladores reais da história.
## O relógio de cinco segundos nunca é encurtado para fazer este teste passar.
const TORNADO := "res://src/historia/bosses/harpia/tornado_vendaval.gd"
const HARPIA := "res://src/historia/bosses/harpia/harpia_da_ilha.gd"
const ID := "harpia_-_animated_low_poly"
var falhas := 0
var j: CharacterBody3D
var bib: BibliotecaDeModelos
var modo: GDScript
var boss: AnimalDaIlha

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, texto: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + texto)
	if not cond: falhas += 1

func quadros(n: int) -> void:
	for i in n: await physics_frame

func rodar() -> void:
	modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = "user://test_harpia_vendaval.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	root.get_node("GameFlow").start_story()
	await quadros(100)
	j = current_scene.jogador_local()
	bib = MapaMontador.biblioteca_em_uso()
	boss = novo_boss()
	await habilidade_do_boss()
	await duracao_e_entrada_tardia()
	await tipos_e_cancelamento()
	await parede()
	await respawn()
	await montaria()
	await piloto()
	await capturas_concorrentes()
	await morte_da_conjuradora()
	boss.queue_free()
	await quadros(5)
	ok(get_nodes_in_group("tornados_harpia").is_empty(), "nenhum tornado residual ao concluir cenários")
	modo.mapa_forcado = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	modo.progresso_forcado = ""
	print("HARPIA_VENDAVAL_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)

func novo_boss() -> AnimalDaIlha:
	var b: AnimalDaIlha = load(HARPIA).new()
	var ficha := bib.ficha_de_animal(ID)
	b.montar(bib, ID, ficha, {"id": "harpia_teste", "centro": Vector3.ZERO,
		"meio": Vector3(80, 40, 80), "base": Basis.IDENTITY, "ficha": ficha})
	b.position = Vector3(0, 12, -30)
	b.ponto_de_origem = b.position
	current_scene.add_child(b)
	return b

func tornado(onde: Vector3) -> Node3D:
	var t: Node3D = load(TORNADO).new()
	t.position = onde
	t.configurar(boss, Vector3.BACK)
	current_scene.add_child(t)
	return t

func capturado(no: Node) -> bool:
	return is_instance_valid(no) and no.has_meta("captura_vento") and is_instance_valid(no.get_meta("captura_vento"))

func livre(no: Node) -> bool:
	return is_instance_valid(no) and not capturado(no) and not (no.has_meta("arremesso_vento") and is_instance_valid(no.get_meta("arremesso_vento")))

func preparar_jogador(onde := Vector3(0, .9, 0)) -> void:
	j.net_force_respawn()
	await quadros(8)
	j.global_position = onde
	j.velocity = Vector3.ZERO
	await quadros(3)

func duracao_e_entrada_tardia() -> void:
	await preparar_jogador()
	var camada := j.collision_layer
	var mascara := j.collision_mask
	var hp: float = j.health
	var t := tornado(Vector3(0, 0, -1))
	var tardio := NpcDaIlha.new()
	tardio.tipo = "npc_domador"
	tardio.position = Vector3(60, 0, 0)
	current_scene.add_child(tardio)
	var visto_inicio := false
	var visto_tardio := false
	var soltou := false
	var fim := 0
	var primeira_captura: Node
	var mesmo_dono := true
	var lancou := false
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	for i in 325:
		await physics_frame
		if not is_instance_valid(t):
			fim = i + 1
			soltou = not capturado(j) and not capturado(tardio)
			lancou = j.esta_arremessado()
			break
		if capturado(j):
			visto_inicio = true
			if primeira_captura == null: primeira_captura = j.get_meta("captura_vento")
			mesmo_dono = mesmo_dono and j.get_meta("captura_vento") == primeira_captura
		if i == int(4.0 / tick): tardio.global_position = t.global_position + Vector3(0, 0, .5)
		visto_tardio = visto_tardio or capturado(tardio)
	ok(visto_inicio and mesmo_dono, "jogador capturado cedo tem um único dono do movimento")
	ok(visto_tardio, "NPC estático que entra no quarto segundo é capturado")
	ok(absf(fim * tick - 5.0) <= tick * 1.1, "relógio único termina em %.3f s, incluindo entrada tardia" % (fim * tick))
	ok(soltou and lancou, "fim do tornado lança o jogador e solta também o NPC tardio")
	ok(is_equal_approx(float(j.health), hp), "vendaval não acrescenta dano contínuo não solicitado")
	ok(j.collision_layer == camada and j.collision_mask == mascara, "lançamento restaura colisões do jogador")
	await quadros(360)
	ok(livre(j) and livre(tardio) and tardio.process_mode != Node.PROCESS_MODE_DISABLED,
		"jogador e NPC recuperam controle após pousar")
	tardio.queue_free()

func tipos_e_cancelamento() -> void:
	await preparar_jogador(Vector3(30, .9, 0))
	var companhia: Node = current_scene.get_node("Companhia")
	var id: String = current_scene.progressao.adicionar_pet("horse", "Cavalo vendaval", ModoDoPet.LIVRE)
	ok(companhia.chamar(id), "pet real é invocado pelo inventário")
	await quadros(5)
	var pet: CharacterBody3D = companhia.pet_fora(id)
	if pet == null: return
	pet.global_position = Vector3(0, .05, 0)
	ok(pet.collision_layer == 0, "pet conserva camada zero antes da captura")
	var animal := AnimalDaIlha.new()
	var f := bib.ficha_de_animal("cow")
	animal.montar(bib, "cow", f, {"centro": Vector3.ZERO, "meio": Vector3.ONE * 50, "base": Basis.IDENTITY})
	animal.position = Vector3(1, .05, 1)
	current_scene.add_child(animal)
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_domador"
	npc.position = Vector3(-1, 0, 1)
	current_scene.add_child(npc)
	var objeto := StaticBody3D.new()
	objeto.position = Vector3(0, 0, 1)
	current_scene.add_child(objeto)
	var t := tornado(Vector3(0, 0, -1))
	var viram := [false, false, false]
	for i in 50:
		await physics_frame
		for k in 3: viram[k] = viram[k] or capturado([pet, animal, npc][k])
	ok(viram.all(func(v): return v), "pet camada zero, animal e NPC estático são capturados (%s)" % str(viram))
	ok(not capturado(objeto) and not capturado(boss), "cenário e conjuradora ficam fora da captura")
	ok(pet.global_position.distance_to(j.global_position) > 15, "pet não teleporta para o dono durante a captura")
	t.cancelar()
	await quadros(360)
	ok(livre(pet) and livre(animal) and livre(npc), "cancelamento libera todos os tipos sem estados presos")
	ok(pet.collision_layer == 0 and animal.collision_layer == 1 and npc.collision_layer == 1,
		"camadas originais restauradas após cancelamento")
	companhia.recolher(id)
	animal.queue_free()
	npc.queue_free()
	objeto.queue_free()
	await quadros(3)

func parede() -> void:
	await preparar_jogador()
	var obstaculo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(20, 12, .4)
	col.shape = forma
	obstaculo.add_child(col)
	obstaculo.position = Vector3(0, 6, 7)
	current_scene.add_child(obstaculo)
	await quadros(3)
	var t := tornado(Vector3(0, 0, -1))
	var maior_z := j.position.z
	var viu := false
	for i in 305:
		await physics_frame
		if capturado(j):
			viu = true
			maior_z = maxf(maior_z, j.position.z)
	ok(viu and maior_z < 7.2, "capturado não atravessa parede (z máximo %.2f)" % maior_z)
	ok(not is_instance_valid(t) and not capturado(j), "parede não impede expiração aos cinco segundos")
	obstaculo.queue_free()
	await quadros(5)

func respawn() -> void:
	await preparar_jogador()
	var t := tornado(Vector3(0, 0, -1))
	await quadros(12)
	ok(capturado(j), "jogador capturado antes do respawn")
	j.net_force_respawn()
	await quadros(2)
	ok(livre(j) and j.process_mode != Node.PROCESS_MODE_DISABLED, "respawn remove imediatamente o vínculo de vento")
	t.cancelar()
	await quadros(4)
	ok(j.corpo_livre_para_golpe(), "respawn devolve capacidade de atacar")

func montaria() -> void:
	await preparar_jogador()
	var companhia: Node = current_scene.get_node("Companhia")
	var montarias: Node = current_scene.get_node("Montarias")
	ok(companhia.chamar("caranguejo"), "invoca montaria existente")
	await quadros(20)
	var pet: CharacterBody3D = companhia.pet_fora("caranguejo")
	if pet == null: return
	j.global_position = pet.global_position + Vector3(2, .9, 0)
	await quadros(3)
	ok(montarias.montar(pet), "monta pelo controlador real")
	if not montarias.ativa():
		companhia.recolher("caranguejo"); return
	var origem := j.global_position
	var t := tornado(Vector3(origem.x, pet.global_position.y, origem.z - 1))
	var pegou_j := false
	var pegou_pet := false
	for i in 30:
		await physics_frame
		pegou_j = pegou_j or capturado(j)
		pegou_pet = pegou_pet or capturado(pet)
	ok(pegou_j and pegou_pet and not montarias.ativa(), "cavaleiro e montaria tornam-se capturas independentes")
	t.cancelar()
	await quadros(360)
	ok(livre(j) and livre(pet) and j.montaria == null, "cancelamento não deixa montaria ou cavaleiro travados")
	companhia.recolher("caranguejo")

func piloto() -> void:
	await preparar_jogador()
	var nav: Node = current_scene.get("_navegacao")
	var barco: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
	ok(barco.configurar(bib, "boat", bib.tamanho_padrao("boat")), "barco de produção configurado para teste do piloto")
	barco.position = Vector3(300, AguaDoMundo.superficie_em(300, 0), 0)
	current_scene.add_child(barco)
	nav.barcos.append(barco)
	j.global_position = barco.leme.global_position + Vector3.UP * .85
	j.velocity = Vector3.ZERO
	await quadros(3)
	ok(nav.assumir(barco), "jogador assume o leme pelo controlador real")
	if not nav.ativo():
		nav.barcos.erase(barco)
		barco.queue_free()
		return
	await quadros(4)
	var antes := j.global_position
	var t := tornado(antes + Vector3(0, -.3, -.5))
	var pegou := false
	var distancia := INF
	for i in 20:
		await physics_frame
		if capturado(j):
			pegou = true
			distancia = j.global_position.distance_to(antes)
			break
	ok(pegou and not nav.ativo() and j.navegacao == null, "vento captura piloto e encerra comando")
	ok(distancia < 1.0, "entrada na captura preserva posição atual do piloto (%.3f m)" % distancia)
	var parado := barco.global_transform
	await quadros(30)
	ok(not barco.is_physics_processing() and barco.global_transform.is_equal_approx(parado),
		"barco sem piloto estaciona durante o vendaval")
	ok(not capturado(barco) and barco.collision_layer == 1, "barco continua cenário com colisão")
	t.cancelar()
	await quadros(5)
	ok(livre(j) and j.collision_mask != 0, "cancelamento restaura controle e colisões do piloto")
	nav.barcos.erase(barco)
	barco.queue_free()
	await quadros(3)

func capturas_concorrentes() -> void:
	await preparar_jogador()
	var a := tornado(Vector3(0, 0, -1))
	var b := tornado(Vector3(0, 0, -1))
	await quadros(8)
	var vinculos := 0
	for t in [a, b]:
		for captura in t.capturas:
			if is_instance_valid(captura) and captura.alvo == j and captura.em_orbita:
				vinculos += 1
	ok(vinculos == 1 and capturado(j), "dois tornados concorrentes não duplicam dono do jogador")
	a.cancelar()
	b.cancelar()
	await quadros(3)
	ok(livre(j) and j.corpo_livre_para_golpe(), "cancelamento concorrente restaura o jogador")

func morte_da_conjuradora() -> void:
	await preparar_jogador()
	var t := tornado(Vector3(0, 0, -1))
	await quadros(10)
	ok(capturado(j), "captura ativa antes de matar a conjuradora")
	boss.take_damage(boss.max_health + 1.0, j.global_position)
	await quadros(3)
	ok(not is_instance_valid(t) and livre(j), "morte da Harpia remove tornado e liberta o jogador")
	ok(not j.esta_arremessado(), "cancelamento por morte não aplica lançamento final de cinco segundos")

func habilidade_do_boss() -> void:
	await preparar_jogador()
	var combate: Node = boss.get("combate")
	ok(combate.iniciar_vendaval(j), "Harpia inicia a preparação do vendaval pelo controlador de produção")
	var max_tornados := 0
	var pegou := false
	var antecipou := true
	for i in 400:
		await physics_frame
		var total := get_nodes_in_group("tornados_harpia").size()
		max_tornados = maxi(max_tornados, total)
		if i < 50: antecipou = antecipou and total == 0
		pegou = pegou or capturado(j)
	ok(antecipou and max_tornados == 1, "preparação da Harpia antecede um único tornado ativo")
	ok(pegou, "tornado lançado pela Harpia alcança e captura o jogador pela trajetória real")
	ok(get_nodes_in_group("tornados_harpia").is_empty() and not capturado(j), "habilidade devolve o jogador ao fim sem tornado residual")
	combate.cancelar()
