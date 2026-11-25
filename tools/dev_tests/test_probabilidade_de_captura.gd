extends SceneTree
## Pokébola (08/11/2026): a conta de captura dos jogos Pokémon (Ger. III/IV) e o estoque (3 a cada 5 min).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_probabilidade_de_captura.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func rodar() -> void:
	await process_frame
	var P := ProbabilidadeDeCaptura
	print("-- fórmula: a = (3·HPmax − 2·HP)·taxa·bola / (3·HPmax) --")
	ok(P.valor_a(1.0, 45.0) == 15.0, "vida cheia, taxa 45: a = 15")
	ok(P.valor_a(0.5, 45.0) == 30.0, "metade da vida, taxa 45: a = 30")
	ok(P.valor_a(0.5, 45.0, 2.0) == 60.0, "Ultra Ball (2×) dobra: a = 60 (o exemplo da calculadora do Dragonfly Cave)")
	ok(P.valor_a(0.0, 45.0) == 45.0, "vida em 1 ponto ≈ 0: a = taxa")
	ok(P.valor_a(1.0, 3.0) == 1.0, "nunca cai de 1")
	ok(P.valor_a(0.0, 255.0) == 255.0, "taxa 255 com vida mínima: 255 (garantida)")
	print("\n-- chance por bola (4 chacoalhadas) --")
	ok(is_equal_approx(P.chance(255.0), 1.0), "a = 255: captura garantida")
	ok(absf(P.chance(127.5) - 0.5) < 0.001, "a = 127,5: 50 %")
	ok(P.chance(15.0) < P.chance(30.0) and P.chance(30.0) < P.chance(60.0), "mais a, mais chance")
	var n := 20000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var acertos := 0
	for i in n:
		if P.sortear(60.0, rng)["capturou"]:
			acertos += 1
	ok(absf(float(acertos) / n - P.chance(60.0)) < 0.015, "o sorteio converge para a chance (%.3f contra %.3f)" % [float(acertos) / n, P.chance(60.0)])
	var s: Dictionary = P.sortear(1.0, rng)
	ok(int(s["chacoalhadas"]) >= 0 and int(s["chacoalhadas"]) <= 4, "chacoalhadas entre 0 e 4")
	print("\n-- raridade pela dificuldade --")
	ok(P.faixa_do_xp(1.0)["nome"] == "comum" and P.faixa_do_xp(1.0)["taxa"] == 255, "coelho (XP 1): comum, 255")
	ok(P.faixa_do_xp(12.0)["nome"] == "incomum", "vaca (12): incomum")
	ok(P.faixa_do_xp(60.0)["nome"] == "raro" and P.faixa_do_xp(60.0)["taxa"] == 45, "búfalo (60): raro, 45")
	ok(P.faixa_do_xp(100.0)["nome"] == "muito raro", "100: muito raro")
	ok(P.faixa_do_xp(405.0)["nome"] == "lendário" and P.faixa_do_xp(405.0)["taxa"] == 3, "gorila (405): lendário, 3")
	var chance_comum := P.chance(P.valor_a(0.5, 255.0))
	var chance_lendario := P.chance(P.valor_a(0.5, 3.0))
	ok(absf(chance_comum - 2.0 / 3.0) < 0.01 and chance_lendario < 0.02, "raridade pesa: comum a meia vida = %d %%, lendário = %.1f %%" % [roundi(chance_comum * 100.0), chance_lendario * 100.0])
	print("\n-- estoque: 3 de início e +3 a cada 5 min --")
	var prog := ProgressaoDoPersonagem.new()
	var c: Node = load("res://src/historia/captura/captura_de_inimigos.gd").new()
	c.progressao = prog
	root.add_child(c)
	c._recarregar(0.1)
	ok(c.quantidade() == 3, "começa com 3 pokébolas (%d)" % c.quantidade())
	ok(c.gastar() and c.quantidade() == 2, "gastar tira 1")
	c._recarregar(299.0)
	ok(c.quantidade() == 2, "aos 299 s ainda não recarregou")
	c._recarregar(2.0)
	ok(c.quantidade() == 5, "aos 300 s: +3 (%d)" % c.quantidade())
	for i in 5:
		c.gastar()
	ok(c.quantidade() == 0 and not c.gastar(), "zerou: não dá para atirar")
	c.dar(500)
	ok(c.quantidade() == CapturaDeInimigos.MAXIMO_DE_BOLAS, "teto de %d" % CapturaDeInimigos.MAXIMO_DE_BOLAS)
	var salvo := prog.para_dict()
	ok(int((salvo["sistemas"]["pokebolas"] as Dictionary)["n"]) == CapturaDeInimigos.MAXIMO_DE_BOLAS, "o estoque vai no save")
	print("\nPROBABILIDADE_DE_CAPTURA %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
