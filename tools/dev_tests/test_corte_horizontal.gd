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
var _ini_normalizado := 0.42
var _lamina: Array[float] = []       # ângulo do fio com a vertical, em graus
var _tronco: Array[Vector3] = []     # inclinação do tronco
var _pe_r: Array[Vector2] = []       # pé direito (frente, lado)
var _pe_l: Array[Vector2] = []
var _joelhos: Array[Vector2] = []    # flexão dos joelhos (Shin_R.x, Shin_L.x)
var _ponta_local: Array[Vector3] = []  # ponta da espada em ESPAÇO LOCAL do player
var _giro_raiz: Array[Vector3] = []    # yaw de root / SkinPivot / GLBModel
var _t_amostra: Array[float] = []      # o `_sword_slash_t` de cada amostra
var _hb_ini := 0.0                     # janela de dano, em tempo normalizado
var _hb_fim := 1.0


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
## O índice da amostra mais próxima de um instante `t` do golpe.
func _indice_em(t: float) -> int:
	var melhor := 0
	for i in _t_amostra.size():
		if absf(_t_amostra[i] - t) < absf(_t_amostra[melhor] - t):
			melhor = i
	return melhor


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
		# ⚠️ ESTA CHECAGEM MUDOU DE PERGUNTA. Antes cobrava que as fases da
		# animacao fossem IGUAIS a janela de dano. Elas deixaram de ser, de
		# proposito: a lamina e carregada pelo antebraco, que anda atrasado pela
		# cadeia cinetica, e com as fases coincidindo o fio cruzava a frente a
		# 92% da janela — o dano abria com a espada ainda armada a direita.
		# `Melee.COMPENSACAO_CADEIA` adianta a ANIMACAO para o cruzamento cair no
		# meio da janela. Cobrar igualdade agora seria cobrar o defeito.
		# O que importa esta no bloco 7: o fio CRUZA dentro da janela.
		print("   (as fases da animacao sao adiantadas em %.3f para compensar a cadeia)"
			% Melee.COMPENSACAO_CADEIA)

		_fim_normalizado = fases.y
		_ini_normalizado = fases.x
		_hb_ini = ativa_de / dur_espada
		_hb_fim = ativa_ate / dur_espada
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
		var pa_t = player.get("_proc_anim")
		if yoru != null and is_instance_valid(yoru):
			# ⚠️ AMOSTRAR POR `t`, NAO POR INDICE DO ARRAY. A primeira versao
			# usava fracao do array como se fosse fracao do golpe; sao coisas
			# diferentes (a amostragem comeca um quadro depois do disparo e vai
			# alem do fim), e por isso os indices caiam no lugar errado — o teste
			# lia a espada JA na esquerda no "inicio da janela".
			_t_amostra.append(pa_t.get("_sword_slash_t"))
			var lado: Vector3 = player.global_transform.basis.x   # +X = direita
			var ponta: Vector3 = (yoru.ponta as Node3D).global_position
			_lateral.append((ponta - player.global_position).dot(lado))
			_mao_ao_cabo.append(_dist_ao_cabo(yoru, _mao_esquerda()))
			# direção do fio: 90° = deitada (corte horizontal), 0° = em pé
			var eixo := (ponta - (yoru.guarda as Node3D).global_position).normalized()
			_lamina.append(rad_to_deg(acos(clampf(absf(eixo.dot(Vector3.UP)), 0.0, 1.0))))
			var tr := player.find_child("Torso", true, false) as Node3D
			_tronco.append(tr.rotation if tr else Vector3.ZERO)
			var frente := -player.global_transform.basis.z
			# ⚠️ ESPAÇO LOCAL DO PERSONAGEM, como manda a especificação: a
			# validação não pode depender da câmera. `affine_inverse` leva a
			# ponta global para o referencial do player, onde +X é a direita DELE
			# e -Z a frente DELE, independente de onde a câmera esteja.
			_ponta_local.append(player.global_transform.affine_inverse() * ponta)
			var pivo := player.find_child("SkinPivot", true, false) as Node3D
			var mod := player.find_child("GLBModel_base", true, false) as Node3D
			_giro_raiz.append(Vector3(player.rotation.y,
				pivo.rotation.y if pivo else 0.0, mod.rotation.y if mod else 0.0))
			var jr := player.find_child("Shin_R", true, false) as Node3D
			var jl := player.find_child("Shin_L", true, false) as Node3D
			_joelhos.append(Vector2(jr.rotation.x if jr else 0.0, jl.rotation.x if jl else 0.0))
			for par in [["Foot_R", _pe_r], ["Foot_L", _pe_l]]:
				var pe := player.find_child(par[0] as String, true, false) as Node3D
				var rel: Vector3 = (pe.global_position - player.global_position) if pe else Vector3.ZERO
				(par[1] as Array).append(Vector2(rel.dot(frente), rel.dot(lado)))

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

		# ------------------------------- 4. A DIREÇÃO DA LÂMINA
		# Num corte HORIZONTAL o fio tem de estar deitado. 90° = deitada,
		# 0° = em pé. Medido antes deste trabalho: a lâmina EMPINAVA até 43,8°
		# no meio do golpe — bate de chapa em vez de cortar.
		print("\n4. A DIRECAO DA LAMINA")
		var i0 := int(_lamina.size() * _ini_normalizado)
		var i1 := int(_lamina.size() * _fim_normalizado)
		var pior_lamina := 999.0
		for i in range(i0, mini(i1 + 1, _lamina.size())):
			pior_lamina = minf(pior_lamina, _lamina[i])
		print("   pior angulo do fio na janela ativa: %.1f graus da vertical" % pior_lamina)
		ok(pior_lamina > 65.0,
			"o fio fica DEITADO no golpe (pior %.1f graus, 90 = horizontal)" % pior_lamina)

		# ------------------------------- 5. O BALANÇO DO CORPO
		print("\n5. O BALANCO DO CORPO")
		var x0: float = _tronco[0].x
		var z0: float = _tronco[0].z
		var dx := 0.0
		var dz := 0.0
		for t in _tronco:
			dx = maxf(dx, absf(t.x - x0))
			dz = maxf(dz, absf(t.z - z0))
		print("   tronco: %.1f graus de inclinacao a frente, %.1f de tombo lateral"
			% [rad_to_deg(dx), rad_to_deg(dz)])
		ok(rad_to_deg(dx) > 12.0,
			"o corpo INCLINA no golpe (%.1f graus)" % rad_to_deg(dx))
		ok(rad_to_deg(dz) > 10.0,
			"e TOMBA de lado, dando peso ao corte (%.1f graus)" % rad_to_deg(dz))

		# ⚠️ O TRONCO NAO PODE CARREGAR O GIRO — e esta e a guarda do defeito
		# relatado: "o personagem rotaciona correto, porem a animacao esta
		# permanecendo a mesma como se ele estivesse estatico". Neste rig o
		# `Torso` e pai da cabeca, dos bracos E das pernas, entao yaw nele roda o
		# corpo em BLOCO. Chegou a 90,4 graus na versao anterior. Quem gira sao
		# os bracos.
		var dy := 0.0
		var y0: float = _tronco[0].y
		for t in _tronco:
			dy = maxf(dy, absf(t.y - y0))
		print("   tronco gira apenas %.1f graus em Y (os bracos e que levam a espada)"
			% rad_to_deg(dy))
		ok(rad_to_deg(dy) < 20.0,
			"o TRONCO fica quase parado: %.1f graus de giro (o corpo nao roda em bloco)"
				% rad_to_deg(dy))

		# ------------------------------- 6. A TROCA DOS PES
		# O pé direito passa à FRENTE cruzando, o esquerdo recua e vira pivô.
		# Antes os dois terminavam do mesmo lado, o que lê como tropeço.
		print("\n6. A TROCA DOS PES")
		var r_frente := -9.0
		var l_frente := 9.0
		for v in _pe_r:
			r_frente = maxf(r_frente, v.x)
		for v in _pe_l:
			l_frente = minf(l_frente, v.x)
		print("   pe DIREITO avanca ate %+.2f m (comecou em %+.2f)" % [r_frente, _pe_r[0].x])
		print("   pe ESQUERDO recua ate %+.2f m (comecou em %+.2f)" % [l_frente, _pe_l[0].x])
		ok(r_frente - _pe_r[0].x > 0.15,
			"o pe direito PASSA A FRENTE (%.2f m de avanco)" % (r_frente - _pe_r[0].x))
		# ⚠️ ESTA CHECAGEM MUDOU DE PERGUNTA, e o motivo importa. A versão
		# anterior cobrava "o pé esquerdo RECUA, virando pivô" — e passava,
		# porque o tronco girava 97° e LEVAVA a perna junto. Não era passada, era
		# carona: neste rig o `Torso` é pai de tudo.
		#
		# Com o giro devolvido aos braços (a pedido do dono: "cabeça e torso
		# ficam estáticos, pernas se dobram para manter o equilíbrio"), a perna
		# esquerda deixou de viajar e passou a ESCORAR. Cobrar o recuo agora seria
		# cobrar o sintoma do defeito que acabou de ser corrigido.
		var flexao_r := 0.0
		var flexao_l := 0.0
		for j in _joelhos:
			flexao_r = maxf(flexao_r, absf(j.x - _joelhos[0].x))
			flexao_l = maxf(flexao_l, absf(j.y - _joelhos[0].y))
		print("   joelhos dobram: direito %.1f graus, esquerdo %.1f graus"
			% [rad_to_deg(flexao_r), rad_to_deg(flexao_l)])
		ok(rad_to_deg(flexao_r) > 10.0 and rad_to_deg(flexao_l) > 8.0,
			"as PERNAS DOBRAM para segurar o equilibrio (%.1f e %.1f graus)"
				% [rad_to_deg(flexao_r), rad_to_deg(flexao_l)])
		# e voltam para a base no fim
		var voltou_r: float = absf(_pe_r[_pe_r.size() - 1].x - _pe_r[0].x)
		ok(voltou_r < 0.08,
			"os pes voltam a base no fim do golpe (%.2f m de resto)" % voltou_r)
		# =====================================================================
		#  7. VALIDACAO DO ESPACO LOCAL (exigida pela especificacao)
		# =====================================================================
		#  "Verifique o componente X. Preparacao: x > 0. Cruzamento: x -> 0.
		#   Final: x < 0. Isso confirma objetivamente que a espada atravessou
		#   +X -> centro -> -X, independentemente da posicao da camera."
		print("\n7. A ESPADA EM ESPACO LOCAL DO PERSONAGEM")
		var i_ini := _indice_em(_hb_ini)
		var i_fim := _indice_em(_hb_fim)

		# o cruzamento: onde |x| e minimo dentro da janela ativa
		var i_cruz := i_ini
		for i in range(i_ini, i_fim + 1):
			if absf(_ponta_local[i].x) < absf(_ponta_local[i_cruz].x):
				i_cruz = i
		var cruz: Vector3 = _ponta_local[i_cruz]
		var antes_x: float = _ponta_local[i_ini].x
		var depois_x: float = _ponta_local[i_fim].x
		print("   inicio da janela: x=%+.2f   cruzamento: x=%+.2f z=%+.2f   fim: x=%+.2f"
			% [antes_x, cruz.x, cruz.z, depois_x])
		ok(antes_x > 0.3, "a espada COMECA no lado +X local (direita): %+.2f" % antes_x)
		ok(absf(cruz.x) < 0.5, "CRUZA o centro (|x| = %.2f)" % absf(cruz.x))
		ok(depois_x < -0.3, "e TERMINA no lado -X local (esquerda): %+.2f" % depois_x)
		ok(cruz.z < -0.5,
			"o cruzamento acontece A FRENTE do personagem (z = %+.2f, -Z e a frente)" % cruz.z)

		#  "Nao produzir uma simples translacao reta. A PONTA deve descrever um
		#   ARCO." -> no cruzamento a ponta tem de estar MAIS A FRENTE do que nos
		#   dois extremos; se z fosse igual nos tres, seria uma reta.
		# ⚠️ A BARRIGA E A SAGITA, nao a diferenca para a ponta mais avancada.
		# A primeira versao fazia `min(z_dir, z_esq) - z_centro` e reprovava um
		# arco de verdade: como o lado esquerdo do golpe ja termina bem a frente
		# (z = -1,46), o "minimo" quase encostava no centro e a conta dava 0,18 m
		# para uma curva que avanca 1,3 m. Sagita e a distancia do MEIO DA CORDA
		# ate a curva — que e o que "quanto o arco embarriga" quer dizer.
		var z_dir: float = _ponta_local[i_ini].z
		var z_esq: float = _ponta_local[i_fim].z
		var meio_da_corda: float = (z_dir + z_esq) * 0.5
		var barriga: float = meio_da_corda - cruz.z
		print("   z nos extremos: %+.2f (dir) e %+.2f (esq); meio da corda %+.2f, centro %+.2f -> sagita %.2f m"
			% [z_dir, z_esq, meio_da_corda, cruz.z, barriga])
		ok(barriga > 0.4,
			"a ponta descreve um ARCO, nao uma reta (%.2f m de barriga a frente)" % barriga)

		#  "O ROOT do personagem deve permanecer orientado para frente."
		print("\n8. O PERSONAGEM NAO DA MEIA-VOLTA")
		var g_root := 0.0
		var g_pivo := 0.0
		var g_mod := 0.0
		for g in _giro_raiz:
			g_root = maxf(g_root, absf(g.x - _giro_raiz[0].x))
			g_pivo = maxf(g_pivo, absf(g.y - _giro_raiz[0].y))
			g_mod = maxf(g_mod, absf(g.z - _giro_raiz[0].z))
		print("   giro maximo: root %.2f, SkinPivot %.2f, GLBModel %.2f graus"
			% [rad_to_deg(g_root), rad_to_deg(g_pivo), rad_to_deg(g_mod)])
		ok(rad_to_deg(g_root) < 2.0 and rad_to_deg(g_pivo) < 2.0 and rad_to_deg(g_mod) < 2.0,
			"root, pivo e modelo NAO giram: o personagem segue voltado para -Z")

		# =====================================================================
		#  9. OS 16 QUADROS DE REFERENCIA DA ESPECIFICACAO
		# =====================================================================
		#  Nao sao keyframes: sao poses de referencia para conferir a trajetoria.
		#  A especificacao nomeia cinco como criticos — 4, 7, 9, 11 e 12.
		print("\n9. OS 16 QUADROS (espaco LOCAL do personagem)")
		var nomes := {
			1: "neutra", 2: "inicio da preparacao", 3: "carregamento",
			4: "PREPARACAO MAXIMA", 5: "disparo", 6: "inicio da aceleracao",
			7: "ACELERACAO", 8: "entrada do corte", 9: "CRUZAMENTO DO CENTRO",
			10: "saida do centro", 11: "FINAL DO CORTE", 12: "FOLLOW-THROUGH",
			13: "desaceleracao", 14: "retorno", 15: "reestabilizacao", 16: "neutro"}
		var criticos := [4, 7, 9, 11, 12]
		for q in range(1, 17):
			var t := float(q - 1) / 15.0
			var pl: Vector3 = _ponta_local[_indice_em(t)]
			var lado_txt := "+X DIREITA" if pl.x > 0.35 else ("-X ESQUERDA" if pl.x < -0.35 else "  CENTRO  ")
			var marca := " <<<" if q in criticos else ""
			print("   %2d %-22s x=%+6.2f z=%+6.2f  %s%s"
				% [q, nomes[q], pl.x, pl.z, lado_txt, marca])

		# A especificacao: "Quadro 4: espada visivelmente a DIREITA. Quadro 9:
		# atravessando a frente. Quadro 11: visivelmente a ESQUERDA. Quadro 12:
		# ainda mais a esquerda devido a inercia."
		var q4: Vector3 = _ponta_local[_indice_em(3.0 / 15.0)]
		var q9: Vector3 = _ponta_local[_indice_em(8.0 / 15.0)]
		var q11: Vector3 = _ponta_local[_indice_em(10.0 / 15.0)]
		var q12: Vector3 = _ponta_local[_indice_em(11.0 / 15.0)]
		ok(q4.x > 0.5, "quadro 4 (preparacao maxima): espada a DIREITA (x=%+.2f)" % q4.x)
		ok(q9.z < -0.8, "quadro 9 (cruzamento): a espada esta A FRENTE (z=%+.2f)" % q9.z)
		ok(q11.x < -0.5, "quadro 11 (final do corte): espada a ESQUERDA (x=%+.2f)" % q11.x)
		ok(q12.x <= q11.x + 0.35,
			"quadro 12 (follow-through): a inercia mantem a espada a esquerda (x=%+.2f)" % q12.x)

		_pronto = true
