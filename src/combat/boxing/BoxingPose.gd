class_name BoxingPose
extends RefCounted
## IK de dois segmentos: mantém comprimento dos ossos e mãos fechadas do asset.
## Alvos em coordenadas do corpo (fração da altura); a mão que não golpeia fica no queixo.
const GUARD := {"L": Vector3(-0.13, 0.27, -0.10), "R": Vector3(0.13, 0.28, -0.09)}
const REACH := {"L": Vector3(-0.08, 0.15, -0.59), "R": Vector3(0.08, 0.15, -0.59)}

## Balanço do tórax: carga (torce para trás na preparação), giro para o lado do
## punho e leve inclinação à frente no contato. Aplicado ANTES da IK dos braços,
## então o ombro avança de verdade e soma alcance ao soco; a hitbox e a marca
## amostram esta mesma pose. A cabeça contra-gira para manter os olhos no alvo.
const TORSO_TURN := 0.30
const TORSO_LOAD := 0.14
const TORSO_LEAN := 0.10
const HEAD_COUNTER := 0.7

## `torso_turn`/`torso_load` são curvas contínuas por fase (ver BossVisual.pose_at);
## `extension`/`preparation` continuam movendo só o braço.
static func apply(view: Node3D, side: String, extension: float, preparation: float, torso_turn: float = 0.0, torso_load: float = 0.0) -> void:
	var actor: Node3D = view.get_parent()
	var height: float = actor.definition.height
	# Giro positivo em Y leva o ombro DIREITO à frente; o esquerdo pede o negativo.
	var turn_sign := -1.0 if side == "L" else 1.0
	var twist := turn_sign * (TORSO_TURN * torso_turn - TORSO_LOAD * torso_load)
	# Rotação negativa em X leva o topo do tronco para a frente (-Z).
	var lean := -TORSO_LEAN * torso_turn + TORSO_LEAN * 0.3 * torso_load
	var up := actor.global_basis * Vector3.UP
	var right := actor.global_basis * Vector3.RIGHT
	rotate_bone(view.skeleton, view.bones["Torso"], up, twist)
	rotate_bone(view.skeleton, view.bones["Torso"], right, lean)
	rotate_bone(view.skeleton, view.bones["Head"], up, -twist * HEAD_COUNTER)
	for hand in ["L", "R"]:
		var target: Vector3 = GUARD[hand] * height
		if hand == side:
			# Jab curto e reto, sem perseguir o alvo depois do compromisso.
			target = target.lerp(REACH[hand] * height, extension)
			target.z += preparation * 0.10
			target.y += preparation * 0.025
		var outward := -0.5 if hand == "L" else 0.5
		arm(view, hand, actor.to_global(target), actor.global_basis * Vector3(outward, -1, 0))

static func arm(view: Node3D, side: String, target: Vector3, pole: Vector3) -> void:
	var skeleton: Skeleton3D = view.skeleton
	var upper: int = view.bones["UpperArm_" + side]
	var lower: int = view.bones["ForeArm_" + side]
	var hand: int = view.bones["Hand_" + side]
	var shoulder := bone_position(skeleton, upper)
	var elbow := bone_position(skeleton, lower)
	var wrist := bone_position(skeleton, hand)
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var difference := target - shoulder
	var distance := clampf(difference.length(), absf(a - b) + 0.001, a + b - 0.001)
	var direction := difference.normalized()
	var projected := pole - direction * pole.dot(direction)
	if projected.length_squared() < 0.001:
		projected = direction.cross(Vector3.RIGHT)
	var along := (a * a - b * b + distance * distance) / (2 * distance)
	var elbow_target := shoulder + direction * along + projected.normalized() * sqrt(maxf(0, a * a - along * along))
	align(skeleton, upper, elbow - shoulder, elbow_target - shoulder)
	elbow = bone_position(skeleton, lower)
	wrist = bone_position(skeleton, hand)
	align(skeleton, lower, wrist - elbow, shoulder + direction * distance - elbow)

## Gira um osso em torno de um eixo GLOBAL, preservando a pose do quadro.
static func rotate_bone(skeleton: Skeleton3D, index: int, world_axis: Vector3, angle: float) -> void:
	if index < 0 or absf(angle) < 0.0001:
		return
	var world_rotation := skeleton.global_basis.orthonormalized()
	var axis := (world_rotation.inverse() * world_axis).normalized()
	var pose := skeleton.get_bone_global_pose(index)
	var desired := Basis(axis, angle) * pose.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		desired = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * desired
	skeleton.set_bone_pose_rotation(index, desired.get_rotation_quaternion())

static func bone_position(skeleton: Skeleton3D, index: int) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin

static func align(skeleton: Skeleton3D, index: int, current: Vector3, wanted: Vector3) -> void:
	if current.length_squared() < 0.000001 or wanted.length_squared() < 0.000001:
		return
	var delta := Basis(Quaternion(current.normalized(), wanted.normalized()))
	var world_rotation := skeleton.global_basis.orthonormalized()
	var pose := skeleton.get_bone_global_pose(index)
	var desired := world_rotation.inverse() * delta * world_rotation * pose.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		desired = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * desired
	skeleton.set_bone_pose_rotation(index, desired.get_rotation_quaternion())
