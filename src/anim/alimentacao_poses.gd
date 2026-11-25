extends RefCounted
## Sobreposição só do tronco/braços. Recursos editáveis, sem root motion.
const COMER = preload("res://assets/animations/alimentacao/comer.tres")
const BEBER = preload("res://assets/animations/alimentacao/beber.tres")
const PAPEIS := ["UpperArm_R", "ForeArm_R", "Head", "UpperArm_L"]

static func clipe(tipo: String) -> Animation:
	return BEBER if tipo == "agua" else COMER

static func aplicar(off: Dictionary, jogador: Node) -> void:
	var dados: Dictionary = jogador.get_meta("alimentacao_pose", {})
	if dados.is_empty(): return
	var anim := clipe(str(dados.tipo))
	var t := clampf(float(dados.tempo), 0.0, anim.length)
	var peso := smoothstep(0.0, .18, t) * (1.0 - smoothstep(anim.length - .25, anim.length, t))
	for i in anim.get_track_count():
		var papel := str(anim.track_get_path(i)).get_slice(":", 0)
		off[papel] = (off.get(papel, Vector3.ZERO) as Vector3).lerp(anim.value_track_interpolate(i, t), peso)
