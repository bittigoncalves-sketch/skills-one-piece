extends SceneTree
## Regras da luta do Buggy no ringue (22/11/2026): 11 vidas, 0,6 s, Z/X/C ataca, F defende, recompensa 350 + 6500 e o barril liberado.
var total := 0
var falhas := 0
func ok(m: String, c: bool) -> void:
	total += 1
	if not c: falhas += 1
	print(("PASS " if c else "FALHA ") + m)

func _init() -> void:
	var R := preload("res://src/historia/buggy_cais/regras_da_luta_do_buggy.gd")
	var D := preload("res://src/historia/buggy_cais/regras_do_desafio_buggy.gd")
	var A := preload("res://src/historia/alvida/regras_da_alvida.gd")
	ok("11 vidas e o MESMO tempo do treino (1,2 s; decisão do dono em 22/11)", R.VIDA == 11 and absf(R.TEMPO_DO_PROMPT - RegrasDoTreino.TEMPO_DO_PROMPT) < 0.0001)
	ok("Z rápido (1 golpe), X carregado (pausa e forte), C múltiplo (3 golpes)", R.GOLPES["Z"].golpes == 1 and R.GOLPES["Z"].carga == 0.0 and R.GOLPES["X"].carga > 0.0 and R.GOLPES["X"].forca > R.GOLPES["Z"].forca and R.GOLPES["C"].golpes == 3)
	ok("os três golpes duram mais que o contato (o último soco do C cabe na duração)", R.GOLPES.values().all(func(g): return float(g.duracao) > float(g.carga) + R.INSTANTE_DO_CONTATO + R.INTERVALO_ENTRE_GOLPES * (int(g.golpes) - 1)))
	ok("recompensa: 350 moedas e 6500 XP", R.OURO == 350 and R.XP == 6500)
	var r := R.new()
	ok("começa 11 x 11", r.vida_jogador == 11 and r.vida_buggy == 11 and not r.terminou())
	var p := r.proxima(0.9, 0.0)
	ok("sorteio alto = ataque do jogador com Z/X/C", p["tipo"] == R.Tipo.ATAQUE and p["tecla"] in R.TECLAS_DE_ATAQUE)
	p = r.proxima(0.1, 0.5)
	ok("sorteio baixo = o Buggy ataca e a tecla é F", p["tipo"] == R.Tipo.DEFESA and p["tecla"] == "F")
	var e := r.resolver(R.Tipo.ATAQUE, true)
	ok("ataque certo tira 1 do Buggy", e["dano_buggy"] == 1 and r.vida_buggy == 10 and r.acertos == 1)
	e = r.resolver(R.Tipo.ATAQUE, false)
	ok("ataque errado não tira vida de ninguém", e["dano_buggy"] == 0 and e["dano_jogador"] == 0 and r.vida_buggy == 10 and r.vida_jogador == 11 and r.erros == 1)
	e = r.resolver(R.Tipo.DEFESA, true)
	ok("defesa certa bloqueia: ninguém perde vida", e["bloqueou"] and r.vida_jogador == 11 and r.defesas == 1)
	e = r.resolver(R.Tipo.DEFESA, false)
	ok("defesa errada (ou tempo) tira 1 do jogador", e["dano_jogador"] == 1 and r.vida_jogador == 10)
	# 11 acertos = vitória
	var v := R.new()
	for i in 11:
		v.resolver(R.Tipo.ATAQUE, true)
	ok("11 ataques certos zeram o Buggy: o jogador vence", v.terminou() and v.jogador_venceu() and v.vida_buggy == 0)
	ok("depois do fim nada mais muda", v.resolver(R.Tipo.DEFESA, false)["dano_jogador"] == 0 and v.vida_jogador == 11)
	# 11 defesas falhas = derrota
	var d := R.new()
	for i in 11:
		d.resolver(R.Tipo.DEFESA, false)
	ok("11 defesas falhas: o Buggy vence", d.terminou() and not d.jogador_venceu() and d.vida_jogador == 0)
	# sem 4 do mesmo tipo seguidos
	var s := R.new()
	var maior := 0
	var seguidas := 0
	var ultimo := -1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		var q := s.proxima(rng.randf(), rng.randf())
		seguidas = seguidas + 1 if q["tipo"] == ultimo else 1
		ultimo = q["tipo"]
		maior = maxi(maior, seguidas)
	ok("nunca mais que %d rodadas do mesmo tipo em fila (maior: %d)" % [R.MAX_SEGUIDAS, maior], maior <= R.MAX_SEGUIDAS)
	# recompensa e barril
	var prog := ProgressaoDoPersonagem.new()
	prog.nivel = 7
	D._gravar(prog, D.ACEITOU)
	ok("sem a missão da luta aceita a luta não está disponível", not D.luta_disponivel(prog))
	ok("não venceu o Buggy ainda: barril trancado", not A.venceu_o_buggy(prog))
	prog.aceitar_missao(D.MISSAO_LUTA)
	ok("aceitou e nível 7: a luta está disponível", D.luta_disponivel(prog))
	ok("derrota não paga nada", R.concluir(prog, false).is_empty() and D.fase(prog) == D.ACEITOU)
	var xp0 := prog.xp
	var ouro0 := prog.ouro
	var nivel0 := prog.nivel
	var res := R.concluir(prog, true)
	ok("vitória paga 350 moedas", int(res.get("ouro", 0)) == 350 and prog.ouro == ouro0 + 350)
	ok("a tabela da missão paga 6500 de XP e o jogador ganhou XP (nível %d → %d)" % [nivel0, prog.nivel], int(preload("res://src/historia/missoes/missoes.gd").dados(D.MISSAO_LUTA).get("xp", 0)) == 6500 and (prog.nivel > nivel0 or prog.xp > xp0))
	ok("a missão foi entregue", prog.estado_da_missao(D.MISSAO_LUTA) == "entregue" and bool(res.get("missao_entregue", false)))
	ok("fase = luta_vencida", D.fase(prog) == D.LUTA_VENCIDA)
	ok("vencer o Buggy na luta libera o barril da Alvida", A.venceu_o_buggy(prog))
	var ouro1 := prog.ouro
	ok("pagar de novo não acontece (idempotente)", R.concluir(prog, true).is_empty() and prog.ouro == ouro1)
	ok("save novo (sem fase) não conta como vitória", not D.venceu_o_buggy(ProgressaoDoPersonagem.new()))
	var q2 := ProgressaoDoPersonagem.new()
	D._gravar(q2, D.COPOS_CERTO)
	ok("copos certos também valem como vencer o Buggy", A.venceu_o_buggy(q2))
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
