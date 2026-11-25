extends RefCounted
## Coreografia autoral da GORO GORO NO MI. Tempo em segundos recebido do golpe;
## não depende do FPS nem de clipe de outra fruta. O rig tem 13 papéis e não tem
## dedos: a mão aberta é expressa pela pronação do antebraço inteiro.
##
## A INTENÇÃO POR TRÁS DOS QUATRO GESTOS — o raio não é empurrado, é CHAMADO.
## Onde a Ope é um cirurgião (gesto contido, precisão), a Goro é um deus do
## trovão: o corpo se abre, o braço aponta, e a energia vem de fora dele. Por
## isso quase toda pose aqui termina com o peito exposto e o braço estendido, e
## nenhuma delas "soca".
##
## ⚠️ DOIS NOMES SÃO CONTRATO COM O CÓDIGO DE EFEITO, não escolha de estilo:
## `el_thor` e `mamaragan` já eram escritos em `caster.set_meta("custom_pose",…)`
## pelo `GoroFXGrande` — o do El Thor desde o dia em que a pose foi prometida e
## não escrita ("a pose ainda NÃO existe lá", `GoroFXGrande.el_thor`). Renomear
## aqui quebraria a limpeza que aquele arquivo já faz.

const SANGO := "goro_sango"
const EL_THOR := "el_thor"
const SHUNSHIN := "goro_shunshin"
const MAMARAGAN := "mamaragan"
const MAMARAGAN_SOLTA := "mamaragan_solta"

## Duração de cada gesto. O X bate com o `lock_movement(1.6)` do `GoroFXGrande`:
## pose e travamento têm de acabar juntos, senão o corpo volta ao normal com o
## jogador ainda preso, ou o contrário.
const DURATIONS := {
	SANGO: 0.55,
	EL_THOR: 1.60,
	SHUNSHIN: 0.45,
	MAMARAGAN: 1.10,          # entra e SUSTENTA — a carga não tem fim previsto
	MAMARAGAN_SOLTA: 0.50,
}

## Poses que dominam o corpo inteiro. As demais deixam as PERNAS correndo por
## baixo — mesmo mecanismo do `GuraPoses.CORPO_INTEIRO`.
##
## Só o X entra aqui, e por um motivo concreto: é o único golpe da fruta que
## trava o jogador. O V ficou de fora porque desde a remodelação de 2026-09-12 o
## jogador CANALIZA ANDANDO, e uma perna autorada brigaria com a corrida.
const CORPO_INTEIRO := [EL_THOR]

const ROLES := ["Torso", "Neck", "Head", "UpperArm_R", "ForeArm_R",
	"UpperArm_L", "ForeArm_L", "Thigh_R", "Shin_R", "Foot_R",
	"Thigh_L", "Shin_L", "Foot_L"]

# ---------------------------------------------------------------------------
#  QUADROS, EM GRAUS. Perna em zero = "não escrevo isto, a locomoção que mande".
# ---------------------------------------------------------------------------

const READY := [Vector3(-2,-4,0),Vector3(1,0,0),Vector3(1,4,0),
	Vector3(10,0,9),Vector3(20,0,4),Vector3(9,0,-13),Vector3(28,0,-6),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]

# ---- Z, SANGO: o braço recua carregando e ESTENDE. Pernas livres. ----
const SANGO_COIL := [Vector3(4,-24,-3),Vector3(-2,0,1),Vector3(-3,20,2),
	Vector3(-26,-18,26),Vector3(96,-12,6),Vector3(22,14,-22),Vector3(52,0,-10),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]
# Braço TOTALMENTE estendido e antebraço pronado: a palma vira para o alvo.
const SANGO_FIRE := [Vector3(-8,26,4),Vector3(4,0,-1),Vector3(7,-22,-2),
	Vector3(92,14,8),Vector3(4,-46,0),Vector3(-10,-18,-28),Vector3(34,0,-12),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]
const SANGO_HOLD := [Vector3(-5,17,2),Vector3(2,0,-1),Vector3(4,-14,-1),
	Vector3(78,10,10),Vector3(14,-34,2),Vector3(2,-11,-24),Vector3(32,0,-10),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]

# ---- X, EL THOR: o braço CHAMA o céu. Corpo inteiro (o golpe trava). ----
# O gatilho do raio sai do `ForeArm_R` (ver `GoroFXGrande.gatilho_do_braco`),
# então o antebraço precisa estar VERTICAL no instante em que ele dispara.
const THOR_GATHER := [Vector3(12,-14,-4),Vector3(-6,0,2),Vector3(-12,12,3),
	Vector3(-34,-16,22),Vector3(74,-20,6),Vector3(-28,14,-20),Vector3(66,10,-10),
	Vector3(16,7,14),Vector3(-34,0,0),Vector3(20,0,-6),
	Vector3(10,-8,-16),Vector3(-30,0,0),Vector3(17,0,6)]
# Braço praticamente vertical, peito aberto, cabeça acompanhando para cima.
const THOR_CALL := [Vector3(-16,-6,-2),Vector3(-14,0,1),Vector3(-22,5,2),
	Vector3(172,-6,14),Vector3(6,0,2),Vector3(-46,10,-22),Vector3(30,6,-12),
	Vector3(-6,6,12),Vector3(-14,0,0),Vector3(9,0,-4),
	Vector3(-14,-6,-14),Vector3(-12,0,0),Vector3(8,0,5)]
const THOR_HOLD := [Vector3(-12,-4,-1),Vector3(-11,0,1),Vector3(-18,4,1),
	Vector3(166,-4,12),Vector3(10,0,2),Vector3(-40,8,-20),Vector3(28,5,-11),
	Vector3(-4,5,11),Vector3(-12,0,0),Vector3(8,0,-4),
	Vector3(-11,-5,-13),Vector3(-10,0,0),Vector3(7,0,4)]
# O braço desce trazendo a coluna junto: o corpo "puxa" o raio para o chão.
const THOR_DOWN := [Vector3(14,8,2),Vector3(6,0,-1),Vector3(13,-7,-2),
	Vector3(44,8,18),Vector3(56,0,4),Vector3(16,-8,-26),Vector3(44,0,-12),
	Vector3(26,-6,15),Vector3(-38,0,0),Vector3(19,0,-6),
	Vector3(6,5,-16),Vector3(-22,0,0),Vector3(13,0,5)]

# ---- C, SHUNSHIN: compressão e arranco. Pernas livres (o corpo é teleportado). ----
const SHUN_CROUCH := [Vector3(22,-10,-2),Vector3(-10,0,1),Vector3(-16,9,2),
	Vector3(-34,-12,16),Vector3(70,-8,4),Vector3(-30,10,-18),Vector3(64,6,-8),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]
# Corpo estendido na direção do salto, braços jogados para TRÁS: pura aceleração.
const SHUN_BURST := [Vector3(-26,6,1),Vector3(12,0,-1),Vector3(18,-5,-1),
	Vector3(-58,10,10),Vector3(16,4,2),Vector3(-54,-8,-14),Vector3(20,0,-6),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]

# ---- V, MAMARAGAN: canaliza com o braço erguido, ANDANDO. Pernas livres. ----
const MAMA_RAISE := [Vector3(-6,-10,-2),Vector3(-8,0,1),Vector3(-13,9,2),
	Vector3(128,-10,20),Vector3(40,-14,6),Vector3(-18,12,-22),Vector3(52,8,-10),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]
# SUSTENTADO: os dois braços erguidos, segurando a tempestade lá em cima.
const MAMA_CHANNEL := [Vector3(-9,-6,-1),Vector3(-12,0,1),Vector3(-19,5,1),
	Vector3(158,-8,16),Vector3(18,-8,4),Vector3(-42,8,-20),Vector3(26,6,-12),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]
# SOLTAR: os braços DESCEM juntos, com o tronco. É o gesto que derruba a bola.
const MAMA_SLAM := [Vector3(26,4,1),Vector3(14,0,-1),Vector3(22,-4,-1),
	Vector3(22,6,16),Vector3(72,0,4),Vector3(14,-6,-24),Vector3(66,0,-10),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0),
	Vector3(0,0,0),Vector3(0,0,0),Vector3(0,0,0)]


static func e_golpe(state: String) -> bool:
	return DURATIONS.has(state)


static func toma_o_corpo(state: String) -> bool:
	return CORPO_INTEIRO.has(state)


static func golpe(add: Callable, off: Dictionary, weight: float, time: float,
		phase: float, state: String) -> void:
	if weight <= 0.001 or not e_golpe(state):
		return
	var pose := sample(state, phase)
	for role in pose:
		add.call(off, role, pose[role] * weight)

	# CREPITAÇÃO. A Ope respira; a Goro TREME — o corpo de quem está com corrente
	# passando por ele não fica parado. Frequência alta e amplitude minúscula:
	# acima disto vira tremedeira cômica, e some no braço que está estendido.
	var buzz := sin(time * 47.0) * 0.0055 * weight
	add.call(off, "ForeArm_R", Vector3(buzz, 0, buzz * 0.5))
	add.call(off, "ForeArm_L", Vector3(-buzz, 0, -buzz * 0.5))
	add.call(off, "Neck", Vector3(buzz * 0.35, 0, 0))


static func sample(state: String, phase: float) -> Dictionary:
	var frames: Array = []
	var times: Array = []
	match state:
		SANGO:
			frames = [READY, SANGO_COIL, SANGO_FIRE, SANGO_HOLD, READY]
			times = [0.0, 0.14, 0.21, 0.34, 0.55]
		EL_THOR:
			frames = [READY, THOR_GATHER, THOR_CALL, THOR_HOLD, THOR_DOWN, READY]
			times = [0.0, 0.22, 0.40, 1.05, 1.28, 1.60]
		SHUNSHIN:
			frames = [READY, SHUN_CROUCH, SHUN_BURST, READY]
			times = [0.0, 0.12, 0.22, 0.45]
		MAMARAGAN:
			# O ÚLTIMO TRECHO É UM HOLD PROPOSITAL: a carga não tem fim previsto
			# (o jogador decide), e o `sample` fixa a fase no último segmento.
			# Sem este quadro repetido a pose voltaria para READY sozinha enquanto
			# a bola ainda está crescendo lá em cima.
			frames = [READY, MAMA_RAISE, MAMA_CHANNEL, MAMA_CHANNEL]
			times = [0.0, 0.34, 0.72, 1.10]
		MAMARAGAN_SOLTA:
			frames = [MAMA_CHANNEL, MAMA_SLAM, READY]
			times = [0.0, 0.16, 0.50]
		_:
			return {}

	var segment := 0
	while segment < times.size() - 2 and phase > float(times[segment + 1]):
		segment += 1
	var progress := clampf((phase - float(times[segment])) /
		maxf(float(times[segment + 1]) - float(times[segment]), 0.001), 0.0, 1.0)
	# Quintic ease: quadros parados na antecipação e no assentamento, meio decidido.
	var eased := progress * progress * progress * (progress * (progress * 6.0 - 15.0) + 10.0)
	var out := {}
	for i in ROLES.size():
		var from: Vector3 = frames[segment][i]
		var to: Vector3 = frames[segment + 1][i]
		out[ROLES[i]] = from.lerp(to, eased) * (PI / 180.0)

	if state == EL_THOR:
		# Os 11 raios do El Thor caem um a um enquanto o braço está sustentado.
		# Cada queda dá um tranco curto no ombro e na coluna: o corpo REAGE ao
		# que está chamando, em vez de ficar de estátua os 0,65 s do hold.
		for i in range(11):
			var quando := 0.42 + float(i) * 0.058
			var tranco := _pulse(phase - quando, 0.085)
			out["UpperArm_R"] += Vector3(-0.055, 0.0, 0.02) * tranco
			out["Torso"] += Vector3(0.02, 0.0, 0.0) * tranco
	return out


static func _pulse(t: float, length: float) -> float:
	if t <= 0.0 or t >= length:
		return 0.0
	return sin(PI * t / length)
