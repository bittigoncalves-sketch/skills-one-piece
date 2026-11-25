class_name PernasDeAreia
extends SkeletonModifier3D
# ============================================================================
#  AS PERNAS VIRAM AREIA (15/10/2026) — o Crocodile em voo.
#
#  Um `SkeletonModifier3D` (roda DEPOIS da animação, então ela não desfaz o efeito): com
#  `forca` de 0 a 1 encolhe as duas pernas até quase zero — a malha que pesa nelas
#  colapsa no quadril — e quem põe a areia no lugar (cone + grãos) é o `VooDeAreia`.
#  `forca` 0 devolve as pernas inteiras.
# ============================================================================

const OSSOS: Array[String] = ["LeftUpLeg", "RightUpLeg"]
const ESCALA_MINIMA := 0.001

var forca := 0.0
## Quantas vezes o esqueleto chamou o modificador (diagnóstico do teste).
var chamadas := 0


func _process_modification_with_delta(_delta: float) -> void:
	chamadas += 1
	var sk := get_skeleton()
	if sk == null or forca <= 0.0:
		return
	var s := lerpf(1.0, ESCALA_MINIMA, clampf(forca, 0.0, 1.0))
	for nome in OSSOS:
		var i := sk.find_bone(nome)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3.ONE * s)
