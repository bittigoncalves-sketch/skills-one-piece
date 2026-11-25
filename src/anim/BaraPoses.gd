extends RefCounted
## Coreografia em segundos: punho comprometido, pinça, artilharia e festival.
## Todas as chaves são papéis semânticos: servem ao rig base e ao Buggy skinado.

const DURATIONS := {"bara_z": 1.12, "bara_x": 1.50, "bara_c": 1.25, "bara_v": 3.15}
const ROLES := ["Torso", "Neck", "Head", "UpperArm_R", "ForeArm_R",
	"UpperArm_L", "ForeArm_L", "Thigh_R", "Shin_R", "Foot_R",
	"Thigh_L", "Shin_L", "Foot_L"]

const GUARD := [Vector3(-3, -5, 0), Vector3(1, 0, 0), Vector3(2, 5, 0),
	Vector3(28, -10, 19), Vector3(66, 5, 0), Vector3(34, 10, -20), Vector3(78, -5, 0),
	Vector3(8, 5, 12), Vector3(-18, 0, 0), Vector3(10, 0, -5),
	Vector3(-5, -6, -14), Vector3(-12, 0, 0), Vector3(9, 0, 5)]
const COIL := [Vector3(7, -24, -5), Vector3(-2, 0, 1), Vector3(-5, 24, 4),
	Vector3(-19, -20, 31), Vector3(106, -14, 5), Vector3(52, 17, -24), Vector3(71, 0, -3),
	Vector3(2, 10, 16), Vector3(-24, 0, 0), Vector3(17, 0, -6),
	Vector3(21, -9, -17), Vector3(-33, 0, 0), Vector3(20, 0, 6)]
const SEND := [Vector3(-12, 20, 4), Vector3(4, 0, -1), Vector3(8, -20, -3),
	Vector3(97, 5, 12), Vector3(7, 0, 0), Vector3(8, -18, -26), Vector3(69, 0, -5),
	Vector3(32, -8, 16), Vector3(-37, 0, 0), Vector3(17, 0, -6),
	Vector3(-12, 7, -16), Vector3(-11, 0, 0), Vector3(12, 0, 5)]
const RECALL := [Vector3(1, -9, -1), Vector3(0, 0, 0), Vector3(-1, 9, 1),
	Vector3(63, -12, 25), Vector3(53, -8, 2), Vector3(28, 7, -22), Vector3(77, 0, -5),
	Vector3(14, 5, 13), Vector3(-24, 0, 0), Vector3(12, 0, -5),
	Vector3(-2, -5, -14), Vector3(-14, 0, 0), Vector3(10, 0, 5)]
const PINCH_OPEN := [Vector3(5, -4, 0), Vector3(-1, 0, 0), Vector3(-4, 4, 0),
	Vector3(38, -30, 66), Vector3(65, -19, 8), Vector3(38, 30, -66), Vector3(65, 19, -8),
	Vector3(18, 9, 21), Vector3(-29, 0, 0), Vector3(15, 0, -8),
	Vector3(13, -9, -21), Vector3(-26, 0, 0), Vector3(15, 0, 8)]
const PINCH_CLOSE := [Vector3(-14, 5, 0), Vector3(4, 0, 0), Vector3(10, -5, 0),
	Vector3(91, 19, 17), Vector3(15, 4, 0), Vector3(91, -19, -17), Vector3(15, -4, 0),
	Vector3(29, -4, 20), Vector3(-39, 0, 0), Vector3(19, 0, -8),
	Vector3(20, 4, -20), Vector3(-31, 0, 0), Vector3(18, 0, 8)]
const CANNON_PREP := [Vector3(-21, -13, 0), Vector3(6, 0, 0), Vector3(14, 13, 0),
	Vector3(54, -17, 33), Vector3(58, 5, 0), Vector3(63, 14, -29), Vector3(35, -5, 0),
	Vector3(34, 8, 20), Vector3(-52, 0, 0), Vector3(25, 0, -8),
	Vector3(20, -10, -23), Vector3(-39, 0, 0), Vector3(22, 0, 9)]
const CANNON_AIM := [Vector3(-10, -10, -3), Vector3(2, 0, 1), Vector3(7, 10, 2),
	Vector3(30, -22, 37), Vector3(89, 13, 4), Vector3(71, 11, -26), Vector3(22, 0, -3),
	Vector3(24, 8, 20), Vector3(-38, 0, 0), Vector3(20, 0, -8),
	Vector3(9, -9, -21), Vector3(-26, 0, 0), Vector3(17, 0, 8)]
const CANNON_RECOIL := [Vector3(13, -5, -2), Vector3(-4, 0, 1), Vector3(-8, 5, 1),
	Vector3(53, -22, 39), Vector3(107, 9, 6), Vector3(57, 14, -31), Vector3(73, 0, -5),
	Vector3(5, 7, 20), Vector3(-25, 0, 0), Vector3(19, 0, -8),
	Vector3(30, -9, -22), Vector3(-42, 0, 0), Vector3(22, 0, 8)]
const FESTIVAL_READY := [Vector3(-7, 0, 0), Vector3(2, 0, 0), Vector3(5, 0, 0),
	Vector3(46, -24, 38), Vector3(91, -5, 4), Vector3(46, 24, -38), Vector3(91, 5, -4),
	Vector3(18, 8, 19), Vector3(-29, 0, 0), Vector3(16, 0, -7),
	Vector3(12, -8, -20), Vector3(-24, 0, 0), Vector3(14, 0, 7)]

static func e_golpe(state: String) -> bool:
	return DURATIONS.has(state)

static func golpe(add: Callable, off: Dictionary, weight: float, _time: float,
		phase: float, state: String) -> void:
	if weight <= 0.001 or not e_golpe(state):
		return
	var pose := sample(state, phase)
	for role in pose:
		add.call(off, role, pose[role] * weight)

static func sample(state: String, phase: float) -> Dictionary:
	var frames: Array = []
	var times: Array = []
	match state:
		"bara_z":
			frames = [GUARD, COIL, SEND, SEND, RECALL, GUARD]
			times = [0.0, 0.17, 0.24, 0.59, 0.94, 1.12]
		"bara_x":
			frames = [GUARD, PINCH_OPEN, PINCH_CLOSE, PINCH_CLOSE, FESTIVAL_READY, GUARD]
			times = [0.0, 0.28, 0.38, 0.80, 1.20, 1.50]
		"bara_c":
			frames = [GUARD, CANNON_PREP, CANNON_AIM, CANNON_AIM, CANNON_RECOIL, CANNON_AIM, GUARD]
			times = [0.0, 0.22, 0.48, 0.65, 0.72, 0.91, 1.25]
		"bara_v":
			frames = [GUARD, PINCH_OPEN, FESTIVAL_READY, FESTIVAL_READY, PINCH_OPEN,
				PINCH_CLOSE, PINCH_CLOSE, FESTIVAL_READY, GUARD]
			times = [0.0, 0.28, 0.49, 1.84, 1.99, 2.10, 2.30, 2.55, 3.15]
		_:
			return {}
	var segment := 0
	while segment < times.size() - 2 and phase > float(times[segment + 1]):
		segment += 1
	var progress := clampf((phase - float(times[segment])) /
		maxf(0.001, float(times[segment + 1]) - float(times[segment])), 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	var pose := {}
	for index in ROLES.size():
		var from: Vector3 = frames[segment][index]
		var to: Vector3 = frames[segment + 1][index]
		pose[ROLES[index]] = from.lerp(to, eased) * (PI / 180.0)
	if state == "bara_v":
		# Four alternating shoulder releases. Same physical hands return between
		# strikes; the pose does not manufacture extra limbs or touch gameplay.
		for index in 4:
			var strike := 0.60 + float(index) * 0.35
			var wind := _pulse(phase, strike - 0.10, strike, strike + 0.22)
			if wind <= 0.0:
				continue
			# BaraController usa 0=L, 1=R: o ombro libera a mão que voa.
			var side := "L" if index % 2 == 0 else "R"
			var sign_side := 1.0 if side == "R" else -1.0
			pose["UpperArm_" + side] += Vector3(0.84, 0.23 * sign_side, -0.20 * sign_side) * wind
			pose["ForeArm_" + side] += Vector3(-1.38, 0.0, 0.0) * wind
			pose["Torso"] += Vector3(-0.08, 0.22 * sign_side, 0.035 * sign_side) * wind
			pose["Head"] += Vector3(0.06, -0.22 * sign_side, -0.035 * sign_side) * wind
	# O avatar base possui falanges reais. O driver ignora os papéis ausentes
	# no Buggy, cujas luvas já são punhos fechados na geometria importada.
	var close_weight := smoothstep(0.0, 0.14, phase)
	if state == "bara_c":
		close_weight *= 0.40
	for side in ["L", "R"]:
		for finger in ["Index", "Middle", "Ring", "Little"]:
			for phalanx in 3:
				pose["%s%d_%s" % [finger, phalanx + 1, side]] = Vector3([-1.05, -1.25, -0.85][phalanx], 0, 0) * close_weight
		for phalanx in 3:
			pose["Thumb%d_%s" % [phalanx + 1, side]] = Vector3([-0.36, -0.55, -0.45][phalanx], 0, 0) * close_weight
	return pose

static func _pulse(time: float, start: float, peak: float, end: float) -> float:
	if time <= start or time >= end:
		return 0.0
	if time <= peak:
		return smoothstep(start, peak, time)
	return 1.0 - smoothstep(peak, end, time)
