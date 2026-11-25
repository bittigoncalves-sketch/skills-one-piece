extends SceneTree
# 3ª missão, "Resgate o baú" (21/11/2026): regras puras + fluxo no mapa real (mímico, golpe, drop, entrega). Rodar:
#   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_resgate_do_bau.gd
# (etapas do --script sem citar classes que usam autoloads: variáveis sem tipo)
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

func _com_buggy_resolvido() -> ProgressaoDoPersonagem:
	var p := ProgressaoDoPersonagem.new()
	p.aceitar_missao("treino"); p.contar_abate("treino"); p.entregar_missao("treino")
	RegrasDoDesafioBuggy.marcar_chegada(p); RegrasDoDesafioBuggy.resolver_copos(p, true)
	return p

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	print("\n===== RESGATE DO BAÚ =====")
	var R := RegrasDoResgateDoBau
	# --- regras puras
	var p0 := ProgressaoDoPersonagem.new()
	ok("sem o desafio do Buggy resolvido a missão NÃO pode ser aceita", not p0.aceitar_missao(R.MISSAO))
	var lj0 = preload("res://src/historia/npcs/loja_do_barba_negra.gd").new()
	lj0.set("npc", "npc_barba_negra"); lj0.set("missao", R.MISSAO); lj0.set("progressao", p0)
	ok("BLOQUEADA (sem o Buggy): a fala é a das lojas, não a oferta", lj0.fala().contains("Tiro a fruta") and not lj0.fala().contains("Um baú misterioso"))
	var p := _com_buggy_resolvido()
	ok("depois do Buggy a missão está disponível", p.estado_da_missao(R.MISSAO) == "disponivel")
	ok("sem aceitar não começa a procura", not R.deve_comecar(p) and not R.comecar(p))
	ok("aceitar a missão", p.aceitar_missao(R.MISSAO))
	ok("começar a procura (uma vez)", R.deve_comecar(p) and R.comecar(p) and R.fase(p) == R.PROCURANDO and not R.comecar(p))
	ok("pegar sem derrubar não vale", not R.pegar_drop(p) and p.estado_da_missao(R.MISSAO) == "aceita")
	ok("derrubar o mímico solta o drop no ponto", R.mimico_atingido(p, Vector3(1, 2, 3)) and R.fase(p) == R.SOLTO and R.posicao_do_drop(p) == Vector3(1, 2, 3))
	ok("golpes repetidos não duplicam o drop", not R.mimico_atingido(p, Vector3(9, 9, 9)) and R.posicao_do_drop(p) == Vector3(1, 2, 3))
	var salvo := "user://teste_resgate.json"
	p.salvar(salvo)
	var l := ProgressaoDoPersonagem.carregar(salvo)
	ok("save/load no meio preserva fase e posição do drop", R.fase(l) == R.SOLTO and R.posicao_do_drop(l) == Vector3(1, 2, 3))
	# mochila cheia: o drop NÃO é pego e nada muda
	var cheia := ProgressaoDoPersonagem.carregar(salvo)
	for i in cheia.inventario.slots.size():
		cheia.inventario.slots[i] = McItem.pilha(null, 0)
	for i in cheia.inventario.slots.size():
		cheia.inventario.inserir(InventarioMinecraft.nova("minecraft:stone", 64))
	ok("mochila CHEIA: não pega o drop e a fase não muda", not R.pegar_drop(cheia) and R.fase(cheia) == R.SOLTO and cheia.estado_da_missao(R.MISSAO) == "aceita")
	ok("pegar o drop cumpre a missão (pronta) e só uma vez", R.pegar_drop(p) and p.estado_da_missao(R.MISSAO) == "pronta" and not R.pegar_drop(p))
	ok("o Baú misterioso ENTROU na mochila (1 unidade, com nome e ícone)", p.inventario.contar(BauMisteriosoItem.ID) == 1 and RegrasDeItens.nome(BauMisteriosoItem.ID).contains("Baú misterioso") and RegrasDeItens.icone(BauMisteriosoItem.ID) != null and RegrasDeItens.limite(BauMisteriosoItem.ID) == 1)
	var sem_item := ProgressaoDoPersonagem.carregar(salvo)
	R.pegar_drop(sem_item)
	BauMisteriosoItem.consumir(sem_item.inventario)          # o jogador "perdeu" o item
	var ouro_si := sem_item.ouro
	ok("entregar SEM o item não paga e não muda nada", not bool(R.entregar(sem_item)["ok"]) and sem_item.ouro == ouro_si and sem_item.estado_da_missao(R.MISSAO) == "pronta")
	var ouro0 := p.ouro; var xp0 := p.xp; var nv0 := p.nivel
	var girafas0 := p.quantas_akuma("ushi_ushi_giraffe")
	ok("antes de entregar o jogador NÃO tem a fruta da girafa", girafas0 == 0)
	ok("entregar CONSOME o item e paga 20 moedas e 700 XP", bool(R.entregar(p)["ok"]) and p.ouro == ouro0 + 20 and (p.xp != xp0 or p.nivel != nv0) and p.inventario.contar(BauMisteriosoItem.ID) == 0)
	ok("RECOMPENSA EXTRA: recebeu a Ushi Ushi no Mi (1 nas frutas guardadas)", p.quantas_akuma("ushi_ushi_giraffe") == 1)
	ok("não paga duas vezes (nem a fruta)", not bool(R.entregar(p)["ok"]) and not p.entregar_missao(R.MISSAO) and p.quantas_akuma("ushi_ushi_giraffe") == 1)
	ok("entregar sem o item NÃO dá a fruta", sem_item.quantas_akuma("ushi_ushi_giraffe") == 0)
	var lm = preload("res://src/historia/missoes/loja_de_missao.gd").new()
	lm.set("missao", "resgate_do_bau"); lm.set("progressao", p)
	var lin: Array = lm.linhas(p, null)
	ok("a janela da missão anuncia a fruta no prêmio", lin.size() == 1 and str(lin[0].detalhe).contains("Ushi Ushi"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(salvo))
	# --- no mapa real
	var caminho := "user://teste_resgate_mapa.json"
	var prog := _com_buggy_resolvido()
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var pl = null
	var d = null
	for i in 6000:
		await physics_frame
		pl = get_first_node_in_group("player")
		if pl != null and current_scene != null and current_scene.get("resgate_do_bau") != null:
			d = current_scene.resgate_do_bau; break
	ok("o orquestrador do resgate existe", d != null)
	if d == null:
		quit(1); return
	await frames(60)
	var progresso = d.progressao
	# o Barba Negra oferece a missão
	var barba = null
	for n in current_scene.find_children("*", "NpcDaIlha", true, false):
		if n.tipo == "npc_barba_negra": barba = n
	ok("o Barba Negra existe e tem a missão do resgate", barba != null and barba.missao() == "resgate_do_bau")
	var loja = barba.loja()
	loja.set("progressao", progresso)
	var linhas: Array = loja.linhas(progresso, null)
	ok("a janela do Barba mostra a missão no TOPO com botão Aceitar", linhas.size() > 1 and linhas[0].id == "resgate_do_bau" and linhas[0].botoes[0].texto == "Aceitar")
	ok("as lojas dele continuam na janela (retirar fruta, roleta…)", linhas.any(func(x): return x.id == "retirar_fruta"))
	ok("FALA no estado DISPONÍVEL (desbloqueada) = oferta do bau.json", loja.fala().contains("Um baú misterioso apareceu") and loja.fala().contains("Ushi Ushi"))
	loja.executar(progresso, null, "aceitar", "resgate_do_bau")
	ok("FALA em andamento = andamento do bau.json", loja.fala().contains("A bússola aponta"))
	ok("aceitar pela janela", progresso.estado_da_missao("resgate_do_bau") == "aceita")
	await frames(90)
	ok("a procura começa e o mímico nasce", R.fase(progresso) == R.PROCURANDO and is_instance_valid(d.mimico))
	var m = d.mimico
	var alvo = d.ponto_da_bussola()
	ok("a bússola aponta para o mímico", alvo is Vector3 and alvo.distance_to(m.global_position) < 0.5)
	ok("o mímico fica a ~64 m do Barba Negra (50–90 m)", m.global_position.distance_to(barba.global_position) > 50.0 and m.global_position.distance_to(barba.global_position) < 90.0)
	ok("começa DISFARÇADO (tampa fechada)", m.estado == 0 and not m._boca.visible)
	ok("está no grupo de alvos de golpe e tem corpo físico", m.is_in_group("alvo_de_golpe") and m is StaticBody3D)
	# o jogador chega perto: revela
	pl.global_position = m.global_position + Vector3(3.0, 1.0, 0.0)
	await frames(30)
	ok("chegando perto o mímico se REVELA (boca aberta)", m.estado == 1 and m._boca.visible)
	var p_antes = m.global_position
	await frames(120)
	ok("ele FOGE aos saltos (moveu-se > 2 m)", m.global_position.distance_to(p_antes) > 2.0)
	ok("não passou do raio da fuga", m.global_position.distance_to(m.origem) <= m.RAIO_DA_FUGA + 1.0)
	var agua = AguaDoMundo.nivel_em(m.global_position.x, m.global_position.z)
	ok("não foi parar na água", is_nan(agua) or m.global_position.y > agua)
	# golpe REAL: uma DamageZone do jogador sobre o mímico
	var zona = DamageZone.new()
	current_scene.add_child(zona)
	zona.global_position = m.global_position + Vector3(0, 0.4, 0)
	zona.setup(20.0, 8.0, Vector3.ZERO, 0.4, pl, 1.2)
	await frames(40)
	var chegou_drop = is_instance_valid(d.drop) or R.fase(progresso) == R.SOLTO
	ok("UM golpe real derruba o mímico e solta o drop", chegou_drop)
	if not chegou_drop:
		m.take_damage(20.0)                 # diagnóstico: caminho direto
		await frames(20)
		print("    (a DamageZone não acertou; take_damage direto → fase %s)" % R.fase(progresso))
	await frames(30)
	ok("fase solta e drop no chão", R.fase(progresso) == R.SOLTO and is_instance_valid(d.drop))
	ok("a bússola passa a apontar o drop", d.ponto_da_bussola() is Vector3 and d.ponto_da_bussola().distance_to(d.drop.global_position) < 0.5)
	pl.global_position = d.drop.global_position + Vector3(0.5, 0.0, 0.0)
	await frames(40)
	ok("pegar o drop: missão PRONTA, bússola some", progresso.estado_da_missao("resgate_do_bau") == "pronta" and d.ponto_da_bussola() == null)
	ok("FALA pronta = 'Entregue-o e receberá…'", loja.fala().contains("Entregue-o e receberá"))
	ok("o item está na mochila antes de entregar", progresso.inventario.contar("historia:bau_misterioso") == 1)
	var ouro0b = progresso.ouro; var xp_total0 = progresso.xp + progresso.nivel * 100000
	loja.executar(progresso, null, "entregar", "resgate_do_bau")
	ok("a entrega pela janela do Barba tirou o item da mochila", progresso.inventario.contar("historia:bau_misterioso") == 0)
	ok("FALA concluída (após entregar) = concluida do bau.json", loja.fala().contains("Obrigado pelo baú"))
	ok("e entregou a Ushi Ushi no Mi (N › FRUTAS)", progresso.quantas_akuma("ushi_ushi_giraffe") == 1)
	ok("falar com o Barba e entregar: +20 moedas", progresso.ouro == ouro0b + 20 and progresso.estado_da_missao("resgate_do_bau") == "entregue")
	ok("…e o XP entrou (700)", progresso.xp + progresso.nivel * 100000 > xp_total0 or progresso.nivel > 1)
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
