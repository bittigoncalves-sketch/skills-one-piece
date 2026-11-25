extends SceneTree
## Fluxo real N (inventário) → companhia + física medida e limpeza do efeito.
## 30/09/2026: tirar/guardar o pet saiu do M e foi para o inventário N (pedido do dono).
## Mapa/progresso exclusivos; não usa nem grava a campanha do dono.
var _falhas := 0
var _modo: GDScript
var _capturar := false

func _init() -> void:
	call_deferred("_executar")

func _ok(condicao: bool, mensagem: String) -> void:
	print(("  ✅ " if condicao else "  ❌ ") + mensagem)
	if not condicao:
		_falhas += 1

func _quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _executar() -> void:
	_capturar = "--capturar" in OS.get_cmdline_user_args()
	_modo = load("res://src/historia/ModoHistoria.gd")
	_modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	_modo.progresso_forcado = "user://teste_pet_caranguejo_progresso.json"
	root.get_node("GameFlow").start_story()
	await _quadros(100)
	var cena := current_scene
	var jogador: CharacterBody3D = cena.jogador_local()
	var hud: Node = cena.get_node("HistoriaHud")
	var companhia: Node = cena.get_node("Companhia")
	var bib := BibliotecaDeModelos.padrao()
	_ok(bib.tem("caranguejo_grande") and bib.categorias_do_modelo("caranguejo_grande").has("pets"), "modelo disponível na categoria pets")
	# Desde 18/10/2026 o jogo novo começa sem pets: o teste concede o caranguejo.
	cena.progressao.pets["caranguejo"] = {"especie": "caranguejo", "nome": "Caranguejo", "modo": str(CatalogoDePets.modo_inicial("caranguejo"))}
	cena.progressao.mudou.emit()
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_M
	tecla.pressed = true
	hud._input(tecla)
	hud.central().find_child("Aba_inventario", true, false).pressed.emit()
	_ok(hud.inventario_aberto(), "M + aba Inventário abre o inventário")
	_ok(hud.inventario().find_child("Aba_pets", true, false) == null, "o inventário não tem mais a aba PETS (a Tripulação faz o mesmo)")
	companhia.chamar("caranguejo")
	await _quadros(80)
	var pet: CharacterBody3D = companhia.invocado
	_ok(is_instance_valid(pet) and pet.is_on_floor(), "Tirar do N spawna o pet no chão")
	if not is_instance_valid(pet):
		quit(1)
		return
	var id := pet.get_instance_id()
	companhia.chamar("caranguejo")
	await _quadros(30)
	_ok(companhia.invocado.get_instance_id() == id and get_nodes_in_group("pets_historia").size() == 1, "chamar novamente reposiciona sem duplicar")
	# Regressão do pivô: geometria da junta deve ser local, não repetir sua posição.
	var junta: MeshInstance3D = pet.visual.find_child("Junta_E_0", true, false)
	_ok(junta.mesh.get_aabb().get_center().length() < .01, "pivô das juntas não duplica a translação da pata")
	var escala_antes: Vector3 = pet.visual.scale
	if _capturar:
		await _foto(cena, jogador, pet, "menu", true)
	hud._input(tecla)
	# O alvo é reposicionado, mas pet usa o seu _physics_process real em todos os quadros.
	jogador.set_physics_process(false)
	jogador.global_position = pet.global_position + Vector3(14, 1, 0)
	var houve_run := false
	var houve_walk := false
	var lateral := 1.0
	var distancia_inicial := pet.global_position.distance_to(jogador.global_position)
	for i in 280:
		await physics_frame
		houve_run = houve_run or pet.estado == &"run"
		houve_walk = houve_walk or pet.estado == &"walk"
		if i > 25 and pet.get_real_velocity().length() > 1.0 and pet.is_on_floor():
			lateral = minf(lateral, absf(pet.visual.basis.x.normalized().dot(pet.get_real_velocity().normalized())))
	_ok(houve_run and houve_walk, "distância ativa run e aproximação passa por walk")
	_ok(lateral > .9, "deslocamento lateral medido: alinhamento mínimo %.3f" % lateral)
	_ok(pet.global_position.distance_to(jogador.global_position) < distancia_inicial * .4, "pet alcança o jogador")
	await _quadros(80)
	_ok(pet.estado == &"idle", "chegando perto entra em idle")
	_ok(pet.visual.scale.is_equal_approx(escala_antes), "animação preserva escala do modelo")
	# Pulo real do alvo: liga de novo a física e dá impulso ao corpo, sem forçar o pet.
	jogador.set_physics_process(true)
	jogador.velocity.y = 16.0
	jogador.global_position.y += .2
	var houve_jump := false
	var topo := pet.global_position.y
	for i in 100:
		await physics_frame
		houve_jump = houve_jump or pet.estado == &"jump"
		topo = maxf(topo, pet.global_position.y)
	_ok(houve_jump and topo > .5, "jump acompanha salto do jogador: altura %.2f m" % topo)
	await _quadros(70)
	_ok(pet.is_on_floor(), "pet aterrissa depois de jump")
	# Intervalo real: observa emissão espontânea antes de pedir a rajada para foto.
	var contador := [0]
	pet.soltou_bolhas.connect(func(): contador[0] += 1)
	await _quadros(740)
	_ok(contador[0] >= 1, "bolhas saem espontaneamente no intervalo configurado")
	pet.soltar_bolhas()
	await _quadros(5)
	var emissores: Array = pet.animador.emissores
	_ok(emissores.size() == 2 and emissores[0].global_position.distance_to(emissores[1].global_position) > 1.0, "bolhas usam marcadores nas duas garras")
	if _capturar:
		await _foto(cena, jogador, pet, "pet", false)
	pet._relogio_bolhas = 50.0
	await _quadros(160)
	var efeitos := 0
	for filho in pet.get_children():
		if str(filho.name).begins_with("BolhasCaranguejo"):
			efeitos += 1
	_ok(efeitos == 0, "rajadas terminam e removem seus nós")
	# Mudança de rumo: o corpo continua lateral depois de virar uma esquina.
	jogador.set_physics_process(false)
	jogador.global_position = pet.global_position + Vector3(0, 1, 10)
	await _quadros(160)
	_ok(absf(pet.visual.basis.x.normalized().dot(Vector3.FORWARD)) > .9, "virar para outro eixo mantém a marcha lateral")
	# Respawn/teleporte distante do dono: recuperação em chão seguro.
	jogador.global_position += Vector3(60, 0, 0)
	await _quadros(20)
	_ok(pet.global_position.distance_to(jogador.global_position) < 7, "pet se recupera após respawn distante do jogador")
	# Uma parede física no caminho nunca pode ser atravessada pela perseguição.
	var inicio := pet.global_position
	var parede := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(.5, 4, 12)
	forma.shape = caixa
	parede.add_child(forma)
	cena.add_child(parede)
	parede.global_position = inicio + Vector3(3, 2, 0)
	jogador.global_position = inicio + Vector3(9, 1, 0)
	var atravessou := false
	for i in 120:
		await physics_frame
		var relativo := pet.global_position - parede.global_position
		atravessou = atravessou or (relativo.x > 0 and absf(relativo.z) < 6 and relativo.y < 2)
	_ok(not atravessou, "perseguição respeita parede sólida")
	parede.queue_free()
	await _quadros(2)
	# Controle negativo do spawn: dono fora do mapa → recusa sem fabricar chão.
	var anterior := jogador.global_position
	jogador.set_physics_process(false)
	jogador.global_position = Vector3(1000, 5, 1000)
	_ok(not companhia.chamar(), "sem chão próximo o spawn é recusado")
	jogador.global_position = anterior
	# Peça da loja ativada no mapa, pelo mesmo caminho do modo história.
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json").mapa
	var info := bib.info("caranguejo_grande")
	var p: Dictionary = mapa.pecas[0].duplicate(true)
	p.merge({"id": "pet_colocado", "tipo": "modelo", "modelo": "caranguejo_grande", "tamanho": (info.tamanho as Vector3) * 1.3,
		"posicao": Vector3(10, (info.tamanho as Vector3).y * .5, 10), "rotacao_graus": Vector3.ZERO}, true)
	mapa.pecas = [p]
	var raiz_mapa := MapaMontador.montar(cena, mapa)
	var ligados: int = companhia.ligar_no_mapa(raiz_mapa, mapa, bib)
	_ok(ligados == 1 and raiz_mapa.get_node_or_null("pet_colocado") == null and raiz_mapa.get_node_or_null("Pet_pet_colocado") != null, "peça do editor vira pet ativo sem colisão estática sobrando")
	var pet_mapa: Node3D = raiz_mapa.get_node("Pet_pet_colocado")
	_ok(pet_mapa.visual.scale.is_equal_approx(Vector3.ONE * 1.3), "escala da peça do editor é preservada no pet")
	raiz_mapa.queue_free()
	companhia.recolher("caranguejo")          # a aba PETS do inventário saiu (10/11/2026): pela Companhia
	await _quadros(3)
	_ok(companhia.invocado == null and not is_instance_valid(pet), "Guardar remove o pet")
	_ok(get_nodes_in_group("pets_historia").is_empty(), "nenhum pet sobra depois da limpeza")
	_modo.mapa_forcado = ""
	_modo.progresso_forcado = ""
	print("PET CARANGUEJO: %d falhas" % _falhas)
	quit(1 if _falhas else 0)

func _foto(cena: Node3D, jogador: Node3D, pet: Node3D, sufixo: String, menu: bool) -> void:
	var camera := Camera3D.new()
	cena.add_child(camera)
	camera.fov = 48
	camera.global_position = pet.global_position + Vector3(5, 3.6, -6)
	camera.look_at(pet.global_position + Vector3(0, .65, -.25))
	camera.make_current()
	if not menu:
		jogador.global_position = pet.global_position + Vector3(-2.6, .9, 1.0)
		pet.set_physics_process(false)
		pet.soltar_bolhas()
	await _quadros(25)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/pets/%s.png" % sufixo)
	pet.set_physics_process(true)
	camera.queue_free()
