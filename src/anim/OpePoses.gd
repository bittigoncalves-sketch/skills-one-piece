extends RefCounted
## Coreografia autoral do cirurgião: gesto deliberado, ação precisa, assentamento.
## Tempo em segundos recebido do cast; não depende do FPS ou de clipes de outra fruta.
## O rig tem 13 papéis sem dedos: pronação é expressa pelo antebraço inteiro.

const ROOM := "ope_room"
const SHAMBLES := "ope_shambles"
const TAKT := "ope_takt"
const GAMMA := "ope_gamma"
const DURATIONS := {ROOM: 0.85, SHAMBLES: 0.65, TAKT: 1.65, GAMMA: 0.95}
const ROLES := ["Torso", "Neck", "Head", "UpperArm_R", "ForeArm_R",
	"UpperArm_L", "ForeArm_L", "Thigh_R", "Shin_R", "Foot_R",
	"Thigh_L", "Shin_L", "Foot_L"]

# Quadros em graus. Cada pose escreve o corpo inteiro: apoio, contrapeso,
# cabeça estabilizada e os dois braços têm intenção própria.
const READY := [Vector3(-2,-5,0),Vector3(1,0,0),Vector3(1,5,0),
	Vector3(12,0,10),Vector3(22,0,4),Vector3(10,0,-14),Vector3(30,0,-6),
	Vector3(5,3,9),Vector3(-12,0,0),Vector3(8,0,-3),
	Vector3(-3,-4,-10),Vector3(-8,0,0),Vector3(6,0,3)]
const ROOM_PREP := [Vector3(5,-15,-4),Vector3(-2,0,1),Vector3(-3,14,3),
	Vector3(58,-18,28),Vector3(69,-15,8),Vector3(15,8,-24),Vector3(48,0,-12),
	Vector3(12,6,13),Vector3(-24,0,0),Vector3(10,0,-4),
	Vector3(-4,-8,-16),Vector3(-15,0,0),Vector3(11,0,5)]
const ROOM_PRESS := [Vector3(-9,10,3),Vector3(3,0,-1),Vector3(5,-10,-2),
	Vector3(49,-8,27),Vector3(13,80,-9),Vector3(33,-8,-31),Vector3(40,0,-18),
	Vector3(22,-6,16),Vector3(-30,0,0),Vector3(15,0,-7),
	Vector3(4,7,-18),Vector3(-20,0,0),Vector3(13,0,6)]
const ROOM_SETTLE := [Vector3(-5,6,1),Vector3(1,0,0),Vector3(4,-6,-1),
	Vector3(39,-6,24),Vector3(18,72,-8),Vector3(20,-4,-25),Vector3(35,0,-12),
	Vector3(16,-4,14),Vector3(-23,0,0),Vector3(12,0,-6),
	Vector3(2,5,-16),Vector3(-17,0,0),Vector3(11,0,5)]
const SWAP_PREP := [Vector3(3,-22,-4),Vector3(-1,0,1),Vector3(-1,21,3),
	Vector3(38,-30,33),Vector3(101,22,10),Vector3(19,16,-29),Vector3(65,0,-10),
	Vector3(12,8,13),Vector3(-20,0,0),Vector3(10,0,-4),
	Vector3(-11,-8,-15),Vector3(-13,0,0),Vector3(9,0,5)]
const SWAP_CROSS := [Vector3(-5,20,3),Vector3(2,0,-1),Vector3(3,-20,-2),
	Vector3(82,31,16),Vector3(22,62,-18),Vector3(47,-24,-38),Vector3(42,0,-12),
	Vector3(23,-11,17),Vector3(-30,0,0),Vector3(15,0,-6),
	Vector3(4,8,-17),Vector3(-15,0,0),Vector3(10,0,5)]
const SWAP_FOLLOW := [Vector3(-3,11,1),Vector3(1,0,0),Vector3(2,-12,-1),
	Vector3(63,20,20),Vector3(37,48,-8),Vector3(29,-11,-26),Vector3(54,0,-9),
	Vector3(13,-5,13),Vector3(-20,0,0),Vector3(11,0,-4),
	Vector3(-2,4,-13),Vector3(-11,0,0),Vector3(8,0,4)]
const TAKT_LOW := [Vector3(-9,-15,-3),Vector3(3,0,0),Vector3(5,13,2),
	Vector3(28,-19,36),Vector3(30,78,-14),Vector3(30,18,-35),Vector3(38,-35,-12),
	Vector3(21,9,18),Vector3(-32,0,0),Vector3(18,0,-7),
	Vector3(12,-10,-20),Vector3(-29,0,0),Vector3(19,0,7)]
const TAKT_LIFT := [Vector3(8,-12,-3),Vector3(-3,0,1),Vector3(-6,12,2),
	Vector3(137,-10,30),Vector3(32,25,12),Vector3(64,15,-35),Vector3(64,-34,-10),
	Vector3(4,6,15),Vector3(-15,0,0),Vector3(7,0,-5),
	Vector3(-8,-8,-17),Vector3(-10,0,0),Vector3(6,0,6)]
const TAKT_SEND := [Vector3(-7,14,2),Vector3(2,0,-1),Vector3(4,-14,-1),
	Vector3(80,6,20),Vector3(13,66,-8),Vector3(41,-14,-36),Vector3(55,-15,-15),
	Vector3(24,-6,16),Vector3(-29,0,0),Vector3(15,0,-6),
	Vector3(3,6,-18),Vector3(-16,0,0),Vector3(11,0,6)]
const GAMMA_COIL := [Vector3(9,-30,-6),Vector3(-3,0,1),Vector3(-6,27,4),
	Vector3(-28,-24,33),Vector3(88,-28,8),Vector3(66,17,-26),Vector3(77,14,-13),
	Vector3(1,9,15),Vector3(-30,0,0),Vector3(21,0,-5),
	Vector3(31,-11,-16),Vector3(-42,0,0),Vector3(23,0,6)]
const GAMMA_THRUST := [Vector3(-17,24,5),Vector3(5,0,-1),Vector3(11,-23,-4),
	Vector3(105,10,10),Vector3(6,9,0),Vector3(-15,-22,-31),Vector3(56,-5,-14),
	Vector3(51,-10,15),Vector3(-52,0,0),Vector3(20,0,-6),
	Vector3(-17,9,-15),Vector3(-12,0,0),Vector3(19,0,5)]
const GAMMA_FOLLOW := [Vector3(-10,14,2),Vector3(3,0,-1),Vector3(6,-14,-1),
	Vector3(86,4,17),Vector3(27,6,4),Vector3(3,-13,-23),Vector3(41,0,-9),
	Vector3(32,-5,13),Vector3(-34,0,0),Vector3(15,0,-5),
	Vector3(-8,5,-14),Vector3(-10,0,0),Vector3(12,0,5)]


static func e_golpe(state: String) -> bool:
	return DURATIONS.has(state)


static func golpe(add: Callable, off: Dictionary, weight: float, time: float,
		phase: float, state: String) -> void:
	if weight <= 0.001 or not e_golpe(state):
		return
	var pose := sample(state, phase)
	for role in pose:
		add.call(off, role, pose[role] * weight)
	# Respiração baixa e atrasada em relação à mão: precisão, sem tremedeira.
	var breath := sin(time * 2.4) * 0.008 * weight
	add.call(off, "Neck", Vector3(breath, 0, 0))
	add.call(off, "ForeArm_L", Vector3(-breath, 0, breath))


static func sample(state: String, phase: float) -> Dictionary:
	var frames: Array = []
	var times: Array = []
	match state:
		ROOM:
			frames = [READY, ROOM_PREP, ROOM_PRESS, ROOM_SETTLE, READY]
			times = [0.0, 0.27, 0.61, 0.72, 0.85]
		SHAMBLES:
			frames = [READY, SWAP_PREP, SWAP_CROSS, SWAP_FOLLOW, READY]
			times = [0.0, 0.20, 0.29, 0.40, 0.65]
		TAKT:
			frames = [READY, TAKT_LOW, TAKT_LIFT, TAKT_SEND, TAKT_SEND, READY]
			times = [0.0, 0.18, 0.50, 0.66, 1.16, 1.65]
		GAMMA:
			frames = [READY, GAMMA_COIL, GAMMA_COIL, GAMMA_THRUST, GAMMA_FOLLOW, READY]
			times = [0.0, 0.20, 0.26, 0.34, 0.57, 0.95]
		_:
			return {}
	var segment := 0
	while segment < times.size() - 2 and phase > float(times[segment + 1]):
		segment += 1
	var progress := clampf((phase - float(times[segment])) /
		maxf(float(times[segment + 1]) - float(times[segment]), 0.001), 0.0, 1.0)
	# Quintic ease gives still poses at anticipation/settle and a decisive middle.
	var eased := progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)
	var out := {}
	for i in ROLES.size():
		var from: Vector3 = frames[segment][i]
		var to: Vector3 = frames[segment + 1][i]
		out[ROLES[i]] = from.lerp(to, eased) * (PI / 180.0)
	if state == TAKT:
		# Each projectile has an intentional tiny shoulder/elbow release, with the
		# support hand following 25 ms later. Frequencies don't depend on render FPS.
		for release in [0.65, 0.77, 0.89, 1.01, 1.13]:
			var snap := _pulse(phase - release, 0.10)
			var follow := _pulse(phase - release - 0.025, 0.11)
			out["ForeArm_R"] += Vector3(-0.13, 0.05, 0.0) * snap
			out["UpperArm_L"] += Vector3(0.045, 0.0, -0.025) * follow
			out["Torso"] += Vector3(-0.018, 0.012, 0.0) * follow
	return out


static func _pulse(t: float, length: float) -> float:
	if t <= 0.0 or t >= length:
		return 0.0
	return sin(PI * t / length)
