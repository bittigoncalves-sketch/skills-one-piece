class_name FruitPoses
extends RefCounted
# ============================================================================
#  POSES DE FRUTA — extraidas do ProceduralAnimator em 2026-08-14.
#
#  POR QUE ELAS SAIRAM DE LA: o `ProceduralAnimator.gd` bateu 900 linhas, o teto
#  do projeto (docs/LIMITE_DE_TAMANHO.md). O gatilho ja estava declarado desde a
#  cirurgia de rig: "na proxima pose de fruta que entrar, extrair as poses de
#  fruta". A animacao de recepcao de dano e essa proxima pose.
#
#  POR QUE ESTAS SEIS E NAO OUTRAS: elas sao a parte que CRESCE a cada fruta
#  nova. O nucleo (locomocao, idle, ar, parkour, IK das pernas) e estavel e fica
#  em ~740 linhas. Separar pelo que cresce, e nao pelo que e "opcional", e o que
#  faz a divisao continuar valendo daqui a dez frutas.
#
#  COMO SE COMUNICAM COM O ANIMADOR: recebem o proprio `_add` como Callable.
#  Nao e enfeite — o `_add` carrega duas coisas que estas funcoes NAO PODEM
#  perder: o espelhamento de `is_backwards` e o filtro `_n.has(role)`, que ignora
#  papel que o rig do personagem atual nao tem. Passar o Callable preserva as
#  duas de graca; reimplementar aqui as duplicaria (e duplicar numero/regra e
#  como nasceu o furo de municao infinita, item 14).
#
#  CONVENCAO DE LADO: `_R` e o lado +X (direita anatomica) desde 2026-08-14.
#  Antes disso o `base.scn` estava espelhado — se voce ler codigo antigo que
#  parece trocado, e por isso. Ver item 39 da LISTA_DE_CORRECOES.
# ============================================================================

static func hibashira_pose(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	# Base de combate: pernas bem abertas lateralmente e joelhos flexionados firmes na terra.
	add.call(off, "Thigh_L", Vector3(0.5, 0.0, -0.45) * w)
	add.call(off, "Thigh_R", Vector3(0.5, 0.0, 0.45) * w)
	add.call(off, "Shin_L", Vector3(-0.85, 0.0, 0.0) * w)
	add.call(off, "Shin_R", Vector3(-0.85, 0.0, 0.0) * w)
	add.call(off, "Foot_L", Vector3(0.35, 0.0, 0.2) * w)
	add.call(off, "Foot_R", Vector3(0.35, 0.0, -0.2) * w)
	# Tronco dobrado profundamente para frente em direção ao centro da erupção de chamas.
	add.call(off, "Torso", Vector3(-0.85, 0.25, 0.1) * w)
	# Cabeça erguida com olhar feroz à frente (superando a inclinação do tronco).
	add.call(off, "Head", Vector3(0.65, -0.2, 0.0) * w)
	# Braço Direito socando o chão à frente/centro (punho cravado na erupção).
	add.call(off, "UpperArm_R", Vector3(0.6, 0.0, 0.5) * w)
	add.call(off, "ForeArm_R", Vector3(1.1, 0.0, 0.0) * w)
	# Braço Esquerdo flexionado para trás em equilíbrio dinâmico de chamas.
	add.call(off, "UpperArm_L", Vector3(-1.1, -0.3, -0.35) * w)
	add.call(off, "ForeArm_L", Vector3(0.15, 0.0, 0.0) * w)

static func kurouzu_pose(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	add.call(off, "UpperArm_R", Vector3(1.55, 0.0, 0.2) * w)
	add.call(off, "ForeArm_R", Vector3(0.05, 0.0, 0.0) * w)
	add.call(off, "Torso", Vector3(-0.15, -0.25, 0.0) * w)
	add.call(off, "Thigh_L", Vector3(-0.25, 0.0, -0.2) * w)
	add.call(off, "Thigh_R", Vector3(0.35, 0.0, 0.2) * w)
	add.call(off, "Shin_L", Vector3(-0.4, 0.0, 0.0) * w)

static func black_hole_pose(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	add.call(off, "Thigh_L", Vector3(0.4, 0.0, -0.45) * w)
	add.call(off, "Thigh_R", Vector3(0.4, 0.0, 0.45) * w)
	add.call(off, "Shin_L", Vector3(-0.65, 0.0, 0.0) * w)
	add.call(off, "Shin_R", Vector3(-0.65, 0.0, 0.0) * w)
	add.call(off, "Torso", Vector3(-0.6, 0.3, 0.1) * w)
	add.call(off, "Head", Vector3(0.45, -0.25, 0.0) * w)
	add.call(off, "UpperArm_R", Vector3(0.4, 0.0, 0.4) * w)
	add.call(off, "ForeArm_R", Vector3(0.2, 0.0, 0.0) * w)
	add.call(off, "UpperArm_L", Vector3(-0.9, -0.2, -0.4) * w)

static func gura_rush_pose(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001: return

	# Tronco à FRENTE (x NEGATIVO é frente — x positivo joga o topo p/ trás, e a
	# versão anterior usava +0,3, ou seja, corria de costas para o próprio avanço).
	# Sem torção no Y: torcer o tronco tiraria o braço do perfil lateral limpo,
	# que é justamente o que o T tem de leitura.
	add.call(off, "Torso", Vector3(-0.15, 0.0, 0.0) * w)

	# BRAÇO DIREITO ABERTO PARA O LADO (metade do T). O braço ESQUERDO não recebe
	# nada aqui — é o que separa esta pose do `gura_v_tpose`, que abre os dois.
	add.call(off, "UpperArm_R", Vector3(0.0, 0.0, 1.4) * w)
	add.call(off, "ForeArm_R", Vector3(-0.1, 0.0, 0.0) * w)

	# Cabeça compensa a inclinação do tronco, para o olhar seguir no alvo em vez
	# de acompanhar o peito para baixo.
	add.call(off, "Head", Vector3(0.18, 0.0, 0.0) * w)

static func gura_x_charge_pose(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001: return
	# Braço direito estendido diretamente na direção da mira para capturar o alvo,
	# X = 1.5 aponta perfeitamente para frente (-Z).
	var vib_y = sin(t * 30.0) * 0.02
	var vib_z = cos(t * 35.0) * 0.02
	add.call(off, "UpperArm_R", Vector3(1.5 + vib_y, -vib_y, -(0.1 + vib_z)) * w)
	add.call(off, "ForeArm_R", Vector3(-0.1 + vib_y, 0.0, 0.0) * w)
	add.call(off, "Torso", Vector3(0.1, 0.0, 0.0) * w)
	add.call(off, "Head", Vector3(0.1, 0.0, 0.0) * w)

static func gura_v_poses(add: Callable, off: Dictionary, w: float, t: float, state: String) -> void:
	if w <= 0.001: return
	
	if state == "gura_v_prep":
		# Preparação (0.0s): Postura firme, respira fundo
		var resp = sin(t * 3.0) * 0.05
		add.call(off, "Torso", Vector3(0.1 - resp, 0, 0) * w)
		add.call(off, "Head", Vector3(-0.1 + resp, 0, 0) * w)
		add.call(off, "UpperArm_L", Vector3(0.2, 0.0, -0.1) * w)
		add.call(off, "UpperArm_R", Vector3(0.2, 0.0, 0.1) * w)
		
	elif state == "gura_v_squat":
		# Agachamento (1.0s): Flexiona joelhos, braços pra trás
		add.call(off, "Thigh_L", Vector3(0.8, -0.1, 0) * w)
		add.call(off, "Thigh_R", Vector3(0.8, 0.1, 0) * w)
		add.call(off, "Shin_L", Vector3(-1.0, 0, 0) * w)
		add.call(off, "Shin_R", Vector3(-1.0, 0, 0) * w)
		add.call(off, "Torso", Vector3(0.3, 0, 0) * w)
		add.call(off, "UpperArm_L", Vector3(-1.2, 0.0, -0.2) * w)
		add.call(off, "UpperArm_R", Vector3(-1.2, 0.0, 0.2) * w)
		
	elif state == "gura_v_gather":
		# Reúne energia (2.0s): Agachado vibrando fortemente
		var vib = sin(t * 45.0) * 0.03
		add.call(off, "Thigh_L", Vector3(0.9, -0.1, 0) * w)
		add.call(off, "Thigh_R", Vector3(0.9, 0.1, 0) * w)
		add.call(off, "Shin_L", Vector3(-1.1, 0, 0) * w)
		add.call(off, "Shin_R", Vector3(-1.1, 0, 0) * w)
		add.call(off, "Torso", Vector3(0.4 + vib, 0, 0) * w)
		add.call(off, "UpperArm_L", Vector3(-1.3, 0.0, -0.3 - vib) * w)
		add.call(off, "UpperArm_R", Vector3(-1.3, 0.0, 0.3 + vib) * w)
		add.call(off, "ForeArm_L", Vector3(0.5, 0, 0) * w)
		add.call(off, "ForeArm_R", Vector3(0.5, 0, 0) * w)
		
	elif state == "gura_v_lift":
		# Levanta os braços (3.0s): Braços sobem lentamente
		var vib = sin(t * 30.0) * 0.02
		add.call(off, "Torso", Vector3(0.0, 0, 0) * w)
		add.call(off, "UpperArm_L", Vector3(0.0, -0.2, -0.8 - vib) * w)
		add.call(off, "UpperArm_R", Vector3(0.0, 0.2, 0.8 + vib) * w)
		
	elif state == "gura_v_tpose":
		# Pose em T (4.0s): Braços totalmente horizontais, vibração máxima
		var vib = sin(t * 50.0) * 0.05
		add.call(off, "Torso", Vector3(-0.1, 0, 0) * w)
		add.call(off, "Head", Vector3(0.1, 0, 0) * w)
		add.call(off, "UpperArm_L", Vector3(0.0, 0.0, -1.4 - vib) * w)
		add.call(off, "UpperArm_R", Vector3(0.0, 0.0, 1.4 + vib) * w)
		add.call(off, "ForeArm_L", Vector3(-0.1, 0, 0) * w)
		add.call(off, "ForeArm_R", Vector3(-0.1, 0, 0) * w)
