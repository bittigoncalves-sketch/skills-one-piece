extends SceneTree
## Reanimação do coração: minigame (robôs), chances em 30 min, coração voxel e o fluxo no Modo História.
## godot --headless --path . --script tools/dev_tests/test_coracao.gd

var _falhas := 0
var _n := 0
var _agora := 1000000

func _ok(cond: bool, msg: String) -> void:
	_n += 1
	if cond:
		print("  ✅ ", msg)
	else:
		_falhas += 1
		print("  ❌ ", msg)

func _init() -> void:
	_rodar.call_deferred()

func _quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _real(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _rodar() -> void:
	await process_frame
	_minigame()
	_janela()
	await _coracao_voxel()
	await _historia()
	print("\nCORACAO %d/%d; falhas=%d" % [_n - _falhas, _n, _falhas])
	quit(_falhas)

# ------------------------------------------------------------- A. o minigame
func _jogar(semente: int, bot: String) -> BatidaDoCoracao:
	var b := BatidaDoCoracao.new(semente)
	var dt := 1.0 / 60.0
	var seg := false
	while not b.terminou:
		match bot:
			"esperto": seg = b.pressao < 0.55 and not b.avisando and not b.arritmia
			"grosso":   # decide a cada 0,35 s: o reflexo de uma pessoa
				if int(b.tempo / 0.35) != int((b.tempo - dt) / 0.35):
					seg = b.pressao < 0.55 and not b.avisando
			"sempre": seg = true
			"nunca": seg = false
		b.passo(dt, seg)
	return b

func _media(bot: String) -> Array:
	var soma := 0.0
	var menor := 1.0
	var maior := 0.0
	var mortes := 0
	var maior_vida := 0.0
	var proporcional := true
	for s in 100:
		var b := _jogar(s, bot)
		soma += b.nota()
		menor = minf(menor, b.nota())
		maior = maxf(maior, b.nota())
		if not b.voltou():
			mortes += 1
		maior_vida = maxf(maior_vida, b.vida_devolvida())
		if b.voltou() and not is_equal_approx(b.vida_devolvida(), 0.5 * b.nota()):
			proporcional = false
	return [soma / 100.0, menor, maior, mortes, maior_vida, proporcional]

func _minigame() -> void:
	print("\n-- A. minigame (15 s, nota = barra cheia, vida ≤ 50 %) --")
	var esperto := _media("esperto")
	var grosso := _media("grosso")
	var sempre := _media("sempre")
	var nunca := _media("nunca")
	_ok(esperto[0] >= 0.85 and esperto[3] == 0, "jogador esperto: nota média %.2f, nunca morre" % esperto[0])
	_ok(grosso[0] > 0.4 and grosso[0] < 0.85 and grosso[1] < grosso[2], "jogador com reflexo de 0,35 s: nota média %.2f (de %.2f a %.2f) — depende da habilidade" % [grosso[0], grosso[1], grosso[2]])
	_ok(sempre[3] == 100 and nunca[3] == 100, "só segurar ou só soltar não reanima: nota < 10 %% e o coração não volta (%d e %d de 100)" % [sempre[3], nunca[3]])
	_ok(esperto[4] <= 0.5 and grosso[4] <= 0.5, "a vida devolvida nunca passa de 50 %% da máxima (maior: %.2f)" % maxf(esperto[4], grosso[4]))
	_ok(esperto[5] and grosso[5], "a vida devolvida é 50 %% × a nota")
	var b := BatidaDoCoracao.new(1)
	var passos := 0
	while not b.passo(1.0 / 60.0, false):
		passos += 1
	_ok(passos / 60.0 <= BatidaDoCoracao.DURACAO + 0.1, "o minigame acaba em %.1f s (limite %.0f s)" % [passos / 60.0, BatidaDoCoracao.DURACAO])
	var b2 := BatidaDoCoracao.new(2)
	for i in 600:
		b2.passo(1.0 / 60.0, b2.pressao < 0.55 and not b2.avisando and not b2.arritmia)
	_ok(b2.avisando or b2.arritmia or b2.tempo > 0, "há aviso antes de cada arritmia (a ‘!’)")
	var viu_aviso := false
	var b3 := BatidaDoCoracao.new(3)
	var antes_do_aviso_arritmia := true
	var teve_arritmia := false
	while not b3.terminou:
		var arr_antes := b3.arritmia
		b3.passo(1.0 / 60.0, false)
		if b3.avisando:
			viu_aviso = true
		if b3.arritmia and not arr_antes:
			teve_arritmia = true
			antes_do_aviso_arritmia = viu_aviso
	_ok(teve_arritmia and antes_do_aviso_arritmia, "toda arritmia é precedida do aviso")

# ------------------------------------------------------- B. chances em 30 min
func _janela() -> void:
	print("\n-- B. 1 ressurreição por janela de 30 minutos (relógio simulado) --")
	ReanimacaoDoCoracao.relogio_ms = func() -> int: return _agora
	ReanimacaoDoCoracao.esquecer_tentativas()
	_ok(ReanimacaoDoCoracao.MAX_TENTATIVAS == 1, "o limite é 1 ressurreição")
	_ok(ReanimacaoDoCoracao.chances_restantes() == 1, "começa com 1 chance")
	_agora = 1000000
	ReanimacaoDoCoracao.registrar(_agora)
	_ok(ReanimacaoDoCoracao.chances_restantes() == 0, "usou 1: nenhuma chance (a 2ª morte é certa)")
	_agora = 1000000 + 29 * 60000
	_ok(ReanimacaoDoCoracao.chances_restantes() == 0, "aos 29 min ainda vale a janela")
	_agora = 1000000 + 30 * 60000 + 1000
	_ok(ReanimacaoDoCoracao.chances_restantes() == 1, "passada a janela: 1 chance de novo")
	ReanimacaoDoCoracao.esquecer_tentativas()
	ReanimacaoDoCoracao.relogio_ms = Callable()

# ------------------------------------------------------------ C. o coração voxel
func _coracao_voxel() -> void:
	print("\n-- C. coração voxel --")
	var cubos := CoracaoVoxel.total_de_cubos()
	_ok(cubos > 800 and cubos < 6000, "o coração tem %d cubos" % cubos)
	var m := CoracaoVoxel.malha()
	var nomes: Array[String] = []
	for i in m.get_surface_count():
		nomes.append(m.surface_get_name(i))
	_ok(nomes.has("copa") and nomes.has("copa_clara") and nomes.has("tronco"), "três tons de vermelho (%s)" % str(nomes))
	_ok(ArvoreVoxel.faces_invertidas(m) == 0, "faces para fora (sem lado transparente)")
	var aabb := m.get_aabb()
	_ok(aabb.size.y > aabb.size.z and aabb.size.x > aabb.size.z * 0.9, "o volume é de coração: largo e alto, mais fino na profundidade (%s)" % aabb.size)
	var v := CoracaoVoxel.new()
	root.add_child(v)
	await process_frame
	v.bater(1.0)
	await process_frame
	_ok(v._raiz.scale.x > 1.05, "a batida faz o coração inchar (%.2f×)" % v._raiz.scale.x)
	v.queue_free()

# -------------------------------------------------------- D. Modo História de verdade
func _esperto(b: BatidaDoCoracao) -> bool:
	return b.pressao < 0.55 and not b.avisando and not b.arritmia

func _nunca(_b: BatidaDoCoracao) -> bool:
	return false

func _limpar(p: Node3D) -> void:
	for nome in ["ReanimacaoDoCoracao", "MorteDoJogador"]:
		var n := current_scene.get_node_or_null(nome)
		if n != null:
			n.queue_free()
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	p.net_force_respawn()
	p.morrendo = false
	p.remove_meta("damage_immune")
	await _quadros(3)

func _historia() -> void:
	print("\n-- D. no Modo História: vida zero -> coração -> volta ou morre --")
	ReanimacaoDoCoracao.esquecer_tentativas()
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_coracao.json")
	root.get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	var p: Node3D = null
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
	_ok(p != null and p.ao_morrer.is_valid(), "o Modo História instala o gancho")
	if p == null:
		return
	await _quadros(30)
	var y_antes: float = p._char_model.position.y

	# 1) vida zero -> minigame, e o robô esperto reanima
	p.health = 0.0
	p.die_and_respawn()
	await _quadros(3)
	var r := current_scene.get_node_or_null("ReanimacaoDoCoracao") as ReanimacaoDoCoracao
	_ok(r != null and current_scene.get_node_or_null("MorteDoJogador") == null, "vida zero abre o coração e NÃO a sequência de morte")
	if r == null:
		return
	_ok(is_equal_approx(Engine.time_scale, ReanimacaoDoCoracao.ESCALA_DO_MUNDO) and p.morrendo, "o mundo desacelera e o jogador fica parado (×%.2f)" % Engine.time_scale)
	_ok(ReanimacaoDoCoracao.tentativas_na_janela() == 1 and ReanimacaoDoCoracao.chances_restantes() == 0, "gastou a única chance")
	var coracao := r.find_children("*", "CoracaoVoxel", true, false)
	_ok(coracao.size() == 1, "o coração voxel está na tela")
	var vida_logo := [-1.0]      # a vida no instante em que o jogador levanta (depois a regeneração normal mexe nela)
	r.terminou.connect(func(_v: bool) -> void: vida_logo[0] = p.health)
	r.robo = _esperto
	r.acelerar = 6
	var t0 := Time.get_ticks_msec()
	while r.resultado.is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	_ok(r.resultado == "voltou" and r.batidas >= 4, "o robô esperto fez o coração voltar (%d batidas, nota %.2f)" % [r.batidas, r.batida.nota()])
	var nota := r.batida.nota()
	await _real(ReanimacaoDoCoracao.PAUSA_DEPOIS_DA_NOTA + 0.5)
	var esperada: float = p.max_health * 0.5 * nota
	_ok(absf(vida_logo[0] - esperada) < 0.05 and vida_logo[0] <= p.max_health * 0.5 + 0.001,
		"voltou com %.2f de %.0f de vida (50%% × nota %.2f = %.2f; teto 50%%)" % [vida_logo[0], p.max_health, nota, esperada])
	_ok(not p.morrendo and not p._eliminado and Engine.time_scale == 1.0, "o jogador levanta e o mundo volta ao normal")
	_ok(is_equal_approx(p._char_model.position.y, y_antes), "o corpo volta à altura de sempre")
	_ok(bool(p.get_meta("damage_immune", false)), "ganha uns segundos de imunidade ao levantar")
	await _real(ReanimacaoDoCoracao.IMUNIDADE_AO_VOLTAR + 0.3)
	_ok(not bool(p.get_meta("damage_immune", false)), "…e a imunidade acaba")
	_ok(current_scene.get_node_or_null("ReanimacaoDoCoracao") == null, "a camada do coração é removida")

	# o save: a chance gasta foi GRAVADA (formato v3) e sobrevive a reabrir o jogo
	var caminho := "user://test_coracao.json"
	var salvo := ProgressaoDoPersonagem.carregar(caminho)
	_ok(salvo.reanimacoes_ms.size() == 1 and absi(salvo.reanimacoes_ms[0] - ReanimacaoDoCoracao.agora()) < 120000,
		"a reanimação foi gravada no save (%s)" % str(salvo.reanimacoes_ms))
	var json := JSON.parse_string(FileAccess.get_file_as_string(caminho)) as Dictionary
	_ok(int(json.get("versao", 0)) == 3 and json.has("reanimacoes"), "formato do save v3 com o campo `reanimacoes`")
	_ok(salvo.reanimacoes_na_janela(ReanimacaoDoCoracao.agora(), ReanimacaoDoCoracao.JANELA_MS) == 1,
		"relido do disco, ainda conta 1 ressurreição na janela de 30 min")
	_ok(ProgressaoDoPersonagem.new().reanimacoes_ms.is_empty(), "campanha nova (reiniciar) começa sem reanimações")
	var velho := ProgressaoDoPersonagem.de_dict({"formato": "skills-one-piece/progresso", "versao": 2, "nivel": 3})
	_ok(velho != null and velho.reanimacoes_ms.is_empty(), "save antigo (v2, sem o campo) abre normalmente")
	var sujo := ProgressaoDoPersonagem.de_dict({"formato": "skills-one-piece/progresso", "versao": 3,
		"reanimacoes": ["x", -5, null, 1700000000000.0, 1700000100000, 0, {}, 1700000050000]})
	var esperado_sujo: Array[int] = [1700000000000, 1700000050000, 1700000100000]
	_ok(sujo.reanimacoes_ms == esperado_sujo, "valores inválidos no arquivo são descartados e a lista fica em ordem (%s)" % str(sujo.reanimacoes_ms))
	var muitos: Array = []
	for i in 20:
		muitos.append(1700000000000 + i * 1000)
	_ok(ProgressaoDoPersonagem.de_dict({"formato": "skills-one-piece/progresso", "reanimacoes": muitos}).reanimacoes_ms.size() == ProgressaoDoPersonagem.MAX_REANIMACOES_GUARDADAS,
		"arquivo com lista enorme: guarda só as últimas %d" % ProgressaoDoPersonagem.MAX_REANIMACOES_GUARDADAS)

	# 2) nota baixa -> o coração não volta -> morte de sempre (a janela é zerada: com 1 chance, a morte anterior a gastou)
	await _limpar(p)
	ReanimacaoDoCoracao.esquecer_tentativas()
	p.health = 0.0
	p.die_and_respawn()
	await _quadros(3)
	r = current_scene.get_node_or_null("ReanimacaoDoCoracao") as ReanimacaoDoCoracao
	_ok(r != null and ReanimacaoDoCoracao.chances_restantes() == 0, "2ª morte (1 por janela): abre o coração com a chance recém-gasta")
	r.robo = _nunca
	r.acelerar = 6
	t0 = Time.get_ticks_msec()
	while r.resultado.is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	_ok(r.resultado == "morreu", "sem jogar, o coração não volta (nota %.2f < 10 %%)" % r.batida.nota())
	await _real(ReanimacaoDoCoracao.PAUSA_DEPOIS_DA_NOTA + 0.6)
	_ok(current_scene.get_node_or_null("MorteDoJogador") != null, "e começa a sequência de morte de sempre")
	_ok(not bool(p.get_meta("damage_immune", false)) or p.get_node_or_null("x") == null, "a imunidade do coração não fica presa")

	# 3) sem chances -> morte certa direto
	await _limpar(p)
	ReanimacaoDoCoracao.esquecer_tentativas()
	ReanimacaoDoCoracao.registrar()
	p.health = 0.0
	p.die_and_respawn()
	await _quadros(3)
	_ok(current_scene.get_node_or_null("ReanimacaoDoCoracao") == null and current_scene.get_node_or_null("MorteDoJogador") != null,
		"depois de 1 reanimação em 30 min a morte é certa (sem minigame)")

	# 4) queda no vazio -> morte direta e NÃO gasta chance
	await _limpar(p)
	ReanimacaoDoCoracao.esquecer_tentativas()
	p.morrendo = true
	ReanimacaoDoCoracao.iniciar(p, true)
	await _quadros(3)
	_ok(current_scene.get_node_or_null("ReanimacaoDoCoracao") == null and current_scene.get_node_or_null("MorteDoJogador") != null
		and ReanimacaoDoCoracao.chances_restantes() == ReanimacaoDoCoracao.MAX_TENTATIVAS, "queda no vazio: morte direta, sem gastar chance")
	await _limpar(p)
	ReanimacaoDoCoracao.esquecer_tentativas()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
