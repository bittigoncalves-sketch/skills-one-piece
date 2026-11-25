extends SceneTree
## Mede a coreografia da GORO GORO (`src/anim/GoroPoses.gd`) amostrando as poses
## direto, sem abrir o jogo. Não julga se ficou bonito — isso depende de jogar;
## verifica o que dá para afirmar com número.
##
## O que este teste pega, e que já mordeu este projeto antes:
##   • gesto MORTO (quadros quase iguais: a pose existe e o corpo não se mexe)
##   • SALTO entre quadros (teleporte de membro, que lê como falha de animação)
##   • perna escrita numa pose PARCIAL — brigaria com a corrida por baixo
##   • gesto que não volta ao repouso e deixa o corpo torto depois do golpe

const GoroPoses = preload("res://src/anim/GoroPoses.gd")

var _f := 0

func _init() -> void:
	print("\n===== COREOGRAFIA DA GORO GORO =====")
	_amostragem()
	_parciais_nao_escrevem_perna()
	_volta_ao_repouso()
	_el_thor_aponta_para_cima()
	print("\n===== %s =====" % ("POSES OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)


## Amplitude e continuidade de cada gesto, em graus.
func _amostragem() -> void:
	print("\n-- amplitude e continuidade (graus) --")
	for estado in GoroPoses.DURATIONS:
		var dur: float = GoroPoses.DURATIONS[estado]
		var passos := 160
		var anterior := {}
		var amp_max := 0.0
		var salto_max := 0.0
		var papel_amp := ""
		var papel_salto := ""
		# Amplitude por papel = maior afastamento do primeiro quadro do gesto.
		var primeiro := GoroPoses.sample(estado, 0.0)
		for i in range(passos + 1):
			var fase: float = dur * float(i) / float(passos)
			var atual: Dictionary = GoroPoses.sample(estado, fase)
			if atual.is_empty():
				print("  ❌ %s: sample devolveu vazio" % estado)
				_f += 1
				return
			for papel in atual:
				var d: float = rad_to_deg((atual[papel] - primeiro[papel]).length())
				if d > amp_max:
					amp_max = d
					papel_amp = papel
				if not anterior.is_empty():
					var s: float = rad_to_deg((atual[papel] - anterior[papel]).length())
					if s > salto_max:
						salto_max = s
						papel_salto = papel
			anterior = atual
		# ⚠️ O TETO É EM GRAUS POR SEGUNDO, NÃO POR AMOSTRA.
		#
		# A primeira versão deste teste comparava o passo absoluto entre amostras
		# e reprovou `goro_sango` e `el_thor`. Estava errado: com o mesmo número
		# de amostras, um gesto de 0,45 s e outro de 1,60 s têm passos de tempo
		# diferentes, e os graus por amostra NÃO são comparáveis entre eles.
		#
		# O teto saiu de MEDIR A OPE, que é a régua aprovada do projeto:
		# `ope_room` 1052 °/s, `ope_shambles` 1931, `ope_takt` 835 e
		# `ope_gamma` 3250 — o pico dela, no golpe decisivo. 3400 °/s dá margem
		# sobre esse pico sem deixar passar teleporte de membro.
		var dt: float = dur / float(passos)
		var vel_max: float = salto_max / dt
		print("  %-18s amplitude %6.1f° (%s)   pico %7.0f °/s (%s)"
			% [estado, amp_max, papel_amp, vel_max, papel_salto])
		# Um gesto precisa MEXER: abaixo disto a pose é decorativa.
		_ok(amp_max >= 25.0, "%s: o corpo realmente se move (%.1f° ≥ 25°)" % [estado, amp_max])
		_ok(vel_max <= 3400.0,
			"%s: velocidade dentro do envelope da Ope (%.0f ≤ 3400 °/s)" % [estado, vel_max])


## Pose parcial não pode escrever perna: a locomoção manda nelas.
func _parciais_nao_escrevem_perna() -> void:
	print("\n-- poses parciais deixam as pernas para a locomoção --")
	var pernas := ["Thigh_R", "Shin_R", "Foot_R", "Thigh_L", "Shin_L", "Foot_L"]
	for estado in GoroPoses.DURATIONS:
		if GoroPoses.toma_o_corpo(estado):
			continue
		var pior := 0.0
		var dur: float = GoroPoses.DURATIONS[estado]
		for i in range(60):
			var pose: Dictionary = GoroPoses.sample(estado, dur * float(i) / 59.0)
			for papel in pernas:
				pior = maxf(pior, rad_to_deg(pose[papel].length()))
		_ok(pior <= 0.001, "%s: pernas intocadas (pior %.4f°)" % [estado, pior])


## Quem não sustenta tem de voltar ao repouso, ou o corpo fica torto depois.
func _volta_ao_repouso() -> void:
	print("\n-- o corpo volta ao repouso no fim do gesto --")
	# `MAMARAGAN` é a exceção declarada: ele SUSTENTA a canalização até o jogador
	# soltar, e quem devolve o corpo é o `MAMARAGAN_SOLTA` logo depois.
	for estado in GoroPoses.DURATIONS:
		var dur: float = GoroPoses.DURATIONS[estado]
		var fim: Dictionary = GoroPoses.sample(estado, dur)
		var repouso: Dictionary = GoroPoses.sample(GoroPoses.SANGO, 0.0)
		var pior := 0.0
		for papel in fim:
			pior = maxf(pior, rad_to_deg((fim[papel] - repouso[papel]).length()))
		if estado == GoroPoses.MAMARAGAN:
			_ok(pior >= 20.0, "%s: SUSTENTA a canalização no fim (%.1f°)" % [estado, pior])
		else:
			_ok(pior <= 1.0, "%s: volta ao repouso (%.2f° ≤ 1°)" % [estado, pior])


## O gatilho do El Thor sai do ForeArm_R para CIMA, então o braço tem de estar no
## alto do curso ANTES de os raios começarem a cair.
##
## ⚠️ O QUE ESTE TESTE NÃO PROVA. Ele lê o EULER do papel, não a direção do braço
## no mundo. Medido na arena em 2026-09-12: com `UpperArm_R.x = 172°` o braço
## sobe em DIAGONAL acima da cabeça, não na vertical — a conversão depende da
## orientação de repouso do rig, que não está visível daqui. A afirmação honesta
## é "chega ao alto do próprio curso a tempo", e é essa que está escrita abaixo.
## Para julgar a direção de verdade, ver a captura `12_pose_el_thor.png`.
func _el_thor_aponta_para_cima() -> void:
	print("\n-- El Thor: o braço está no alto do curso quando o raio sobe --")
	var melhor := 0.0
	var quando := 0.0
	for i in range(120):
		var fase: float = 1.60 * float(i) / 119.0
		var pose: Dictionary = GoroPoses.sample(GoroPoses.EL_THOR, fase)
		var grau := rad_to_deg(pose["UpperArm_R"].x)
		if grau > melhor:
			melhor = grau
			quando = fase
	print("    pico do ombro direito: %.1f° em %.2f s" % [melhor, quando])
	_ok(melhor >= 150.0, "o ombro chega ao alto do curso (%.1f° ≥ 150°)" % melhor)
	_ok(quando <= 0.75, "e chega ANTES dos raios começarem (%.2f s ≤ 0,75 s)" % quando)


func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c:
		_f += 1
