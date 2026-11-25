extends RefCounted
## Equilíbrio no convés e mãos à frente do posto de comando.
static func aplicar(off: Dictionary, papeis: Dictionary, tempo: float, direcao: float) -> void:
	for papel in papeis:
		off[papel] = Vector3.ZERO
	off["Torso"] = Vector3(-.05, direcao * -.08, sin(tempo * 1.1) * .025)
	off["Head"] = Vector3(.05, direcao * .16, 0)
	for lado: String in ["L", "R"]:
		var s := -1.0 if lado == "L" else 1.0
		off["Thigh_" + lado] = Vector3(.10, 0, s * .12)
		off["Shin_" + lado] = Vector3(-.14, 0, 0)
		off["UpperArm_" + lado] = Vector3(.72 + s * direcao * .16, 0, s * .14)
		off["ForeArm_" + lado] = Vector3(.72 - s * direcao * .12, 0, 0)
