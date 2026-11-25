extends RefCounted
## PESCA (03/10/2026) — braços segurando a vara. Quem escolhe a pose é a `Pescaria`
## (meta `pesca_pose` no jogador); a vara em si é orientada pelo visual, não pelo
## braço (src/historia/pesca/vara_de_pesca_visual.gd).
##
## Convenção do rig (docs/erros.md, 03/10): +X no UpperArm/ForeArm = FRENTE (−Z);
## no Torso, −X = inclinar para a frente. `test_pesca` mede mão × ombro.
##
##   segura    — mão direita na frente da cintura, vara apontada para a água;
##   arremesso — `fase` 0..1: leva a vara por cima do ombro (0–0,45), chicoteia
##               para a frente (0,45–0,7) e volta a segurar;
##   puxando   — as duas mãos: direita firme, esquerda na carretilha (gira com
##               `girando`), tronco para trás.

const BRACOS_D := ["UpperArm_R", "ForeArm_R"]
const BRACOS_E := ["UpperArm_L", "ForeArm_L"]

const SEGURA_D := [Vector3(0.35, 0.0, 0.12), Vector3(1.05, 0.0, 0.0)]
const ACIMA_D := [Vector3(2.7, 0.0, 0.18), Vector3(0.9, 0.0, 0.0)]
const CHICOTE_D := [Vector3(1.25, 0.0, 0.08), Vector3(0.15, 0.0, 0.0)]
const PUXA_D := [Vector3(0.6, 0.0, 0.1), Vector3(0.95, 0.0, 0.0)]
const PUXA_E := [Vector3(0.55, 0.0, -0.3), Vector3(1.35, 0.0, 0.0)]


## Usa as DUAS mãos nesta pose? (o clipe de corrida deixa o braço esquerdo livre se não)
static func duas_maos(pose: String) -> bool:
	return pose == "puxando"


static func aplicar(off: Dictionary, papeis: Dictionary, tempo: float, pose: String, fase: float,
		girando: bool, w: float) -> void:
	var alvo_d: Array = SEGURA_D
	match pose:
		"arremesso":
			alvo_d = _arremesso(fase)
		"puxando":
			alvo_d = PUXA_D
	_por(off, papeis, BRACOS_D, alvo_d, w)
	if pose == "puxando":
		var giro := sin(tempo * 14.0) * 0.18 if girando else 0.0
		_por(off, papeis, BRACOS_E, [PUXA_E[0] + Vector3(0, 0, giro * 0.5), PUXA_E[1] + Vector3(giro, 0, 0)], w)
		if papeis.has("Torso"):
			off["Torso"] = off.get("Torso", Vector3.ZERO) + Vector3(0.1, 0.0, 0.0) * w


static func _arremesso(fase: float) -> Array:
	if fase < 0.45:
		return _mistura(SEGURA_D, ACIMA_D, smoothstep(0.0, 0.45, fase))
	if fase < 0.7:
		return _mistura(ACIMA_D, CHICOTE_D, smoothstep(0.45, 0.7, fase))
	return _mistura(CHICOTE_D, SEGURA_D, smoothstep(0.7, 1.0, fase))


static func _mistura(a: Array, b: Array, k: float) -> Array:
	return [(a[0] as Vector3).lerp(b[0], k), (a[1] as Vector3).lerp(b[1], k)]


static func _por(off: Dictionary, papeis: Dictionary, nomes: Array, alvo: Array, w: float) -> void:
	for i in nomes.size():
		if papeis.has(nomes[i]):
			off[nomes[i]] = (off.get(nomes[i], Vector3.ZERO) as Vector3).lerp(alvo[i], w)
