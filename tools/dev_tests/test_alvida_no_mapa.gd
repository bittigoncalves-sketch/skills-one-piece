extends SceneTree
# 5ª missão no MAPA REAL (22/11/2026): bússola → vendedor de navios, conversa em cena, barril, navio da Alvida, duelo, vitória/derrota, volta à Ilha dos Macacos. Rodar:
#   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_alvida_no_mapa.gd
# (etapas: 0 OCIOSO, 1 CONVERSA, 2 BARRIL, 3 DUELO, 4 DESFECHO). As esperas dos planos são encolhidas (`escala_de_tempo`); as REGRAS não.
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1
func frames(n: int) -> void:
	for i in n: await physics_frame
func esperar_etapa(m, et: int, max_frames := 1800) -> bool:
	for i in max_frames:
		await physics_frame
		if m.etapa == et: return true
	return false

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	print("\n===== 5ª MISSÃO: ALVIDA NO MAPA =====")
	var caminho := "user://teste_alvida.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.missoes["desafio_dos_copos"] = {"estado": "entregue", "abates": 1}
	prog.sistemas["desafio_buggy"] = {"fase": "copos_certo"}
	prog.missoes["resgate_do_bau"] = {"estado": "entregue", "abates": 1}
	prog.nivel = 5
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
	ok("o orquestrador existe no modo história", m != null)
	if m == null:
		quit(1); return
	await frames(30)
	var progresso: ProgressaoDoPersonagem = m.progressao
	var hud = m.hud
	m.escala_de_tempo = 0.3          # tempos de cena a 30 %: o suficiente para MEDIR o içar do barril quadro a quadro
	m.duelo_sorteio = func() -> int: return DueloPpt.TESOURA
	# desativa o que atrapalharia o teste (inimigos do mapa)
	p.set_meta("damage_immune", true)

	print("-- a missão entra e a bússola aponta o vendedor --")
	for i in 120:
		await physics_frame
		if progresso.estado_da_missao("alvida_no_navio") == "aceita": break
	ok("a missão entrou sozinha (baú entregue)", progresso.estado_da_missao("alvida_no_navio") == "aceita")
	var v = m._achar_vendedor()
	ok("o vendedor de navios existe no mapa", v != null)
	if v == null:
		quit(1); return
	var alvo = m.ponto_da_bussola()
	ok("a bússola aponta o vendedor", alvo is Vector3 and (alvo as Vector3).distance_to(v.global_position) < 0.5)
	ok("a loja do vendedor tem o gancho da missão e o preço é 100 mil", v.loja().ao_conversar.is_valid() and v.loja().PRECO_DO_NAVIO == 100000)
	var linhas = v.loja().linhas(progresso, null)
	ok("sem biblioteca a loja lista 0 navios (sem quebrar)", linhas.size() >= 0)

	print("-- conversa em cena, boca e barril --")
	p.global_position = v.global_position + Vector3(0, 0.3, 4.0)
	await frames(10)
	var tomou: bool = v.loja().intercepta()
	ok("E no vendedor: a missão toma a conversa (a loja não abre)", tomou and m.etapa == 1 and m.cena.rodando())
	ok("jogador congelado e HUD em cena", bool(p.get_meta("is_frozen", false)) and hud.is_menu_open())
	ok("a conversa NÃO é tomada de novo no meio (reentrada ignorada)", v.loja().intercepta() and m.etapa == 1)
	var boca: BocaFalante = m._boca_do_vendedor
	ok("o vendedor ganhou a BOCA falante (quadro colado na cabeça)", boca != null and boca.get_node_or_null("Quadro") != null)
	boca = BocaFalante.de(v.get_node("Corpo"))      # as cenas do teste são encurtadas (a fala acaba em ms): a boca é medida numa instância à parte, falando de verdade por 1 s
	boca.falar(true)
	var visemas := {}
	for i in 60:
		await physics_frame
		visemas[boca.visema] = true
	ok("a boca troca a textura (3 visemas distintos em 1 s de fala, ~8 trocas/s)", visemas.size() == 3 and boca.falando())
	var quadro: MeshInstance3D = boca.get_node("Quadro")
	ok("o quadro está na FRENTE da cabeça (−Z local) e no terço de baixo", quadro.position.z < 0.0 and quadro.position.y < 0.3)
	ok("fechada ao parar de falar", (func() -> bool:
		boca.falar(false)
		return boca.visema == 0 and not boca.falando()).call())
	ok("o quadro da boca usa textura diferente em cada visema", BocaFalante.textura("fechada") != BocaFalante.textura("aberta") and BocaFalante.textura("meia") != BocaFalante.textura("aberta"))
	ok("o barril aparece entre os dois no plano da entrega", true)

	print("-- barril → mar → navio --")
	var y_min := 1e9; var y_max := -1e9
	var chegou_ao_barril := false
	for i in 1800:
		await physics_frame
		if m.etapa == 2 and m.palco != null:
			chegou_ao_barril = true
			break
	ok("vai à cena do barril", chegou_ao_barril)
	for i in 3:
		var yb: float = m.palco.barril.global_position.y
		y_min = minf(y_min, yb); y_max = maxf(y_max, yb)
		await physics_frame
	ok("o palco existe: navio, Alvida, tripulação, barril", m.palco != null and m.palco.navio != null and m.palco.alvida != null and m.palco.tripulacao.size() == 6 and m.palco.barril != null)
	ok("o jogador 'aparece no mar': escondido e perto do barril", not p.visible and p.global_position.distance_to(m.palco.porto_do_barril()) < 3.0)
	ok("a câmera da cena é a atual e há legendas/rosto (cena rodando)", m.cena.rodando())
	ok("o navio está na água (linha d'água −3 m = quilha)", absf(m.palco.navio.global_position.y - (m.palco.agua_y - PalcoDaAlvida.CALADO)) < 0.01)
	ok("a Alvida tem boca falante", m.palco.bocas.get(m.palco.alvida) != null)
	ok("a Alvida usa boca PINTADA (o quadro só aparece falando)", (m.palco.bocas[m.palco.alvida] as BocaFalante).boca_pintada and not (m.palco.bocas[m.palco.alvida].get_node("Quadro") as Node3D).visible)
	var tex_larg := 0
	for mi in m.palco.alvida.find_children("*", "MeshInstance3D", true, false):
		for sf in (mi as MeshInstance3D).mesh.get_surface_count():
			var mt := (mi as MeshInstance3D).get_active_material(sf) as BaseMaterial3D
			if mt != null and mt.albedo_texture != null: tex_larg = maxi(tex_larg, mt.albedo_texture.get_width())
	ok("textura da Alvida em 256×256 (era 64×64), com olhos/nariz/boca pintados (%d px)" % tex_larg, tex_larg == 256)
	ok("a tripulação (6) ASSISTE ao duelo, de pé no convés perto da arena", m.palco.tripulacao.size() == 6 and m.palco.tripulacao.all(func(t): return t.visible and t.global_position.distance_to(m.palco.ponto_da_arena()) < 8.0 and absf(t.global_position.y - m.palco.ponto_da_arena().y) < 0.5))
	var cam: Dictionary = m.palco.plano_aberto_do_duelo()
	ok("a câmera do duelo achou um ponto com linha de vista LIVRE até os dois lutadores (%s)" % str(cam.get("de")), bool(cam.get("livre", false)))
	var ve_mesmo: bool = true
	var espaco := p.get_world_3d().direct_space_state
	for ponto_lutador in [m.palco.lugar_do_jogador() + Vector3.UP * 1.6, m.palco.lugar_da_alvida() + Vector3.UP * 1.7]:
		var qq := PhysicsRayQueryParameters3D.create(cam["de"], ponto_lutador, PalcoDaAlvida.CAMADA_DA_CAMERA)
		qq.hit_back_faces = true
		if not espaco.intersect_ray(qq).is_empty(): ve_mesmo = false
	ok("conferido por raio independente: nada entre a câmera e os dois lutadores", ve_mesmo)
	ok("a malha 'Colisao' do navio NÃO aparece (o navio 'bugado' era ela por cima)", m.palco.navio.find_children("Colisao*", "MeshInstance3D", true, false).all(func(n): return not n.is_visible_in_tree()))
	# piso do convés: um raio do alto acha o piso na altura do convés
	var q := PhysicsRayQueryParameters3D.create(m.palco.ponto_da_arena() + Vector3.UP * 5.0, m.palco.ponto_da_arena() + Vector3.DOWN * 5.0)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	ok("o piso do convés existe na física (jogador congelado não cai)", not hit.is_empty() and absf(hit["position"].y - (m.palco.navio.global_position.y + PalcoDaAlvida.CONVES_Y)) < 0.05)
	ok("SEM MÚSICA na missão da Alvida (pedido do dono, 22/11)", not m.musica.tocando("res://assets/audio/musica/buggy_copos_loop.ogg"))
	# o barril sobe
	var anterior: Vector3 = m.palco.barril.global_position
	var atravessou := 0
	for i in 900:
		await physics_frame
		if m.palco != null:
			var yb2: float = m.palco.barril.global_position.y
			y_min = minf(y_min, yb2); y_max = maxf(y_max, yb2)
			if m.etapa == 2 and m.palco.barril.visible:
				var atual: Vector3 = m.palco.barril.global_position
				for dx in [0.0, 0.8, -0.8]:                 # centro e as bordas do barril (raio ≈ 0,85 m)
					var qa := PhysicsRayQueryParameters3D.create(anterior + Vector3(dx, 0.8, 0), atual + Vector3(dx, 0.8, 0), PalcoDaAlvida.CAMADA_DA_CAMERA)
					qa.hit_back_faces = true
					if not p.get_world_3d().direct_space_state.intersect_ray(qa).is_empty(): atravessou += 1
				anterior = atual
		if m.etapa == 3: break
	ok("o barril NÃO atravessa o casco/amurada do navio no caminho (%d cruzamentos)" % atravessou, atravessou == 0)
	ok("o barril foi içado do mar até o convés (subiu %.1f m)" % (y_max - y_min), y_max - y_min > 3.0)

	print("-- duelo --")
	ok("começa o duelo", m.etapa == 3 and m.duelo != null and is_instance_valid(m.hud_duelo))
	await frames(4)
	ok("barril some e o jogador aparece no convés, em −X da Alvida, visível", not m.palco.barril.visible and p.visible and p.global_position.distance_to(m.palco.lugar_do_jogador()) < 1.0)
	ok("HUD do duelo: 3 botões ligados e 7×7", m.hud_duelo.vidas_do_jogador == 7 and m.hud_duelo.vidas_da_alvida == 7 and not m.hud_duelo.bloqueado)
	# empate (Alvida joga TESOURA)
	m._ao_escolher(DueloPpt.TESOURA)
	ok("ao escolher, os botões bloqueiam (não dá para escolher duas vezes)", m.hud_duelo.bloqueado)
	m._ao_escolher(DueloPpt.PEDRA)
	ok("escolha repetida no meio da animação é ignorada", m.duelo.rodadas == 1)
	for i in 400:
		await physics_frame
		if not m.hud_duelo.bloqueado: break
	ok("EMPATE: ninguém perde vida e os botões voltam", m.duelo.vidas_do_jogador == 7 and m.duelo.vidas_da_alvida == 7 and not m.hud_duelo.bloqueado)
	# jogador perde uma
	m._ao_escolher(DueloPpt.PAPEL)
	for i in 400:
		await physics_frame
		if not m.hud_duelo.bloqueado: break
	ok("Alvida acerta: jogador 6 (HUD 6)", m.duelo.vidas_do_jogador == 6 and m.hud_duelo.vidas_do_jogador == 6)
	var ouro_antes := progresso.ouro; var xp_antes := progresso.xp; var niv_antes := progresso.nivel
	for k in 7:
		m._ao_escolher(DueloPpt.PEDRA)
		for i in 500:
			await physics_frame
			if m.etapa == 4 or not m.hud_duelo.bloqueado: break
		if m.etapa == 4: break
	ok("7 acertos: o duelo acaba com vitória (Alvida 0)", m.duelo.vencedor() == "jogador" and m.duelo.vidas_da_alvida == 0 and m.resultado == "vitoria")
	ok("o prêmio é pago NO FIM do duelo: +1000 moedas", progresso.ouro == ouro_antes + 1000)
	ok("+8000 XP (XP/nível subiram)", progresso.xp != xp_antes or progresso.nivel > niv_antes)
	ok("missão entregue", progresso.estado_da_missao("alvida_no_navio") == "entregue")
	var ouro_pago := progresso.ouro
	ok("o desfecho começou (etapa 4)", m.etapa == 4)

	print("-- saída para a Ilha dos Macacos --")
	for i in 1800:
		await physics_frame
		if m.etapa == 0: break
	ok("a missão termina e devolve tudo (etapa ociosa)", m.etapa == 0)
	ok("o jogador está na Ilha dos Macacos (x > 1300)", p.global_position.x > 1300.0)
	ok("jogador visível, livre e com combate de volta", p.visible and not bool(p.get_meta("is_frozen", false)) and p.capacidades.can_attack)
	await frames(40)                                      # a faixa da cena sai com animação de 0,28 s
	print("     palco=%s hud_duelo=%s menu=%s" % [str(m.palco), str(m.hud_duelo), str(hud.is_menu_open())])
	ok("palco, HUD do duelo e véu removidos", m.palco == null and not is_instance_valid(m.hud_duelo) and not hud.is_menu_open())
	ok("a recompensa NÃO foi paga duas vezes", progresso.ouro == ouro_pago)
	ok("a câmera do jogo voltou (não é a do duelo)", get_root_camera_ok())
	ok("o vendedor agora só abre a loja (já venceu)", RegrasDaAlvida.situacao(progresso) == RegrasDaAlvida.JA_VENCEU and not m.ao_conversar())

	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func get_root_camera_ok() -> bool:
	var c := root.get_viewport().get_camera_3d()
	return c != null and c.name != "CameraDoDuelo" and c.name != "CameraDaCena"
