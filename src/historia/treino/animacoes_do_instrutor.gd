class_name AnimacoesDoInstrutor
extends RefCounted
# ============================================================================
#  ANIMAÇÕES DO INSTRUTOR (21/11/2026) — o instrutor deixa de ser uma estátua apontando: função PURA `pose(t, falando)` devolve as rotações (rad) por osso que o
#  `NpcDaIlha` põe a cada quadro na meta `pose_de_skill` (o `ProceduralAnimator` as SOMA ao idle). Sem estado: o mesmo `t` dá a mesma pose (testável).
#
#  Ciclo de 14 s: guarda saltitante → combo no ar (jab E, jab D, direto D) → guarda → aponta para o boneco → guarda → ensaia o gancho.
#  Falando (conversa/fala): vira o "explicar" — mão direita aberta gesticulando e a cabeça acenando — e volta ao ciclo ao terminar.
#  GATILHO: se outro NPC precisar de ciclo próprio, extrair `Ciclo` (lista de {inicio, fim, pose}) para um recurso; com 1 usuário o código fica aqui.
# ============================================================================
const PERIODO := 14.0
const SUAVE := 0.18            # segundos de mistura entre dois trechos

const GUARDA := {
	"UpperArm_R": Vector3(42, -6, -16), "ForeArm_R": Vector3(108, 0, 0),
	"UpperArm_L": Vector3(36, 0, 20), "ForeArm_L": Vector3(105, 0, 0),
	"Thigh_R": Vector3(-16, 0, 11), "Thigh_L": Vector3(14, 0, -11), "Shin_R": Vector3(24, 0, 0), "Shin_L": Vector3(14, 0, 0),
	"Torso": Vector3(0, 16, 0), "Head": Vector3(0, -16, 0),
}
const JAB_E := {"UpperArm_L": Vector3(88, 0, 4), "ForeArm_L": Vector3(4, 0, 0), "Torso": Vector3(0, -6, 0), "Head": Vector3(0, 4, 0)}
const JAB_D := {"UpperArm_R": Vector3(90, 6, 0), "ForeArm_R": Vector3(2, 0, 0), "Torso": Vector3(0, 30, 0), "Head": Vector3(0, -28, 0), "Thigh_R": Vector3(-8, 0, 11)}
const GANCHO := {"UpperArm_R": Vector3(50, 0, -30), "ForeArm_R": Vector3(70, 0, 0), "Torso": Vector3(0, 34, 6), "Thigh_L": Vector3(24, 0, -11), "Shin_L": Vector3(30, 0, 0)}
const EXPLICAR := {
	"UpperArm_R": Vector3(58, -14, 6), "ForeArm_R": Vector3(70, 0, 0),
	"UpperArm_L": Vector3(8, 0, 10), "ForeArm_L": Vector3(20, 0, 0),
	"Thigh_R": Vector3(-4, 0, 6), "Thigh_L": Vector3(4, 0, -6), "Torso": Vector3(0, 4, 0), "Head": Vector3(0, -4, 0),
}


## Pose do instante `t` (s): `{osso: Vector3 em rad}`. `apontar` = a pose antiga (braço D esticado para o boneco) em GRAUS, vinda do `VisualDoInstrutor`.
static func pose(t: float, falando: bool, apontar: Dictionary = {}) -> Dictionary:
	var graus := _graus(t, falando, apontar)
	var saida := {}
	for osso: String in graus:
		saida[osso] = (graus[osso] as Vector3) * PI / 180.0
	return saida


static func _graus(t: float, falando: bool, apontar: Dictionary) -> Dictionary:
	var c := fposmod(t, PERIODO)
	var base := _guarda_saltitante(t)
	var corpo := base
	if falando:
		return _mistura(base, _explicar(t), 1.0)
	# Combo (5,0–6,9 s): jab E, jab D, direto D (um soco a cada ~0,55 s, estendendo e voltando).
	var s1 := _soco(c - 5.0, 0.55)
	if s1.x > 0.0:
		corpo = _mistura(corpo, JAB_E, s1.x)
	var s2 := _soco(c - 5.6, 0.55)
	if s2.x > 0.0:
		corpo = _mistura(corpo, JAB_D, s2.x)
	var s3 := _soco(c - 6.2, 0.6)
	if s3.x > 0.0:
		corpo = _mistura(corpo, JAB_D, s3.x)
	# Aponta para o boneco (8,0–10,6 s), se houver a pose.
	if not apontar.is_empty():
		corpo = _mistura(corpo, apontar, _janela(c, 8.0, 10.6))
	# Ensaia o gancho (11,6–12,8 s).
	corpo = _mistura(corpo, GANCHO, _janela(c, 11.6, 12.8))
	return corpo


static func _ciclos(n: int) -> float:
	return float(n) / PERIODO


## Saltito da guarda: joelhos e tronco acompanham um pulso de 1,8 Hz; a cabeça fica estável.
static func _guarda_saltitante(t: float) -> Dictionary:
	var p := sin(t * TAU * _ciclos(25))      # frequências = nº inteiro de voltas por período: o ciclo de 14 s fecha sem salto
	var g := GUARDA.duplicate()
	g["Thigh_R"] = (g["Thigh_R"] as Vector3) + Vector3(3.0 * p, 0, 0)
	g["Thigh_L"] = (g["Thigh_L"] as Vector3) - Vector3(3.0 * p, 0, 0)
	g["Shin_R"] = (g["Shin_R"] as Vector3) + Vector3(4.0 * p, 0, 0)
	g["Shin_L"] = (g["Shin_L"] as Vector3) - Vector3(4.0 * p, 0, 0)
	g["Torso"] = (g["Torso"] as Vector3) + Vector3(2.0 * p, 2.0 * sin(t * TAU * _ciclos(13)), 0)
	g["UpperArm_R"] = (g["UpperArm_R"] as Vector3) + Vector3(0, 0, 2.5 * p)
	return g


static func _explicar(t: float) -> Dictionary:
	var e := EXPLICAR.duplicate()
	var g := sin(t * TAU * _ciclos(10))           # gesto lento da mão
	e["UpperArm_R"] = (e["UpperArm_R"] as Vector3) + Vector3(10.0 * g, 6.0 * g, 0)
	e["ForeArm_R"] = (e["ForeArm_R"] as Vector3) + Vector3(14.0 * g, 0, 0)
	e["Head"] = (e["Head"] as Vector3) + Vector3(5.0 * sin(t * TAU * _ciclos(15)), 0, 0)      # aceno
	return e


## (extensão 0–1, _) de um soco que começa em `x = 0` e dura `d`: sobe rápido (35%) e volta (65%). Fora da janela → (−1, 0).
static func _soco(x: float, d: float) -> Vector2:
	if x < 0.0 or x > d:
		return Vector2(-1.0, 0.0)
	var f := x / d
	return Vector2(smoothstep(0.0, 0.35, f) if f < 0.35 else 1.0 - smoothstep(0.35, 1.0, f), 0.0)


## 0→1→0 com bordas suaves de `SUAVE` s nos limites da janela [a, b].
static func _janela(c: float, a: float, b: float) -> float:
	return smoothstep(a, a + SUAVE * 4.0, c) * (1.0 - smoothstep(b - SUAVE * 4.0, b, c))


## Para cada osso: valor de `a` levado em direção ao de `b` por `w` (osso só em `b` parte do zero; só em `a` fica como está).
static func _mistura(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var r := a.duplicate()
	for osso: String in b:
		var va: Vector3 = a.get(osso, Vector3.ZERO)
		r[osso] = va.lerp(b[osso] as Vector3, w)
	return r
