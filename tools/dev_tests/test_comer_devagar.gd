extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_comer_devagar.gd
var p: Node3D
var boneco: Node3D
var treino
var prog
var passou := 0
var falhas := 0

func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _rodar() -> void:
	await process_frame
	var P = load("res://src/historia/tripulantes/provisoes.gd")
	print("\n-- números --")
	ok("tempo de comer: pão ≈ 2,1 s, maçã no mínimo (2 s), carne assada 4 s, nunca passa de 4,5 s", absf(P.tempo_de_comer("pao") - 2.125) < 0.01 and P.tempo_de_comer("maca") == 2.0 and absf(P.tempo_de_comer("carne_assada") - 4.0) < 0.01)
	ok("bônus de regeneração: pão 17,5 s ×3; carne assada 40 s ×3; água e leite NÃO dão", absf(P.bonus_de_regeneracao("pao").duracao - 17.5) < 0.01 and P.bonus_de_regeneracao("pao").fator == 3.0 and absf(P.bonus_de_regeneracao("carne_assada").duracao - 40.0) < 0.01 and P.bonus_de_regeneracao("agua_potavel").duracao == 0.0 and P.bonus_de_regeneracao("leite").fator == 1.0)

	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_comer_devagar.json"))
	modo.set("progresso_forcado", "user://test_comer_devagar.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	prog = current_scene.progressao
	await frames(10)
	var hud = current_scene.get_node("HistoriaHud")
	var alim = p.get_node("AlimentacaoVisual")
	var est = P.estado(prog)
	est.estoque["pao"] = 2
	est.fome = 100.0
	print("\n-- comer devagar --")
	ok("começa a comer (devolve verdadeiro)", hud._comer_devagar(P, p, alim))
	ok("a unidade foi RESERVADA na hora (estoque 2 → 1) e a fome ainda não entrou", int(est.estoque["pao"]) == 1 and absf(float(est.fome) - 100.0) < 0.01)
	ok("está comendo", alim.comendo())
	await frames(60)
	ok("depois de 1 s ainda comendo e sem fome paga (clipe esticado para ~2,1 s)", alim.comendo() and absf(float(est.fome) - 100.0) < 0.01)
	var antes_estoque: int = int(est.estoque["pao"])
	ok("clicar de novo comendo NÃO começa outra refeição nem gasta outra unidade", not hud._comer_devagar(P, p, alim) and int(est.estoque["pao"]) == antes_estoque)
	await frames(110)
	ok("terminou: a fome entrou (+25) e acabou de comer", not alim.comendo() and absf(float(est.fome) - 125.0) < 0.01)
	ok("e a regeneração acelerada ligou (×%.1f)" % p._vida.fator_da_comida(), p._vida.fator_da_comida() == 3.0)

	print("\n-- regeneração --")
	p._vida.vida_max = 100.0
	p._vida.vida = 50.0
	p._vida._t_ultimo_dano = -999999
	p._vida._t_bonus_kill = -999999
	p._vida.regenerar(1.0)
	var com_comida: float = p._vida.vida - 50.0
	p._vida._t_comida_ate_ms = -999999
	p._vida.vida = 50.0
	p._vida.regenerar(1.0)
	var sem_comida: float = p._vida.vida - 50.0
	ok("com a comida a vida regenera 3× mais (%.3f contra %.3f por s)" % [com_comida, sem_comida], sem_comida > 0.0 and absf(com_comida / sem_comida - 3.0) < 0.05)
	p._vida.premiar_comida(3.0, 5.0)
	p._vida._t_bonus_kill = Time.get_ticks_msec()
	p._vida.vida = 50.0
	p._vida.regenerar(1.0)
	ok("o bônus de kill (4×) NÃO empilha com a comida (3×): vale o maior (%.3f)" % (p._vida.vida - 50.0), absf((p._vida.vida - 50.0) / sem_comida - 4.0) < 0.05)
	p._vida._t_bonus_kill = -999999
	p._vida._t_comida_ate_ms = -999999

	print("\n-- interrupção --")
	est.fome = 100.0
	var pao0: int = int(est.estoque["pao"])
	ok("começa outra refeição", hud._comer_devagar(P, p, alim) and int(est.estoque["pao"]) == pao0 - 1)
	await frames(40)
	alim.cancelar()                       # dano/rolagem/morte cortam
	ok("cortada no meio: o item VOLTA ao estoque, nenhuma fome entra e não há bônus", int(est.estoque["pao"]) == pao0 and absf(float(est.fome) - 100.0) < 0.01 and p._vida.fator_da_comida() == 1.0 and not alim.comendo())
	print("\n-- sem comida --")
	est.estoque.erase("pao")
	for id in P.COMIDAS_NA_BARRA:
		est.estoque[id] = 0
	ok("sem comida: não começa e não trava", not hud._comer_devagar(P, p, alim) and not alim.comendo())
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("COMER_DEVAGAR %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
