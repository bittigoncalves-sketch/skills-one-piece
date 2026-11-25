extends RefCounted
## Coreografia autoral da Gomu Gomu no Mi, Gear 2 e Gear 3.
## Define rotações angulares em graus para os 13 nós do rig procedural.
## Interpolado suavemente por fase (0.0 a 1.0) independente de FPS.

const PISTOL := "gomu_pistol"
const BAZOOKA := "gomu_bazooka"
const GATLING := "gomu_gatling"
const GEAR2_PUMP := "gomu_gear2_pump"
const JET_PISTOL := "gomu_jet_pistol"
const JET_BAZOOKA := "gomu_jet_bazooka"
const GEAR3 := "gomu_gear3"

const DURATIONS := {
	PISTOL: 0.65,
	BAZOOKA: 0.85,
	GATLING: 1.65,
	GEAR2_PUMP: 0.95,
	JET_PISTOL: 0.45,
	JET_BAZOOKA: 0.60,
	GEAR3: 1.55,
}

const ROLES := [
	"Torso", "Neck", "Head",
	"UpperArm_R", "ForeArm_R",
	"UpperArm_L", "ForeArm_L",
	"Thigh_R", "Shin_R", "Foot_R",
	"Thigh_L", "Shin_L", "Foot_L"
]

# Postura neutra de combate elástico
const READY := [
	Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(0, 0, 0),
	Vector3(15, 0, 10), Vector3(25, 0, 5),
	Vector3(15, 0, -10), Vector3(25, 0, -5),
	Vector3(5, 0, 5), Vector3(-10, 0, 0), Vector3(5, 0, -5),
	Vector3(5, 0, -5), Vector3(-10, 0, 0), Vector3(5, 0, 5)
]

# --- PISTOL: Puxada para trás do braço direito, mira com a esquerda, snap frontal ---
const PISTOL_PREP := [
	Vector3(4, 28, 2), Vector3(-1, -10, 0), Vector3(-3, -18, 0),
	Vector3(-45, 15, 20), Vector3(30, 0, 10),
	Vector3(75, 5, -12), Vector3(15, 0, -5),
	Vector3(12, 10, 8), Vector3(-18, 0, 0), Vector3(8, 0, -4),
	Vector3(-6, -8, -12), Vector3(-12, 0, 0), Vector3(8, 0, 4)
]
const PISTOL_RELEASE := [
	Vector3(-8, -18, -2), Vector3(2, 6, 0), Vector3(4, 12, 0),
	Vector3(88, -8, 8), Vector3(8, 0, 4),
	Vector3(-25, 10, -18), Vector3(45, 0, -10),
	Vector3(18, -10, 10), Vector3(-25, 0, 0), Vector3(12, 0, -6),
	Vector3(2, 6, -14), Vector3(-16, 0, 0), Vector3(10, 0, 5)
]
const PISTOL_SETTLE := [
	Vector3(-2, -5, 0), Vector3(1, 2, 0), Vector3(1, 3, 0),
	Vector3(45, -4, 10), Vector3(20, 0, 5),
	Vector3(10, 5, -10), Vector3(30, 0, -5),
	Vector3(10, -4, 8), Vector3(-15, 0, 0), Vector3(8, 0, -4),
	Vector3(4, 4, -10), Vector3(-12, 0, 0), Vector3(7, 0, 4)
]

# --- BAZOOKA: Ambos os braços recuam em arco, arremesso explosivo com duas palmas ---
const BAZOOKA_PREP := [
	Vector3(-12, 0, 0), Vector3(4, 0, 0), Vector3(6, 0, 0),
	Vector3(-65, 12, 28), Vector3(25, 0, 12),
	Vector3(-65, -12, -28), Vector3(25, 0, -12),
	Vector3(22, 0, 12), Vector3(-35, 0, 0), Vector3(16, 0, -6),
	Vector3(22, 0, -12), Vector3(-35, 0, 0), Vector3(16, 0, 6)
]
const BAZOOKA_THRUST := [
	Vector3(16, 0, 0), Vector3(-4, 0, 0), Vector3(-8, 0, 0),
	Vector3(92, -4, 12), Vector3(6, 0, 4),
	Vector3(92, 4, -12), Vector3(6, 0, -4),
	Vector3(-8, 0, 14), Vector3(-15, 0, 0), Vector3(10, 0, -5),
	Vector3(-8, 0, -14), Vector3(-15, 0, 0), Vector3(10, 0, 5)
]
const BAZOOKA_SETTLE := [
	Vector3(2, 0, 0), Vector3(0, 0, 0), Vector3(-1, 0, 0),
	Vector3(50, -2, 10), Vector3(18, 0, 5),
	Vector3(50, 2, -10), Vector3(18, 0, -5),
	Vector3(8, 0, 8), Vector3(-14, 0, 0), Vector3(7, 0, -4),
	Vector3(8, 0, -8), Vector3(-14, 0, 0), Vector3(7, 0, 4)
]

# --- GATLING: Onda contínua de tronco com alternância dos ombros ---
const GATLING_R_FWD := [
	Vector3(-4, -16, -1), Vector3(1, 6, 0), Vector3(2, 10, 0),
	Vector3(86, -6, 12), Vector3(10, 0, 4),
	Vector3(-30, 8, -16), Vector3(55, 0, -10),
	Vector3(14, -8, 12), Vector3(-22, 0, 0), Vector3(10, 0, -5),
	Vector3(4, 6, -12), Vector3(-14, 0, 0), Vector3(8, 0, 4)
]
const GATLING_L_FWD := [
	Vector3(-4, 16, 1), Vector3(1, -6, 0), Vector3(2, -10, 0),
	Vector3(-30, -8, 16), Vector3(55, 0, 10),
	Vector3(86, 6, -12), Vector3(10, 0, -4),
	Vector3(4, -6, 12), Vector3(-14, 0, 0), Vector3(8, 0, -4),
	Vector3(14, 8, -12), Vector3(-22, 0, 0), Vector3(10, 0, 5)
]

# --- GEAR 2 PUMP: Pose clássica agachada com punho no solo ---
const GEAR2_CROUCH := [
	Vector3(-28, 8, 0), Vector3(8, 0, 0), Vector3(14, -6, 0),
	Vector3(38, 10, 24), Vector3(75, 12, 10),   # braço direito estendido ao chão
	Vector3(45, -12, -32), Vector3(65, 0, -15),  # braço esquerdo apoiado na coxa
	Vector3(68, 6, 18), Vector3(-88, 0, 0), Vector3(36, 0, -8),
	Vector3(62, -8, -18), Vector3(-82, 0, 0), Vector3(32, 0, 8)
]

# --- JET PISTOL: Disparo instantâneo com rastro supersônico ---
const JET_SNAP := [
	Vector3(-10, -24, -3), Vector3(3, 8, 0), Vector3(5, 16, 0),
	Vector3(95, -12, 6), Vector3(4, 0, 2),
	Vector3(-40, 15, -20), Vector3(65, 0, -12),
	Vector3(22, -12, 14), Vector3(-32, 0, 0), Vector3(15, 0, -6),
	Vector3(4, 8, -16), Vector3(-18, 0, 0), Vector3(11, 0, 6)
]

# --- GEAR 3: Soco Gigante (Hone Fuusen -> Peso Colossal -> Arremesso) ---
# 1. Morder polegar / inflar
const GEAR3_BITE := [
	Vector3(-16, 14, 0), Vector3(6, -8, 0), Vector3(12, -14, 0),
	Vector3(95, 24, 38), Vector3(108, 0, 15), # mão direita na boca
	Vector3(25, -10, -20), Vector3(35, 0, -10),
	Vector3(26, 0, 12), Vector3(-38, 0, 0), Vector3(16, 0, -6),
	Vector3(18, 0, -12), Vector3(-30, 0, 0), Vector3(14, 0, 6)
]
# 2. Inércia do braço gigante (corpo inclinado pelo peso colossal)
const GEAR3_HEAVY := [
	Vector3(-22, 28, 4), Vector3(5, -12, -1), Vector3(8, -20, -2),
	Vector3(-55, 18, 25), Vector3(45, 0, 12), # braço carregando massa
	Vector3(45, -15, -35), Vector3(25, 0, -8),
	Vector3(34, 12, 18), Vector3(-48, 0, 0), Vector3(22, 0, -8),
	Vector3(8, -10, -20), Vector3(-20, 0, 0), Vector3(12, 0, 6)
]
# 3. Disparo monumental do Gigant Pistol
const GEAR3_SMASH := [
	Vector3(18, -22, -4), Vector3(-4, 8, 1), Vector3(-8, 15, 2),
	Vector3(92, -10, 12), Vector3(8, 0, 4), # braço gigante lançado à frente
	Vector3(-45, 16, -26), Vector3(48, 0, -10),
	Vector3(-12, -10, 16), Vector3(-20, 0, 0), Vector3(12, 0, -5),
	Vector3(24, 12, -18), Vector3(-42, 0, 0), Vector3(18, 0, 6)
]

static func e_golpe(state: String) -> bool:
	return DURATIONS.has(state)

static func golpe(add: Callable, off: Dictionary, weight: float, time: float,
		phase: float, state: String) -> void:
	if weight <= 0.001 or not e_golpe(state):
		return
	var pose := sample(state, phase)
	for role in pose:
		add.call(off, role, pose[role] * weight)
	# Leve pulsação elástica
	var bounce := sin(time * 6.0) * 0.012 * weight
	add.call(off, "Torso", Vector3(bounce, 0, 0))

static func sample(state: String, phase: float) -> Dictionary:
	var frames: Array = []
	var times: Array = []
	match state:
		PISTOL:
			frames = [READY, PISTOL_PREP, PISTOL_RELEASE, PISTOL_SETTLE, READY]
			times = [0.0, 0.18, 0.35, 0.52, 0.65]
		BAZOOKA:
			frames = [READY, BAZOOKA_PREP, BAZOOKA_THRUST, BAZOOKA_SETTLE, READY]
			times = [0.0, 0.28, 0.48, 0.70, 0.85]
		GATLING:
			# Loop de socos alternados dentro da barragem
			frames = [READY, GATLING_R_FWD, GATLING_L_FWD, GATLING_R_FWD, GATLING_L_FWD, GATLING_R_FWD, GATLING_L_FWD, READY]
			times = [0.0, 0.22, 0.45, 0.70, 0.95, 1.20, 1.45, 1.65]
		GEAR2_PUMP:
			frames = [READY, GEAR2_CROUCH, GEAR2_CROUCH, READY]
			times = [0.0, 0.22, 0.72, 0.95]
		JET_PISTOL:
			frames = [READY, JET_SNAP, PISTOL_SETTLE, READY]
			times = [0.0, 0.12, 0.32, 0.45]
		JET_BAZOOKA:
			frames = [READY, BAZOOKA_PREP, BAZOOKA_THRUST, READY]
			times = [0.0, 0.18, 0.42, 0.60]
		GEAR3:
			frames = [READY, GEAR3_BITE, GEAR3_HEAVY, GEAR3_SMASH, GEAR3_SMASH, READY]
			times = [0.0, 0.35, 0.72, 1.05, 1.30, 1.55]
		_:
			return {}

	var p := clampf(phase, 0.0, 1.0)
	var max_time: float = times[times.size() - 1]
	var current_t := p * max_time

	var idx := 0
	while idx < times.size() - 2 and times[idx + 1] < current_t:
		idx += 1

	var t0: float = times[idx]
	var t1: float = times[idx + 1]
	var span: float = maxf(t1 - t0, 0.0001)
	var frac: float = clampf((current_t - t0) / span, 0.0, 1.0)
	var smooth_frac := frac * frac * (3.0 - 2.0 * frac) # smoothstep

	var f0: Array = frames[idx]
	var f1: Array = frames[idx + 1]
	var out: Dictionary = {}
	for i in range(mini(ROLES.size(), mini(f0.size(), f1.size()))):
		out[ROLES[i]] = (f0[i] as Vector3).lerp(f1[i] as Vector3, smooth_frac)
	return out
