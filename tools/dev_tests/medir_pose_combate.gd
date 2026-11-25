extends SceneTree
# ============================================================================
#  MEDIR POSE DO COMBATE DIRECIONAL — sonda de autoria (não é teste de bateria).
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (§8.3). Dispara cada golpe do estilo no
#  jogador REAL do Modo História e mede, quadro a quadro, no espaço do CORPO
#  (frente = −Z, metros):
#    • erro da IK: punho real × alvo da chave (reach impossível aparece aqui);
#    • o punho do efetor: onde está, quão à frente chega, e EM QUE FASE;
#    • o pico de velocidade do punho: tem que cair no ATIVO (é o "perigoso");
#    • os PÉS (Fase 6), no MUNDO (é o que o olho vê), separados pelo estado do pé de
#      apoio: TRAVADO (tem de ser ~0: é a IK não alcançando), SOLTO rente ao chão (é o
#      deslize que se vê) e quantos PASSOS; a sola mais baixa (afundou?) e o quadril.
#
#  Medir em espaço do corpo, nunca em rotação somada à mão (regra do projeto).
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/medir_pose_combate.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://medir_pose_combate.json"
## Sola até esta altura sobre a origem do modelo conta como NO CHÃO (a sola em repouso
## mede −0,02…0,00 no base_v2).
const ALTURA_NO_CHAO := 0.025


func _init() -> void:
	await process_frame
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	var jogador: Node = null
	for p in get_root().get_tree().get_nodes_in_group("player"):
		jogador = p
	jogador.capacidades = CapacidadesDoJogador.completas()
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	var ap := AplicadorDePose.new()
	var dt := 1.0 / Engine.physics_ticks_per_second

	# Aquecimento: o primeiro golpe saindo do IDLE mede outra coisa (braço subindo da
	# posição pendurada, pé ainda sem âncora). Mede-se o golpe saindo da GUARDA.
	e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	while e.atacando():
		await physics_frame
	for golpe in e.estilo.golpes:
		for i in 40:
			await physics_frame
		ap.montar(jogador.modelo_visual())
		var lado := "R" if String(golpe.efetor).ends_with("_R") else "L"
		e.pedir_ataque(golpe.direcao)
		var pose := {}
		var pior_ik := 0.0
		var mais_a_frente := 0.0
		var fase_mais_a_frente := ""
		var anterior := Vector3.INF
		var maior_vel := 0.0
		var fase_maior_vel := ""
		var linhas := PackedStringArray()
		var pes := {"L": {"ant": Vector3.INF, "travado": 0.0, "solto": 0.0, "passos": 0, "estado": "", "min_y": INF, "salto": 0.0, "ant_pe": Vector3.INF},
			"R": {"ant": Vector3.INF, "travado": 0.0, "solto": 0.0, "passos": 0, "estado": "", "min_y": INF, "salto": 0.0, "ant_pe": Vector3.INF}}
		var real: AplicadorDePose = e.ator._aplicador   # o do executor: é ele que trava os pés
		var quadril_min := INF
		var pior_ik_perna := 0.0
		var andando_max := 0.0
		var chao: float = jogador.modelo_visual().global_position.y
		while e.atacando():
			await physics_frame
			if not e.atacando():
				break
			var t := e.tempo_da_acao()
			PoseDeCombate.amostrar(golpe, e.estilo.guarda, t, pose)
			var punho := ap.para_corpo(ap.posicao_global("Wrist_" + lado))
			var alvo: Vector3 = pose["mao_" + lado]
			var efetor := ap.para_corpo(ap.posicao_global(golpe.efetor))
			var fase_nome: String = GolpeDirecional.Fase.keys()[e.fase()]
			if e.peso_da_pose() >= 0.999:
				pior_ik = maxf(pior_ik, punho.distance_to(alvo))
			if -efetor.z > mais_a_frente:
				mais_a_frente = -efetor.z
				fase_mais_a_frente = fase_nome
			if anterior != Vector3.INF and e.peso_da_pose() >= 0.999:
				var v := efetor.distance_to(anterior) / dt
				if v > maior_vel:
					maior_vel = v
					fase_maior_vel = fase_nome
			anterior = efetor
			for pl in pes:
				var sola := ap.posicao_global("Sole_" + pl)
				var bola := ap.posicao_global("Ball_" + pl)   # o pivô gira sobre ela: é ela que não pode deslizar
				var m: Dictionary = pes[pl]
				var y: float = sola.y - chao
				m["min_y"] = minf(m["min_y"], y)
				var estado: String = real.estado_do_pe(pl)
				if estado == "passo" and m["estado"] != "passo":
					m["passos"] += 1
				if m["ant"] != Vector3.INF and estado == m["estado"]:
					var d := Vector2(bola.x - m["ant"].x, bola.z - m["ant"].z).length()
					if estado == "travado":
						m["travado"] += d
					elif estado == "solto" and y <= ALTURA_NO_CHAO:
						m["solto"] += d
				# O SALTO do tornozelo num quadro: é o teletransporte que o olho vê, e ele
				# acontece com o pé no ar — fora da conta de deslize rente ao chão.
				var tornozelo := ap.posicao_global("Foot_" + pl)
				if m["ant_pe"] != Vector3.INF:
					m["salto"] = maxf(m["salto"], tornozelo.distance_to(m["ant_pe"]))
				m["ant_pe"] = tornozelo
				m["estado"] = estado
				m["ant"] = bola
			quadril_min = minf(quadril_min, ap.para_corpo(ap.posicao_global("Torso")).y)
			# IK da perna: bola do pé travado × âncora (no chão, x e z).
			for pl in ["L", "R"]:
				var anc: Vector3 = real._pes[pl]["ancora"]
				if anc != Vector3.INF:
					var b := ap.posicao_global("Ball_" + pl)
					pior_ik_perna = maxf(pior_ik_perna, Vector2(b.x - anc.x, b.z - anc.z).length())
			var andar: Vector3 = jogador.velocity - e._avanco_aplicado
			andando_max = maxf(andando_max, Vector2(andar.x, andar.z).length() / 1.5)
			linhas.append("   t=%.3f %-11s peso=%.2f punho=(%+.2f %+.2f %+.2f) alvo=(%+.2f %+.2f %+.2f) efetor=(%+.2f %+.2f %+.2f)"
				% [t, fase_nome, e.peso_da_pose(), punho.x, punho.y, punho.z, alvo.x, alvo.y, alvo.z, efetor.x, efetor.y, efetor.z])
		print("\n== %s (%s, efetor %s) ==" % [golpe.id, GolpeDirecional.Direcao.keys()[golpe.direcao], golpe.efetor])
		for i in range(0, linhas.size(), 3):
			print(linhas[i])
		print("   pior erro da IK (peso 1): %.3f m" % pior_ik)
		print("   efetor mais à frente: %.3f m, na fase %s" % [mais_a_frente, fase_mais_a_frente])
		print("   pico de velocidade do efetor (pose inteira): %.2f m/s, na fase %s" % [maior_vel, fase_maior_vel])
		for pl in pes:
			print("   pé %s: antepé travado desliza %.1f cm | solto rente ao chão %.1f cm | %d passo(s) | sola mais baixa %+.3f m | maior salto do tornozelo num quadro %.1f cm (%.1f m/s)" % [pl,
				pes[pl]["travado"] * 100.0, pes[pl]["solto"] * 100.0, pes[pl]["passos"], pes[pl]["min_y"],
				pes[pl]["salto"] * 100.0, pes[pl]["salto"] * 60.0])
		print("   pior erro do pé travado (antepé × âncora): %.3f m" % pior_ik_perna)
		print("   quadril mais baixo (espaço do corpo): %.3f m; maior fração 'andando' (velocidade − avanço): %.2f" % [quadril_min, andando_max])
	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	quit(0)
