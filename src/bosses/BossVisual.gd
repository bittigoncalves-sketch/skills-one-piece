class_name BossVisual
extends Node3D
var actor: Node3D
var model: Node3D
var skeleton: Skeleton3D
var animator: ProceduralAnimator
var telegraph: BossTelegraph
var hand_binding := BossHandBinding.new()
var model_base: Transform3D
var _reaction_pose: Dictionary = {}
var _reaction_display := 0.0
var _reaction_phase := ""
var _dash_weight := 0.0
var _tuck_weight := 0.0
var _dash_local := Vector3.ZERO
var bones: Dictionary = {}
var _valid := false
var _display_elapsed := 0.0
var _display_sequence := -1
var _sound_sequence := -1
var _wave_sequence := -1

func setup(owner_actor: Node3D) -> void:
	actor = owner_actor
	var data: Dictionary = actor.definition.visual.instantiate_visual()
	if data.is_empty():
		push_error("Visual do Boss não pôde ser montado")
		return
	model = data.node
	add_child(model)
	var bounds := PlayerModelKit.model_aabb(model)
	var factor: float = actor.definition.height / maxf(bounds.size.y, 0.01)
	model.scale = Vector3.ONE * factor
	model.position.y = -actor.definition.height * 0.5 - bounds.position.y * factor
	model_base = model.transform
	skeleton = BodyScanner._find_skeleton(model)
	var profile := BodyScanner.scan(model)
	animator = ProceduralAnimator.new()
	add_child(animator)
	animator.setup(profile)
	for role in actor.definition.visual.bone_map:
		bones[role] = skeleton.find_bone(actor.definition.visual.bone_map[role])
	for side in ["L", "R"]:
		bones["Hand_" + side] = skeleton.find_bone(actor.definition.visual.hand_bones.get(side, ""))
	_valid = bones["Hand_L"] >= 0 and bones["Hand_R"] >= 0
	telegraph = BossTelegraph.new()
	telegraph.name = "ReachTelegraph"
	add_child(telegraph)
	hand_binding.setup(self)
	present(0.0)

func present(delta: float) -> void:
	if not _valid:
		return
	hand_binding.present()
	if actor.dead:
		telegraph.visible = false
		model.rotation.x = -PI * 0.5
		model.position.y = -actor.definition.height * 0.5 + 0.25
		return
	animator.update(actor.net_velocity, actor.reaction == "", false, delta, 0.0, false, false, "", "", false, 0.0, 0.0, -1, 0.0,
		"dano" if actor.state == "stunned" and actor.reaction == "" else "")
	if actor.action_sequence != _display_sequence:
		_display_sequence = actor.action_sequence
		_display_elapsed = actor.action_elapsed
		if actor.action_id != "" and not current_move() is BossSlashAbility:
			_aim_telegraph()
	if actor.authoritative():
		_display_elapsed = actor.action_elapsed
	else:
		# Suaviza até dois intervalos de snapshot, sem criar eventos de combate.
		_display_elapsed = minf(maxf(_display_elapsed, actor.action_elapsed) + delta, actor.action_elapsed + 2.0 / 30.0)
	var move := current_move()
	if actor.action_id != "" and actor.action_elapsed >= move.windup and _sound_sequence != actor.action_sequence:
		_sound_sequence = actor.action_sequence
		AudioFX.whoosh(actor.get_parent(), hand_position(move.hand), 1.15)
	var time := _display_elapsed if actor.action_id != "" else -1.0
	if move is BossSlashAbility and actor.action_id != "":
		_present_slash(move)
	telegraph.present(move, time, actor.state == "stunned" or actor.reaction != "")
	pose_at(time)
	_present_reaction(delta)
	_present_mobility(delta)

## Recepção de M1 por cima da guarda. No cliente o tempo da fase é suavizado como
## o do golpe; a pose mistura entre fases, então nenhuma troca de fase dá estalo.
## Dash: o corpo inclina para o lado do deslocamento, girando pelos pés. Pulo: as
## pernas recolhem; no segundo impulso recolhem mais. Pesos suavizados, então a
## pose entra e sai sem estalo mesmo com o estado chegando por snapshot.
func _present_mobility(delta: float) -> void:
	var dash_goal := 1.0 if actor.mobility == BossMobility.DASH else 0.0
	var tuck_goal := 0.0
	if actor.mobility == BossMobility.JUMP:
		tuck_goal = 1.0 if actor.jumps_used >= 2 else 0.6
	_dash_weight = lerpf(_dash_weight, dash_goal, 1.0 - exp(-(40.0 if dash_goal > _dash_weight else 12.0) * delta))
	_tuck_weight = lerpf(_tuck_weight, tuck_goal, 1.0 - exp(-18.0 * delta))
	if _dash_weight > 0.001 and actor.dash_direction.length_squared() > 0.001:
		_dash_local = (actor.global_basis.orthonormalized().inverse() * actor.dash_direction).normalized()
	var skeleton_right := actor.global_basis * Vector3.RIGHT
	if _tuck_weight > 0.001:
		for side in ["L", "R"]:
			BoxingPose.rotate_bone(skeleton, bones["Thigh_" + side], skeleton_right, 1.35 * _tuck_weight)
			BoxingPose.rotate_bone(skeleton, bones["Shin_" + side], skeleton_right, -1.9 * _tuck_weight)
	if _dash_weight > 0.001 and _dash_local.length_squared() > 0.001:
		var feet := Vector3(0, -actor.definition.height * 0.5, 0)
		var axis := Vector3.UP.cross(_dash_local).normalized()
		var lean := Transform3D(Basis(), feet) * Transform3D(Basis(axis, 0.32 * _dash_weight), Vector3.ZERO) * Transform3D(Basis(), -feet)
		model.transform = lean * model.transform

func _present_reaction(delta: float) -> void:
	if actor.reaction != _reaction_phase or actor.authoritative():
		_reaction_phase = actor.reaction
		_reaction_display = actor.reaction_elapsed
	else:
		_reaction_display = minf(maxf(_reaction_display, actor.reaction_elapsed) + delta, actor.reaction_elapsed + 2.0 / 30.0)
	BossReactionPose.blend(_reaction_pose, BossReactionPose.target(actor.reaction, _reaction_display, actor.reaction_count), delta)
	BossReactionPose.apply(self, _reaction_pose)

## Linha do corte: refeita a cada quadro enquanto aparece (no servidor a mira já
## travou; no cliente a rotação replicada assenta em um ou dois snapshots). O
## cliente cria a própria frente, só visual, quando o lançamento chega.
func _present_slash(move: BossSlashAbility) -> void:
	if actor.action_elapsed >= move.aim_time and actor.action_elapsed < move.windup:
		var path := BossCombat.slash_path(actor, move)
		# A cápsula soma o raio nas pontas; recolhe para a marca não passar da parede.
		var inset: Vector3 = (path[1] - path[0]).normalized() * minf(move.width * 0.5, path[0].distance_to(path[1]) * 0.5)
		telegraph.aim(path[0] + inset, path[1] - inset, move.width * 0.5, actor.global_position.y - actor.definition.height * 0.5)
	if not actor.authoritative() and _wave_sequence != actor.action_sequence \
			and actor.action_elapsed >= move.windup and actor.action_elapsed < move.windup + move.active + 0.1:
		_wave_sequence = actor.action_sequence
		BossCombat.spawn_wave(actor, move)

func current_move() -> BossAbility:
	return actor.definition.move_for(actor.action_id)

## A marca usa o MESMO caminho que a varredura de dano amostra: mão no início do
## contato até a extensão completa. Resolvido uma vez por soco, com a rotação já
## comprometida; o `pose_at` do final de `present` recoloca a pose exibida.
func _aim_telegraph() -> void:
	var move := current_move()
	pose_at(move.windup)
	var start := hand_position(move.hand)
	pose_at(move.windup + move.active * 0.6)
	var finish := hand_position(move.hand)
	if move is BossDetachedAbility:
		var trajectory := BossDetachedAttack.path(actor, move)
		start = trajectory[0]
		finish = trajectory[1]
	telegraph.aim(start, finish, move.hit_radius, actor.global_position.y - actor.definition.height * 0.5)

func pose_at(time: float) -> void:
	if not _valid:
		return
	# O driver restaura a base antes de cada amostra; IK não acumula erro. O modelo
	# volta ao repouso também: a IK mira em espaço do ator, e o giro de corpo da
	# recepção (BossReactionPose) é reaplicado por último em `present`.
	model.transform = model_base
	if animator._driver:
		animator._driver.push()
	var ability := current_move()
	if ability is BossDetachedAbility:
		var extension := smoothstep(ability.windup * 0.7, ability.windup, time) if time >= 0 else 0.0
		var recover_at: float = ability.windup + ability.active + ability.return_time
		if time > recover_at:
			extension = 1.0 - smoothstep(recover_at, ability.duration(), time)
		BoxingPose.apply(self, "R", extension, 0.0, extension, 0.0)
		return
	if ability is BossSlashAbility:
		BossThrowPose.apply(self, ability, time)
		return
	var extension := 0.0
	var preparation := 0.0
	# Tórax em curvas CONTÍNUAS entre fases: a carga some enquanto o braço estende e
	# o giro volta atrasado em relação ao braço na recuperação.
	var turn := 0.0
	var torso_load := 0.0
	if time >= 0 and time < ability.windup:
		preparation = smoothstep(0, ability.windup, time)
		torso_load = preparation
	elif time >= ability.windup and time < ability.windup + ability.active:
		extension = smoothstep(0, ability.active * 0.6, time - ability.windup)
		torso_load = 1.0 - extension
		turn = extension
	elif time >= ability.windup + ability.active:
		var recovering := time - ability.windup - ability.active
		extension = 1.0 - smoothstep(0, ability.recovery * 0.6, recovering)
		turn = 1.0 - smoothstep(ability.recovery * 0.15, ability.recovery * 0.9, recovering)
	BoxingPose.apply(self, ability.hand, extension, preparation, turn, torso_load)

func hand_position(side: String = "L") -> Vector3:
	return BoxingPose.bone_position(skeleton, bones["Hand_" + side]) if _valid else global_position
