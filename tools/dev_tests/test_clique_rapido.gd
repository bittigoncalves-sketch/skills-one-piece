extends SceneTree
## Clique rápido (Minecraft 1.8) no M1 de punho. Conferido contra LivingEntity.hurt do 1.20.1:
## invulnerável 10 ticks; dentro, dano <= último é recusado e maior tira só a diferença.
var _ok := 0
var _falhas := 0

func _check(nome: String, cond: bool) -> void:
	if cond: _ok += 1
	else:
		_falhas += 1
		print("FALHA: ", nome)

func _init() -> void:
	var alvo := Node.new()
	# 1) primeiro golpe entra inteiro e empurra
	var a := CombatResolver.filtro_minecraft(alvo, 50.0, 1000)
	_check("1o golpe inteiro", a["dano"] == 50.0 and a["empurra"])
	# 2) cliques rápidos dentro de 0,5 s, mesmo dano: recusados
	for t in [1100, 1200, 1300, 1499]:
		var b := CombatResolver.filtro_minecraft(alvo, 50.0, t)
		_check("recusa %d" % t, b["dano"] == 0.0 and not b["empurra"])
	# 3) golpe maior dentro da janela: só a diferença, sem empurrão
	var c := CombatResolver.filtro_minecraft(alvo, 80.0, 1400)
	_check("diferenca", c["dano"] == 30.0 and not c["empurra"])
	var d := CombatResolver.filtro_minecraft(alvo, 80.0, 1450)
	_check("igual ao novo ultimo recusado", d["dano"] == 0.0)
	# 4) depois de 0,5 s do 1o golpe a janela fecha: entra inteiro
	var e := CombatResolver.filtro_minecraft(alvo, 50.0, 1500)
	_check("janela reabre", e["dano"] == 50.0 and e["empurra"])
	# 5) tabela rápida: golpe instantâneo, igual nos 4 passos, sem knockdown
	_check("clique_rapido ligado", Melee.clique_rapido)
	for i in 4:
		var g := Melee.passo(i)
		_check("passo %d startup" % i, is_equal_approx(Melee.startup(i), 0.06))
		_check("passo %d trava <= 0,18" % i, Melee.recuo(i) <= 0.18)
		_check("passo %d dano igual" % i, float(g["dano"]) == Melee.DANO_CLIQUE and float(g["kb"]) == (Melee.KB_QUARTO_CLIQUE if i == 3 else Melee.KB_CLIQUE))
		_check("passo %d sem knockdown" % i, Melee.derruba(i) == 0.0)
		_check("passo %d pico no fim do startup" % i, is_equal_approx(Melee.impacto_no_clipe(i), float(g["pico"])) or Melee.inicio(i) == 0.0)
	# 5b) clipes do Epic Fight (se extraídos localmente): existem, carregam e o pico cabe no clipe
	if ResourceLoader.exists(Melee.PASTA_EF + "ef_fist_auto1.res"):
		for i in 4:
			var clip := Melee.clipe(i)
			_check("passo %d clipe carrega" % i, clip != null and (i == 2 or String(Melee.passo(i)["anim"]).begins_with("ef_")))
			if clip != null:
				_check("passo %d janela dentro do clipe" % i, Melee.fim_da_janela(i) <= clip.length + 0.001 and Melee.inicio(i) >= 0.0)
				_check("passo %d pico no fim do startup" % i, absf(Melee.impacto_no_clipe(i) - float(Melee.passo(i)["pico"])) < 0.01 or Melee.inicio(i) == 0.0)
	else:
		print("  (sem clipes EF locais: rode tools/epic_fight/extrair_do_jar.py + ef_para_glb.py + bake)")
	# 6) espada não muda
	_check("espada intacta", Melee.startup(0, "sword") > 0.2)
	# 7) interruptor devolve o combo com peso
	Melee.clique_rapido = false
	_check("combo antigo volta", is_equal_approx(Melee.startup(0), 0.20) and Melee.derruba(3) > 0.0)
	Melee.clique_rapido = true
	print("test_clique_rapido: %d ok, %d falhas" % [_ok, _falhas])
	quit(1 if _falhas > 0 else 0)
