extends RefCounted
## Quadril no assento; pernas abraçam o animal, mãos apoiadas à frente.
static func aplicar(off: Dictionary, papeis: Dictionary, tempo: float, velocidade: float, larga: bool) -> void:
	for papel in papeis:
		off[papel] = Vector3.ZERO
	var balanco := sin(tempo * 9.0) * 0.035 * clampf(velocidade / 7.0, 0, 1)
	off["Torso"] = Vector3(-0.08 + balanco, 0, 0)
	off["Head"] = Vector3(0.08 - balanco, 0, 0)
	for lado: String in ["L", "R"]:
		var sinal := -1.0 if lado == "L" else 1.0
		off["Thigh_" + lado] = Vector3(1.7 if larga else 1.28, sinal * -0.25, sinal * (0.9 if larga else 0.32))
		off["Shin_" + lado] = Vector3(-2.05 if larga else -1.36, 0, 0)
		off["Foot_" + lado] = Vector3(0.12, 0, 0)
		off["UpperArm_" + lado] = Vector3(0.55, 0, sinal * 0.15)
		off["ForeArm_" + lado] = Vector3(0.88, 0, 0)

## Ciclo oposto das pernas sincronizado à pedaleira, inclusive ao parar.
static func bicicleta(off: Dictionary, papeis: Dictionary, fase: float) -> void:
	for papel in papeis: off[papel] = Vector3.ZERO
	off["Torso"] = Vector3(.20, 0, 0)
	off["Head"] = Vector3(-.15, 0, 0)
	for lado: String in ["L", "R"]:
		var sinal := -1.0 if lado == "L" else 1.0
		var ciclo := sin(fase + (PI if lado == "L" else 0.0))
		off["Thigh_" + lado] = Vector3(1.05 + .32*ciclo, 0, sinal*.08)
		off["Shin_" + lado] = Vector3(-1.45 - .48*ciclo, 0, 0)
		off["Foot_" + lado] = Vector3(.25 + .16*ciclo, 0, 0)
		off["UpperArm_" + lado] = Vector3(.85, 0, sinal*.12)
		off["ForeArm_" + lado] = Vector3(.5, 0, 0)
