class_name BossReactionPose
extends RefCounted
## Animação procedural da recepção de M1 do Boss: tranco (1º/2º acerto), voo
## arqueado (3º), queda de costas e levantar. Só apresentação; a fase vem dos
## campos replicados de BossActor.
##
## ⚠️ Tudo em espaço do ATOR (-Z = frente, atacante à frente). O esqueleto do
## Meshy é Z-up; nenhum eixo local de osso é usado direto, então a pose não
## depende da convenção do asset.
##
## Convenção de sinais: rotação positiva em X leva o topo do corpo para TRÁS
## (+Z) e, num membro que aponta para baixo, leva a ponta para a FRENTE.
const FIELDS := ["body_pitch", "body_yaw", "body_roll", "lift", "torso_pitch", "torso_yaw", "head_pitch", "arms", "arm_l", "arm_r"]
const ENTER := 45.0
const EXIT := 14.0

## Parâmetros-alvo da fase. Ângulos em radianos; `lift` e braços em fração da altura.
static func target(reaction: String, t: float, count: int) -> Dictionary:
	var p := {"body_pitch": 0.0, "body_yaw": 0.0, "body_roll": 0.0, "lift": 0.0, "torso_pitch": 0.0,
		"torso_yaw": 0.0, "head_pitch": 0.0, "arms": 0.0, "arm_l": BoxingPose.GUARD["L"], "arm_r": BoxingPose.GUARD["R"], "stiffness": EXIT}
	match reaction:
		BossHitReaction.STAGGER:
			# Bate em 0,05 s, segura, e solta devagar até o fim da paralisia.
			var e := minf(1.0, t / 0.05) * (1.0 - smoothstep(0.35, BossHitReaction.STAGGER_TIME, t))
			var tremor := sin(t * 55.0) * 0.035 * e
			# 1º acerto torce para um lado, 2º para o outro: dois golpes não leem iguais.
			var side := 1.0 if count % 2 == 1 else -1.0
			p.body_pitch = 0.10 * e
			p.body_yaw = 0.20 * side * e
			p.body_roll = -0.06 * side * e
			p.torso_pitch = 0.26 * e + tremor
			p.torso_yaw = 0.16 * side * e
			p.head_pitch = 0.38 * minf(1.0, maxf(0.0, t - 0.03) / 0.06) * e
			# Guarda quebrada: a mão do lado do giro abre para trás, a outra cobre o rosto.
			p.arms = e
			p.arm_l = Vector3(-0.24, 0.30, 0.03) if side > 0 else Vector3(-0.07, 0.35, -0.15)
			p.arm_r = Vector3(0.07, 0.35, -0.15) if side > 0 else Vector3(0.24, 0.30, 0.03)
			p.stiffness = ENTER
		BossHitReaction.LAUNCHED:
			# Corpo arqueado indo de costas; braços e cabeça ficam para trás do voo
			# (à frente do corpo, na direção do atacante).
			var a := smoothstep(0.0, 0.55, t)
			p.body_pitch = lerpf(0.35, 1.0, a)
			p.torso_pitch = 0.34
			p.head_pitch = 0.45
			p.arms = 1.0
			p.arm_l = Vector3(-0.20, 0.44, -0.30)
			p.arm_r = Vector3(0.20, 0.46, -0.26)
			p.stiffness = 30.0
		BossHitReaction.KNOCKDOWN:
			# Bate de costas no chão com um quique curto.
			var bounce := sin(minf(t / 0.22, 1.0) * PI) * 0.10
			p.body_pitch = PI * 0.5 - bounce
			p.lift = 0.08 + bounce * 0.05
			p.head_pitch = -0.20 * smoothstep(0.2, 0.6, t)
			p.arms = 1.0
			p.arm_l = Vector3(-0.30, 0.26, 0.04)
			p.arm_r = Vector3(0.30, 0.26, 0.04)
			p.stiffness = 32.0
		BossHitReaction.GETUP:
			# Senta (tronco para frente) enquanto o corpo gira de volta de pé.
			var g := smoothstep(0.0, BossHitReaction.GETUP_TIME, t)
			p.body_pitch = PI * 0.5 * (1.0 - g)
			p.lift = 0.08 * (1.0 - g)
			p.torso_pitch = -0.55 * sin(g * PI)
			p.head_pitch = -0.25 * sin(g * PI)
			p.arms = 1.0 - g
			p.arm_r = Vector3(0.24, 0.10, 0.12)
			p.arm_l = Vector3(-0.20, 0.30, -0.12)
			p.stiffness = 24.0
	return p

## Aproxima `state` do alvo com rigidez exponencial: entrada rápida, saída suave.
static func blend(state: Dictionary, goal: Dictionary, delta: float) -> void:
	var k := 1.0 - exp(-float(goal.stiffness) * delta) if delta > 0 else 1.0
	for key in FIELDS:
		state[key] = lerp(state.get(key, goal[key]), goal[key], k)

## Aplica depois da guarda de boxe (BoxingPose), para os ossos já estarem na base
## do quadro. `view.model_base` é a transformação de repouso do modelo.
static func apply(view: Node3D, state: Dictionary) -> void:
	var actor: Node3D = view.get_parent()
	var height: float = actor.definition.height
	if float(state.arms) > 0.001:
		for side in ["L", "R"]:
			var guard: Vector3 = BoxingPose.GUARD[side]
			var goal: Vector3 = guard.lerp(state["arm_" + side.to_lower()], float(state.arms)) * height
			BoxingPose.arm(view, side, actor.to_global(goal), actor.global_basis * Vector3(-0.5 if side == "L" else 0.5, -1, 0))
	var skeleton: Skeleton3D = view.skeleton
	BoxingPose.rotate_bone(skeleton, view.bones["Torso"], actor.global_basis * Vector3.RIGHT, state.torso_pitch)
	BoxingPose.rotate_bone(skeleton, view.bones["Torso"], actor.global_basis * Vector3.UP, state.torso_yaw)
	BoxingPose.rotate_bone(skeleton, view.bones["Head"], actor.global_basis * Vector3.RIGHT, state.head_pitch)
	# Corpo inteiro gira em torno dos pés: quem está no ar ou caído gira pela base.
	var feet := Vector3(0, -height * 0.5, 0)
	var rotation := Basis(Vector3.UP, state.body_yaw) * Basis(Vector3.RIGHT, state.body_pitch) * Basis(Vector3.BACK, state.body_roll)
	var pivot := Transform3D(Basis(), feet + Vector3.UP * float(state.lift) * height) * Transform3D(rotation, Vector3.ZERO) * Transform3D(Basis(), -feet)
	view.model.transform = pivot * view.model_base
