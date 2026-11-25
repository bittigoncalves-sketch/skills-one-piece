extends SceneTree
# Fuzz do duelo (3000 partidas) + save/load da vitória e da derrota (22/11/2026). Rodar: godot --headless --path . --script tools/dev_tests/test_alvida_fuzz_e_save.gd
var f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: f += 1
func _init() -> void:
	await process_frame
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var bad := 0; var maxr := 0; var win := 0
	for g in 3000:
		var d := DueloPpt.new(); d.sorteio = func() -> int: return rng.randi_range(0, 2)
		var n := 0
		while not d.terminou() and n < 500:
			var r := d.jogar(rng.randi_range(0, 2)); n += 1
			if r.is_empty() or d.vidas_do_jogador < 0 or d.vidas_da_alvida < 0 or d.vidas_do_jogador > 7 or d.vidas_da_alvida > 7: bad += 1
			if r["evento"] == DueloPpt.EMPATE and (r["vidas_do_jogador"] != d.vidas_do_jogador): bad += 1
		if not d.terminou() or (d.vidas_do_jogador > 0 and d.vidas_da_alvida > 0) or (d.vidas_do_jogador == 0 and d.vidas_da_alvida == 0): bad += 1
		if d.vencedor() == "jogador": win += 1
		maxr = maxi(maxr, n)
		if not d.jogar(0).is_empty(): bad += 1
	ok("3000 duelos aleatórios: invariantes (vidas 0..7, um vencedor, nada depois do fim) — %d violações; máx %d rodadas; vitórias do jogador %d/3000 (~50%%)" % [bad, maxr, win], bad == 0 and win > 1300 and win < 1700)
	# save/load
	var p := ProgressaoDoPersonagem.new()
	p.missoes["treino"] = {"estado": "entregue", "abates": 1}
	p.missoes["desafio_dos_copos"] = {"estado": "entregue", "abates": 1}
	p.sistemas["desafio_buggy"] = {"fase": "copos_certo"}
	p.missoes["resgate_do_bau"] = {"estado": "entregue", "abates": 1}
	RegrasDaAlvida.liberar(p)
	RegrasDaAlvida.registrar_vitoria(p)
	var cam := "user://fuzz_alvida.json"
	p.salvar(cam)
	var q = ProgressaoDoPersonagem.carregar(cam)
	ok("save/load: missão entregue, vitória e prêmio persistem", q != null and q.estado_da_missao("alvida_no_navio") == "entregue" and RegrasDaAlvida.vitorias(q) == 1 and q.ouro == 1000 and RegrasDaAlvida.situacao(q) == RegrasDaAlvida.JA_VENCEU)
	var p2 := ProgressaoDoPersonagem.new()
	p2.missoes["treino"] = {"estado": "entregue", "abates": 1}
	p2.missoes["desafio_dos_copos"] = {"estado": "entregue", "abates": 1}
	p2.sistemas["desafio_buggy"] = {"fase": "copos_certo"}
	p2.missoes["resgate_do_bau"] = {"estado": "entregue", "abates": 1}
	RegrasDaAlvida.liberar(p2)
	p2.inventario.inserir(InventarioMinecraft.nova("minecraft:cobblestone", 9))
	RegrasDaAlvida.registrar_derrota(p2, "t1")
	p2.salvar(cam)
	var q2 = ProgressaoDoPersonagem.carregar(cam)
	ok("save/load da derrota: itens continuam perdidos, 1 derrota, id da tentativa guardado, repetir não apaga", q2 != null and q2.inventario.contar("minecraft:cobblestone") == 0 and RegrasDaAlvida.derrotas(q2) == 1 and not RegrasDaAlvida.registrar_derrota(q2, "t1")["ok"])
	print("\n" + ("TUDO OK" if f == 0 else "%d FALHA(S)" % f))
	quit(1 if f > 0 else 0)
