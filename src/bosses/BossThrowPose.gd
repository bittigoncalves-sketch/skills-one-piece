class_name BossThrowPose
extends RefCounted
## Arremesso do corte, como um lançamento de beisebol: a perna esquerda dobra e
## sobe (apoio numa perna só), a mão direita vai por cima da cabeça e para trás,
## o tronco torce e inclina para trás; no lançamento a perna desce à frente, o
## tronco gira e a mão passa por cima e à frente da cabeça, terminando cruzada
## embaixo.
##
## Poses-chave em espaço do ATOR (-Z = frente), interpoladas com smoothstep.
## Braços em fração da altura (alvo da IK); ângulos em radianos. Convenção:
## rotação positiva em X leva a ponta de um membro que aponta para baixo para a
## FRENTE e o topo do tronco para TRÁS; giro negativo em Y leva o ombro direito
## para trás.
const NEUTRAL := {
	"arm_r": Vector3(0.13, 0.28, -0.09), "arm_l": Vector3(-0.13, 0.27, -0.10),
	"torso_yaw": 0.0, "torso_pitch": 0.0, "head_yaw": 0.0,
	"thigh_l": 0.0, "shin_l": 0.0, "thigh_r": 0.0, "shin_r": 0.0, "knee_in": 0.0,
}

## [instante, pose]. Instantes em função da habilidade para acompanhar ajustes de dados.
static func keys(move: BossSlashAbility) -> Array:
	var release := move.windup + move.active
	return [
		[0.0, NEUTRAL],
		# Enquanto mira: começa a subir a perna e levar a mão para cima.
		[move.aim_time, {"arm_r": Vector3(0.17, 0.42, 0.02), "arm_l": Vector3(-0.14, 0.30, -0.22),
			"torso_yaw": -0.25, "torso_pitch": 0.05, "head_yaw": 0.20,
			"thigh_l": 0.60, "shin_l": -0.80, "thigh_r": 0.05, "shin_r": -0.10, "knee_in": 0.15}],
		# Carregado: joelho alto, mão acima da cabeça e para trás, luva apontando o alvo.
		[move.windup * 0.8, {"arm_r": Vector3(0.15, 0.49, 0.31), "arm_l": Vector3(-0.13, 0.34, -0.34),
			"torso_yaw": -0.55, "torso_pitch": 0.20, "head_yaw": 0.45,
			"thigh_l": 1.35, "shin_l": -1.60, "thigh_r": 0.12, "shin_r": -0.25, "knee_in": 0.35}],
		# Início do impulso: a perna começa a descer, a mão vai ainda mais para trás.
		[move.windup, {"arm_r": Vector3(0.15, 0.45, 0.35), "arm_l": Vector3(-0.12, 0.30, -0.26),
			"torso_yaw": -0.50, "torso_pitch": 0.12, "head_yaw": 0.40,
			"thigh_l": 0.90, "shin_l": -0.95, "thigh_r": 0.10, "shin_r": -0.22, "knee_in": 0.20}],
		# Mão passa acima e à frente da cabeça (arco por cima, não atravessa o rosto).
		[move.windup + move.active * 0.45, {"arm_r": Vector3(0.16, 0.52, -0.12), "arm_l": Vector3(-0.12, 0.25, -0.10),
			"torso_yaw": -0.05, "torso_pitch": -0.10, "head_yaw": 0.05,
			"thigh_l": 0.60, "shin_l": -0.50, "thigh_r": -0.05, "shin_r": -0.15, "knee_in": 0.05}],
		# Soltou: braço estendido à frente, perna plantada, tronco girado e inclinado.
		[release, {"arm_r": Vector3(0.06, 0.30, -0.55), "arm_l": Vector3(-0.12, 0.22, -0.02),
			"torso_yaw": 0.45, "torso_pitch": -0.35, "head_yaw": -0.30,
			"thigh_l": 0.45, "shin_l": -0.25, "thigh_r": -0.25, "shin_r": -0.10, "knee_in": 0.0}],
		# Acompanhamento: a mão termina cruzada embaixo.
		[release + move.recovery * 0.4, {"arm_r": Vector3(-0.06, 0.12, -0.36), "arm_l": Vector3(-0.14, 0.22, -0.05),
			"torso_yaw": 0.40, "torso_pitch": -0.40, "head_yaw": -0.30,
			"thigh_l": 0.40, "shin_l": -0.25, "thigh_r": -0.20, "shin_r": -0.10, "knee_in": 0.0}],
		[move.duration(), NEUTRAL],
	]

static func sample(move: BossSlashAbility, time: float) -> Dictionary:
	var frames := keys(move)
	if time <= 0:
		return NEUTRAL
	for i in range(1, frames.size()):
		if time <= frames[i][0]:
			var a: Dictionary = frames[i - 1][1]
			var b: Dictionary = frames[i][1]
			var w := smoothstep(frames[i - 1][0], frames[i][0], time)
			var pose := {}
			for key in NEUTRAL:
				pose[key] = lerp(a[key], b[key], w)
			return pose
	return NEUTRAL

## Chamado depois do `push` do driver (ossos na base do quadro).
static func apply(view: Node3D, move: BossSlashAbility, time: float) -> void:
	var pose := sample(move, time)
	var actor: Node3D = view.get_parent()
	var height: float = actor.definition.height
	var skeleton: Skeleton3D = view.skeleton
	var up := actor.global_basis * Vector3.UP
	var right := actor.global_basis * Vector3.RIGHT
	BoxingPose.rotate_bone(skeleton, view.bones["Torso"], up, pose.torso_yaw)
	BoxingPose.rotate_bone(skeleton, view.bones["Torso"], right, pose.torso_pitch)
	BoxingPose.rotate_bone(skeleton, view.bones["Head"], up, pose.head_yaw)
	# Joelho da perna erguida entra para o centro (a base do Buggy é aberta; sem isto a
	# perna sobe para o lado). Positivo em Z leva o pé de um membro esquerdo para +X.
	BoxingPose.rotate_bone(skeleton, view.bones["Thigh_L"], actor.global_basis * Vector3.BACK, pose.knee_in)
	for side in ["L", "R"]:
		var suffix: String = side.to_lower()
		BoxingPose.rotate_bone(skeleton, view.bones["Thigh_" + side], right, pose["thigh_" + suffix])
		BoxingPose.rotate_bone(skeleton, view.bones["Shin_" + side], right, pose["shin_" + suffix])
	# IK depois do tronco: os ombros já estão onde o giro os levou.
	BoxingPose.arm(view, "R", actor.to_global(pose.arm_r * height), actor.global_basis * Vector3(0.6, -1, 0.3))
	BoxingPose.arm(view, "L", actor.to_global(pose.arm_l * height), actor.global_basis * Vector3(-0.5, -1, 0))
