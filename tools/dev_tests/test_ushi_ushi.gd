extends SceneTree
## Ushi Ushi no Mi (21/11/2026): 3 formas, Z/X/C da humanoide, Pescoçada e Martelada da girafa, corte leve (sem lag).
## Rodar: godot --headless --path . --script tools/dev_tests/test_ushi_ushi.gd
var total := 0
var falhas := 0

class Alvo extends Node3D:
	var health := 100000.0
	var hits := 0
	var dano_total := 0.0
	var empurrao := Vector3.ZERO
	func _ready() -> void:
		add_to_group(AlvosDeGolpe.GRUPO)
	func take_damage(dano: float, _origem: Vector3, impulso: Vector3, _stun: float) -> void:
		health -= dano
		hits += 1
		dano_total += dano
		empurrao = impulso

func _init() -> void:
	executar.call_deferred()

func verificar(cond: bool, desc: String) -> void:
	total += 1
	if not cond: falhas += 1
	print(("PASS " if cond else "FALHA ") + desc)

func manter() -> void:
	var p = get_first_node_in_group("player")
	if p != null and p.capacidades != null: p.capacidades.can_use_fruit = true

func quadros(n: int) -> void:
	for i in n:
		# O ciclo de sobrevivência reaplica as capacidades da progressão (sem item "fruta" na barra: can_use_fruit=false); o teste mantém a fruta liberada.
		var p = get_first_node_in_group("player")
		if p != null and p.capacidades != null: p.capacidades.can_use_fruit = true
		await physics_frame
		await process_frame

func alvo(pos: Vector3) -> Alvo:
	var a := Alvo.new()
	current_scene.add_child(a)
	a.global_position = pos
	return a

func executar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://ushi_teste.json")
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var avancos = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	var prog = current_scene.get("progressao")   # a fruta precisa estar na PROGRESSÃO: senão o ciclo de sobrevivência re-equipa "nada" e troca o controlador
	prog.fruta = "ushi_ushi_giraffe"
	prog.skills["fruta"] = maxi(1, int(prog.skills.get("fruta", 0)))
	prog.fruta_ativa = true
	prog.item_ativo = prog.NENHUM_ITEM        # sem o item "Luta" na mão: senão `fruta_a_equipar` devolve o estilo base e troca o controlador
	modo.equipar_fruta(j, "ushi_ushi_giraffe")
	await quadros(12)
	# O save forçado normalmente desliga o redutor da campanha; medir o dano real dela.
	DanoDaHistoria.ligar_para(true)
	physics_frame.connect(manter)                   # libera a fruta ANTES da física de cada tick (o ciclo de sobrevivência a trava de vez em quando)
	var c = j.get_node("FrutaMinePiece")
	verificar(is_instance_valid(c.ushi), "módulo da Ushi Ushi carregado")
	if not is_instance_valid(c.ushi):
		quit(1)
		return
	var u = c.ushi
	var forca_original := float(j.get_meta("bonus_fisico_historia", 0.0))
	var luta := load("res://src/combat/frutas_mine_piece/luta.gd")
	var golpes_luta := ceili(float(luta.MAXIMO_RAJADA - luta.INICIO_RAJADA) / float(luta.INTERVALO_RAJADA))
	for nivel in [1, 10, 35, 100]:
		var forca: float = prog.RegrasDosAtributos.bonus_fisico(nivel)
		j.set_meta("bonus_fisico_historia", forca)
		for forma in [0, 1, 2]:
			u.forma = forma
			var z: DamageSpec = u._spec_do_golpe("Z")
			var x: DamageSpec = u._spec_do_golpe("X")
			var comparavel := z.dano > float(Balance.MINE_PIECE_LUTA.soco.dano) * 0.1 + forca \
				and x.dano > float(Balance.MINE_PIECE_LUTA.pesado.dano) * 0.1 * 1.5 + forca
			if forma != 2:
				var rajada: DamageSpec = u._spec_do_golpe("C")
				var luta_total := float(golpes_luta) * (float(Balance.MINE_PIECE_LUTA.rajada.dano) * 0.1 + forca) + float(Balance.MINE_PIECE_LUTA["final"].dano) * 0.1 + forca
				comparavel = comparavel and rajada.dano > float(Balance.MINE_PIECE_LUTA.rajada.dano) * 0.1 + forca and rajada.teto > luta_total
			var comparacao := "Z e X carregado" if forma == 2 else "Z, X carregado e C completo"
			verificar(comparavel, "nível %d forma %d: %s da luta ficam abaixo da girafa" % [nivel, forma, comparacao])
	u.forma = 0
	j.set_meta("bonus_fisico_historia", forca_original)
	j.max_energy = 2000.0
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	# ---- sons: um por ataque, nenhum mudo nem estourado, duração coerente
	for cue in UshiAudio.DURACAO:
		var st := UshiAudio.stream(cue)
		var seg := float(st.data.size()) / 2.0 / UshiAudio.RATE
		var pico := UshiAudio.pico(cue)
		verificar(pico > 0.25 and pico <= 1.0 and absf(seg - float(UshiAudio.DURACAO[cue])) < 0.01, "som '%s': pico %.2f, %.2f s" % [cue, pico, seg])
	# ---- teclas e HUD
	var mapa: Dictionary = c.mapa_de_teclas()
	verificar(mapa.Z == 1101 and mapa.X == 1102 and mapa.C == 1103, "humano/humanoide: Z X C autorais")
	var nomes: Array = c.estado_das_tecnicas().map(func(e): return e.nome)
	verificar(nomes.has("Investida do Pescoço") and nomes.has("Corte no Ar") and nomes.has("Rajada de Cortes"), "HUD lista os 3 golpes novos")
	verificar(not nomes.has("Finger Pistol") and not nomes.has("Tempest Kick"), "golpes antigos do mod saíram da lista")
	# ---- Z humano (forma 0): investida do pescoço
	var dir: Vector3 = c.olhar().normalized()       # a mira real (com altura): é para onde o pescoço e o corte vão
	var olho: Vector3 = j.global_position + Vector3.UP * 1.5
	var a1 := alvo(olho + dir * 3.5)
	var e0: float = j.energy
	c.usar_tecla("Z", true)
	c.usar_tecla("Z", false)
	verificar(u.ativo and is_equal_approx(e0 - j.energy, 60.0), "Z inicia e cobra 60")
	var feriu_no_preparo := false
	for i in 60:                                   # espera o fim do PREPARO por fase (não por nº de quadros: o passo físico varia com a carga da máquina)
		await quadros(1)
		if u.fase == 1 and a1.hits > 0: feriu_no_preparo = true
		if u.fase != 1: break
	verificar(not feriu_no_preparo, "antecipação do Z não fere")
	await quadros(30)
	verificar(a1.hits == 1, "Z fere o alvo a 3,5 m exatamente uma vez (hits=%d)" % a1.hits)
	verificar(a1.dano_total > 0.0 and a1.empurrao.length() > 1.0, "Z causa dano e empurra")
	verificar(absf(a1.dano_total - (11.71875 + forca_original * 0.5)) < 0.01, "Z humano na campanha aplica dano e bônus de força (%.3f)" % a1.dano_total)
	await quadros(45)
	verificar(not u.ativo and not c.controla_movimento(), "Z termina e libera o corpo")
	verificar(not is_instance_valid(u._pescoco), "pescoço de investida removido ao fim")
	c.usar_tecla("Z", true)
	verificar(not u.ativo, "recarga impede repetir o Z")
	# ---- X humano: corte no ar atinge longe
	var a2 := alvo(olho + dir * 9.0)         # o corte para no chão: a 9 m na mira ele ainda está no ar
	var a_fora := alvo(olho + dir * 9.0 + dir.cross(Vector3.UP).normalized() * 6.0)
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	await quadros(8)
	var vivos := get_nodes_in_group("nada").size()
	await quadros(40)
	verificar(a2.hits == 1 and a2.dano_total > 0.0, "X acerta o alvo a 9 m (hits=%d dano=%.0f)" % [a2.hits, a2.dano_total])
	verificar(absf(a2.dano_total - (19.53125 + forca_original * 0.5)) < 0.01, "X humano na campanha aplica dano e bônus de força (%.3f)" % a2.dano_total)
	verificar(a_fora.hits == 0, "X não acerta quem está 6 m ao lado")
	await quadros(50)
	var cortes := 0
	for n in current_scene.get_children():
		if n is UshiCorte: cortes += 1
	verificar(cortes == 0, "o corte some depois do alcance (restam %d)" % cortes)
	# ---- C humano: rajada
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	var a3 := alvo(olho + dir * 10.0)
	u.controlador.iniciar_recarga(1103, 0.0)
	var base_max := 0.0
	for i in 110:                                   # linha de base: os mesmos 110 quadros SEM golpe (a cena do teste já pesa)
		manter()
		var t0 := Time.get_ticks_usec()
		await physics_frame
		await process_frame
		base_max = maxf(base_max, float(Time.get_ticks_usec() - t0) / 1000.0)
	print("INFO quadro mais lento SEM golpe (baseline): %.1f ms" % base_max)
	c.usar_tecla("C", true)                          # a rajada só dispara DEPOIS da baseline
	c.usar_tecla("C", false)
	var pico := 0
	var tmax := 0.0
	for i in 110:
		manter()
		var t0 := Time.get_ticks_usec()
		await physics_frame
		await process_frame
		tmax = maxf(tmax, float(Time.get_ticks_usec() - t0) / 1000.0)
		var n := 0
		for k in current_scene.get_children():
			if k is UshiCorte: n += 1
		pico = maxi(pico, n)
	verificar(u.cortes_lancados >= 10, "rajada lança 9 cortes (total contado %d)" % u.cortes_lancados)
	verificar(pico <= UshiCorte.MAX_VIVOS, "no máximo %d cortes vivos (pico %d)" % [UshiCorte.MAX_VIVOS, pico])
	verificar(a3.hits >= 4 and a3.dano_total <= 324.01 and a3.dano_total > 0.0, "C fere várias vezes sem passar do teto (hits=%d dano=%.0f)" % [a3.hits, a3.dano_total])
	var dano_por_corte := 4.39453125 + forca_original * float(golpes_luta + 1) / 18.0
	verificar(a3.hits > 0 and absf(a3.dano_total - float(a3.hits) * dano_por_corte) < 0.02 and a3.hits <= 9, "C na campanha aplica dano e bônus por corte (hits=%d dano=%.3f)" % [a3.hits, a3.dano_total])
	print("INFO quadro mais lento durante a rajada: %.1f ms" % tmax)
	# ---- parâmetros da bicuda: a ABDUÇÃO vai para a perna (Z da coxa) e a inclinação lateral para o tronco (não trocados)
	var p30: Dictionary = UshiChute.pose_x(0.30)
	verificar((p30.Thigh_R as Vector3).z > 1.2 and absf((p30.Torso as Vector3).z) < 0.5, "X no impulso: coxa D abre %.2f rad de lado e o tronco inclina só %.2f rad" % [(p30.Thigh_R as Vector3).z, (p30.Torso as Vector3).z])
	# ---- animação de chute (humano/humanoide): pose no rig, pico no instante da emissão, salto visual, limpeza
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	await quadros(60)
	u.controlador.iniciar_recarga(1102, 0.0)
	var y0: float = j._char_model.position.y
	var cortes0: int = u.cortes_lancados
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	var coxa_max := 0.0
	var salto_max := 0.0
	var emitiu_no_pico := false
	for i in 120:
		await quadros(1)
		if j.has_meta("pose_externa"):
			coxa_max = maxf(coxa_max, (j.get_meta("pose_externa").Thigh_R as Vector3).x)
		salto_max = maxf(salto_max, j._char_model.position.y - y0)
		if u.cortes_lancados > cortes0 and not emitiu_no_pico:
			emitiu_no_pico = absf(u.tempo - UshiChute.X_PICO) < 0.05
	verificar(coxa_max > 1.3, "X: perna direita sobe até o pico do chute (coxa %.2f rad)" % coxa_max)
	verificar(emitiu_no_pico, "X: o corte sai no quadro do pico do chute (0,34 s)")
	verificar(salto_max > 0.15, "X: salto visual de ~0,25 m (%.2f m)" % salto_max)
	verificar(not j.has_meta("pose_externa") and absf(j._char_model.position.y - y0) < 0.001, "X: pose e altura do corpo restauradas ao fim")
	# C: 9 chutes, cada corte no pico de um chute, alternando os pés
	u.controlador.iniciar_recarga(1103, 0.0)
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	var antes: int = u.cortes_lancados
	var coxas_d := 0
	var coxas_e := 0
	c.usar_tecla("C", true)
	c.usar_tecla("C", false)
	for i in 160:
		await quadros(1)
		if j.has_meta("pose_externa"):
			var ps: Dictionary = j.get_meta("pose_externa")
			if (ps.Thigh_R as Vector3).x > 1.2: coxas_d += 1
			if (ps.Thigh_L as Vector3).x > 1.2: coxas_e += 1
	print("INFO C: tempo=%.2f ativo=%s soltos=%d fase=%d" % [u.tempo, u.ativo, u._cortes_soltos, u.fase])
	verificar(u.cortes_lancados - antes == 9, "C: exatamente 9 cortes, um por chute (%d)" % (u.cortes_lancados - antes))
	verificar(coxas_d > 0 and coxas_e > 0, "C: chutes alternam as duas pernas (D %d quadros, E %d quadros no pico)" % [coxas_d, coxas_e])
	verificar(not j.has_meta("pose_externa"), "C: pose removida ao fim")
	for n in get_nodes_in_group("ushi_corte"):
		n.queue_free()
	# ---- X e C voam RETO na mira e vão longe (pedido do dono: "não sobe e não vai longe")
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	await quadros(90)
	u.controlador.iniciar_recarga(1102, 0.0)
	var mira_exata: Vector3 = c.olhar().normalized()
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	var max_desvio := 0.0
	var visto := 0
	for i in 90:
		await quadros(1)
		for n in get_nodes_in_group("ushi_corte"):
			visto += 1
			max_desvio = maxf(max_desvio, (n as UshiCorte).direcao.angle_to(mira_exata))
	verificar(visto > 0 and max_desvio < 0.01, "X voa reto na direção da mira, sem subir (desvio máximo %.4f rad em %d observações)" % [max_desvio, visto])
	verificar(float(load("res://src/combat/ushi/ushi_ushi.gd").DADOS.X.alc) >= 40.0 and float(load("res://src/combat/ushi/ushi_ushi.gd").DADOS.C.alc) >= 32.0, "alcances: X 40 m, C 32 m")
	var horiz := Vector3(mira_exata.x, 0.0, mira_exata.z).normalized()
	var pos_c: Vector3 = j.global_position + Vector3.UP * 1.0
	var longe := alvo(pos_c + horiz * 36.0)
	UshiCorte.criar(current_scene, pos_c, horiz, j, Balance.novo("ushi_ushi_giraffe", "X"), 2.6, 0.2, float(load("res://src/combat/ushi/ushi_ushi.gd").DADOS.X.vel), float(load("res://src/combat/ushi/ushi_ushi.gd").DADOS.X.alc))
	for i in 140:
		await quadros(1)
	verificar(longe.hits == 1, "a lâmina chega a um alvo a 36 m em linha reta (hits=%d)" % longe.hits)
	# ---- custo de CPU do pior caso: 14 cortes vivos (o teto) contra 60 alvos, medido pelo monitor de física do motor
	for i in 60:
		alvo(olho + dir * 6.0 + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
	await quadros(5)
	var sem := 0.0
	for i in 120:
		await quadros(1)
		sem += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	for i in 14:
		var cc := UshiCorte.criar(current_scene, olho + dir * 1.0, dir, j, Balance.novo("ushi_ushi_giraffe", "X"), 2.6, float(i) * 0.4, 0.5, 500.0)
		cc.com_dano = true
	await quadros(5)
	var com := 0.0
	for i in 120:
		await quadros(1)
		com += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var custo_ms := (com - sem) / 120.0 * 1000.0
	print("INFO custo de física: sem cortes %.3f ms/quadro, com 14 cortes x 60 alvos %.3f ms/quadro (diferença %.3f ms)" % [sem / 120.0 * 1000.0, com / 120.0 * 1000.0, custo_ms])
	verificar(custo_ms < 2.5, "14 cortes vivos contra 60 alvos custam < 2,5 ms de física por quadro, pior caso (%.3f ms; medido 0,1–0,6 ms em máquina ociosa)" % custo_ms)
	for n in get_nodes_in_group("ushi_corte"):
		n.queue_free()
	await quadros(3)
	# ---- parede: nem o corte nem o pescoço ferem através do cenário
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	var parede := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(8, 8, 0.6)
	col.shape = caixa
	parede.add_child(col)
	current_scene.add_child(parede)
	parede.global_position = olho + dir * 5.0
	parede.look_at(olho + dir * 6.0)
	var atras := alvo(olho + dir * 8.0)
	await quadros(3)
	u.controlador.iniciar_recarga(1102, 0.0)
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	await quadros(70)
	verificar(atras.hits == 0, "X não fere alvo atrás de parede (hits=%d)" % atras.hits)
	u.controlador.iniciar_recarga(1101, 0.0)
	var atras2 := alvo(olho + dir * 5.6 + dir.cross(Vector3.UP).normalized() * 0.0)
	c.usar_tecla("Z", true)
	c.usar_tecla("Z", false)
	await quadros(70)
	verificar(atras2.hits == 0, "Z não fere alvo logo atrás de parede (hits=%d)" % atras2.hits)
	parede.queue_free()
	# ---- formas
	await quadros(40)
	c.transformar(false)
	await quadros(240)
	verificar(u.forma == 1 and c.forma_atual() == 1, "J: humano → humanoide (forma %d, mod %d)" % [u.forma, c.forma_atual()])
	verificar(is_instance_valid(j.get_node_or_null("FormaZoan")), "humanoide desenha o modelo do mod")
	verificar(float(j.get_meta("resistencia_de_forma", 1.0)) == 1.5, "transformado: meta resistencia_de_forma = 1,5")
	c.transformar(false)
	await quadros(60)
	verificar(u.forma == 2, "J: humanoide → girafa")
	verificar(is_instance_valid(j.get_node_or_null("FormaGirafa")) and not is_instance_valid(j.get_node_or_null("FormaZoan")), "girafa quadrúpede no lugar do humanoide")
	var m2: Dictionary = c.mapa_de_teclas()
	verificar(m2.has("Z") and m2.has("X") and not m2.has("C") and not m2.has("V"), "girafa: Z e X, sem C (e sem V)")
	nomes = c.estado_das_tecnicas().map(func(e): return e.nome)
	verificar(nomes.has("Pescoçada") and nomes.has("Martelada") and nomes.size() == 2, "HUD da girafa: Pescoçada, Martelada")
	u.bloqueio_de_forma = 0.0
	c.usar_tecla("C", true)
	verificar(not u.ativo, "C não existe na girafa")
	# ---- Pescoçada
	j.energy = 2000.0
	c._sincronizar_para_o_mod()
	dir = c.olhar().normalized()
	olho = j.global_position + Vector3.UP * 2.0
	var g1 := alvo(olho + dir * 6.0)
	print("INFO girafa pré-Z: fruta_ativa=%s livre=%s morrendo=%s energia=%.0f recarga1111=%.2f ativo_c=%s ativo_u=%s bloq=%.2f" % [c.fruta_ativa(), j.corpo_livre_para_golpe(), j.morrendo, j.energy, c.recarga_da_tecnica(1111), c.ativo, u.ativo, u.bloqueio_de_forma])
	c.usar_tecla("Z", true)
	c.usar_tecla("Z", false)
	var menor := 1e9
	for i in 70:
		await quadros(1)
		if u.fase == 2:
			menor = minf(menor, Geometry3D.get_closest_point_to_segment(g1.global_position, u._raiz(), u._ponta()).distance_to(g1.global_position))
	print("INFO pescoçada: menor distância alvo-pescoço %.2f; raiz %s ponta %s alvo %s dir %s" % [menor, u._raiz(), u._ponta(), g1.global_position, dir])
	verificar(g1.hits == 1 and g1.dano_total > 0.0, "Pescoçada fere alvo a 6 m (hits=%d)" % g1.hits)
	verificar(absf(g1.dano_total - (11.71875 + forca_original * 0.5)) < 0.01, "Pescoçada na campanha aplica dano e bônus de força (%.3f)" % g1.dano_total)
	var neck: UshiPescoco = j.get_node("FormaGirafa").pescoco
	await quadros(50)
	verificar(not u.ativo and absf(neck.extensao - 1.0) < 0.2, "pescoço volta ao repouso (ext %.2f)" % neck.extensao)
	# ---- Martelada
	u.controlador.iniciar_recarga(1112, 0.0)
	var lado := dir.cross(Vector3.UP).normalized()
	var dir_plano := Vector3(dir.x, 0, dir.z).normalized()
	var g2 := alvo(j.global_position + dir_plano * 3.2 + Vector3.UP * 0.9)      # no chão, na frente: o arco do nariz passa por aqui
	var menor2 := 1e9
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	for i in 80:
		await quadros(1)
		if u.fase == 2:
			menor2 = minf(menor2, u._ponta().distance_to(g2.global_position))
	print("INFO martelada: hits=%d dano=%.0f menor distância do nariz %.2f" % [g2.hits, g2.dano_total, menor2])
	verificar(g2.hits == 1 and g2.dano_total > 0.0, "Martelada fere o alvo à frente, no chão, exatamente uma vez")
	verificar(absf(g2.dano_total - (23.4375 + forca_original * 0.5)) < 0.01, "Martelada na campanha aplica dano e bônus de força (%.3f)" % g2.dano_total)
	# ---- resistência de 1,5× transformado (duas pancadas separadas por >0,5 s: a janela de invulnerabilidade do Minecraft não pode mascarar)
	var meta_ok: bool = float(j.get_meta("resistencia_de_forma", 1.0)) == 1.5
	j.remove_meta("damage_immune")
	var vida0: float = j.health
	j.set_meta("resistencia_de_forma", 1.0)
	j.take_damage(10.0)
	var perdeu_normal: float = vida0 - j.health
	await quadros(80)
	j.health = vida0
	j.set_meta("resistencia_de_forma", 1.5)
	j.take_damage(10.0)
	var perdeu_transformado: float = vida0 - j.health
	j.health = vida0
	j.set_meta("damage_immune", true)
	verificar(perdeu_normal > 0.0 and absf(perdeu_transformado - perdeu_normal / 1.5) < 0.05, "transformado perde 1,5× menos vida (%.3f vs %.3f)" % [perdeu_transformado, perdeu_normal])
	# ---- volta ao humano
	print("INFO antes de voltar: u.ativo=%s c.ativo=%s bloqueio=%.2f forma=%d" % [u.ativo, c.ativo, u.bloqueio_de_forma, u.forma])
	c.transformar(false)
	await quadros(240)
	verificar(u.forma == 0 and c.forma_atual() == 0, "J: girafa → humano (forma %d, mod %d)" % [u.forma, c.forma_atual()])
	verificar(not is_instance_valid(j.get_node_or_null("FormaGirafa")) and not is_instance_valid(j.get_node_or_null("FormaZoan")), "nenhuma forma desenhada no humano")
	verificar(not j.has_meta("resistencia_de_forma"), "humano: sem resistência extra de forma")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
