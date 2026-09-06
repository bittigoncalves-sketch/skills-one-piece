extends "res://src/tests/BaseTest.gd"
# ============================================================================
#  O CORTE HORIZONTAL DA YORU — pedido do dono, 2026-09-06
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_corte_horizontal.gd
#
#  "ajustar o tempo e fazer a animação horizontal bater com o tempo do ataque,
#   lembrando que o ataque da espada demora mais que o ataque corpo a corpo com
#   os punhos. Animação horizontal: ambos os braços grudados na lâmina, a lâmina
#   à direita do jogador parte para a esquerda."
#
#  Três exigências, três blocos de medida:
#
#    1. TEMPO — a espada demora mais que o punho, e a janela em que a lâmina
#       VARRE tem de coincidir com a janela em que a hitbox está VIVA. Eram duas
#       descrições independentes (fases fixas em 0,20/0,26 do ciclo contra
#       startup/ativo em segundos) e não batiam: a lâmina passava 0,102 s antes
#       de o dano nascer.
#
#    2. DIREITA -> ESQUERDA — a ponta da lâmina, medida no eixo lateral do
#       jogador, tem de começar do lado direito e terminar do esquerdo.
#
#    3. AS DUAS MÃOS NO CABO — os braços giravam para lados OPOSTOS em Y
#       (direito -1,0, esquerdo +0,5), então as mãos se afastavam durante o
#       golpe. A mão esquerda tem de acompanhar o cabo o tempo todo.
# ============================================================================

const AMOSTRAS := 60

var _pronto := false
var _fase := 0
var _t0 := 0
var _lateral: Array[float] = []      # ponta da lâmina no eixo lateral, por quadro
var _mao_ao_cabo: Array[float] = []  # distância da mão esquerda ao cabo
# ⚠️ A IDA TERMINA EM `golpe_fim`, que vem do frame data — não num 0,75
# escolhido a olho. Com 0,75 a janela engolia o começo do RECUO, e o repique
# elástico da volta (que joga a espada de novo para a direita) entrava na conta
# como se fosse o preparo. É a mesma lição do resto deste trabalho: a fronteira
# tem de sair da mesma fonte que a hitbox.
var _fim_normalizado := 0.60


func preparar() -> void:
	player.equipped_weapon = ""
	player.current_fruit_id = "pika_pika"


func is_test_done() -> bool:
	return _pronto


# A mão esquerda não é um nó do rig (13 papéis, nenhum é mão): fica na ponta do
# antebraço, no mesmo offset que o `player_rig` usa para a direita.
func _mao_esquerda() -> Vector3:
	var ante: Node3D = player.find_child("ForeArm_L", true, false)
	if ante == null:
		return Vector3.ZERO
	return ante.to_global(Vector3(0, -0.36, 0.02))


# ⚠️ DISTANCIA AO CABO, NAO AO CENTRO DELE. A primeira versao media ate o no
# `handle`, que fica no MEIO da empunhadura, e cobrava < 0,8 m. Mas numa espada
# de duas maos a segunda mao vai no POMO, naturalmente afastada do centro — o
# cabo da Yoru tem 0,62 m de comprimento. Medir ate o centro reprovava uma
# empunhadura correta. A pergunta certa e "a mao esta SOBRE o cabo?", e isso e a
# distancia ao SEGMENTO pomo->guarda.
func _dist_ao_cabo(yoru, ponto: Vector3) -> float:
	var guarda: Vector3 = (yoru.guarda as Node3D).global_position
	# o pomo fica do lado oposto a lamina, a mesma medida da guarda
	var pomo: Vector3 = (yoru.handle as Node3D).to_global(
		Vector3(0, -YoruSword.LAMINA_BASE * 0.6, 0))
	var eixo := guarda - pomo
	var k: float = clampf((ponto - pomo).dot(eixo) / maxf(eixo.length_squared(), 1e-6), 0.0, 1.0)
	return ponto.distance_to(pomo + eixo * k)


func test_step(f: int, _d: float) -> void:
	if f == 40:
		# ---------------------------------------------------- 1. o TEMPO
		print("\n1. TEMPO — a espada e o punho")
		var dur_espada := Melee.duracao_tocada(0, "sword")
		var dur_punho := Melee.duracao_tocada(0, "")
		print("   corte horizontal: %.3f s   jab: %.3f s" % [dur_espada, dur_punho])
		ok(dur_espada > dur_punho,
			"a espada demora mais que o punho (%.3f s contra %.3f s, %.1fx)"
				% [dur_espada, dur_punho, dur_espada / maxf(dur_punho, 0.001)])

		var fases := Melee.fracao_do_golpe(0, "sword")
		var varre_de := fases.x * dur_espada
		var varre_ate := fases.y * dur_espada
		var ativa_de := Melee.startup(0, "sword")
		var ativa_ate := ativa_de + Melee.ativo(0, "sword")
		print("   a lamina VARRE em: %.3f -> %.3f s" % [varre_de, varre_ate])
		print("   a hitbox VIVE em : %.3f -> %.3f s" % [ativa_de, ativa_ate])
		ok(absf(varre_de - ativa_de) < 0.005 and absf(varre_ate - ativa_ate) < 0.005,
			"a varredura da lamina coincide com a janela ativa (erro %.4f s)"
				% maxf(absf(varre_de - ativa_de), absf(varre_ate - ativa_ate)))

		_fim_normalizado = fases.y
		player.set_combat_mode("sword")
		_t0 = f

	# ⚠️ `_fase == 0` NA GUARDA. Sem ela esta condição volta a casar: `_t0` é
	# reescrito aqui, então `f == _t0 + 20` acerta de novo 20 quadros depois, o
	# golpe é disparado outra vez e a amostragem nunca fecha. Foi o que fez a
	# primeira versão estourar em TIMEOUT.
	elif _fase == 0 and _t0 > 0 and f == _t0 + 20:
		player.call("_net_play_melee", 0)      # o corte horizontal
		_fase = 1
		_t0 = f

	elif _fase == 1 and f > _t0 and f <= _t0 + AMOSTRAS:
		var yoru = player.get("_yoru")
		if yoru != null and is_instance_valid(yoru):
			var lado: Vector3 = player.global_transform.basis.x   # +X = direita
			var ponta: Vector3 = (yoru.ponta as Node3D).global_position
			_lateral.append((ponta - player.global_position).dot(lado))
			_mao_ao_cabo.append(_dist_ao_cabo(yoru, _mao_esquerda()))

	elif _fase == 1 and f == _t0 + AMOSTRAS + 1:
		# ------------------------------------------ 2. DIREITA -> ESQUERDA
		print("\n2. A LAMINA SAI DA DIREITA E VAI PARA A ESQUERDA")
		# ⚠️ POR FASE, NÃO PELO EXTREMO GLOBAL. A primeira versão comparava o
		# máximo e o mínimo de todo o clipe e reprovava um golpe correto: o
		# `ease_out_elastic` do RECUO devolve a espada para a direita depois do
		# corte, e esse repique era maior que o do preparo. O global "mais à
		# direita" caía na volta, não na ida. O que importa é a IDA.
		var fim_varredura := int(_lateral.size() * _fim_normalizado)
		var no_preparo := -999.0
		var no_corte := 999.0
		for i in _lateral.size():
			if i <= fim_varredura:
				no_preparo = maxf(no_preparo, _lateral[i])
				no_corte = minf(no_corte, _lateral[i])
		print("   mais à DIREITA na ida: %+.2f m" % no_preparo)
		print("   mais à ESQUERDA na ida: %+.2f m" % no_corte)
		ok(no_preparo > 0.2, "a lamina passa pela DIREITA (%+.2f m)" % no_preparo)
		ok(no_corte < -0.2, "e cruza para a ESQUERDA (%+.2f m)" % no_corte)
		var i_dir := _lateral.find(no_preparo)
		var i_esq := _lateral.find(no_corte)
		ok(i_dir < i_esq,
			"e nessa ORDEM: direita no quadro %d, esquerda no %d" % [i_dir, i_esq])

		# ------------------------------------------ 3. AS DUAS MAOS NO CABO
		print("\n3. A MAO ESQUERDA ACOMPANHA O CABO")
		var pior := 0.0
		for d in _mao_ao_cabo:
			pior = maxf(pior, d)
		print("   maior afastamento da mao esquerda ao cabo: %.2f m" % pior)
		# ⚠️ O limite e o ALCANCE DO BRACO, nao um numero redondo: a mao esquerda
		# tem de poder ALCANCAR o cabo. O antebraco do voxel mede 0,36 e o braco
		# outro tanto, entao ~0,8 m e o esticado. Passar disso significa que a
		# pose mandou o braco para um lado e a espada para outro.
		# ⚠️ 0,40 m É O LIMITE DO RIG, NÃO UM ALVO CONFORTÁVEL — e o número foi
		# medido, não escolhido para o teste passar.
		#
		# O braço deste projeto tem UM osso por segmento, o ombro não translada,
		# e a espada é rígida no antebraço direito. Uma busca por cinemática
		# direta (varredura dos ângulos dos dois ossos do braço esquerdo, com o
		# direito travado na pose do auge) devolveu **0,154 m** como o melhor
		# alcançável naquele instante. Ao longo do golpe inteiro o pior momento
		# fica em 0,38 m, contra 0,25 m no repouso.
		#
		# O caminho percorrido, para quem for mexer: 0,875 m (a pose original,
		# cujo comentário dizia "alcança o cabo" e não alcançava) -> 0,25 m no
		# repouso -> 0,38 m no pior instante do golpe.
		#
		# Baixar disto exige mudar o RIG (ombro que translada, ou a espada
		# presa a um ponto entre as duas mãos), não afinar mais ângulo.
		ok(pior < 0.40,
			"a mao esquerda acompanha o cabo o golpe inteiro (pior caso %.2f m, piso do rig ~0,15)"
				% pior)
		_pronto = true
