class_name UshiChute
extends RefCounted
## POSES DE CHUTE da Ushi Ushi (X e C) — plano do Codex em `docs/frutas/ushi_ushi/PLANO_ANIMACOES.md`. Funções PURAS: devolvem papel→Vector3 (rad, deslocamento
## sobre o repouso) para a meta `pose_externa` do rig (`ProceduralAnimator`). O modelo da girafa humanoide segue as juntas do rig, então a mesma pose move
## o corpo humano (forma 0) e a girafa humanoide (forma 1, de pernas rígidas: o joelho some sozinho). Convenções do rig (MeleePoses/mink_kick):
##   Thigh.x + = perna para a FRENTE · Shin.x − = joelho dobrado · Torso.x − = tronco à frente · UpperArm.x + = braço à frente.
const G := PI / 180.0
## X — BICUDA LATERAL aérea (0,74 s; PICO e emissão do corte em 0,34 s): a perna sai pelo LADO (abduzida, joelho dobrado) e varre em arco
## horizontal à frente do corpo, com a ponta do pé (a "bicuda"); o tronco gira e se inclina para o lado oposto. Pedido do dono (21/11/2026).
## [t, coxaR_x, joelhoR, coxaL_x, joelhoL, torso_x, bracoR, bracoL, coxaR_z (abdução), torso_giro, torso_lado] em graus.
const X_QUADROS := [
	[0.00, 0.0, -8.0, 0.0, -8.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[0.15, 25.0, -60.0, 25.0, -55.0, -10.0, -25.0, 20.0, 55.0, 12.0, 0.0],      # arma: recolhe a direita com o joelho para fora, peso na esquerda
	[0.30, 70.0, -75.0, 10.0, -20.0, 5.0, -10.0, 10.0, 80.0, 18.0, -12.0],      # impulso: pés deixam o chão, perna alta e aberta de lado
	[0.34, 105.0, 15.0, 20.0, -45.0, 15.0, -35.0, 25.0, 8.0, -22.0, -22.0],     # PICO: perna esticada varreu o arco, corte sai da ponta do pé
	[0.40, 95.0, -5.0, 25.0, -40.0, 5.0, -10.0, 10.0, -8.0, -26.0, -14.0],      # termina o arco, atravessando a frente do corpo
	[0.55, 20.0, -35.0, 20.0, -45.0, -12.0, 0.0, 0.0, 0.0, -8.0, 0.0],          # aterrissa na esquerda, absorve no joelho
	[0.74, 0.0, -8.0, 0.0, -8.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]
const X_PICO := 0.34
const X_SALTO := 0.30                 # m, altura visual no pico
const C_CICLO := 0.14                 # cada chute da rajada
const C_PICO := 0.084                 # instante do pico (e da emissão) dentro de cada ciclo


static func _suave(a: float, b: float, u: float) -> float:
	var k := smoothstep(0.0, 1.0, clampf(u, 0.0, 1.0))
	return lerpf(a, b, k)


## O rig atrasa ~60 ms para executar a pose (peso `_ext_w` + suavização): `ATRASO_DO_RIG` antecipa a linha do tempo para o PICO visível coincidir com a emissão em 0,34 s.
const ATRASO_DO_RIG := 0.06


## Pose do X no tempo `t` desde a tecla (0..0,74).
static func pose_x(t: float) -> Dictionary:
	var q := X_QUADROS
	var i := 0
	while i < q.size() - 2 and t > float(q[i + 1][0]):
		i += 1
	var a: Array = q[i]
	var b: Array = q[i + 1]
	var u := inverse_lerp(float(a[0]), float(b[0]), clampf(t, float(a[0]), float(b[0])))
	var v: Array = []
	for k in range(1, 11):
		v.append(_suave(float(a[k]), float(b[k]), u) * G)
	# v[7]=abdução da coxa D · v[8]=giro do tronco · v[9]=inclinação lateral do tronco (ordem de `_montar`: abdu_r, giro, lado)
	return _montar(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], 0.0)


## Altura visual do salto do X (m) no tempo `t`.
static func salto_x(t: float) -> float:
	return X_SALTO * sin(PI * clampf((t - 0.26) / 0.36, 0.0, 1.0))


## Um chute da rajada (bicuda lateral): `u` = fração do ciclo (0..1), `lado` +1 direita / −1 esquerda, `k` = índice do chute (variação determinística).
static func pose_c(u: float, lado: float, k: int) -> Dictionary:
	var t := u * C_CICLO
	var var_perna := sin(float(k) * 2.1) * 5.0                  # ±5° na altura da perna: quebra a repetição
	var var_tronco := sin(float(k) * 1.3 + 0.7) * 8.0           # ±8° no tronco
	var coxa: float
	var joelho: float
	var abdu: float                                              # abdução (a perna sai pelo lado) — 55° armando, ~20° no pico (arco varrido)
	if t < 0.042:
		var k1 := t / 0.042
		coxa = _suave(10.0, 25.0, k1)
		joelho = _suave(-20.0, -60.0, k1)
		abdu = _suave(15.0, 55.0, k1)
	elif t < C_PICO:
		var k2 := (t - 0.042) / 0.042
		coxa = _suave(25.0, 95.0 + var_perna, k2)
		joelho = _suave(-60.0, 15.0, k2)
		abdu = _suave(55.0, 20.0, k2)
	else:
		var k3 := (t - C_PICO) / (C_CICLO - C_PICO)
		coxa = _suave(95.0 + var_perna, 10.0, k3)
		joelho = _suave(15.0, -20.0, k3)
		abdu = _suave(20.0, 15.0, k3)
	var pico := clampf(1.0 - absf(t - C_PICO) / C_PICO, 0.0, 1.0) if t < 2.0 * C_PICO else 0.0
	var tronco := _suave(0.0, 10.0, pico) + var_tronco * 0.4          # inclina para trás no pico (contrapeso)
	var braco_ativo := -30.0 * pico                                    # o braço do lado do chute recua
	var braco_apoio := 25.0 * pico
	var d := lado > 0.0
	var coxa_a := coxa * G
	var joelho_a := joelho * G
	var joelho_s := -20.0 * G                                           # perna de apoio absorve
	var giro := -lado * 0.38 * pico                                     # o tronco gira junto com a varredura
	var abdu_r := (abdu * G) if d else 0.0
	return _montar(coxa_a if d else 0.0, joelho_a if d else joelho_s, 0.0 if d else coxa_a, joelho_s if d else joelho_a, tronco * G,
		(braco_ativo if d else braco_apoio) * G, (braco_apoio if d else braco_ativo) * G, abdu_r, giro, lado * -0.3 * pico, (abdu * G) if not d else 0.0)


## Monta o dicionário de papéis. `abdu_r`/`abdu_l` = abertura lateral da coxa (rad; direita +, esquerda −), `giro` = torção do tronco, `lado` = inclinação lateral.
static func _montar(coxa_r: float, joelho_r: float, coxa_l: float, joelho_l: float, torso: float, braco_r: float, braco_l: float, abdu_r: float, giro: float, lado: float, abdu_l := 0.0) -> Dictionary:
	return {
		"Thigh_R": Vector3(coxa_r, 0.0, 0.05 + abdu_r), "Shin_R": Vector3(joelho_r, 0.0, 0.0),
		"Thigh_L": Vector3(coxa_l, 0.0, -0.05 - abdu_l), "Shin_L": Vector3(joelho_l, 0.0, 0.0),
		"Torso": Vector3(-torso, giro, lado),
		"UpperArm_R": Vector3(braco_r, 0.0, 0.18), "UpperArm_L": Vector3(braco_l, 0.0, -0.18),
	}
