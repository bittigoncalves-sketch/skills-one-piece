class_name WeaponPoses
extends RefCounted
# ============================================================================
#  POSES DE ARMAS (Weapons)
#
#  Segrega as poses procedurais de armas das poses de Akuma no Mi para manter o 
#  Princípio de Responsabilidade Única (SRP) e evitar que módulos inchem.
# ============================================================================

static func two_handed_sword_idle(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	
	# Tronco levemente rotacionado para alinhar os ombros com a espada à frente
	add.call(off, "Torso", Vector3(0.05, -0.1, 0.0) * w)
	add.call(off, "Head", Vector3(-0.05, 0.1, 0.0) * w)
	
	# Pernas abertas em V (Base Firme de Combate)
	add.call(off, "Thigh_R", Vector3(0.0, 0.4, 0.2) * w)
	add.call(off, "Thigh_L", Vector3(0.0, -0.4, -0.2) * w)
	
	# Braço Direito (mão principal no punho/hilt) estendido à frente, levemente dobrado
	add.call(off, "UpperArm_R", Vector3(0.7, -0.1, 0.1) * w)
	add.call(off, "ForeArm_R", Vector3(0.1, 0.0, 0.0) * w)
	
	# Braço Esquerdo — a SEGUNDA MÃO, no pomo. O comentário sempre disse "alcança
	# o cabo"; medido, ela ficava a **0,875 m** dele, ou seja não alcançava nada.
	#
	# Os valores abaixo saíram de uma BUSCA por cinemática direta (varredura dos
	# ângulos dos dois ossos, medindo a distância da mão ao cabo a cada
	# combinação), não de tentativa e erro: 0,875 m -> 0,366 m, que é o limite
	# geométrico do braço neste rig. E 0,366 m do CENTRO do cabo é justamente
	# onde vai a segunda mão — o cabo da Yoru tem 0,62 m, então a mão cai perto
	# do pomo, que é onde ela deve estar numa espada de duas mãos.
	add.call(off, "UpperArm_L", Vector3(1.14, -0.15, 1.03) * w)
	add.call(off, "ForeArm_L", Vector3(-0.31, -0.60, 0.10) * w)

static func ease_in_cubic(x: float) -> float:
	return x * x * x

static func ease_out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)

static func ease_out_elastic(x: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0
	var c4 = (2.0 * PI) / 3.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0

# ============================================================================
#  AS FASES DA ANIMACAO VEM DO FRAME DATA (2026-09-06)
# ============================================================================
#  Eram 0,20 e 0,26 do ciclo, escritos a mao aqui. A hitbox, por outro lado,
#  nasce em `startup` e vive `ativo` SEGUNDOS, vindos de `Melee.COMBO_SWORD`.
#  Duas descricoes independentes da mesma coisa, e elas nao batiam:
#
#      corte horizontal (0,20/0,09/0,20 = 0,49 s de ciclo)
#        hitbox ATIVA .....: 0,200 -> 0,290 s
#        anim GOLPEIA .....: 0,098 -> 0,127 s
#        a lamina passava 0,102 s ANTES de a hitbox nascer
#
#  Ou seja: o fio varria o alvo, e so seis quadros depois o dano aparecia — com
#  a espada ja no arco de volta. Agora quem manda e o frame data, e os dois
#  concordam por construcao.
#
#  Os padroes abaixo sao os numeros antigos, e valem para quem chamar sem dizer
#  as fases (o `two_handed_sword_idle` e qualquer uso futuro sem tabela).
const GOLPE_INICIO_PADRAO := 0.20
const GOLPE_FIM_PADRAO := 0.26

static func _get_slash_frame(t: float, inicio: float = GOLPE_INICIO_PADRAO,
		fim: float = GOLPE_FIM_PADRAO) -> float:
	var i: float = clampf(inicio, 0.02, 0.95)
	var f: float = clampf(fim, i + 0.02, 0.98)
	if t < i:
		var preparo := clampf(t / i, 0.0, 1.0)
		return lerpf(0.0, -0.4, ease_in_cubic(preparo)) # puxa pra trás
	elif t < f:
		var golpe := clampf((t - i) / (f - i), 0.0, 1.0)
		return lerpf(-0.4, 1.0, ease_out_expo(golpe)) # joga pra frente rápido
	else:
		var recuo := clampf((t - f) / maxf(1.0 - f, 0.01), 0.0, 1.0)
		return lerpf(1.0, 0.0, ease_out_elastic(recuo)) # volta pro repouso com bounce

static func two_handed_sword_slash(add: Callable, off: Dictionary, w: float, t: float,
		type: int, golpe_inicio: float = GOLPE_INICIO_PADRAO,
		golpe_fim: float = GOLPE_FIM_PADRAO) -> void:
	if w <= 0.001:
		return

	# Progresso do golpe usando delays para criar Cadeia Cinética (Chicote)
	# Delays aumentados para enfatizar a "fluidez" (os braços e a arma vêm BEM depois do corpo)
	#
	# ⚠️ O ATRASO DA CADEIA ENCOLHEU de 0,05/0,10 para 0,03/0,06. Ele é medido em
	# tempo NORMALIZADO, então com o ciclo da espada mais longo (0,76 s no
	# horizontal contra 0,49 antes) o atraso antigo empurrava o braço 0,076 s
	# depois do tronco — o fio chegava atrasado à própria janela ativa. A cadeia
	# cinética continua existindo; ela só deixou de comer a janela de acerto.
	var frame_torso := _get_slash_frame(t, golpe_inicio, golpe_fim)
	var frame_upper := _get_slash_frame(clampf(t - 0.03, 0.0, 1.0), golpe_inicio, golpe_fim)
	var frame_fore  := _get_slash_frame(clampf(t - 0.06, 0.0, 1.0), golpe_inicio, golpe_fim)
	
	# Pernas flexionam e abrem mais durante o golpe para criar momento de base
	add.call(off, "Thigh_R", Vector3(0.2, 0.5, 0.3) * absf(frame_torso) * w)
	add.call(off, "Thigh_L", Vector3(0.2, -0.5, -0.3) * absf(frame_torso) * w)

	# Como as duas mãos seguram a mesma espada, o ForeArm_L e UpperArm_L seguem o direito
	match type:
		0: # ================================================================
			#  HORIZONTAL: as DUAS MAOS no cabo, a lamina sai da DIREITA e
			#  varre para a ESQUERDA. Pedido do dono, 2026-09-06.
			# ================================================================
			#  ⚠️ OS BRACOS GIRAVAM PARA LADOS OPOSTOS: o direito tinha Y = -1,0
			#  e o esquerdo Y = +0,5. Como o `frame` multiplica os dois, um ia
			#  para a esquerda enquanto o outro ia para a direita — as maos se
			#  afastavam uma da outra durante o golpe, e o que se via era um
			#  braco conduzindo a espada e o outro abrindo para o lado contrario.
			#  Duas maos no mesmo cabo tem de girar para o MESMO lado.
			#
			#  ⚠️ O SINAL EM Y FOI MEDIDO, E CONTRARIA O QUE OS ROTULOS ANTIGOS
			#  SUGERIAM. Deduzi primeiro pelos nomes ("tipo 0 = direita para
			#  esquerda" usava Y negativo) e sai errado: rastreando a ponta da
			#  lamina no eixo lateral do jogador, o preparo levava a espada para
			#  a ESQUERDA (+1,07 -> -0,11 m) e o golpe a trazia de volta para a
			#  direita. Invertido.
			#
			#  O que a medicao diz: coeficiente Y POSITIVO. O `frame` sai de -0,4
			#  no preparo (produto negativo -> lamina a DIREITA) e vai a +1,0 no
			#  golpe (produto positivo -> lamina a ESQUERDA). Que e exatamente
			#  "a lamina a direita do jogador parte para a esquerda".
			#
			#  O tronco carrega a maior parte do giro (-1,15): num corte de duas
			#  maos quem gira e o CORPO, e os bracos so acompanham. Coeficiente
			#  grande demais nos bracos e o que descolava a pose do cabo.
			#  ⚠️ QUEM GIRA É O TRONCO, E ISSO FOI MEDIDO, NÃO ESCOLHIDO.
			#  A primeira versão pôs o giro no BRAÇO (Torso -1,15 contra
			#  UpperArm_R -1,30) e a mão esquerda soltava do cabo no auge: 0,25 m
			#  no repouso, 0,55 m no golpe. Uma busca por cinemática direta com o
			#  braço direito travado na pose do auge devolveu 0,362 m como o
			#  MELHOR alcançável ali — ou seja, nenhum ângulo do braço esquerdo
			#  resolvia. Com a espada presa ao antebraço direito varrendo forte,
			#  o ombro esquerdo simplesmente não chega.
			#
			#  A saída é anatômica: o TRONCO leva o giro e os dois ombros vão
			#  juntos, que é como se corta com as duas mãos de verdade. O braço
			#  vira acompanhamento, não motor.
			add.call(off, "Torso", Vector3(0.16, 1.70, 0.12) * frame_torso * w)
			add.call(off, "Head", Vector3(-0.10, 0.35, 0.0) * frame_torso * w)
			# Direito CONDUZ (a mao principal, a do `handle`) — mas de leve.
			add.call(off, "UpperArm_R", Vector3(0.75, 0.95, 0.24) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(0.24, 0.22, 0.0) * frame_fore * w)
			# Esquerdo ACOMPANHA no mesmo sentido, com quase a mesma amplitude:
			# e o que mantem a segunda mao no cabo em vez de abrir.
			add.call(off, "UpperArm_L", Vector3(0.17, 1.16, 0.14) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(0.24, -0.80, 0.0) * frame_fore * w)
		1: # Corte Esquerda para Direita
			add.call(off, "Torso", Vector3(0.4, 1.0, -0.2) * frame_torso * w)
			add.call(off, "Head", Vector3(-0.2, 0.5, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(1.4, 1.4, -0.9) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(0.6, 0.0, -0.6) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(1.4, 1.4, 0.3) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(0.6, 0.4, -0.3) * frame_fore * w)
		2: # Corte Vertical (Cima para Baixo)
			add.call(off, "Torso", Vector3(0.8, 0.0, 0.0) * frame_torso * w)
			add.call(off, "Head", Vector3(0.3, 0.0, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(2.4, 0.0, 0.0) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(1.0, 0.0, 0.0) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(2.4, 0.6, 0.5) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(1.0, 0.3, 0.0) * frame_fore * w)

