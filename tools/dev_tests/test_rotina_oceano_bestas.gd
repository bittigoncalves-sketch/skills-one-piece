extends SceneTree
## Ciclo autônomo completo no modo história, com água/fundo/rigs reais.
const PASTA := "res://art_src/validation/bestas_mar/mergulho"
var total := 0
var falhas := 0
var tela := false
var camera: Camera3D
var legenda: Label

func _init() -> void: rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	if not cond: falhas += 1
	print(("OK " if cond else "FALHA ") + msg)

func quadros(n: int) -> void:
	for i in n: await physics_frame

func foto(b: Node3D, estado: String) -> void:
	if not tela: return
	camera.global_position = b.global_position + Vector3(22, 10, -25)
	camera.look_at(b.global_position + Vector3(0, 4, 0))
	camera.make_current()
	legenda.text = str(b.especie) + " · " + estado
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA.path_join(str(b.especie) + "_" + estado + ".png"))

func rodar() -> void:
	await process_frame
	tela = OS.get_cmdline_user_args().has("--tela")
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json").mapa
	mapa.pecas[0].tamanho = Vector3(128, 2, 128)
	for i in 4:
		var id: String = "besta_mar_" + ["bovina", "girafa", "javali", "serpente"][i]
		var tamanho := bib.tamanho_padrao(id)
		mapa.pecas.append({"id": id, "tipo": "modelo", "modelo": id, "posicao": Vector3(54 if i < 3 else -100, tamanho.y / 2, -35 + 30 * i),
			"tamanho": tamanho, "rotacao_graus": Vector3.ZERO, "colisao": true, "cor": Color.WHITE, "material": "liso"})
	MapaArquivo.salvar("user://rotina_bestas_mapa.json", mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "user://rotina_bestas_mapa.json")
	modo.set("progresso_forcado", "user://rotina_bestas_save.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://rotina_bestas_save.json"))
	root.get_node("GameFlow").start_story()
	await quadros(90)
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	jogador.set_physics_process(false)
	jogador.global_position = Vector3.ZERO
	var pacificas: Array[Node] = []
	var boss: Node
	var vistos := {}
	var imersoes := {}
	var retornos := {}
	var fotografados := {}
	for b in get_nodes_in_group("bestas_do_mar"):
		if b.boss(): boss = b
		else:
			pacificas.append(b)
			vistos[b.especie] = {}
			imersoes[b.especie] = 0.0
			retornos[b.especie] = false
			b._rng.seed = 771 + pacificas.size()
			# O ciclo testa a SEQUÊNCIA (ir, mergulhar, subir, voltar, dormir) com mergulho
			# curto; o fôlego longo de verdade (60 s, 08/10/2026) é medido no fim.
			b.ficha.tempo_submerso = 6.0
			b.iniciar_rotina()
	if tela:
		camera = Camera3D.new()
		current_scene.add_child(camera)
		var camada := CanvasLayer.new()
		root.add_child(camada)
		legenda = Label.new()
		legenda.position = Vector2(25, 110)
		legenda.add_theme_font_size_override("font_size", 25)
		camada.add_child(legenda)
	# Sem forçar estados: o relógio real da IA deve produzir ida, mergulho e volta.
	# 12000 quadros (200 s; eram 6600): com o relevo marinho de 14/10/2026 a plataforma
	# rasa (5–25 m) não cabe estas bestas de 13–17 m a 100 m da praia, e o passeio vai até
	# ter água para o corpo inteiro (160–210 m) — ida e volta mais longas.
	for i in 12000:
		for b in pacificas:
			var s: String = b.estado
			if not vistos[b.especie].has(s):
				vistos[b.especie][s] = true
				print("ESTADO ", b.especie, " ", s, " em ", b.global_position)
			var chave: String = str(b.especie) + s
			if tela and not fotografados.has(chave) and b.animador.tempo > minf(b.animador.duracao() * .45, 1.3):
				fotografados[chave] = true
				await foto(b, s)
			imersoes[b.especie] = maxf(imersoes[b.especie], AguaDoMundo.submersao(b.global_position, b._altura))
			if vistos[b.especie].has("nadando_submerso") and s == "dormindo" and not b.nadando:
				retornos[b.especie] = true
		if retornos.values().all(func(v): return v): break
		await physics_frame
	for b in pacificas:
		for s in ["dormindo", "nadando_walk", "mergulhando", "nadando_submerso", "emergindo"]:
			ok(vistos[b.especie].has(s), b.especie + ": ciclo visita " + s)
		ok(imersoes[b.especie] >= .99, b.especie + ": corpo inteiro entra na água (%.3f)" % imersoes[b.especie])
		ok(retornos[b.especie], b.especie + ": volta fisicamente à praia e dorme")
		ok(not b.agressiva, b.especie + ": permanece pacífica durante passeio")
	# Atacar durante descida interrompe rotina e prepara revide na superfície.
	var b: Node = pacificas[0]
	# Fundo raso proíbe a descida; não basta haver água acima da cápsula.
	b.set_physics_process(false)
	b.global_position = Vector3(66, 2, -35)
	await quadros(2)
	ok(b._limite_de_mergulho() < 2.0, "água rasa não autoriza mergulho através do fundo")
	b.set_physics_process(true)
	b.global_position = b.mar
	b.global_position.y = AguaDoMundo.superficie_em(b.mar.x, b.mar.z) - b._calado
	b.velocity = Vector3.ZERO
	b._voltando = false
	b._banho = true
	b._destino = b.mar
	b._rotina = 20.0
	for i in 400:
		await physics_frame
		if b.estado == "mergulhando" and b.animador.tempo > 1.0: break
	ok(b.estado == "mergulhando", "pré-condição: ataque recebido durante mergulho")
	jogador.global_position = b.global_position + Vector3(0, 3, -6)
	b.take_damage(1.0, jogador.global_position)
	ok(b.agressiva and not b._passeando and b._profundidade == 0.0 and b.estado == "recebendo_dano", "dano interrompe mergulho e prioriza revide")
	var reagiu := false
	for i in 500:
		await physics_frame
		if b.estado == "disparando_ataque":
			reagiu = true
			await quadros(45)
			await foto(b, "revide")
			break
	ok(reagiu, "pacífica emerge e desfere ataque após provocação")
	# Boss permanece no combate, mesmo com relógio de rotina vencido.
	# Alvo na praia, acima do fundo raso (não enterrado na rampa submarina).
	jogador.global_position = Vector3(-55, .9, 55)
	boss._rotina = -100.0
	var tiros := [0]
	boss.disparou.connect(func(_b): tiros[0] += 1)
	var repousou := false
	for i in 1200:
		await physics_frame
		if boss.estado in ["dormindo", "comendo", "mergulhando", "nadando_submerso"]: repousou = true
		if tela and boss.estado == "disparando_ataque" and boss.animador.tempo > 1.1 and not fotografados.has("boss"):
			fotografados["boss"] = true
			await foto(boss, "disparo")
	ok(boss.agressiva and tiros[0] >= 3, "Sea Serpent prioriza ataques sem provocação (%d bolhas)" % tiros[0])
	ok(not repousou and not boss._passeando and not boss._banho, "boss não entra no ciclo pacífico durante combate")
	await foto(boss, "combate")
	# Fôlego (08/10/2026, pedido do dono: "a besta não tem limite de respiração como o
	# jogador, então pode mergulhar por bastante tempo"): a ficha pede um minuto e ela
	# segue submersa por mais que os 30 s de fôlego do jogador.
	var perfis: Dictionary = load("res://src/historia/bestas_mar/perfis.json").data
	var longos := true
	for id in perfis:
		longos = longos and float(perfis[id].get("tempo_submerso", 0.0)) >= 60.0
	ok(longos, "toda besta mergulha por pelo menos 60 s (perfis.json)")
	var f: Node = pacificas[1]
	f.ficha.tempo_submerso = 60.0
	jogador.global_position = Vector3(-55, .9, 55)
	f.agressiva = false
	f.alvo = null
	f.global_position = f.mar
	f.global_position.y = AguaDoMundo.superficie_em(f.mar.x, f.mar.z) - f._calado
	f.velocity = Vector3.ZERO
	f._voltando = false
	f._banho = true
	f._destino = f.mar
	f._rotina = 20.0
	f.mudar("nadando_walk")
	for i in 600:
		await physics_frame
		if f.estado == "nadando_submerso": break
	var submersa := 0.0
	var minima := 1.0
	for i in 1950:          # 32,5 s
		await physics_frame
		if f.estado != "nadando_submerso": break
		submersa += 1.0 / 60.0
		minima = minf(minima, AguaDoMundo.submersao(f.global_position, f._altura))
	ok(submersa >= 32.0 and minima >= .99, "%s fica %.1f s submersa sem subir (corpo inteiro: %.2f) — mais que o fôlego do jogador" % [f.especie, submersa, minima])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("ROTINA OCEANO BESTAS: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
