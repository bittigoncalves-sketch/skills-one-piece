extends SceneTree
# ============================================================================
#  TRIPULAÇÃO — "Navegar?" e a escolha dos aliados (15/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_tripulacao.gd
#
#  Pedido do dono: ao entrar no barco o jogo pergunta se vai navegar; "não" → costa; "sim" →
#  janela com os aliados em 3D à esquerda e seis vagas cinza com "+" à direita; de 3 a 6
#  aliados para zarpar, menos → tripulação insuficiente → costa. Ave voa em volta, o
#  terrestre fica no convés. Teclas de verdade (Y) e o mesmo caminho do arrastar do Godot.
# ============================================================================

var _ok_n := 0
var _falhas := 0
var p: Node3D
var nav: Node
var hud: Node
var jan: JanelaDaTripulacao
var prog: ProgressaoDoPersonagem
var barco: CharacterBody3D
var vendedor: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_regras()
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_tripulacao.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_tripulacao.json"))
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	nav = current_scene.get("_navegacao")
	hud = current_scene.get("_hud")
	prog = current_scene.get("progressao")
	jan = hud.janela_da_tripulacao()
	p.set_meta("damage_immune", true)
	_ok("a janela da tripulação existe e está ligada à navegação", jan != null and nav.janela == jan)

	# Cenário: um vendedor de barcos em terra (a costa) e um bote no mar.
	var bib := MapaMontador.biblioteca_em_uso()
	vendedor = NpcDaIlha.new()
	vendedor.tipo = "npc_vendedor_barcos"
	vendedor.biblioteca = bib
	current_scene.add_child(vendedor)
	vendedor.global_position = Vector3(0, 0, 0)
	barco = load("res://src/historia/navios/barco.gd").new()
	barco.configurar(bib, "boat", bib.tamanho_padrao("boat"))
	barco.position = Vector3(300, AguaDoMundo.superficie_em(300, 0) + 0.6, 0)
	current_scene.add_child(barco)
	nav.barcos.append(barco)
	# Jogo novo começa sem pets (18/10/2026): os dois que eram iniciais entram como num
	# save antigo (id = espécie), que é o caso que o "restaura o modo da gaivota" confere.
	for especie in ["gaivota", "caranguejo"]:
		prog.pets[especie] = {"especie": especie, "nome": CatalogoDePets.nome(especie), "modo": CatalogoDePets.modo_inicial(especie)}
	prog.adicionar_pet("caranguejo", "Siri")
	prog.adicionar_pet("caranguejo", "Siri")
	for i in 60:
		await physics_frame

	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	_ok("Y no barco pergunta antes de assumir o leme", jan.visible and not nav.ativo() and hud.is_menu_open())
	var pagina := jan.find_child("Pergunta", true, false) as Control
	_ok("a pergunta é \"Deseja navegar?\" com Sim e Não", pagina != null and pagina.visible and pagina.find_child("Sim", true, false) != null and pagina.find_child("Nao", true, false) != null)
	await _tecla_toque(KEY_ESCAPE)
	_ok("modal: o ESC não fecha a pergunta", jan.visible)

	# NÃO → costa.
	jan.responder_nao()
	await physics_frame
	_ok("Não: a janela fecha e o jogador volta à costa (%.0f m do cais)" % p.global_position.distance_to(vendedor.global_position),
		not jan.visible and not nav.ativo() and p.global_position.distance_to(vendedor.global_position) < 12.0)

	# SIM → montagem.
	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	jan.responder_sim()
	await physics_frame
	var montagem := jan.find_child("Montagem", true, false) as Control
	var cartoes: Array = jan.find_children("Aliado_*", "PanelContainer", true, false)
	var vagas: Array = jan.find_children("Vaga_*", "PanelContainer", true, false)
	_ok("Sim: abre a montagem com um cartão por aliado (%d) e seis vagas (%d)" % [cartoes.size(), vagas.size()],
		montagem.visible and cartoes.size() == prog.pets.size() and vagas.size() == 6)
	_ok("cada vaga vazia é cinza com um \"+\"", vagas.all(func(v): return v.find_child("Mais", true, false) != null and (v.find_child("Mais", true, false) as Label).text == "+"))
	_ok("cada aliado tem a vitrine 3D (SubViewport próprio)", cartoes.all(func(c): return c.find_children("*", "SubViewport", true, false).size() == 1))
	var ids: Array = prog.pets.keys()

	# Arrastar: o mesmo contrato do Godot (_get_drag_data → _can_drop_data → _drop_data).
	var c0: Node = jan.find_child("Aliado_" + str(ids[0]), true, false)
	var dado: Variant = c0._get_drag_data(Vector2.ZERO)
	var v0: Node = jan.find_child("Vaga_0", true, false)
	_ok("arrastar um aliado leva o id e a vaga aceita", dado is Dictionary and v0._can_drop_data(Vector2.ZERO, dado))
	v0._drop_data(Vector2.ZERO, dado)
	_ok("soltar na vaga 0 a ocupa (e o cartão fica apagado)", jan.escolhidos() == [str(ids[0])] and v0.find_child("Mais", true, false) == null and c0.modulate.a < 0.5)
	_ok("o aliado em uso não pode ser arrastado de novo", c0._get_drag_data(Vector2.ZERO) == null)
	var v1: Node = jan.find_child("Vaga_1", true, false)
	v1._drop_data(Vector2.ZERO, v0._get_drag_data(Vector2.ZERO))
	_ok("arrastar de vaga para vaga move (sai da 0, entra na 1)", jan.vaga_de(str(ids[0])) == 1 and v0.find_child("Mais", true, false) != null)
	var area: Node = jan.find_child("AreaDaLista", true, false)
	var da_vaga: Variant = v1._get_drag_data(Vector2.ZERO)
	_ok("a lista aceita o aliado vindo de uma vaga e o tira", area._can_drop_data(Vector2.ZERO, da_vaga))
	area._drop_data(Vector2.ZERO, da_vaga)
	_ok("soltar de volta na lista esvazia a vaga", jan.escolhidos().is_empty() and c0.modulate.a > 0.9)

	# INSUFICIENTE: 2 aliados → costa.
	jan.colocar(0, str(ids[0]))
	jan.colocar(1, str(ids[1]))
	jan.zarpar()
	await physics_frame
	_ok("com 2 aliados a tripulação é insuficiente: volta à costa e não pilota",
		not jan.visible and not nav.ativo() and p.global_position.distance_to(vendedor.global_position) < 12.0)

	# CANCELAR na montagem = recusa.
	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	jan.responder_sim()
	jan.cancelar()
	await physics_frame
	_ok("Cancelar volta à costa", not jan.visible and not nav.ativo() and p.global_position.distance_to(vendedor.global_position) < 12.0)

	# ZARPAR com 3.
	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	jan.responder_sim()
	for i in 3:
		jan.colocar(i, str(ids[i]))
	jan.zarpar()
	for i in 5:
		await physics_frame
	_ok("com 3 aliados o jogador assume o leme", nav.ativo() and p.get_meta("pilotando", false))
	_ok("a tripulação registrada tem os 3 (%s)" % str(nav.tripulacao), nav.tripulacao.size() == 3)
	var companhia: Node = current_scene.get("_companhia")
	var gaivota: CharacterBody3D = companhia.pet_fora("gaivota")
	_ok("a gaivota está fora, no modo seguir (voa em volta do navio)", gaivota != null and gaivota.modo == ModoDoPet.SEGUIR and gaivota.get_parent() != barco)
	var no_convez := 0
	var dentro := true
	for id in nav.tripulacao:
		var pet: CharacterBody3D = companhia.pet_fora(id)
		if pet != null and pet.get_parent() == barco:
			no_convez += 1
			var tam: Vector3 = barco.get("tamanho_casco")
			dentro = dentro and absf(pet.position.x) <= tam.x * .5 and absf(pet.position.z) <= tam.z * .5
	_ok("os terrestres (%d) ficam no convés, dentro do casco" % no_convez, no_convez == 2 and dentro)
	nav.sair(true)
	await physics_frame
	_ok("soltar o leme no mar não dispensa a tripulação", nav.tripulacao.size() == 3 and companhia.esta_fora("gaivota"))

	# Chegou ao porto: dispensa.
	barco.global_position = vendedor.global_position + Vector3(10, 0.5, 0)
	await physics_frame
	await _ir_ao_barco(true)
	nav.dispensar_tripulacao()
	_ok("dispensar devolve todos ao inventário e restaura o modo da gaivota",
		nav.tripulacao.is_empty() and not companhia.esta_fora("gaivota") and prog.modo_do_pet("gaivota") == ModoDoPet.LIVRE)

	# HUMANOS da roleta: a Nami a bordo, no convés, dizendo o rumo da ilha mais próxima.
	prog.recrutados = {"nami": true}
	barco.global_position = Vector3(300, AguaDoMundo.superficie_em(300, 0) + 0.6, 0)
	for i in 20:
		await physics_frame
	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	jan.responder_sim()
	var cartao_humano: Node = jan.find_child("Aliado_humano_nami", true, false)
	_ok("a Nami recrutada aparece entre os aliados da janela", cartao_humano != null)
	jan.colocar(0, "humano_nami")
	jan.colocar(1, str(ids[0]))
	jan.colocar(2, str(ids[1]))
	jan.zarpar()
	for i in 5:
		await physics_frame
	var humano := barco.find_child("Tripulante_nami", true, false)
	# Neste mapa só há UMA ilha e é a de onde se veio: sem "próxima ilha" a Nami não conduz.
	_ok("a Nami fica no convés do barco; sem outra ilha o jogador segue no leme", nav.viagem_ativa and humano != null and humano.get_parent() == barco and nav.tem_navegadora() and not nav.nami_conduz and nav.ativo())
	var fala: String = nav.fala_da_navegadora()
	_ok("e ela não inventa rumo (\"%s\")" % fala, fala == "")
	nav._terminar_viagem("")
	await physics_frame
	_ok("dispensar tira a Nami do convés", barco.find_child("Tripulante_nami", true, false) == null and not nav.tem_navegadora())


	# NAVEGAÇÃO (15/10/2026): a viagem segue sem o leme e só acaba ao entrar numa ilha.
	var ilhas := {"ilha_inicial": Rect2(-50, -50, 100, 100), "ilha_dos_macacos": Rect2(600, -100, 200, 200)}
	nav.ilhas_de = func() -> Dictionary: return ilhas
	var faixa: FaixaNavegando = hud.faixa_navegando()
	_ok("a faixa NAVEGANDO existe e começa escondida", faixa != null and not faixa.visible)
	prog.recrutados = {"sanji": true}
	prog.pets = {"gaivota": {"especie": "gaivota", "nome": "G", "modo": &"livre"}, "c1": {"especie": "caranguejo", "nome": "A", "modo": &"seguir"}, "c2": {"especie": "caranguejo", "nome": "B", "modo": &"seguir"}}
	barco.global_position = Vector3(520, AguaDoMundo.superficie_em(520, 0) + 0.6, 0)
	for i in 20:
		await physics_frame
	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	jan.responder_sim()
	jan.colocar(0, "humano_sanji")
	jan.colocar(1, "c1")
	jan.colocar(2, "c2")
	jan.zarpar()
	for i in 5:
		await physics_frame
	# PASSEIO (15/10/2026): o cozinheiro e os caranguejos andam pelo convés em vez de ficar parados.
	var sanji: Node3D = barco.find_child("Tripulante_sanji", true, false)
	var caranguejo: Node3D = companhia.pet_fora("c1")
	var p_sanji: PasseioNoConves = sanji.get_node_or_null("Passeio") if sanji != null else null
	var p_crab: PasseioNoConves = caranguejo.get_node_or_null("Passeio") if caranguejo != null else null
	_ok("o Sanji (modelo do cozinheiro) e o caranguejo têm passeio", p_sanji != null and p_crab != null)
	var tam_casco: Vector3 = barco.get("tamanho_casco")
	var dentro_do_casco := true
	var alturas_ok := true
	var y_conves: float = p_sanji._y_do_convez
	for i in 900:
		await physics_frame
		for q in [sanji, caranguejo]:
			dentro_do_casco = dentro_do_casco and absf(q.position.x) <= tam_casco.x * 0.5 and absf(q.position.z) <= tam_casco.z * 0.5
			alturas_ok = alturas_ok and absf(q.position.y - y_conves) < 0.5
	_ok("o Sanji passeou (%.1f m em 15 s)" % p_sanji.distancia_percorrida, p_sanji.distancia_percorrida > 0.8)
	_ok("o caranguejo passeou (%.1f m)" % p_crab.distancia_percorrida, p_crab.distancia_percorrida > 0.5)
	_ok("sem sair do casco nem da altura do convés", dentro_do_casco and alturas_ok)
	var clipes := sanji.find_children("*", "AnimationPlayer", true, false)
	_ok("o cozinheiro usa os clipes do modelo (descanso/caminhada)", not clipes.is_empty() and (clipes[0].current_animation in ["descanso", "caminhada"]))
	_ok("zarpou: a faixa NAVEGANDO aparece na tela", nav.viagem_ativa and faixa.visible and (faixa.find_child("Titulo", true, false) as Label).text == "NAVEGANDO")
	nav.sair(true)
	await physics_frame
	_ok("soltar o leme NÃO encerra: a faixa continua e a tripulação segue a bordo", nav.viagem_ativa and faixa.visible and nav.tripulacao.size() == 3)
	await _tecla_toque(KEY_Y)
	_ok("Y no barco da viagem volta ao leme sem perguntar de novo", nav.ativo() and not jan.visible)
	nav.sair(true)
	barco.global_position = Vector3(700, barco.global_position.y, 0)
	for i in 10:
		await physics_frame
	_ok("entrar numa ilha encerra: faixa some, tripulação desce, barco para",
		not nav.viagem_ativa and not faixa.visible and nav.tripulacao.is_empty() and not companhia.esta_fora("c1"))

	# Com a NAMI: ela dirige até a PRÓXIMA ilha (a mais perto que não é a de onde se veio).
	prog.recrutados = {"nami": true}
	nav._ultima_ilha = "ilha_inicial"      # veio do porto de origem
	barco.global_position = Vector3(520, AguaDoMundo.superficie_em(520, 0) + 0.6, 0)
	barco.rotation = Vector3.ZERO
	for i in 20:
		await physics_frame
	await _ir_ao_barco()
	await _tecla_toque(KEY_Y)
	jan.responder_sim()
	jan.colocar(0, "humano_nami")
	jan.colocar(1, "c1")
	jan.colocar(2, "c2")
	jan.zarpar()
	for i in 5:
		await physics_frame
	_ok("com a Nami o jogador NÃO está no leme e ela conduz rumo à ilha dos macacos (%s)" % nav.destino,
		nav.viagem_ativa and nav.nami_conduz and not nav.ativo() and nav.destino == "ilha_dos_macacos")
	_ok("o jogador está de pé no convés", p.global_position.distance_to(barco.global_position) < 8.0)
	var proxima := str(nav.fala_da_navegadora())
	_ok("a Nami fala da PRÓXIMA ilha (\"%s\")" % proxima, "próxima ilha é Ilha dos Macacos" in proxima)
	_ok("a faixa diz quem conduz (\"%s\")" % (faixa.find_child("Subtitulo", true, false) as Label).text, "Nami conduz" in (faixa.find_child("Subtitulo", true, false) as Label).text)
	var antes_do_barco := barco.global_position
	for i in 240:
		await physics_frame
	_ok("o barco anda sozinho (%.1f m em 4 s)" % barco.global_position.distance_to(antes_do_barco), barco.global_position.distance_to(antes_do_barco) > 3.0)
	# O jogador CAI do barco: a Nami para o navio e espera; ao subir de novo ela retoma.
	_ok("a bordo a Nami não está parada", nav.jogador_a_bordo() and not nav.nami_parou)
	p.global_position = barco.global_position + Vector3(25, 0.5, 0)
	p.velocity = Vector3.ZERO
	for i in 60:
		await physics_frame
	_ok("fora do casco por 1 s: a Nami para o navio (parou=%s)" % nav.nami_parou, nav.nami_parou and not nav.jogador_a_bordo())
	_ok("a faixa avisa que ela parou (\"%s\")" % (faixa.find_child("Subtitulo", true, false) as Label).text, "parou o navio" in (faixa.find_child("Subtitulo", true, false) as Label).text)
	for i in 600:
		await physics_frame
	_ok("o barco freia até quase parar (%.2f m/s)" % absf(barco.velocidade_atual()), absf(barco.velocidade_atual()) < 0.6)
	var parado_em := barco.global_position
	for i in 120:
		await physics_frame
	_ok("e fica parado esperando (%.1f m em 2 s)" % barco.global_position.distance_to(parado_em), barco.global_position.distance_to(parado_em) < 1.0)
	p.global_position = barco.global_position + barco.global_basis * Vector3(0, 0.3, (barco.get("tamanho_casco") as Vector3).z * 0.5 + 1.0)
	p.velocity = Vector3.ZERO
	await physics_frame
	await _tecla_toque(KEY_Y)
	for i in 30:
		await physics_frame
	_ok("Y perto do casco sobe a bordo e a Nami retoma (a bordo=%s, parada=%s)" % [nav.jogador_a_bordo(), nav.nami_parou], nav.jogador_a_bordo() and not nav.nami_parou)
	var depois := barco.global_position
	for i in 240:
		await physics_frame
	_ok("o barco volta a andar (%.1f m)" % barco.global_position.distance_to(depois), barco.global_position.distance_to(depois) > 1.5)
	# Reposiciona para a chegada abaixo não depender de onde o barco parou.
	barco.global_position = Vector3(520, AguaDoMundo.superficie_em(520, 0) + 0.6, 0)
	barco.rotation = Vector3.ZERO
	p.global_position = barco.leme.global_position + Vector3.UP * 0.9      # o jogador vai junto: a Nami só anda com ele a bordo
	p.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	await _tecla_toque(KEY_Y)
	_ok("Y não toma o leme da Nami", not nav.ativo() and nav.nami_conduz)
	for i in 1500:
		await physics_frame
		if not nav.viagem_ativa:
			break
	_ok("a Nami chega: viagem encerra, tripulação desce e o barco para (x=%.0f)" % barco.global_position.x,
		not nav.viagem_ativa and not faixa.visible and nav.tripulacao.is_empty() and not barco.is_physics_processing())

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nTRIPULACAO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _regras() -> void:
	_ok("gaivota é ave; caranguejo, terrestre", Tripulacao.categoria("gaivota") == Tripulacao.Categoria.AVE and Tripulacao.categoria("caranguejo") == Tripulacao.Categoria.TERRESTRE)
	_ok("mínimo 3 e máximo 6", Tripulacao.MINIMO == 3 and Tripulacao.MAXIMO == 6)
	var fake := ProgressaoDoPersonagem.new()
	fake.pets = {"a": {"especie": "caranguejo", "nome": "A"}, "b": {"especie": "caranguejo", "nome": "B"}, "c": {"especie": "caranguejo", "nome": "C"}}
	_ok("validos descarta repetido e id que não existe", Tripulacao.validos(["a", "a", "x", "b"], fake) == (["a", "b"] as Array[String]))
	_ok("suficiente exige 3", not Tripulacao.suficiente(["a", "b"], fake) and Tripulacao.suficiente(["a", "b", "c"], fake))


func _ir_ao_barco(so_posicionar := false) -> void:
	p.global_position = barco.leme.global_position + Vector3.UP * 0.9
	p.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame


func _tecla_toque(codigo: Key) -> void:
	_tecla(codigo, true)
	await physics_frame
	_tecla(codigo, false)
	await physics_frame


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
