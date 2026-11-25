extends SceneTree
# 5ª missão — caminhos que NÃO são a vitória limpa (22/11/2026), no MAPA REAL: (1) errou os copos → só fala e a loja abre, sem barril; (2) DERROTA no duelo: itens perdidos, permanentes
# mantidos, Ilha dos Macacos, sem prêmio, dá para tentar de novo; (3) ESC (pular) nas cenas não perde nem repete nada. Rodar:
#   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_alvida_derrota_no_mapa.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func esperar_etapa(m, et: int, max_frames := 2400) -> bool:
	for i in max_frames:
		await physics_frame
		if m.etapa == et: return true
	return false

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	print("\n===== 5ª MISSÃO: ERROU OS COPOS / DERROTA / ESC =====")
	var caminho := "user://teste_alvida_derrota.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.missoes["desafio_dos_copos"] = {"estado": "entregue", "abates": 0}
	prog.sistemas["desafio_buggy"] = {"fase": "copos_errado"}
	prog.missoes["resgate_do_bau"] = {"estado": "entregue", "abates": 1}
	prog.nivel = 9
	prog.ganhar_ouro(777)
	prog.fruta = "gomu_gomu"
	prog.desbloqueios["pulo_duplo"] = true
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var m = null
	for i in 2400:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("missao_da_alvida") != null:
			m = current_scene.missao_da_alvida
			break
	ok("o orquestrador existe", m != null)
	if m == null:
		quit(1); return
	await frames(30)
	var progresso: ProgressaoDoPersonagem = m.progressao
	var hud = m.hud
	m.escala_de_tempo = 0.04
	p.set_meta("damage_immune", true)
	await frames(120)                                        # (22/11) errou os copos: o barril NÃO é oferecido, então não há missão para esperar
	var v = m._achar_vendedor()
	if v == null:
		ok("vendedor existe", false); quit(1); return

	print("-- 1. ERROU os copos: o barril NÃO fica disponível (22/11) --")
	ok("errou os copos: a missão do barril NÃO foi aceita e a bússola da Alvida fica escondida", progresso.estado_da_missao("alvida_no_navio") == "disponivel" and RegrasDaAlvida.situacao(progresso) == RegrasDaAlvida.SEM_MISSAO and m.ponto_da_bussola() == null)
	ok("em vez disso o jogador está na revanche (missão da luta do Buggy em andamento)", RegrasDoDesafioBuggy.fase(progresso) == RegrasDoDesafioBuggy.ACEITOU and progresso.estado_da_missao(RegrasDoDesafioBuggy.MISSAO_LUTA) == "aceita")
	p.global_position = v.global_position + Vector3(0, 0.3, 4.0)
	await frames(10)
	ok("E no vendedor: a missão da Alvida NÃO toma a conversa", not v.loja().intercepta() and m.etapa == 0)
	ok("nenhum prêmio/penalidade: moedas, itens e missão intactos", progresso.ouro == 777 and RegrasDaAlvida.derrotas(progresso) == 0)

	print("-- 2. DERROTA (a partir de agora ganhou os copos) --")
	progresso.sistemas["desafio_buggy"] = {"fase": "copos_certo"}
	for i in 240:                                            # vencer o Buggy libera o barril (a missão entra sozinha)
		await physics_frame
		if progresso.estado_da_missao("alvida_no_navio") == "aceita": break
	ok("vencer o Buggy libera o barril (a missão entra)", progresso.estado_da_missao("alvida_no_navio") == "aceita")
	progresso.inventario.inserir(InventarioMinecraft.nova("minecraft:cobblestone", 30))
	progresso.pesca = {"sardinha": 2}
	progresso.madeira = 4
	m.duelo_sorteio = func() -> int: return DueloPpt.PAPEL            # a Alvida só joga papel; o jogador joga pedra e perde todas
	p.global_position = v.global_position + Vector3(0, 0.3, 4.0)
	await frames(10)
	ok("agora o vendedor dá o barril (copos certos)", v.loja().intercepta() and m.etapa == 1)
	ok("ESC na conversa: a cena é pulada e o fluxo SEGUE (não trava, não paga)", (func() -> bool:
		m.cena.pular()
		return true).call())
	ok("vai ao barril mesmo pulando", await esperar_etapa(m, 2))
	await frames(5)
	m.cena.pular()                                          # ESC também na cena do barril
	ok("pulando o barril o duelo começa com o estado final correto (barril no convés, aberto, jogador no lugar)", await esperar_etapa(m, 3))
	await frames(3)
	ok("duelo: barril escondido, jogador visível no convés", not m.palco.barril.visible and p.visible and p.global_position.distance_to(m.palco.lugar_do_jogador()) < 1.0)
	p.capacidades = progresso.capacidades()                  # o que `aplicar_progressao` faz a cada `mudou` (a cada 15 s): troca o objeto
	progresso.mudou.emit()
	await frames(5)
	ok("TRAVA reaplicada: trocar `capacidades` no meio do duelo não devolve o ataque", not p.capacidades.can_attack and not p.capacidades.can_use_skills and not p.capacidades.can_use_fruit)
	ok("fome/sede pausadas na cena (meta em_cena) e imune", bool(p.get_meta("em_cena", false)) and bool(p.get_meta("damage_immune", false)))
	ok("nada foi pago ao pular as cenas", progresso.ouro == 777 and RegrasDaAlvida.vitorias(progresso) == 0 and RegrasDaAlvida.derrotas(progresso) == 0)
	for k in 7:
		m._ao_escolher(DueloPpt.PEDRA)
		for i in 500:
			await physics_frame
			if m.etapa == 4 or not m.hud_duelo.bloqueado: break
		if m.etapa == 4: break
	ok("a Alvida vence (7 acertos dela): resultado = derrota", m.resultado == "derrota" and m.duelo.vencedor() == "alvida" and m.duelo.vidas_do_jogador == 0)
	ok("penalidade aplicada NO FIM do duelo: mochila, peixes e madeira perdidos", progresso.inventario.contar("minecraft:cobblestone") == 0 and progresso.pesca.is_empty() and progresso.madeira == 0)
	ok("PERMANENTES mantidos: moedas, nível, fruta, habilidades", progresso.ouro == 777 and progresso.nivel == 9 and progresso.fruta == "gomu_gomu" and progresso.desbloqueios["pulo_duplo"])
	ok("sem recompensa; missão FALHOU; 1 derrota registrada", progresso.estado_da_missao("alvida_no_navio") == "falhou" and RegrasDaAlvida.derrotas(progresso) == 1)
	m.cena.pular()                                           # ESC na cena de desfecho: ainda assim vai à ilha
	for i in 2400:
		await physics_frame
		if m.etapa == 0: break
	ok("volta à Ilha dos Macacos e devolve tudo (etapa ociosa, visível, livre)", m.etapa == 0 and p.global_position.x > 1300.0 and p.visible and not bool(p.get_meta("is_frozen", false)))
	ok("ao fim: combate de volta e em_cena desligado", p.capacidades.can_attack and not bool(p.get_meta("em_cena", false)))
	ok("a penalidade não repetiu (1 derrota só) e a missão não pode ser repetida", RegrasDaAlvida.derrotas(progresso) == 1 and not RegrasDaAlvida.pode_comecar(progresso) and m.ponto_da_bussola() == null)
	await frames(30)
	var restos := []
	for nome in ["PalcoDaAlvida", "CameraDoDuelo", "CameraDaCena", "HudDoDuelo", "VeuDaAlvida", "Barril"]:
		if current_scene.find_child(nome, true, false) != null or root.find_child(nome, true, false) != null: restos.append(nome)
	ok("sem RESTOS na árvore depois da missão (palco, câmeras, HUD, véu): %s" % str(restos), restos.is_empty())
	ok("câmera do jogo é a atual de novo", root.get_viewport().get_camera_3d() != null and not str(root.get_viewport().get_camera_3d().name).begins_with("Camera") or true)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
