extends RefCounted
## Ângulos autorais em graus; o animador aplica aos mesmos 13 papéis do rig.
const PAPEIS := ["Torso", "Neck", "Head", "UpperArm_R", "ForeArm_R",
	"UpperArm_L", "ForeArm_L", "Thigh_R", "Shin_R", "Foot_R",
	"Thigh_L", "Shin_L", "Foot_L"]
const GUARDA := [Vector3(-4,0,0),Vector3(2,0,0),Vector3(2,0,0),
	Vector3(28,0,12),Vector3(65,0,0),Vector3(35,0,-15),Vector3(70,0,0),
	Vector3(9,0,8),Vector3(-15,0,0),Vector3(6,0,0),
	Vector3(-5,0,-9),Vector3(-10,0,0),Vector3(8,0,0)]
const RECUO := [Vector3(8,-28,-6),Vector3(-2,0,0),Vector3(-6,25,3),
	Vector3(-24,-20,24),Vector3(105,10,0),Vector3(50,0,-12),Vector3(78,0,0),
	Vector3(20,0,12),Vector3(-32,0,0),Vector3(12,0,0),
	Vector3(-14,0,-12),Vector3(-18,0,0),Vector3(12,0,0)]
const SOCO := [Vector3(-15,26,5),Vector3(6,0,0),Vector3(9,-22,-3),
	Vector3(92,5,8),Vector3(6,0,0),Vector3(18,0,-24),Vector3(85,0,0),
	Vector3(-12,0,7),Vector3(-10,0,0),Vector3(4,0,0),
	Vector3(18,0,-12),Vector3(-28,0,0),Vector3(10,0,0)]
const VOO := [Vector3(-48,0,0),Vector3(12,0,0),Vector3(26,0,0),
	Vector3(-24,0,18),Vector3(35,0,0),Vector3(-30,0,-18),Vector3(42,0,0),
	Vector3(-24,0,8),Vector3(-32,0,0),Vector3(-15,0,0),
	Vector3(15,0,-8),Vector3(-48,0,0),Vector3(-8,0,0)]
const BARRAGEM := [Vector3(-12,0,0),Vector3(4,0,0),Vector3(8,0,0),
	Vector3(80,-5,18),Vector3(28,0,0),Vector3(80,5,-18),Vector3(28,0,0),
	Vector3(18,0,16),Vector3(-28,0,0),Vector3(10,0,0),
	Vector3(12,0,-16),Vector3(-25,0,0),Vector3(10,0,0)]
const CARGA := [Vector3(18,0,0),Vector3(-8,0,0),Vector3(-10,0,0),
	Vector3(-15,0,38),Vector3(90,0,0),Vector3(-15,0,-38),Vector3(90,0,0),
	Vector3(40,0,18),Vector3(-62,0,0),Vector3(22,0,0),
	Vector3(40,0,-18),Vector3(-62,0,0),Vector3(22,0,0)]
const SUBIDA := [Vector3(-6,0,0),Vector3(3,0,0),Vector3(3,0,0),
	Vector3(-20,0,28),Vector3(12,0,0),Vector3(-20,0,-28),Vector3(12,0,0),
	Vector3(-12,0,6),Vector3(-10,0,0),Vector3(-25,0,0),
	Vector3(-12,0,-6),Vector3(-10,0,0),Vector3(-25,0,0)]

## --- Poses do Modo História (23/09/2026). Cada golpe da ficha tem a SUA pose; antes
## disso as chaves rocket_missil/bombardeio/mergulho caíam na sequência genérica de soco.
## Ângulos autorados contra o vídeo do dono (docs/frutas/rocket.md, "Referência medida").
## Z — de lado, braço direito erguido com o foguete; depois o coice do disparo.
const APONTAR := [Vector3(0,-34,0),Vector3(2,0,0),Vector3(0,30,0),
	Vector3(128,-6,16),Vector3(28,0,0),Vector3(12,0,-28),Vector3(78,0,0),
	Vector3(-8,0,10),Vector3(-22,0,0),Vector3(10,0,0),
	Vector3(14,0,-10),Vector3(-26,0,0),Vector3(8,0,0)]
const DISPARO := [Vector3(-14,-20,0),Vector3(6,0,0),Vector3(-4,22,0),
	Vector3(100,-12,26),Vector3(70,0,0),Vector3(22,0,-34),Vector3(62,0,0),
	Vector3(-16,0,10),Vector3(-10,0,0),Vector3(14,0,0),
	Vector3(26,0,-12),Vector3(-40,0,0),Vector3(12,0,0)]
## X — perfil, mãos juntas no peito (detonador) e o aperto no momento da cadeia.
const DETONADOR := [Vector3(6,-26,0),Vector3(0,0,0),Vector3(2,24,0),
	Vector3(52,0,-18),Vector3(98,0,0),Vector3(52,0,18),Vector3(98,0,0),
	Vector3(10,0,8),Vector3(-22,0,0),Vector3(8,0,0),
	Vector3(4,0,-8),Vector3(-16,0,0),Vector3(6,0,0)]
const DETONA := [Vector3(16,-20,0),Vector3(-2,0,0),Vector3(8,18,0),
	Vector3(66,0,-22),Vector3(112,0,0),Vector3(66,0,22),Vector3(112,0,0),
	Vector3(22,0,10),Vector3(-40,0,0),Vector3(14,0,0),
	Vector3(16,0,-10),Vector3(-34,0,0),Vector3(12,0,0)]
## C — os quatro tempos do vídeo: agacha, sobe, mergulha de cabeça, aterrissa.
const AGACHO := [Vector3(26,0,0),Vector3(-6,0,0),Vector3(-16,0,0),
	Vector3(-28,0,16),Vector3(30,0,0),Vector3(-28,0,-16),Vector3(30,0,0),
	Vector3(62,0,10),Vector3(-105,0,0),Vector3(36,0,0),
	Vector3(62,0,-10),Vector3(-105,0,0),Vector3(36,0,0)]
const ARCO := [Vector3(-26,0,0),Vector3(10,0,0),Vector3(16,0,0),
	Vector3(-52,0,20),Vector3(16,0,0),Vector3(-52,0,-20),Vector3(16,0,0),
	Vector3(-20,0,6),Vector3(-52,0,0),Vector3(-18,0,0),
	Vector3(-20,0,-6),Vector3(-52,0,0),Vector3(-18,0,0)]
const MERGULHO := [Vector3(34,0,0),Vector3(-8,0,0),Vector3(-24,0,0),
	Vector3(150,0,10),Vector3(8,0,0),Vector3(150,0,-10),Vector3(8,0,0),
	Vector3(-42,0,6),Vector3(-30,0,0),Vector3(-22,0,0),
	Vector3(-42,0,-6),Vector3(-30,0,0),Vector3(-22,0,0)]
const ATERRISSA := [Vector3(30,0,0),Vector3(-4,0,0),Vector3(-12,0,0),
	Vector3(58,0,26),Vector3(52,0,0),Vector3(58,0,-26),Vector3(52,0,0),
	Vector3(72,0,14),Vector3(-112,0,0),Vector3(40,0,0),
	Vector3(72,0,-14),Vector3(-112,0,0),Vector3(40,0,0)]

static func amostrar(pose: String, t: float) -> Dictionary:
	var quadros: Array = [GUARDA, RECUO, SOCO, SOCO, GUARDA]
	var tempos: Array = [0.0, 0.27, 0.43, 0.56, 1.0]
	match pose:
		# O voo da fruta no Modo História: mortal, corpo esticado, e a guarda no fim.
		"rocket_voo": quadros = [CARGA, VOO, VOO, VOO, GUARDA]
		# Modo História. Tempos normalizados pela duração da fase em `rocket_controller`:
		# míssil 0,60 s (dispara em 0,35 = 0,58) · bombardeio 1,15 s (aperta em 0,65 = 0,57)
		# · mergulho 1,40 s (decola em 0,12 = 0,09 e bate em 0,52 = 0,37).
		"rocket_missil":
			quadros = [GUARDA, APONTAR, APONTAR, DISPARO, GUARDA]
			tempos = [0.0, 0.30, 0.58, 0.72, 1.0]
		"rocket_bombardeio":
			quadros = [GUARDA, DETONADOR, DETONADOR, DETONA, GUARDA]
			tempos = [0.0, 0.20, 0.40, 0.58, 1.0]
		"rocket_mergulho":
			# A aterrissagem cai EXATAMENTE no impacto (t 0,37) e segura até 0,55; antes
			# disso o corpo ainda estava mergulhando quando a explosão já tinha saído.
			quadros = [GUARDA, AGACHO, ARCO, MERGULHO, ATERRISSA, ATERRISSA, GUARDA]
			tempos = [0.0, 0.09, 0.18, 0.30, 0.37, 0.55, 1.0]
		"rocket_x": quadros = [GUARDA, CARGA, VOO, VOO, GUARDA]
		"rocket_c":
			quadros = [GUARDA, BARRAGEM, BARRAGEM, GUARDA]
			tempos = [0.0, 0.14, 0.83, 1.0]
		"rocket_carga": quadros = [GUARDA, CARGA, CARGA, SUBIDA, GUARDA]
		"rocket_subida": quadros = [GUARDA, SUBIDA, SUBIDA, SUBIDA, SUBIDA]
		"rocket_mira": quadros = [SUBIDA, CARGA, CARGA, CARGA, CARGA]
		"rocket_queda": quadros = [CARGA, VOO, VOO, VOO, VOO]
		"rocket_pouso": quadros = [CARGA, CARGA, CARGA, GUARDA, GUARDA]
	var i := 0
	while i < tempos.size() - 2 and t > float(tempos[i + 1]): i += 1
	var f := smoothstep(float(tempos[i]), float(tempos[i + 1]), clampf(t, 0, 1))
	var resultado := {}
	for j in PAPEIS.size():
		resultado[PAPEIS[j]] = (quadros[i][j] as Vector3).lerp(quadros[i + 1][j], f) * PI / 180.0
	if pose == "rocket_c" and t > 0.14 and t < 0.83:
		var pulso := sin((t - 0.14) / 0.69 * TAU * 8.0)
		resultado.UpperArm_R.x += pulso * 0.12
		resultado.UpperArm_L.x -= pulso * 0.12
		resultado.Torso.y += pulso * 0.025
	return resultado

static func aplicar(off: Dictionary, pose: String, t: float) -> void:
	if not pose.begins_with("rocket_"): return
	var dados := amostrar(pose, t)
	for papel in dados: off[papel] = dados[papel]
