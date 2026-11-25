extends SceneTree
# ============================================================================
#  TESTE DA POSE DO COMBATE DIRECIONAL — a avaliação pura (sem cena, sem rig).
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 3. Prova que a linha do tempo começa
#  e termina na guarda, passa EXATAMENTE pelas chaves, não teletransporta a mão entre
#  quadros, que a reação sobe e volta, e que a validação das fichas sabe reprovar.
#
#  A pose no corpo de verdade (IK, alcance, pico de velocidade no ATIVO) é medida por
#  `medir_pose_combate.gd` e cobrada no teste de contato.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_pose_de_combate.gd
# ============================================================================

const ESTILO := "res://src/combat/direcional/estilos/boxe.tres"
const EPS := 0.0005

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== POSE DO COMBATE DIRECIONAL =====")
	var estilo := load(ESTILO) as EstiloCorpoACorpo
	_ok(estilo != null and estilo.validar().is_empty(), "boxe.tres carrega e é válido %s" % str(estilo.validar() if estilo else []))
	if estilo != null:
		_pontas_e_chaves(estilo)
		_continuidade(estilo)
		_reacao(estilo)
		_heranca_da_guarda(estilo)
		_validacao_reprova(estilo)
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _perto(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) <= EPS


func _pontas_e_chaves(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 1. começa e termina na guarda, passa pelas chaves --")
	var guarda := {}
	PoseDeCombate.guarda(estilo.guarda, guarda)
	for golpe in estilo.golpes:
		var p := {}
		PoseDeCombate.amostrar(golpe, estilo.guarda, 0.0, p)
		var inicio_ok: bool = _perto(p["mao_R"], guarda["mao_R"]) and _perto(p["mao_L"], guarda["mao_L"])
		PoseDeCombate.amostrar(golpe, estilo.guarda, golpe.duracao(), p)
		var fim_ok: bool = _perto(p["mao_R"], guarda["mao_R"]) and _perto(p["mao_L"], guarda["mao_L"])
		_ok(inicio_ok and fim_ok, "%s: t=0 e t=duração são a guarda" % golpe.id)
		var chaves_ok := true
		for c in golpe.chaves:
			PoseDeCombate.amostrar(golpe, estilo.guarda, c.tempo_em(golpe), p)
			var mao: Vector3 = p["mao_R"] if c.usa_mao_direita else p["mao_L"]
			var alvo := c.mao_direita if c.usa_mao_direita else c.mao_esquerda
			chaves_ok = chaves_ok and _perto(mao, alvo)
		_ok(chaves_ok, "%s: no instante de cada chave a mão está exatamente no alvo dela" % golpe.id)


func _continuidade(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 2. nada teletransporta --")
	for golpe in estilo.golpes:
		var p := {}
		var anterior := Vector3.INF
		var pior := 0.0
		var t := 0.0
		while t <= golpe.duracao():
			PoseDeCombate.amostrar(golpe, estilo.guarda, t, p)
			var mao: Vector3 = p["mao_R"] if String(golpe.efetor).ends_with("_R") else p["mao_L"]
			if anterior != Vector3.INF:
				pior = maxf(pior, mao.distance_to(anterior))
			anterior = mao
			t += 0.001
		# 20 m/s a 1 ms = 2 cm. Um soco rápido chega a ~9 m/s no rig real.
		_ok(pior < 0.02, "%s: maior salto da mão em 1 ms = %.4f m" % [golpe.id, pior])


func _reacao(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 3. a reação sobe, segura e volta --")
	var guarda := {}
	PoseDeCombate.guarda(estilo.guarda, guarda)
	var pico := estilo.reacao_pesada
	var p := {}
	PoseDeCombate.reacao(estilo.guarda, pico, 0.0, p)
	_ok(_perto(p["mao_R"], guarda["mao_R"]), "u=0: guarda")
	PoseDeCombate.reacao(estilo.guarda, pico, 0.4, p)
	_ok(_perto(p["mao_R"], pico.mao_direita), "u=0,4: no pico do tranco")
	PoseDeCombate.reacao(estilo.guarda, pico, 1.0, p)
	_ok(_perto(p["mao_R"], guarda["mao_R"]), "u=1: de volta à guarda")
	_ok(estilo.reacao_para(ResolucaoDeContato.Lado.ESQUERDA, false) == estilo.reacao_esquerda
		and estilo.reacao_para(ResolucaoDeContato.Lado.ESQUERDA, true) == estilo.reacao_pesada,
		"golpe pesado usa a reação pesada venha de onde vier")


## Toda postura que o executor monta completa o que não escreve com a GUARDA DO ESTILO
## — base (pés, joelhos, quadril) e giro do quadril. Erro de 17/09: a guarda erguida herdava
## dela mesma, sem pés, e punha o tornozelo na origem do corpo.
func _heranca_da_guarda(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 3b. toda postura herda a base da guarda do estilo --")
	var g := estilo.guarda
	var casos := []   # [rótulo, pose montada, chave que ela mostra]
	var erguida := {}
	PoseDeCombate.guarda(estilo.pose_guarda_erguida, erguida, g)
	casos.append(["guarda erguida", erguida, estilo.pose_guarda_erguida])
	for par in [["gesto de aparo", estilo.pose_aparo], ["tranco na guarda", estilo.pose_impacto_na_guarda]]:
		var p := {}
		PoseDeCombate.reacao(estilo.pose_guarda_erguida, par[1], 0.45, p, g)
		casos.append([par[0], p, par[1]])
	for par in [["quebra", estilo.pose_quebra_de_guarda], ["rebatido", estilo.pose_rebatido],
			["reação frente", estilo.reacao_frente], ["reação pesada", estilo.reacao_pesada]]:
		var p := {}
		PoseDeCombate.reacao(g, par[1], 0.45, p)
		casos.append([par[0], p, par[1]])
	var erros := PackedStringArray()
	for caso in casos:
		var p: Dictionary = caso[1]
		var c: ChaveDePose = caso[2]
		var pe_l: Vector3 = c.pe_esquerdo if c.usa_pes else g.pe_esquerdo
		var quadril: Vector3 = c.quadril if c.usa_pes else g.quadril
		var torso: Vector3 = c.rotacoes.get("Torso", g.rotacoes.get("Torso", Vector3.ZERO)) * (PI / 180.0)
		if not _perto(p["pe_L"], pe_l) or not _perto(p["quadril"], quadril) \
				or not _perto(p["rot"].get("Torso", Vector3.INF), torso):
			erros.append("%s (pe_L %s, quadril %s)" % [caso[0], p["pe_L"], p["quadril"]])
	_ok(erros.is_empty(), "%d posturas com a base e o quadril herdados da guarda %s" % [casos.size(), str(erros)])
	var sem_heranca := {}
	PoseDeCombate.guarda(estilo.pose_guarda_erguida, sem_heranca)
	_ok(not _perto(sem_heranca["pe_L"], g.pe_esquerdo),
		"controle: sem a herança, a guarda erguida perde os pés (%s) — a checagem sabe reprovar" % sem_heranca["pe_L"])


func _validacao_reprova(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 4. a validação sabe reprovar --")
	var base := estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA)

	var fora_de_ordem := base.duplicate(true) as GolpeDirecional
	var invertidas: Array[ChaveDePose] = []
	for i in range(fora_de_ordem.chaves.size() - 1, -1, -1):
		invertidas.append(fora_de_ordem.chaves[i])
	fora_de_ordem.chaves = invertidas
	_ok(not fora_de_ordem.validar().is_empty(), "chaves fora de ordem são recusadas")

	var sem_ativo := base.duplicate(true) as GolpeDirecional
	var so_preparo: Array[ChaveDePose] = []
	for c in sem_ativo.chaves:
		if c.fase == GolpeDirecional.Fase.PREPARO:
			so_preparo.append(c)
	sem_ativo.chaves = so_preparo
	_ok(not sem_ativo.validar().is_empty(), "golpe sem chave no ATIVO é recusado (contato não desenhado)")

	var sem_efetor := base.duplicate(true) as GolpeDirecional
	sem_efetor.efetor = &""
	_ok(not sem_efetor.validar().is_empty(), "golpe sem efetor é recusado")

	var guarda_manca := estilo.duplicate(true) as EstiloCorpoACorpo
	guarda_manca.guarda.usa_mao_esquerda = false
	_ok(not guarda_manca.validar().is_empty(), "guarda sem uma das mãos é recusada")
	_ok(estilo.guarda.usa_mao_esquerda, "controle: a cópia não alterou o estilo carregado")
