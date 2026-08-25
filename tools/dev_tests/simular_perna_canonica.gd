extends SceneTree
# E SE a perna tivesse a proporção humana? Roda a MESMA geometria do
# ProceduralAnimator (_passada / cadencia / deslize) com a perna medida hoje e
# com a perna canônica, para separar "problema de fórmula" de "problema de rig".
const H_PARADO := 0.94
const H_CORRIDA := 0.80
const H_SPRINT := 0.76
const PASSADA_GANHO := 1.6
const CADENCIA_ESCALA := 0.55
const ALTURA := 1.5

func passada(perna: float, speed01: float, sprint: bool) -> float:
	var p: float = perna * lerpf(0.45, 0.95, clampf(speed01, 0.0, 1.0)) * PASSADA_GANHO
	if sprint: p *= 1.25
	var H: float = perna * (H_SPRINT if sprint else lerpf(H_PARADO, H_CORRIDA, clampf(speed01, 0.0, 1.0)))
	var alcance: float = perna * 0.98
	var meia: float = sqrt(maxf(alcance*alcance - H*H, 0.0))
	return maxf(minf(p, meia*2.0), 0.05)

func _init() -> void:
	print("perna_m;caso;v_m_s;passada_m;passos_por_s(sem freio);cadencia_rad_s;deslize_%")
	for caso in [["hoje (base medido)", 0.469], ["canônica (49,1% de 1,5 m)", 0.7365]]:
		for reg in [["WALK", 4.2, false, 1.0], ["RUN", 7.0, true, 1.667]]:
			var perna: float = caso[1]
			var v: float = reg[1]
			var sp: bool = reg[2]
			var s01: float = clampf(v/4.2, 0.0, 1.8)
			var p: float = passada(perna, s01, sp)
			var passos: float = v / p                      # passos/s com pé cravado
			var w: float = PI * v / p * CADENCIA_ESCALA
			var v_pe: float = p / PI * w
			print("%.3f;%s;%.1f;%.3f;%.2f;%.2f;%.0f%%" % [perna, reg[0], v, p, passos, w, 100.0*absf(v_pe-v)/v])
	print("\nSe o pé tem que ficar cravado (deslize 0), CADENCIA_ESCALA = 1.0 e a")
	print("cadência real vira os 'passos_por_s' da coluna 5. É esse número que")
	print("define se a marcha lê como humana (~2 andando, ~3 correndo) ou hélice.")
	quit()
