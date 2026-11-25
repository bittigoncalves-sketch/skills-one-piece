extends SceneTree
## Cadeia de golpes REAL do Epic Fight no executor direcional (10/11/2026): estilo gerado dos dados do mod, clipe dono do corpo,
## fases do `Animations.java`, atordoamento por StunType, troca de estilo ao empunhar a lâmina e dano no alvo.
##   godot --headless --path . --script tools/dev_tests/test_estilo_epic_fight.gd
const MAPA := "user://test_estilo_ef.json"
const SAVE := "user://test_estilo_ef_progresso.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	ok(EpicFightDados.disponivel(), "dados do Epic Fight extraídos (assets/epic_fight)")
	# ---- estilo gerado: válido, fases e clipes batem com o mod
	for tipo in ["longsword", "dagger", "tachi", "uchigatana", "greatsword"]:
		var e := EstiloEpicFight.criar(tipo)
		ok(e != null, "%s: estilo gerado" % tipo)
		if e == null: continue
		ok(e.validar().is_empty(), "%s: estilo válido (%s)" % [tipo, "; ".join(e.validar())])
		for g in e.golpes:
			var clip := load(g.clipe) as Animation
			ok(clip != null, "%s/%s: clipe carrega" % [tipo, g.nome])
			if clip != null:
				ok(g.duracao() <= clip.length + 0.01, "%s/%s: o golpe (%.2f s) cabe no clipe (%.2f s)" % [tipo, g.nome, g.duracao(), clip.length])
	var lg := EstiloEpicFight.criar("longsword")
	var a1: GolpeDirecional = lg.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA)
	ok(a1.nome == "longsword_auto1" and is_equal_approx(a1.preparo, 0.25) and is_equal_approx(a1.ativo, 0.10) and is_equal_approx(a1.recuperacao, 0.15), "longsword_auto1: 0,25 / 0,10 / 0,15 s (Animations.java)")
	ok(lg.sequencia_cliques == [GolpeDirecional.Direcao.PARA_ESQUERDA, GolpeDirecional.Direcao.PARA_DIREITA, GolpeDirecional.Direcao.FRENTE], "cadeia do clique = auto1 → auto2 → auto3")
	ok(lg.golpe_para(GolpeDirecional.Direcao.FRENTE).nome == "longsword_auto3", "o 3º auto está no 3º encaixe")
	ok(lg.golpe_para(GolpeDirecional.Direcao.CORRIDA).nome == "longsword_dash" and lg.golpe_para(GolpeDirecional.Direcao.NO_AR).nome == "longsword_airslash", "encaixes extras: corrida = dash do mod, no ar = airslash do mod")
	ok(lg.golpe_para(GolpeDirecional.Direcao.AUTO_4) == null and EstiloEpicFight.criar("sword").golpe_para(GolpeDirecional.Direcao.AUTO_4).nome == "sword_auto4", "4º auto só existe onde o mod tem 4 (sword/bokken)")
	var sw := EstiloEpicFight.criar("sword")
	ok(sw.sequencia_cliques.size() == 4 and sw.sequencia_cliques[3] == GolpeDirecional.Direcao.AUTO_4, "a cadeia do bokken tem 4 cliques")
	ok(lg.direcoes_com_golpe().size() == 4 and not lg.direcoes_com_golpe().has(GolpeDirecional.Direcao.CORRIDA), "a IA/gesto só enxergam as 4 direções-base")
	ok(lg.validar().is_empty() and sw.validar().is_empty(), "o validador aceita os encaixes extras")
	ok(EstiloEpicFight.criar("tachi").golpe_para(GolpeDirecional.Direcao.NO_AR) == null, "tachi não tem airslash no mod: sem encaixe de ar")
	ok(EstiloEpicFight.criar("longsword") == lg, "estilo em cache")
	# ---- cena real
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(64, 2, 64)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var prog: ProgressaoDoPersonagem = m.get("progressao")
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var arma = j.get_node_or_null("EspadaDaHistoria")
	var ex: ExecutorCorpoACorpo = j.get("combate_direcional")
	prog.equipar_lamina("ef_iron_longsword", true)
	await quadros(30)
	ok(ex.estilo.id == &"ef_longsword", "empunhar a espada longa troca o estilo para o do Epic Fight (%s)" % ex.estilo.id)
	# alvo à frente
	var frente: Vector3 = -j.global_transform.basis.z
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	alvo.position = j.global_position + frente * 1.3
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 100000.0
	alvo.health = 100000.0
	await quadros(20)
	var anim = j.get("_proc_anim")
	var rastro := arma.get_node_or_null("RastroDeArma") as RastroDeArma
	ok(rastro != null, "a arma do mod traz o RastroDeArma")
	var w_trilha := RastroDeArma.janela_do_golpe(lg.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA))
	ok(is_equal_approx(w_trilha.x, 0.25) and is_equal_approx(w_trilha.y, 0.30), "janela do rastro do longsword_auto1 = 0,25–0,30 s (trail_effects do mod)")
	var viu_fita := false
	var contatos := [0]
	ex.contato.connect(func(_i, _a, _r, _l, _p, _g): contatos[0] += 1)
	ok(ex.pedir_ataque(GolpeDirecional.Direcao.PARA_ESQUERDA), "pede o 1º golpe")
	await quadros(3)
	ok(ex.golpe_atual != null and ex.golpe_atual.clipe.ends_with("ef_longsword_auto1.res"), "o golpe em curso é o auto1 do mod")
	ok(anim != null and anim.is_playing_baked(), "o clipe do mod está dirigindo o corpo")
	for i in 40:
		await quadros(1)
		viu_fita = viu_fita or rastro._pontos.size() >= 2
	ok(viu_fita, "durante a janela do mod o rastro desenha a fita entre cabo e ponta")
	await quadros(50)
	ok(contatos[0] > 0 or alvo.health < 100000.0, "o golpe acertou o alvo (vida %.0f)" % alvo.health)
	ok(prog.durabilidade_de("ef_iron_longsword") < LaminasEpicFight.durabilidade_maxima("ef_iron_longsword"), "o golpe que acertou gastou durabilidade (%d/%d)" % [prog.durabilidade_de("ef_iron_longsword"), LaminasEpicFight.durabilidade_maxima("ef_iron_longsword")])
	ok(arma.carga > 0.0 and is_equal_approx(arma.carga, minf(LaminasEpicFight.dano_do_mod("ef_iron_longsword"), arma.carga_max)), "o golpe que acertou soma o dano do item (7) à barra da habilidade (%.0f/%.0f)" % [arma.carga, arma.carga_max])
	ok(ex.sons_da_arma.get("golpe", []) == ["whoosh"] and not ex.sons_da_arma.get("impacto", []).is_empty(), "o executor leva os sons do mod da espada longa")
	await quadros(40)
	ok(anim != null and not anim.is_playing_baked(), "ao fim do golpe o clipe é solto")
	# cancelar solta o clipe
	ex.pedir_ataque(GolpeDirecional.Direcao.PARA_DIREITA)
	await quadros(3)
	ex.cancelar(&"teste")
	ok(anim != null and not anim.is_playing_baked(), "golpe cancelado solta o clipe")
	# ---- locomoção do mod (hold/walk/run) no lugar da marcha procedural
	ok(anim._loco_arma.has("hold") and anim._loco_arma.has("walk") and anim._loco_arma.has("run"), "espada longa: clipes hold/walk/run do mod ligados")
	anim.update(Vector3.ZERO, true, false, 0.016, 0.0)
	ok(anim.locomocao_de_arma_ativa() == "hold", "parado: pose hold_longsword")
	anim.update(Vector3(0, 0, -anim.SPEED_REF * 0.5), true, false, 0.016, 0.0)
	ok(anim.locomocao_de_arma_ativa() == "walk", "andando: walk_longsword")
	anim.update(Vector3(0, 0, -anim.SPEED_REF), true, false, 0.016, 0.0, true)
	ok(anim.locomocao_de_arma_ativa() == "run", "correndo: run_longsword")
	anim.update(Vector3.ZERO, false, false, 0.016, 0.0)
	ok(anim.locomocao_de_arma_ativa() == "", "no ar: volta à marcha procedural")
	# ---- guarda do mod: com o executor em guarda, a pose guard_longsword; sem, volta hold
	ok(anim._loco_arma.has("guard"), "espada longa: clipe de guarda do mod ligado")
	ex.erguer_guarda()
	await quadros(30)
	anim.update(Vector3.ZERO, true, false, 0.016, 0.0)
	ok(ex.em_guarda() and anim.locomocao_de_arma_ativa() == "guard", "RMB: pose guard_longsword do mod")
	ex.bloqueou.emit(null, j.global_position)
	ok(anim.is_playing_baked(), "bloqueou: toca a reação guard_longsword_hit do mod")
	anim.play_baked(null)
	ex.baixar_guarda()
	await quadros(30)
	anim.update(Vector3.ZERO, true, false, 0.016, 0.0)
	ok(anim.locomocao_de_arma_ativa() == "hold", "soltou a guarda: volta a hold")
	var torso_antes: Vector3 = anim._n["Torso"].rotation
	anim.update(Vector3.ZERO, true, false, 0.016, 0.0)
	var clipe_hold: Animation = anim._loco_arma["hold"]
	var i_torso := -1
	for i in clipe_hold.get_track_count():
		if String(clipe_hold.track_get_path(i)).get_slice(":", 0) == "Torso":
			i_torso = i
	ok(i_torso >= 0 and (anim._n["Torso"].rotation - clipe_hold.value_track_interpolate(i_torso, anim._loco_t)).length() < 0.001, "o torso segue o clipe hold do mod")
	# ---- encaixes extras escolhidos pelo estado do corpo (a ENTRADA, como o clique real)
	var entrada: EntradaCorpoACorpo = j.get("entrada_combate_direcional")
	await quadros(60)
	ex.cancelar(&"teste")
	await quadros(10)
	ok(entrada.pedir_clique(Time.get_ticks_msec()) and ex.golpe_atual.direcao == GolpeDirecional.Direcao.PARA_ESQUERDA, "no chão e parado, o clique é o 1º auto")
	ex.cancelar(&"teste")
	await quadros(10)
	var altura: float = j.global_position.y
	j.global_position.y += 4.0
	j.velocity = Vector3.ZERO
	await quadros(2)
	ok(not j.is_on_floor() and entrada.pedir_clique(Time.get_ticks_msec()) and ex.golpe_atual.direcao == GolpeDirecional.Direcao.NO_AR and ex.golpe_atual.clipe.ends_with("ef_longsword_airslash.res"), "no ar, o clique é o airslash do mod")
	ex.cancelar(&"teste")
	j.global_position.y = altura
	await quadros(20)
	j.set_meta("forcar_corrida", true)
	ok(j.is_on_floor() and entrada.pedir_clique(Time.get_ticks_msec()) and ex.golpe_atual.direcao == GolpeDirecional.Direcao.CORRIDA and ex.golpe_atual.clipe.ends_with("ef_longsword_dash.res"), "correndo, o clique é o dash do mod (longsword_dash)")
	ex.cancelar(&"teste")
	j.set_meta("forcar_corrida", false)
	# ---- movimento do corpo pelo clipe (`Corpo:deslocamento`): o dash da lança (spear_dash, ~3,8 m no mod) avança metros
	prog.equipar_lamina("ef_iron_spear", true)
	await quadros(30)
	alvo.global_position = j.global_position + Vector3(25, 0, 25)             # fora do caminho do dash
	alvo.ponto_de_origem = alvo.global_position
	var antes_pos: Vector3 = j.global_position
	var frente_j: Vector3 = -j.global_basis.z
	j.set_meta("forcar_corrida", true)
	var pediu := entrada.pedir_clique(Time.get_ticks_msec())
	ok(pediu and ex.golpe_atual.clipe.ends_with("ef_spear_dash.res"), "lança correndo: o dash do mod (spear_dash)")
	await quadros(100)
	j.set_meta("forcar_corrida", false)
	var avancou: float = (j.global_position - antes_pos).dot(frente_j)
	ok(avancou > 1.0, "o corpo avança com o clipe (%.1f m para a frente)" % avancou)
	ok(not j.get("_proc_anim").movimento_do_clipe or not j.get("_proc_anim").is_playing_baked(), "o movimento do clipe termina com o clipe")
	ex.cancelar(&"teste")
	prog.equipar_lamina("ef_iron_spear", false)
	await quadros(20)
	# ---- habilidade de várias partes: Rushing Tempo 1 → 2 → 3 (tachi) quando a parte anterior ACERTA
	prog.equipar_lamina("ef_iron_tachi", true)
	await quadros(30)
	ok(ex.estilo.golpe_para(GolpeDirecional.Direcao.HABILIDADE).nome == "rushing_tempo1" and ex.estilo.golpe_para(GolpeDirecional.Direcao.HABILIDADE_3).nome == "rushing_tempo3", "o estilo da tachi tem as 3 partes do Rushing Tempo")
	var viu_segunda := false
	var tentativas := 0
	for dx in [-0.6, 0.0, 0.6]:
		if viu_segunda:
			break
		tentativas += 1
		arma._carregar(100.0)
		alvo.global_position = j.global_position + Vector3(dx, 0, 0) + (-j.global_transform.basis.z) * 0.7
		alvo.ponto_de_origem = alvo.global_position
		alvo.velocity = Vector3.ZERO
		alvo.health = alvo.max_health
		await quadros(5)
		ok(arma.usar_habilidade() and ex.golpe_atual.nome == "rushing_tempo1", "R inicia o Rushing Tempo (parte 1)")
		for i in 70:
			await quadros(1)
			viu_segunda = viu_segunda or (ex.golpe_atual != null and ex.golpe_atual.nome == "rushing_tempo2" and ex.atacando())
		if not viu_segunda:
			ex.cancelar(&"teste")
			await quadros(15)
	ok(viu_segunda, "o clipe da parte 1 ACERTA o boneco (contato físico, sem emitir nada) e a parte 2 (rushing_tempo2) começa sozinha (%d tentativa(s))" % tentativas)
	ex.cancelar(&"teste")
	await quadros(10)
	prog.equipar_lamina("ef_iron_tachi", false)
	await quadros(30)
	ok(not arma.ativa, "guardar a lâmina desliga a espada")
	print("test_estilo_epic_fight: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
