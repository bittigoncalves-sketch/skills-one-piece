extends SceneTree
# Regras da 5ª missão (22/11/2026): duelo pedra-papel-tesoura, condições do vendedor, prêmio idempotente e penalidade da derrota. Sem mapa nem tela. Rodar:
#   godot --headless --path . --script tools/dev_tests/test_duelo_alvida.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _prog_com_bau_entregue(copos_certo: bool) -> ProgressaoDoPersonagem:
	var p := ProgressaoDoPersonagem.new()
	p.missoes["treino"] = {"estado": "entregue", "abates": 1}
	p.missoes["desafio_dos_copos"] = {"estado": "entregue", "abates": 1 if copos_certo else 0}
	p.missoes["resgate_do_bau"] = {"estado": "entregue", "abates": 1}
	if copos_certo:
		p.sistemas["desafio_buggy"] = {"fase": "copos_certo"}
	else:
		p.sistemas["desafio_buggy"] = {"fase": "copos_errado"}
	return p

func _init() -> void:
	print("\n===== DUELO + REGRAS DA ALVIDA =====")
	print("-- tabela pedra/papel/tesoura (as 9 combinações) --")
	var esperado := {[0, 0]: 0, [0, 1]: -1, [0, 2]: 1, [1, 0]: 1, [1, 1]: 0, [1, 2]: -1, [2, 0]: -1, [2, 1]: 1, [2, 2]: 0}
	for k in esperado:
		ok("%s × %s = %d" % [DueloPpt.NOMES[k[0]], DueloPpt.NOMES[k[1]], esperado[k]], DueloPpt.comparar(k[0], k[1]) == esperado[k])

	print("-- 7 vidas, empate = desvio, 7 acertos vencem --")
	var d := DueloPpt.new()
	d.sorteio = func() -> int: return DueloPpt.TESOURA
	ok("começa 7×7", d.vidas_do_jogador == 7 and d.vidas_da_alvida == 7 and not d.terminou() and d.vencedor() == "")
	var r := d.jogar(DueloPpt.TESOURA)
	ok("empate: desvio, ninguém perde vida", r["evento"] == DueloPpt.EMPATE and d.vidas_do_jogador == 7 and d.vidas_da_alvida == 7)
	r = d.jogar(DueloPpt.PEDRA)
	ok("jogador vence a rodada: Alvida 6, jogador 7", r["evento"] == DueloPpt.ACERTO_DO_JOGADOR and d.vidas_da_alvida == 6 and d.vidas_do_jogador == 7)
	r = d.jogar(DueloPpt.PAPEL)
	ok("Alvida vence a rodada: jogador 6", r["evento"] == DueloPpt.ACERTO_DA_ALVIDA and d.vidas_do_jogador == 6)
	for i in 6:
		r = d.jogar(DueloPpt.PEDRA)
	ok("7º acerto do jogador acaba o duelo: vencedor = jogador, Alvida 0", d.terminou() and d.vencedor() == "jogador" and d.vidas_da_alvida == 0 and bool(r["terminou"]))
	ok("depois do fim nada anda (idempotente)", d.jogar(DueloPpt.PEDRA).is_empty() and d.vidas_da_alvida == 0 and d.vidas_do_jogador == 6)
	var d2 := DueloPpt.new()
	d2.sorteio = func() -> int: return DueloPpt.PAPEL
	for i in 7:
		d2.jogar(DueloPpt.PEDRA)
	ok("7 acertos da Alvida: vencedor = alvida, jogador 0", d2.vencedor() == "alvida" and d2.vidas_do_jogador == 0 and d2.vidas_da_alvida == 7)
	ok("jogada inválida é ignorada", DueloPpt.new().jogar(7).is_empty() and DueloPpt.new().jogar(-1).is_empty())
	var d3 := DueloPpt.new()
	var n := [0]
	d3.sorteio = func() -> int:
		n[0] += 1
		return DueloPpt.PEDRA
	var escolha := d3.sortear()
	d3.sortear()
	ok("a Alvida escolhe ANTES e a escolha não muda se pedirem de novo", escolha == DueloPpt.PEDRA and n[0] == 1)
	d3.jogar(DueloPpt.PAPEL)
	d3.sortear()
	ok("a rodada seguinte sorteia de novo", n[0] == 2)
	# aleatório real: as 3 jogadas da Alvida aparecem
	var d4 := DueloPpt.new()
	var vistas := {}
	for i in 60:
		d4.vidas_do_jogador = 99; d4.vidas_da_alvida = 99
		vistas[int(d4.jogar(DueloPpt.PEDRA)["alvida"])] = true
	ok("sorteio real usa as 3 jogadas", vistas.size() == 3)

	print("-- condições da missão --")
	var Missoes = load("res://src/historia/missoes/missoes.gd")
	ok("missão na tabela: 8000 XP + 1000 moedas, depois do baú", Missoes.existe("alvida_no_navio") and int(Missoes.dados("alvida_no_navio").xp) == 8000
		and int(Missoes.dados("alvida_no_navio").ouro) == 1000 and Missoes.dados("alvida_no_navio").depois_de == "resgate_do_bau")
	var p0 := ProgressaoDoPersonagem.new()
	ok("sem o baú: não libera", not RegrasDaAlvida.liberar(p0) and RegrasDaAlvida.situacao(p0) == RegrasDaAlvida.SEM_MISSAO)
	var pe := _prog_com_bau_entregue(false)
	ok("baú entregue mas Buggy NÃO vencido (errou os copos): o barril NÃO fica disponível (22/11)", not RegrasDaAlvida.liberar(pe) and pe.estado_da_missao("alvida_no_navio") == "disponivel" and not RegrasDaAlvida.pode_comecar(pe))
	ok("ERROU os copos: a situação segue sem missão, sem barril", RegrasDaAlvida.situacao(pe) == RegrasDaAlvida.SEM_MISSAO and not RegrasDaAlvida.pode_comecar(pe))
	pe.nivel = 3
	RegrasDoDesafioBuggy._gravar(pe, RegrasDoDesafioBuggy.ACEITOU)
	pe.aceitar_missao(RegrasDoDesafioBuggy.MISSAO_LUTA)
	ok("revanche aceita mas ainda sem vencer: nada de barril", not RegrasDaAlvida.liberar(pe))
	RegrasDaLutaDoBuggy.concluir(pe, true)
	ok("vencer o Buggy no boxe libera o barril (uma vez só)", RegrasDaAlvida.liberar(pe) and not RegrasDaAlvida.liberar(pe) and pe.estado_da_missao("alvida_no_navio") == "aceita")
	var pv0 := _prog_com_bau_entregue(true)
	ok("vencer o Buggy nos copos também libera o barril logo depois do baú", RegrasDaAlvida.liberar(pv0) and pv0.estado_da_missao("alvida_no_navio") == "aceita")
	var pantigo := _prog_com_bau_entregue(false)
	pantigo.missoes["alvida_no_navio"] = {"estado": "aceita", "abates": 0}
	RegrasDaAlvida.liberar(pantigo)
	ok("quem recebeu o barril antes da regra (sem vitória nem duelo) o perde até vencer", pantigo.estado_da_missao("alvida_no_navio") == "disponivel")
	pe = _prog_com_bau_entregue(false)
	RegrasDaAlvida.liberar(pe)
	ok("errou os copos: vitória/derrota não pagam nada", not RegrasDaAlvida.registrar_vitoria(pe)["ok"] and not RegrasDaAlvida.registrar_derrota(pe)["ok"] and pe.ouro == 0 and pe.xp == 0)
	var pl := _prog_com_bau_entregue(false)
	pl.sistemas.erase("desafio_buggy")
	RegrasDaAlvida.liberar(pl)
	ok("save legado (sem a fase dos copos): NÃO conta como vitória nem libera o barril", not RegrasDaAlvida.venceu_o_buggy(pl) and RegrasDaAlvida.situacao(pl) == RegrasDaAlvida.SEM_MISSAO)
	var pv := _prog_com_bau_entregue(true)
	RegrasDaAlvida.liberar(pv)
	ok("ACERTOU os copos: barril liberado", RegrasDaAlvida.situacao(pv) == RegrasDaAlvida.LIBERADO and RegrasDaAlvida.pode_comecar(pv))

	print("-- vitória: +1000 moedas +8000 XP, uma vez --")
	var ouro0 := pv.ouro
	var xp0 := pv.xp; var nivel0 := pv.nivel
	var v1 := RegrasDaAlvida.registrar_vitoria(pv)
	ok("pagou 1000 moedas", v1["ok"] and pv.ouro == ouro0 + 1000 and int(v1["ouro"]) == 1000)
	ok("pagou 8000 XP (soma no XP/nível)", int(v1["xp"]) == 8000 and (pv.xp > xp0 or pv.nivel > nivel0))
	var ouro1 := pv.ouro; var xp1 := pv.xp; var niv1 := pv.nivel
	var v2 := RegrasDaAlvida.registrar_vitoria(pv)
	ok("repetir NÃO paga de novo (idempotente)", not v2["ok"] and pv.ouro == ouro1 and pv.xp == xp1 and pv.nivel == niv1)
	ok("derrota depois da vitória não faz nada", not RegrasDaAlvida.registrar_derrota(pv)["ok"])
	ok("missão entregue + situação JA_VENCEU + persiste", pv.estado_da_missao("alvida_no_navio") == "entregue" and RegrasDaAlvida.situacao(pv) == RegrasDaAlvida.JA_VENCEU
		and RegrasDaAlvida.vitorias(pv) == 1)

	print("-- derrota: perde itens, mantém permanentes, pode tentar de novo --")
	var pd := _prog_com_bau_entregue(true)
	RegrasDaAlvida.liberar(pd)
	pd.ganhar_ouro(500)
	pd.nivel = 12
	pd.fruta = "gomu_gomu"
	pd.guardar_akuma("mera_mera", 1)
	pd.skills["espada"] = 3
	pd.desbloqueios["pulo_duplo"] = true
	pd.barcos = {"mpe_ship_mihawk": true}
	pd.pets = {"p1": {"nome": "Rex"}}
	pd.inventario.inserir(InventarioMinecraft.nova("minecraft:cobblestone", 20))
	pd.inventario.inserir(InventarioMinecraft.nova("minecraft:iron_sword", 1))
	pd.pesca = {"sardinha": 3}
	pd.madeira = 5
	pd.equipamentos = {"vara_de_pesca": true}
	pd.vara_equipada = true
	pd.item_ativo = "vara"
	var inv_ref := pd.inventario
	var derr := RegrasDaAlvida.registrar_derrota(pd)
	ok("derrota registrada e contou itens perdidos", derr["ok"] and int(derr["itens"]) >= 4)
	ok("inventário esvaziado NO MESMO OBJETO (a janela guarda a referência)", pd.inventario == inv_ref and pd.inventario.contar("minecraft:cobblestone") == 0 and pd.inventario.contar("minecraft:iron_sword") == 0)
	ok("peixes, madeira e equipamentos perdidos; mão volta ao estilo de luta", pd.pesca.is_empty() and pd.madeira == 0 and pd.equipamentos.is_empty() and not pd.vara_equipada and pd.item_ativo == "luta")
	ok("PERMANENTES intactos: moedas, nível, fruta, frutas guardadas, skills, habilidades, barcos, pets",
		pd.ouro == 500 and pd.nivel == 12 and pd.fruta == "gomu_gomu" and pd.quantas_akuma("mera_mera") > 0 and int(pd.skills["espada"]) == 3
		and pd.desbloqueios["pulo_duplo"] and pd.barcos.has("mpe_ship_mihawk") and pd.pets.has("p1"))
	ok("sem prêmio na derrota; a missão FALHOU para sempre (não repete); derrotas = 1", pd.estado_da_missao("alvida_no_navio") == "falhou" and RegrasDaAlvida.derrotas(pd) == 1 and not RegrasDaAlvida.pode_comecar(pd) and RegrasDaAlvida.situacao(pd) == RegrasDaAlvida.PERDEU)
	pd.inventario.inserir(InventarioMinecraft.nova("minecraft:cobblestone", 2))
	RegrasDaAlvida.registrar_derrota(pd)
	ok("depois de falhar, outra derrota NÃO conta nem apaga", RegrasDaAlvida.derrotas(pd) == 1 and pd.inventario.contar("minecraft:cobblestone") == 2)
	ok("a missão falhada não volta a ser aceita nem oferecida", not RegrasDaAlvida.liberar(pd) and not pd.aceitar_missao("alvida_no_navio") and not ProgressaoDoPersonagem.Missoes.proximas(pd).has("alvida_no_navio"))
	print("-- derrota idempotente POR TENTATIVA + provisões --")
	var pt := _prog_com_bau_entregue(true)
	RegrasDaAlvida.liberar(pt)
	pt.sistemas["sobrevivencia"] = {"estoque": {"pao": 3, "agua_potavel": 2}}
	pt.inventario.inserir(InventarioMinecraft.nova("minecraft:cobblestone", 5))
	var t1 := RegrasDaAlvida.registrar_derrota(pt, "duelo_A")
	ok("1ª derrota do duelo A: apaga mochila e provisões", t1["ok"] and pt.inventario.contar("minecraft:cobblestone") == 0 and (pt.sistemas["sobrevivencia"]["estoque"] as Dictionary).is_empty())
	pt.inventario.inserir(InventarioMinecraft.nova("minecraft:cobblestone", 7))      # item novo, ganho depois
	var t2 := RegrasDaAlvida.registrar_derrota(pt, "duelo_A")
	ok("sinal REPETIDO do mesmo duelo: nada apaga, nada conta", not t2["ok"] and pt.inventario.contar("minecraft:cobblestone") == 7 and RegrasDaAlvida.derrotas(pt) == 1)
	var t3 := RegrasDaAlvida.registrar_derrota(pt, "duelo_B")
	ok("duelo B depois da missão falhar: não há 2ª chance (nada apaga, derrotas segue 1)", not t3["ok"] and pt.inventario.contar("minecraft:cobblestone") == 7 and RegrasDaAlvida.derrotas(pt) == 1)
	var pu := _prog_com_bau_entregue(true)
	RegrasDaAlvida.liberar(pu)
	pu.madeira = 3
	var em := []
	pu.mudou.connect(func() -> void: em.append([pu.madeira, RegrasDaAlvida.derrotas(pu)]))
	RegrasDaAlvida.registrar_derrota(pu, "duelo_Z")
	ok("a derrota emite UMA vez e já com penalidade + contador + id juntos", em.size() == 1 and em[0][0] == 0 and em[0][1] == 1)
	print("-- vitória numa transação + recuperação de save preso --")
	var pa := _prog_com_bau_entregue(true)
	RegrasDaAlvida.liberar(pa)
	var emissoes := [0]
	pa.mudou.connect(func() -> void: emissoes[0] += 1)
	var va := RegrasDaAlvida.registrar_vitoria(pa)
	ok("vitória paga e NUNCA deixa estado 'pronta' salvo sem prêmio (a 1ª emissão já traz a entrega)", va["ok"] and pa.estado_da_missao("alvida_no_navio") == "entregue" and pa.ouro == 1000)
	var pp := _prog_com_bau_entregue(true)
	RegrasDaAlvida.liberar(pp)
	pp.missoes["alvida_no_navio"] = {"estado": "aceita", "abates": 1}                # snapshot intermediário (pronta, sem prêmio)
	ok("save preso: estado 'pronta' sem prêmio", pp.estado_da_missao("alvida_no_navio") == "pronta" and pp.ouro == 0)
	ok("recuperar entrega UMA vez (1000 moedas) e marca vitória", RegrasDaAlvida.recuperar(pp) and pp.ouro == 1000 and RegrasDaAlvida.vitorias(pp) == 1 and not RegrasDaAlvida.recuperar(pp) and pp.ouro == 1000)
	# save/load
	var salvo := pd.para_dict() if pd.has_method("para_dict") else {}
	print("     (para_dict disponível: %s)" % str(not salvo.is_empty()))
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
