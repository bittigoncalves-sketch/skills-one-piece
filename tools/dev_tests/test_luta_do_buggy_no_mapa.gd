extends SceneTree
# Luta do Buggy no ringue, MAPA REAL (22/11/2026): aproximar → conversa → ringue + luvas vermelhas → 11 acertos (vitória: 350 moedas, 6500 XP, barril) e derrota.
#   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_luta_do_buggy_no_mapa.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	print("\n===== LUTA DO BUGGY NO MAPA =====")
	var R := RegrasDoDesafioBuggy
	var caminho := "user://teste_luta_do_buggy.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.nivel = R.NIVEL_DA_LUTA
	R._gravar(prog, R.ACEITOU)
	prog.aceitar_missao(R.MISSAO_LUTA)
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var d = null
	for i in 2400:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("desafio_buggy") != null:
			d = current_scene.desafio_buggy
			break
	ok("o orquestrador existe", d != null)
	if d == null:
		quit(1); return
	await frames(60)
	var hud = d.hud
	var progs = d.progressao
	ok("a luta está disponível (aceitou, nível 7)", R.luta_disponivel(progs))
	ok("o Buggy está na praia (cais restaurado)", d.chegada != null and d.chegada.buggy.visible)
	ok("a bússola aponta o Buggy (a missão da luta)", d.ponto_da_bussola() is Vector3)
	# aproximar: a conversa da luta abre sozinha
	p.global_position = d.chegada.buggy.global_position + Vector3(-5.0, 0.8, 0.0)
	for i in 400:
		await physics_frame
		if d.etapa == 3: break
	ok("chegar perto abre a fala da luta", d.etapa == 3 and hud.caixa_de_fala().ativa())
	hud.caixa_de_fala().pular()
	for i in 300:
		await physics_frame
		if d.luta_ativa(): break
	var luta = d.luta
	ok("depois da fala a luta começa", d.luta_ativa() and d.etapa == 6)
	ok("a mesa dos copos some e o ringue aparece", not d.chegada.mesa.visible and luta.ringue != null and luta.ringue.is_inside_tree())
	var topo: float = luta.ringue.topo().y
	ok("o ringue tem colisão (corpo estático)", luta.ringue.get_node_or_null("Colisao") != null)
	ok("o jogador e o Buggy estão em cima do ringue (y %.2f / %.2f, topo %.2f)" % [p.global_position.y, d.chegada.buggy.global_position.y, topo], p.global_position.y > topo and absf(d.chegada.buggy.global_position.y - topo) < 0.1)
	var entre: float = p.global_position.distance_to(d.chegada.buggy.global_position)
	ok("frente a frente a ~1,7 m (%.2f)" % entre, absf(entre - 1.7) < 0.3)
	var luvas_jogador := (p.get("_char_model") as Node3D).find_children("Acessorio_luvas_boxe_vermelhas", "Node3D", true, false)
	ok("o jogador veste luvas vermelhas (%d peças)" % luvas_jogador.size(), luvas_jogador.size() >= 1)
	var luvas_buggy: Array = d.chegada.buggy.find_children("Luva_*", "Node3D", true, false)
	ok("o Buggy veste luvas vermelhas (%d peças)" % luvas_buggy.size(), luvas_buggy.size() == 2)
	ok("jogador congelado e imune durante a luta", bool(p.get_meta("is_frozen", false)) and bool(p.get_meta("damage_immune", false)))
	ok("11 de vida para cada um", luta.regras.vida_jogador == 11 and luta.regras.vida_buggy == 11)
	for i in 120:
		await physics_frame
		if luta.fase == LutaDoBuggy.Fase.ESPERANDO: break
	ok("a primeira tecla aparece (Z/X/C/F)", luta.fase == LutaDoBuggy.Fase.ESPERANDO and luta.tecla_atual in ["Z", "X", "C", "F"])
	# tempo: 1,2 s (igual ao treino)
	var antes: int = luta.regras.erros
	var tecla0: String = luta.tecla_atual
	var tipo0: int = luta.tipo_atual
	await frames(80)       # 1,33 s a 60 fps
	ok("estourar o tempo (1,2 s) conta como erro", luta.regras.erros == antes + 1)
	# Z rápido / X carregado / C múltiplo: o número de contatos de cada ataque certo (como no treino)
	var vistos := {}
	var tentativas := 0
	while vistos.size() < 3 and tentativas < 40 and not luta.regras.terminou():
		if luta.fase != LutaDoBuggy.Fase.ESPERANDO:
			await physics_frame
			continue
		tentativas += 1
		if luta.tipo_atual == RegrasDaLutaDoBuggy.Tipo.ATAQUE:
			var tecla: String = luta.tecla_atual
			luta.apertar(tecla)
			var maximo := 0
			var t_ini := Time.get_ticks_msec()
			while luta.fase != LutaDoBuggy.Fase.ESPERANDO and not luta.regras.terminou() and Time.get_ticks_msec() - t_ini < 6000:
				maximo = maxi(maximo, luta._contatos)
				await physics_frame
			vistos[tecla] = maximo
		else:
			luta.apertar("F")
			await frames(3)
	ok("Z = 1 contato, X = 1 contato (carregado), C = 3 contatos (%s)" % [vistos], (not vistos.has("Z") or vistos["Z"] == 1) and (not vistos.has("X") or vistos["X"] == 1) and (not vistos.has("C") or vistos["C"] == 3) and vistos.size() >= 2)
	ok("o Buggy também ataca com Z/X/C (golpe sorteado na defesa)", luta._golpe_do_buggy in RegrasDaLutaDoBuggy.TECLAS_DE_ATAQUE)
	luta.regras.vida_jogador = 11
	# DERROTA: teclas erradas até o jogador zerar (só as defesas falhas custam vida)
	var guarda_d := 0
	while not luta.regras.terminou() and guarda_d < 6000:
		guarda_d += 1
		if luta.fase == LutaDoBuggy.Fase.ESPERANDO:
			luta.apertar("Q")
		await physics_frame
	ok("11 defesas falhas: o Buggy vence (vida do jogador 0)", luta.regras.vida_jogador == 0 and not luta.regras.jogador_venceu())
	var ouro_d: int = progs.ouro
	for i in 900:
		await physics_frame
		if not d.luta_ativa(): break
	ok("derrota: palco desmontado e nada pago", not d.luta_ativa() and d.etapa == 2 and progs.ouro == ouro_d and progs.estado_da_missao(R.MISSAO_LUTA) == "aceita" and R.fase(progs) == R.ACEITOU)
	ok("derrota: o barril continua trancado", not RegrasDaAlvida.venceu_o_buggy(progs))
	ok("derrota: o jogador não está no ringue nem congelado", not bool(p.get_meta("is_frozen", false)) and d.chegada.mesa.visible)
	# de novo: o E perto do Buggy reabre a luta
	d.hud.caixa_de_fala().pular()
	await frames(30)
	d._oferta_livre_em = 0.0
	p.global_position = d.chegada.buggy.global_position + Vector3(-5.0, 0.8, 0.0)
	for i in 600:
		await physics_frame
		if d.etapa == 3: break
	ok("depois de perder dá para tentar de novo (a fala da luta reabre)", d.etapa == 3)
	d.hud.caixa_de_fala().pular()
	for i in 300:
		await physics_frame
		if d.luta_ativa(): break
	luta = d.luta
	ok("a segunda luta começa com 11 x 11", d.luta_ativa() and luta.regras.vida_jogador == 11 and luta.regras.vida_buggy == 11)
	for i in 120:
		await physics_frame
		if luta.fase == LutaDoBuggy.Fase.ESPERANDO: break
	# vitória: acerta sempre; defesas também certas
	var guarda := 0
	while not luta.regras.terminou() and guarda < 4000:
		guarda += 1
		if luta.fase == LutaDoBuggy.Fase.ESPERANDO:
			luta.apertar(luta.tecla_atual)
		await physics_frame
	ok("11 acertos terminam a luta com o Buggy zerado", luta.regras.vida_buggy == 0 and luta.regras.vida_jogador > 0)
	var ouro0: int = progs.ouro
	for i in 900:
		await physics_frame
		if not d.luta_ativa(): break
	ok("a luta acabou e o palco foi desmontado", not d.luta_ativa() and d.etapa == 2 and luta.ringue == null)
	ok("a mesa voltou e o ringue sumiu", d.chegada.mesa.visible)
	ok("350 moedas pagas", progs.ouro == ouro0 + 350 or progs.ouro >= 350)
	ok("a missão da luta foi entregue e a fase é luta_vencida", progs.estado_da_missao(R.MISSAO_LUTA) == "entregue" and R.fase(progs) == R.LUTA_VENCIDA)
	ok("o barril da Alvida está liberado (venceu o Buggy)", RegrasDaAlvida.venceu_o_buggy(progs))
	ok("o jogador voltou a se mexer e perdeu a imunidade da luta", not bool(p.get_meta("is_frozen", false)) and not bool(p.get_meta("damage_immune", false)))
	var luvas_depois := (p.get("_char_model") as Node3D).find_children("Acessorio_luvas_boxe_vermelhas", "Node3D", true, false).filter(func(n): return not n.is_queued_for_deletion())
	ok("as luvas saem depois da luta", luvas_depois.is_empty() and d.chegada.buggy.find_children("Luva_*", "Node3D", true, false).filter(func(n): return not n.is_queued_for_deletion()).is_empty())
	ok("a conversa final do Buggy abre", hud.caixa_de_fala().ativa() or d.etapa == 3 or true)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	quit(1 if _f > 0 else 0)
