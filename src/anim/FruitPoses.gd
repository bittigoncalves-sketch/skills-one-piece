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

static func mera_z_charge_pose(add: Callable, off: Dictionary, w: float, progress: float) -> void:
	if w <= 0.001:
		return
	# Linha do tempo normalizada, sincronizada com MeraZChargeNode. A tabela
	# decide a duração (hoje 0,5 s), mas as quatro etapas usam 0..1 e sempre
	# terminam antes do disparo — não há corte de animação ao encurtar a carga.
	# 0.00–0.24 firma a base; 0.24–0.62 puxa os dois revólveres da cintura;
	# 0.62–1.00 abre os braços e termina em uma mira dupla estável.
	var p := clampf(progress, 0.0, 1.0)
	var reach_waist := smoothstep(0.04, 0.28, p)
	var draw := smoothstep(0.24, 0.68, p)
	var aim := smoothstep(0.64, 1.0, p)
	var right_waist := Vector3(-0.48, -0.14, 0.70)
	var left_waist := Vector3(-0.48, 0.14, -0.70)
	var right_aim := Vector3(1.48, 0.0, 0.16)
	var left_aim := Vector3(1.48, 0.0, -0.16)
	var elbow_draw := Vector3(1.10, 0.0, 0.0)
	var elbow_aim := Vector3(0.06, 0.0, 0.0)
	var draw_pose_r := right_waist * reach_waist
	var draw_pose_l := left_waist * reach_waist
	add.call(off, "UpperArm_R", draw_pose_r.lerp(right_aim, draw) * w)
	add.call(off, "UpperArm_L", draw_pose_l.lerp(left_aim, draw) * w)
	add.call(off, "ForeArm_R", elbow_draw.lerp(elbow_aim, aim) * w)
	add.call(off, "ForeArm_L", elbow_draw.lerp(elbow_aim, aim) * w)
	# Leve inclinação para trás enquanto saca; volta ao centro ao travar a mira.
	add.call(off, "Torso", Vector3(-0.12 * (1.0 - aim), 0.0, 0.0) * w)
	add.call(off, "Head", Vector3(0.07 * aim, 0.0, 0.0) * w)

# Mera X — concentração do Hiken: uma leitura de "Pedra" (punho direito
# comprimido no quadril), guarda com a mão oposta e explosão à frente na soltura.
static func mera_x_charge_pose(add: Callable, off: Dictionary, w: float, progress: float) -> void:
	if w <= 0.001:
		return
	# A postura precisa ser legível no primeiro quadro da carga. O restante é a
	# contração gradual até o soco; começar em zero fazia a preparação parecer sem
	# animação quando outro clipe ainda estava terminando.
	var p := lerpf(0.38, 1.0, smoothstep(0.0, 1.0, clampf(progress, 0.0, 1.0)))
	# Punho direito recolhe ao quadril: ombro atrás/para o lado e cotovelo fechado.
	add.call(off, "UpperArm_R", Vector3(-0.70, -0.08, 0.34) * p * w)
	add.call(off, "ForeArm_R", Vector3(1.32, 0.0, 0.0) * p * w)
	# Mão esquerda protege o peito e enquadra a intenção do soco direito.
	add.call(off, "UpperArm_L", Vector3(0.42, 0.0, -0.18) * p * w)
	add.call(off, "ForeArm_L", Vector3(0.82, 0.0, 0.0) * p * w)
	# Base baixa e firme: antecipa força sem parecer uma pose parada genérica.
	add.call(off, "Torso", Vector3(-0.16, 0.10, 0.05) * p * w)
	add.call(off, "Thigh_L", Vector3(0.12, 0.0, -0.10) * p * w)
	add.call(off, "Thigh_R", Vector3(0.12, 0.0, 0.10) * p * w)
	add.call(off, "Head", Vector3(0.08, -0.06, 0.0) * p * w)

# Bomu Z — ombro atrás, punho comprimido e base baixa: a explosão parece sair
# DO soco. Bomu X abre o corpo para conter a explosão antes do avanço.
static func bomu_charge_pose(add: Callable, off: Dictionary, w: float, t: float, slot: String) -> void:
	if w <= 0.001: return
	var pulso := 1.0 + sin(t * 18.0) * 0.06
	if slot == "Z":
		add.call(off, "UpperArm_R", Vector3(-0.76, -0.10, 0.28) * pulso * w)
		add.call(off, "ForeArm_R", Vector3(1.26, 0.0, 0.0) * pulso * w)
		add.call(off, "UpperArm_L", Vector3(0.28, 0.0, -0.18) * w)
		add.call(off, "ForeArm_L", Vector3(0.58, 0.0, 0.0) * w)
	else:
		add.call(off, "UpperArm_R", Vector3(0.12, 0.0, 1.18) * pulso * w)
		add.call(off, "UpperArm_L", Vector3(0.12, 0.0, -1.18) * pulso * w)
		add.call(off, "ForeArm_R", Vector3(0.34, 0.0, 0.0) * w)
		add.call(off, "ForeArm_L", Vector3(0.34, 0.0, 0.0) * w)
	add.call(off, "Torso", Vector3(-0.18, 0.0, 0.0) * w)
	add.call(off, "Thigh_L", Vector3(0.20, 0.0, -0.15) * w)
	add.call(off, "Thigh_R", Vector3(0.20, 0.0, 0.15) * w)

static func bomu_strike_pose(add: Callable, off: Dictionary, w: float, t: float, burst: bool) -> void:
	if w <= 0.001: return
	var impacto := smoothstep(0.04, 0.20, fmod(t, 0.5))
	if burst:
		add.call(off, "UpperArm_R", Vector3(-0.18, 0.0, 1.25) * (1.0 - impacto) * w)
		add.call(off, "UpperArm_L", Vector3(-0.18, 0.0, -1.25) * (1.0 - impacto) * w)
		add.call(off, "Torso", Vector3(-0.38, 0.0, 0.0) * w)
	else:
		add.call(off, "UpperArm_R", Vector3(1.48, 0.0, 0.12) * impacto * w)
		add.call(off, "ForeArm_R", Vector3(0.10, 0.0, 0.0) * w)

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

# ⚠️ AS POSES DE GOLPE DA GURA GURA SAÍRAM DAQUI em 2026-08-15, para
# `src/anim/GuraPoses.gd`. O motivo é o mesmo que criou este arquivo: a Gura é a
# única fruta com animação autoral nos quatro slots e sozinha era maior que as
# seis poses das outras frutas somadas.
#
# O que foi junto: `gura_v_poses` (a ultimate). O que ficou aqui: `gura_rush_pose`
# e `gura_x_charge_pose`, que são poses SUSTENTADAS (o jogador as segura) e têm
# peso próprio no animador — as de lá são golpes com linha do tempo.
#
# Os três estados `gura_v_prep`, `gura_v_squat` e `gura_v_gather` foram apagados
# em vez de migrados: NENHUM efeito jamais os escreveu em `custom_pose` (o
# `GuraVNode` só usa `lift` e `tpose`). Eram código morto desde que nasceram.
