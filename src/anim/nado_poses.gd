extends RefCounted
## Crawl do protagonista: entrada, apoio, puxada e recuperação com cotovelo alto.
## Ângulos do rig real: tronco -X inclina para -Z; braço +X alcança à frente.
const BRACADA := [
	[0.0, Vector3(3.02, 0.02, 0.12), 0.08],
	[0.18, Vector3(2.55, 0.10, 0.20), 0.65],
	[0.43, Vector3(0.65, 0.12, 0.24), 1.00],
	[0.52, Vector3(-0.22, 0.08, 0.14), 0.12],
	[0.60, Vector3(0.15, 0.18, 1.10), 0.75],
	[0.68, Vector3(2.40, 0.25, 2.70), 2.70],
	[0.78, Vector3(1.45, 0.25, 2.70), 2.10],
	[0.90, Vector3(2.66, 0.12, 0.52), 0.58],
	[1.0, Vector3(3.02, 0.02, 0.12), 0.08],
]

static func braco(fase: float) -> Dictionary:
	var t := fposmod(fase, 1.0)
	for i in BRACADA.size() - 1:
		var a: Array = BRACADA[i]
		var b: Array = BRACADA[i + 1]
		if t <= float(b[0]):
			var k := smoothstep(float(a[0]), float(b[0]), t)
			return {"ombro": (a[1] as Vector3).lerp(b[1], k), "cotovelo": lerpf(a[2], b[2], k)}
	return {"ombro": BRACADA[0][1], "cotovelo": BRACADA[0][2]}

static func aplicar(adicionar: Callable, off: Dictionary, peso: float, fase: float, movimento: float) -> void:
	var crawl := peso * movimento
	var boiar := peso * (1.0 - movimento)
	var ciclo := fase / TAU
	adicionar.call(off, "Torso", Vector3(-1.45, sin(fase) * 0.13, 0) * crawl + Vector3(-0.10, 0, 0) * boiar)
	adicionar.call(off, "Head", Vector3(1.12, maxf(sin(fase - 0.4), 0.0) * 0.24, 0) * crawl)
	for lado: String in ["L", "R"]:
		var sinal := -1.0 if lado == "L" else 1.0
		var deslocamento := 0.0 if lado == "L" else 0.5
		var b := braco(ciclo + deslocamento)
		var ombro: Vector3 = b["ombro"]
		ombro.y *= sinal
		ombro.z *= sinal
		var remada := fase + deslocamento * TAU
		adicionar.call(off, "UpperArm_" + lado, ombro * crawl + Vector3(0.4, 0.15 * sin(remada), sinal * (0.72 + 0.18 * sin(fase))) * boiar)
		adicionar.call(off, "ForeArm_" + lado, Vector3(float(b["cotovelo"]) * crawl + 0.65 * boiar, 0, 0))
		var pernada := sin(fase * 3.0 + deslocamento * TAU)
		adicionar.call(off, "Thigh_" + lado, Vector3((0.04 + 0.19 * pernada) * crawl + (0.35 + 0.25 * sin(remada)) * boiar, 0, 0))
		adicionar.call(off, "Shin_" + lado, Vector3((-0.10 - 0.22 * maxf(-pernada, 0)) * crawl + (-0.72 - 0.22 * cos(remada)) * boiar, 0, 0))
		# Ponta do pé prolonga a canela, sem o ângulo de apoio usado ao andar.
		adicionar.call(off, "Foot_" + lado, Vector3(-1.25 * crawl, 0, 0))
