extends SceneTree
## Dados do Epic Fight no jogo (itens 1–8 do backlog, 10/11/2026) + estamina. Os JSON são LOCAIS (fora do git):
## sem eles as checagens de dados são puladas e só a estamina (padrões embutidos) é testada.
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func _init() -> void:
	# ---- estamina (sempre, com ou sem dados)
	var e := Estamina.new()
	ok(e.atual == 15.0 and e.maximo == 15.0, "começa cheia (15)")
	ok(is_equal_approx(e.custo("roll"), 4.0) and is_equal_approx(e.custo("step"), 3.0), "rolar 4, passo 3")
	ok(e.gastar_habilidade("roll") and is_equal_approx(e.atual, 11.0), "rolar gasta 4")
	ok(e.gastar_habilidade("roll") and e.gastar_habilidade("roll") and is_equal_approx(e.atual, 3.0), "três rolagens seguidas")
	ok(not e.gastar_habilidade("roll") and is_equal_approx(e.atual, 3.0), "sem estamina não gasta nem rola")
	e.passar_tempo(1.4)
	ok(is_equal_approx(e.atual, 3.0), "nada regenera na espera de 1,5 s")
	e.passar_tempo(0.2)
	e.passar_tempo(1.0)
	ok(e.atual > 3.0, "depois da espera regenera")
	for i in 200: e.passar_tempo(0.05)
	ok(is_equal_approx(e.atual, 15.0), "enche de novo e para no máximo")
	var pesada := Estamina.new()
	pesada.peso = 80.0
	ok(pesada.custo("roll") > 4.0, "armadura pesada encarece a esquiva")
	var leve := Estamina.new()
	leve.peso = 0.0
	ok(leve.custo("roll") < 4.0, "sem armadura a esquiva sai mais barata")
	var corpo := Node.new()
	ok(Estamina.de(corpo) == Estamina.de(corpo), "uma estamina por corpo")
	# ---- dados (só se extraídos)
	if not EpicFightDados.disponivel():
		print("  (sem assets/epic_fight/: rode tools/epic_fight/extrair_fases.py e extrair_dados.py)")
	else:
		var f := EpicFightDados.fase("combat/fist_auto1")
		ok(is_equal_approx(float(f.get("pre_atraso", -1)), 0.05) and is_equal_approx(float(f.get("contato", -1)), 0.15), "item 1: soco 0,05–0,15 s")
		ok(EpicFightDados.ataques().size() > 100, "item 1: >100 ataques com fases (%d)" % EpicFightDados.ataques().size())
		ok(is_equal_approx(EpicFightDados.velocidade_do_clipe("combat/fist_auto1"), 4.0 / 3.2), "item 1: velocidade = ataque/basis")
		ok(EpicFightDados.categoria("spear").get("combo", []).has("spear_twohand_auto1"), "item 2: lança tem combo")
		ok(EpicFightDados.categoria("tachi").get("materiais", {}).has("netherite"), "item 2: tachi vai a netherite")
		ok(EpicFightDados.atordoamento("KNOCKDOWN").derruba > 0.0, "item 3: knockdown derruba")
		ok(EpicFightDados.stun_do_ataque("combat/fist_auto1") == "SHORT", "item 3: padrão do mod = SHORT")
		ok(EpicFightDados.max_alvos("greatsword", "iron", "combat/greatsword_auto1") >= 4, "item 3: montante atravessa >=4")
		ok(EpicFightDados.max_alvos("fist", "glove") == 1, "item 3: punho acerta 1")
		ok(EpicFightDados.reacao("combat/knockdown").get("duracao", 0.0) > 0.5, "item 4: knockdown tem duração")
		ok(EpicFightDados.custo_de("roll") == 4.0 and EpicFightDados.estamina().get("maximo") == 15.0, "item 5: estamina do mod")
		ok(not EpicFightDados.ataque("combat/fist_dash").is_empty() and not EpicFightDados.ataque("combat/longsword_airslash").is_empty(), "item 6: dash e airslash têm fases")
		ok(not EpicFightDados.ataque("skill/battojutsu").is_empty() and EpicFightDados.habilidade("battojutsu").has("consumption"), "item 7: battojutsu com fases e custo")
		ok(EpicFightDados.trilhas("combat/axe_auto1").size() > 0, "item 8: trilha do golpe")
		ok(EpicFightDados.armadura("stray_robe").get("weight", 0.0) == 2.0, "armadura do Stray: peso 2")
	print("test_epic_fight_dados: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
