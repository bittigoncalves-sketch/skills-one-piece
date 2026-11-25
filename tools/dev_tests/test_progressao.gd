extends SceneTree
# ============================================================================
#  TESTE DA PROGRESSÃO DO MODO HISTÓRIA — as regras do documento, sem subir o jogo.
#  (docs/references/modo_historia/modohistoriaplanejamento.pdf; seção entre [ ])
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_progressao.gd
# ============================================================================

const ARQUIVO := "user://test_progressao/progresso.json"

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== PROGRESSÃO (MODO HISTÓRIA) =====")
	_estado_inicial()
	_xp_e_niveis()
	_barreira()
	_pontos()
	_teto_absoluto()
	_inimigos()
	_antifarm()
	_disco()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _estado_inicial() -> void:
	print("\n-- [21, 31] estado inicial --")
	var p := ProgressaoDoPersonagem.new()
	_ok(p.raca == "humano" and p.nivel == 1 and p.xp == 0 and p.xp_necessario() == 2000 and p.ouro == 0,
		"humano, nível 1, XP 0 / 2.000 (curva do Mine Piece), ouro 0")
	_ok(p.hp_maximo() == 24 and p.energia_maxima() == 600, "vida 24 (20 + Aumento de Vida I do mod), energia 600 (nível 1: 200 × round(3 / 1,1))")
	_ok(p.titulo() == "Civil", "título Civil [28]")
	var c := p.capacidades()
	# Decisão do dono (30/09/2026), divergindo do PDF [22]: já nasce lutando.
	_ok(c.can_attack and p.skills["combate"] == 1, "já nasce com Combate 1 e o clique liberado (decisão de 30/09)")
	_ok(not c.can_dash and not c.can_double_jump and not c.can_use_skills,
		"sem dash, pulo duplo nem técnicas [23–25]")


func _xp_e_niveis() -> void:
	print("\n-- [4, 5, 10] XP e níveis --")
	var p := ProgressaoDoPersonagem.new()
	var niveis := []
	p.subiu_de_nivel.connect(func(de, para): niveis.append([de, para]))
	p.ganhar_xp(1999)
	_ok(p.nivel == 1 and p.xp == 1999 and p.xp_restante() == 1, "1.999 XP: ainda nível 1, falta 1")
	p.ganhar_xp(1)
	_ok(p.nivel == 2 and p.xp == 0 and niveis == [[1, 2]], "2.000 XP: nível 2, XP zera no novo nível (sem pontos: atributos vêm do nível)")
	p.ganhar_xp(2000 + 2000 + 450)
	_ok(p.nivel == 4 and p.xp == 450 and niveis.size() == 3,
		"um ganho grande sobe dois níveis de uma vez e guarda a sobra (nível 4, 450 XP)")
	p.ganhar_xp(1000)
	_ok(p.xp == 1450 and p.xp_necessario() == 2000 and p.xp_restante() == 550, "nível 4, XP 1.450 / 2.000, faltam 550")
	# Curva do Mine Piece (18/10/2026): nível = f(recompensa) — 10 mil no 5, 100 mil no 10, 1 milhão no 20.
	var R := ProgressaoDoPersonagem.RegrasDeRecompensa
	var xp_por_nivel := ProgressaoDoPersonagem.xp_para(1) == 2000 and ProgressaoDoPersonagem.xp_para(4) == 2000 \
		and ProgressaoDoPersonagem.xp_para(5) == 10000 and ProgressaoDoPersonagem.xp_para(6) == 18000 \
		and ProgressaoDoPersonagem.xp_para(10) == 54000 and ProgressaoDoPersonagem.xp_para(11) == 90000 \
		and ProgressaoDoPersonagem.xp_para(20) == 245000 and ProgressaoDoPersonagem.xp_para(21) == 400000
	_ok(xp_por_nivel, "XP por nível = o do Mine Piece com o arredondamento do UpdateBounty (2.000; 10.000 no 5→6; 18.000; 54.000 no 10→11; 90.000; 245.000 no 20→21; 400.000)")
	_ok(R.xp_de_abate(20.0) == 50 and R.xp_de_abate(200.0) == 150 and R.xp_de_abate(80.0, 1.0, 0.0, 4.0) > R.xp_de_abate(80.0),
		"XP por abate = recompensa do mod: fraco 50, 200 de vida 150, força/armadura sobem")
	# Fórmula completa de `WhenEntityDieProcedure` (relida em 28/10/2026): ataque base ×0,33 na força; armadura, tenacidade e haki
	# como multiplicadores. Valores calculados à mão: Arlong (vida 220, Força V, Resistência III, armadura 8, ataque base 10) e uma
	# vítima de 100 de vida com Força III e os dois hakis no nível 4.
	_ok(R.xp_de_abate(220.0, 5.0, 2.0, 8.0, 10.0) == 17823, "Arlong vale 17.823 (%d)" % R.xp_de_abate(220.0, 5.0, 2.0, 8.0, 10.0))
	_ok(R.xp_de_abate(100.0, 2.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0) == 1426, "haki Armamento e Observação nível 4: +10 %% cada (%d)" % R.xp_de_abate(100.0, 2.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0))
	_ok(R.xp_de_abate(50.0, -1.0, -1.0, 20.0) > R.xp_de_abate(50.0) and R.xp_de_abate(50.0, -1.0, -1.0, 99.0) == R.xp_de_abate(50.0, -1.0, -1.0, 20.0),
		"a armadura rende até 20; acima disso não soma")
	_ok(R.xp_de_abate(50.0, -1.0, -1.0, 0.0, 0.0, 8.0) > R.xp_de_abate(50.0) and R.xp_de_abate(50.0, -1.0, -1.0, 0.0, 0.0, 99.0) == R.xp_de_abate(50.0, -1.0, -1.0, 0.0, 0.0, 8.0),
		"a tenacidade rende até 8")
	_ok(p.titulo(5) == "Especialista" and p.titulo(10) == "Ápice", "títulos 5 Especialista e 10 Ápice [29]")


func _barreira() -> void:
	print("\n-- sem barreira de nível: o nível é só a função da recompensa (A3) --")
	var p := ProgressaoDoPersonagem.new()
	var R := ProgressaoDoPersonagem.RegrasDeRecompensa
	p.ganhar_xp(R.recompensa_do_nivel(7) - R.recompensa_do_nivel(1))
	_ok(p.nivel == 7 and p.xp == 0, "36.000 XP levam exatamente ao nível 7")
	p.ganhar_xp(1000000)
	var total := R.recompensa_do_nivel(7) + 1000000
	_ok(p.nivel == R.nivel_da_recompensa(total) and p.nivel > 10 and p.titulo() == "Ápice",
		"nada segura o 8, o 9 e o 10: com 1 milhão a mais o nível é o da recompensa (%d)" % p.nivel)
	_ok(not ProgressaoDoPersonagem.new().has_method("concluir_missao_especial") and not ProgressaoDoPersonagem.new().has_method("teto"),
		"missão especial e teto saíram")
	# A inversa exata do UpdateBounty (Math.round): o nível n começa na menor recompensa que dá n.
	var exato := true
	for n in range(1, 61):
		exato = exato and R.nivel_da_recompensa(R.recompensa_do_nivel(n)) == n
		if n >= 2:
			exato = exato and R.nivel_da_recompensa(R.recompensa_do_nivel(n) - 1) == n - 1
	_ok(exato, "limiares dos níveis 1–60 = a fórmula do UpdateBounty com arredondamento")


func _teto_absoluto() -> void:
	print("\n-- sem teto por ilha (A3) --")
	var p := ProgressaoDoPersonagem.new()
	p.nivel = 10
	p.ganhar_xp(100000)
	_ok(p.nivel > 10, "na Ilha Inicial o nível passa de 10: nenhum teto por ilha (nível %d)" % p.nivel)
	_ok(p.visitar("ilha_dos_macacos") and not p.visitar("ilha_dos_macacos") and not p.visitar("ilha_que_nao_existe"),
		"visitar a Ilha dos Macacos vale uma vez; ilha fora do cadastro é recusada")
	var lido := ProgressaoDoPersonagem.de_dict(p.para_dict())
	_ok(lido.ilhas_visitadas == ["ilha_inicial", "ilha_dos_macacos"] and lido.nivel == p.nivel,
		"o save guarda as ilhas visitadas e o nível volta inteiro")
	var editado := p.para_dict()
	editado["ilhas_visitadas"] = ["ilha_inventada"]
	_ok(ProgressaoDoPersonagem.de_dict(editado).nivel == p.nivel and ProgressaoDoPersonagem.de_dict(editado).ilhas_visitadas == ["ilha_inicial"],
		"ilha fora do cadastro no save é ignorada; o nível não depende dela")


func _pontos() -> void:
	print("\n-- atributos derivados do nível (PlayerPhysicalAbility do Mine Piece, A6) --")
	var A := ProgressaoDoPersonagem.RegrasDosAtributos
	var p := ProgressaoDoPersonagem.new()
	_ok(not p.has_method("distribuir") and not ("pontos" in p), "pontos livres e distribuição saíram")
	# Quem tem estilo usa o nível − 1; Força: round(min(n,34)), abaixo de 3 vale no máximo 1; níveis = amplificador + 1.
	var forca := {1: 1, 2: 2, 3: 2, 4: 4, 10: 10, 35: 35, 60: 35}
	var f_ok := true
	for n in forca:
		f_ok = f_ok and A.niveis_forca(n) == forca[n]
	_ok(f_ok and is_equal_approx(A.bonus_fisico(4), 12.0), "Força por nível: 1→1, 2→2, 3→2, 4→4, 35→35 (teto 34 + 1) e +3 de dano por nível")
	var resist := {1: 1, 3: 1, 4: 2, 9: 3, 13: 4, 60: 4}
	var r_ok := true
	for n in resist:
		r_ok = r_ok and A.niveis_resistencia(n) == resist[n]
	_ok(r_ok, "Resistência por nível: 1–3→I, 4→II, 9→III, 13+→IV (teto 3 + 1)")
	var vida := {1: 24, 2: 24, 3: 28, 5: 32, 23: 60, 60: 60}
	var v_ok := true
	for n in vida:
		p.nivel = n
		v_ok = v_ok and p.hp_maximo() == vida[n]
	_ok(v_ok, "vida = 20 + 4 × (Aumento de Vida + 1): 24, 24, 28, 32 … teto 60 (amplificador 9)")
	var arm := {1: 1, 10: 10, 30: 30, 31: 30, 80: 30}
	var a_ok := true
	for n in arm:
		a_ok = a_ok and A.armadura(n) == arm[n]
	_ok(a_ok and A.tenacidade(1) == 0 and A.tenacidade(11) == 5 and A.tenacidade(80) == 30, "armadura min(1+n,30); tenacidade min(n/2,30), com n = nível − 1")
	_ok(A.dano_recebido(10.0, 1) < 10.0 and A.dano_recebido(10.0, 40) < A.dano_recebido(10.0, 1), "mais nível, menos dano recebido")
	# Energia do mod (WhenRespawn/PlayerTick): máx. min(4000, 200 × round((2+n)/1,1)); regen a cada 0,5 s = 1 + round((2+min(n,19))/1,1 × 0,2).
	var en := {1: 600, 2: 800, 3: 1000, 10: 2200, 20: 4000, 60: 4000}
	var e_ok := true
	for n in en:
		e_ok = e_ok and A.energia_maxima(n) == en[n]
	_ok(e_ok, "energia máxima do mod por nível: 600, 800, 1000, 2200 … teto 4000 no nível 20")
	_ok(is_equal_approx(A.energia_por_segundo(1), 4.0) and is_equal_approx(A.energia_por_segundo(60), 2.0 * (1.0 + roundi(21.0 / 1.1 * 0.2))),
		"regeneração do mod: 4/s no nível 1 (o dobro com a vida cheia) e teto no 19")
	p = ProgressaoDoPersonagem.new()
	p.nivel = 12
	_ok(p.valor_do_atributo("forca") == 12 and p.valor_do_atributo("armadura") == 12 and p.valor_do_atributo("vida") == p.hp_maximo(),
		"a janela lê os valores do nível")
	var q := ProgressaoDoPersonagem.new()
	q.definir_skill("combate", 0)
	_ok(q.capacidades().can_attack and q.skills["combate"] == 1, "Combate não desce de 1: o clique continua liberado [27]")
	q.definir_skill("espada", 0)
	_ok(q.skills["espada"] == 0, "controle: as outras skills descem a 0 normalmente")
	q.definir_skill("fruta", 9)
	_ok(q.skills["fruta"] == 4, "skill é presa em 0–4 [20]")
	q.desbloquear("pulo_duplo")
	_ok(q.capacidades().can_double_jump and not q.capacidades().can_dash, "pulo duplo desbloqueia sozinho, dash continua travado")


func _inimigos() -> void:
	print("\n-- XP de abate: o mod não reduz por diferença de nível --")
	var R := preload("res://src/historia/recompensa_mine_piece.gd")
	_ok(not ProgressaoDoPersonagem.new().has_method("xp_de_inimigo"), "a penalidade por nível do PDF saiu (A2)")
	# UpdateBountyProcedure: recompensa → nível, com Math.round.
	var casos := {0.0: 0, 10000.0: 5, 28000.0: 6, 100000.0: 10, 190000.0: 11, 1000000.0: 20, 1400000.0: 21}
	var confere := true
	for b: float in casos:
		confere = confere and R.nivel_da_recompensa(b) == casos[b]
	_ok(confere, "nível da recompensa = fórmula do UpdateBounty (faixas 10 mil / 100 mil / 1 milhão)")


func _antifarm() -> void:
	print("\n-- anti-farm e teto de recompensa do mod (WhenEntityDie; B2) --")
	var R := ProgressaoDoPersonagem.RegrasDeRecompensa
	_ok(is_equal_approx(R.limite_por_vitima(5000.0), 24000.0) and is_equal_approx(R.limite_por_vitima(20000.0), 150000.0)
		and is_equal_approx(R.limite_por_vitima(200000.0), 1500000.0) and is_equal_approx(R.limite_por_vitima(2000000.0), 6000000.0),
		"limite por vitima: (fama+3 mil)×3 até 15 mil; (fama+30 mil)×3 até 150 mil; (fama+300 mil)×3 até 1 mi; depois fama×3")
	var p := ProgressaoDoPersonagem.new()
	_ok(is_equal_approx(p.limite_de_recompensa, 10000.0), "o limite do jogador começa em 10.000")
	_ok(p.previa_do_abate(5000) == 5000, "uma vítima de 5.000 entra inteira (a recompensa 1.000 → 6.000, abaixo do limite 24.000)")
	# Limite do jogador baixo e vítima fraca: o abate esbarra no teto e o excedente NÃO entra.
	var q := ProgressaoDoPersonagem.new()
	q.limite_de_recompensa = 3000.0
	_ok(q.previa_do_abate(1000) == 1000 and q.recompensa_total() == 1000, "a prévia não altera nada")
	q.ganhar_xp_de_abate(1000)
	_ok(q.limite_de_recompensa >= 6000.0, "matar sobe o limite (vítima de 1.000 → 12.000, o maior vence)")
	# Teto da regra de jogo: 50 × 100.000 = 5 milhões (nível 30).
	var t := ProgressaoDoPersonagem.new()
	t.nivel = 30
	t.limite_de_recompensa = 1.0e9
	_ok(t.recompensa_total() == 4800000 and t.previa_do_abate(1000000) == 200000, "a recompensa para em 5 milhões (nível 30): entram só 200.000 de 1 milhão")
	t.ganhar_xp_de_abate(1000000)
	_ok(t.recompensa_total() == R.RECOMPENSA_MAXIMA and t.previa_do_abate(1000000) == 0, "no teto, nada mais entra")
	# A recompensa nunca diminui: acima do limite do jogador o abate não rende (e não tira).
	var u := ProgressaoDoPersonagem.new()
	u.nivel = 30
	u.limite_de_recompensa = 3000000.0
	_ok(u.previa_do_abate(1000000) == 0, "acima do limite do jogador não ganha, mas também não perde")
	# Salvar e carregar guarda o limite.
	var lido := ProgressaoDoPersonagem.de_dict(q.para_dict())
	_ok(is_equal_approx(lido.limite_de_recompensa, q.limite_de_recompensa), "o save guarda o limite de recompensa")


func _disco() -> void:
	print("\n-- salvar e carregar --")
	var p := ProgressaoDoPersonagem.new()
	p.ganhar_xp(2000 + 2000 + 200)
	p.ganhar_ouro(1275)
	p.definir_skill("combate", 1)
	p.desbloquear("dash")
	_ok(p.salvar(ARQUIVO) == OK and not FileAccess.file_exists(ARQUIVO + ".tmp"), "grava sem deixar temporário")
	var q := ProgressaoDoPersonagem.carregar(ARQUIVO)
	_ok(q.para_dict() == p.para_dict(), "carregar devolve exatamente o mesmo status")
	_ok(ProgressaoDoPersonagem.carregar("user://test_progressao/nao_existe.json").nivel == 1, "sem arquivo, começa do nível 1")

	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	f.store_string("{ quebrado")
	f.close()
	_ok(ProgressaoDoPersonagem.carregar(ARQUIVO).nivel == 1, "arquivo corrompido não derruba: nível 1")

	var editado := p.para_dict()
	editado["nivel"] = 10
	editado["xp"] = null
	editado["ouro"] = -50
	editado["atributos"] = {"forca": 500, "vida": "muito"}      # campo antigo: ignorado
	editado["pontos"] = 999
	editado["skills"] = {"combate": 12}
	editado["missoes_especiais"] = [3, 8, 8, "x"]
	var r := ProgressaoDoPersonagem.de_dict(editado)
	_ok(r.nivel == 10 and r.xp == 0 and r.ouro == 0 and r.skills["combate"] == 4,
		"arquivo editado à mão: nada negativo, null vira 0, campo antigo de missões especiais ignorado")
	editado["nivel"] = -5
	_ok(ProgressaoDoPersonagem.de_dict(editado).nivel == 1, "nível negativo vira 1")
	_ok(r.hp_maximo() == ProgressaoDoPersonagem.new().RegrasDosAtributos.hp_maximo(10), "atributos e pontos do arquivo são ignorados: a vida vem do nível")
	# Save de antes de 30/09/2026: Combate 0 (o Civil não lutava). Sobe para 1 ao carregar.
	var antigo := p.para_dict()
	antigo["skills"] = {"combate": 0, "espada": 2, "fruta": 1}
	var migrado := ProgressaoDoPersonagem.de_dict(antigo)
	_ok(migrado.skills["combate"] == 1 and migrado.skills["espada"] == 2 and migrado.capacidades().can_attack,
		"save antigo com Combate 0 sobe para 1 (e o resto fica como estava)")
	var sem_skills := p.para_dict()
	sem_skills.erase("skills")
	_ok(ProgressaoDoPersonagem.de_dict(sem_skills).skills["combate"] == 1, "save sem o campo de skills também começa em Combate 1")
