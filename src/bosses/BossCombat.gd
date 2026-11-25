class_name BossCombat
extends Node
## Combo = sequência de golpes da definição (ability + followups). Cada soco é um
## cast próprio: hitbox, orçamento de dano e direção nascem e morrem com ele.
const Sweep = preload("res://src/combat/SwordSweep.gd")
var actor: Node3D
var cooldown_remaining := 0.0
var slash_cooldown_remaining := 0.0
## Quão rápido a mira acompanha o alvo antes de travar (1/s, exponencial).
const SLASH_TURN_RATE := 12.0
const SLASH_GROUP := "boss_slash"
## Passo à frente durante preparação e contato de cada soco (m/s).
const STEP_SPEED := 5.0
var _zone: DamageZone
var _spec: DamageSpec
var _target: Node3D
var _move: BossAbility
var _launched: Dictionary = {}
var detached := BossDetachedAttack.new()

func setup(owner_actor: Node3D) -> void:
	actor = owner_actor
	detached.actor = owner_actor

func busy() -> bool:
	return actor.action_id != ""

func begin(target: Node3D) -> bool:
	if not actor.authoritative() or actor.dead or actor.part_state != "attached" or busy() or cooldown_remaining > 0 or not BossBrain.alive(target):
		return false
	_target = target
	_start_move(0)
	return true

## Corte contra alvo em fuga. A mira acompanha até `aim_time`, depois trava.
func begin_slash(target: Node3D) -> bool:
	var data: BossSlashAbility = actor.definition.slash
	if data == null or not actor.authoritative() or actor.dead or actor.part_state != "attached" or busy() or slash_cooldown_remaining > 0 or not BossBrain.alive(target):
		return false
	_target = target
	_move = data
	actor.combo_index = -1
	actor.action_id = str(data.id)
	actor.action_elapsed = 0.0
	actor.action_sequence += 1
	actor.state = "windup"
	_face(target, 1.0)
	return true

func _face(target: Node3D, weight: float) -> void:
	var direction := target.global_position - actor.global_position
	direction.y = 0
	if direction.length_squared() > 0.0001:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-direction.x, -direction.z), weight)

func _tick_slash(delta: float) -> void:
	var data: BossSlashAbility = _move
	var previous: float = actor.action_elapsed
	actor.action_elapsed += delta
	var current: float = actor.action_elapsed
	if current < data.aim_time:
		_face(_target, 1.0 - exp(-SLASH_TURN_RATE * delta))
	elif previous < data.aim_time:
		# Última correção: daqui em diante a direção (e a linha no chão) não muda.
		_face(_target, 1.0)
	if previous < data.windup and current >= data.windup:
		spawn_wave(actor, data)
	if current >= data.duration():
		cancel("finished")
	elif current >= data.windup + data.active:
		actor.state = "recovery"
	elif current >= data.windup:
		actor.state = "active"
	else:
		actor.state = "windup"

## Origem da frente: à frente do corpo, na altura do tronco.
static func slash_origin(owner_actor: Node3D, data: BossSlashAbility) -> Vector3:
	var forward := -owner_actor.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var floor_y: float = owner_actor.global_position.y - owner_actor.definition.height * 0.5
	var body_width: float = owner_actor.definition.width
	var origin: Vector3 = owner_actor.global_position + forward * (body_width * 0.5 + 0.3)
	origin.y = floor_y + data.height_above_floor
	return origin

## Trecho que o corte percorre: da origem até o alcance ou a primeira parede.
## Personagens não bloqueiam (a frente os atravessa); cenário sim.
static func slash_path(owner_actor: CollisionObject3D, data: BossSlashAbility) -> Array[Vector3]:
	var origin := slash_origin(owner_actor, data)
	var forward := -owner_actor.global_basis.z
	forward.y = 0
	var finish := origin + forward.normalized() * data.slash_range
	var ray := PhysicsRayQueryParameters3D.create(origin, finish, 15, [owner_actor.get_rid()])
	var space := owner_actor.get_world_3d().direct_space_state
	for _i in 16:
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			break
		if hit.collider.has_method("take_damage"):
			var skip := ray.exclude
			skip.append(hit.rid)
			ray.exclude = skip
			continue
		finish = hit.position
		break
	return [origin, finish]

## Cria a frente. No servidor ela aplica dano; nos clientes é só apresentação
## (YoruWave confere a autoridade antes de chamar o CombatResolver).
static func spawn_wave(owner_actor: Node3D, data: BossSlashAbility) -> Node3D:
	var wave := YoruWave.new()
	wave.add_to_group(SLASH_GROUP)
	owner_actor.get_tree().current_scene.add_child(wave)
	wave.global_position = slash_origin(owner_actor, data)
	var forward := -owner_actor.global_basis.z
	forward.y = 0
	wave.setup(owner_actor, str(data.id), forward.normalized(), {
		"damage": data.damage, "kb": data.knockback, "hitstun": data.hitstun, "width": data.width,
		"speed": data.speed, "range": data.slash_range, "ground": false,
		"edge_color": data.edge_color, "core_color": data.core_color,
	})
	AudioFX.whoosh(owner_actor.get_parent(), wave.global_position, 0.75)
	return wave

func _start_move(index: int) -> void:
	_move = actor.definition.moves()[index]
	actor.combo_index = index
	actor.action_id = str(_move.id)
	actor.action_elapsed = 0.0
	actor.action_sequence += 1
	actor.state = "windup"
	# A direção fica comprometida na preparação de CADA soco. Não lê input do jogador.
	var direction := _target.global_position - actor.global_position
	direction.y = 0
	if direction.length_squared() > 0.0001:
		actor.rotation.y = atan2(-direction.x, -direction.z)
	if not _move is BossDetachedAbility:
		_spec = DamageSpec.criar(DamageSpec.Tipo.UNICO, _move.damage, _move.damage).para_cast()

func tick(delta: float) -> void:
	if not actor.authoritative():
		return
	cooldown_remaining = maxf(0, cooldown_remaining - delta)
	slash_cooldown_remaining = maxf(0, slash_cooldown_remaining - delta)
	if not busy() or actor.dead:
		return
	if _move is BossDetachedAbility:
		_tick_detached(delta)
		return
	if _move is BossSlashAbility:
		# Depois de lançado, o corte não depende mais do alvo.
		if actor.action_elapsed < _move.windup and not BossBrain.alive(_target):
			cancel("target_lost")
		else:
			_tick_slash(delta)
		return
	if not BossBrain.alive(_target):
		cancel("target_lost")
		return
	var data := _move
	var previous: float = actor.action_elapsed
	actor.action_elapsed += delta
	var current: float = actor.action_elapsed
	# Interseção temporal: um frame longo não perde a janela inteira do soco.
	var start := maxf(previous, data.windup)
	var end := minf(current, data.windup + data.active)
	if end > start:
		_sample_contact(start, end, data)
		if not busy() or actor.dead:
			return
	if current >= data.duration():
		# O excedente do tick não é repassado: o próximo soco começa no tick seguinte.
		_next_or_finish()
	elif current >= data.windup + data.active:
		actor.state = "recovery"
	elif current >= data.windup:
		actor.state = "active"
	else:
		actor.state = "windup"

func _next_or_finish() -> void:
	var next: int = actor.combo_index + 1
	if next < actor.definition.moves().size() and _can_chain(actor.definition.moves()[next]):
		_release_hit()
		_start_move(next)
	else:
		cancel("finished")

func _can_chain(next_move: BossAbility) -> bool:
	var offset := _target.global_position - actor.global_position
	offset.y = 0
	if next_move is BossDetachedAbility:
		return detached.available() and offset.length() <= next_move.distance and BossBrain.visible(actor, _target)
	return offset.length() <= actor.definition.combo_break_distance and BossBrain.visible(actor, _target)

func _sample_contact(start: float, end: float, data: BossAbility) -> void:
	if not is_instance_valid(_zone):
		_zone = DamageZone.new()
		_zone.name = "BossJabHitbox"
		add_child(_zone)
		_zone.setup(data.damage, data.knockback, Vector3.ZERO, data.duration() + 1, actor, data.hit_radius, null, data.hitstun)
		_zone.monitoring = false
		_zone.exige_linha_de_visao = true
		_zone.origem_linha_de_visao = actor.global_position
		_zone.override_kb_dir = -actor.global_basis.z
		_spec.marcar(_zone)
	var view: BossVisual = actor.presentation
	view.pose_at(start)
	var before := view.hand_position(data.hand)
	var count := maxi(1, ceili((end - start) / (1.0 / 120.0)))
	for i in range(1, count + 1):
		view.pose_at(lerpf(start, end, float(i) / count))
		var after := view.hand_position(data.hand)
		_zone.global_position = after
		for hit in Sweep.contacts(actor.get_world_3d().direct_space_state, before, after, data.hit_radius, 15, [actor.get_rid()]):
			if hit.body.is_in_group("player"):
				_zone._on_body(hit.body)
				launch_if_hit(hit.body, data, _zone)
				if not busy() or not is_instance_valid(_zone):
					return
		before = after

## Arremessa quem o golpe de fato acertou, uma vez — só se o golpe for o ÚLTIMO que
## sai no combo. O 4º soco e o punho destacado declaram arremesso; o soco só o
## usa quando o punho não vai emendar (recarga de 6 s, parte fora). Assim todo
## combo termina arremessando, e nenhum golpe no meio empurra o alvo para fora.
func launch_if_hit(body: Node, data: BossAbility, zone: DamageZone) -> void:
	if not data.launches() or not is_instance_valid(zone) or not zone._hit.has(body) or _launched.has(body):
		return
	if not data is BossDetachedAbility and _detached_follows():
		return
	_launched[body] = true
	if not body.has_method("receber_arremesso") or float(body.get("health")) <= 0:
		return
	var away: Vector3 = body.global_position - actor.global_position
	away.y = 0
	away = away.normalized() if away.length_squared() > 0.0001 else -actor.global_basis.z
	body.receber_arremesso(away * data.launch_horizontal + Vector3.UP * data.launch_vertical)

func _detached_follows() -> bool:
	var next: int = actor.combo_index + 1
	var moves: Array[BossAbility] = actor.definition.moves()
	return next < moves.size() and moves[next] is BossDetachedAbility and detached.available()

## Passo de boxeador: o punho estendido chega a ~0,97 m do centro, e o combo
## começa/emenda com o alvo a até 1,58 m (encostado na diagonal) ou 2,0 m
## (`combo_break_distance`). Medido: nessas distâncias os socos passavam ao lado.
## Na preparação e no contato o corpo avança até `attack_distance`; a direção do
## soco segue travada, então sair de lado continua desviando. Corte e punho
## destacado não andam.
func step_velocity(delta: float) -> Vector3:
	if _move == null or _move is BossSlashAbility or _move is BossDetachedAbility or delta <= 0 \
			or not BossBrain.alive(_target) or actor.action_elapsed >= _move.windup + _move.active:
		return Vector3.ZERO
	var offset := _target.global_position - actor.global_position
	offset.y = 0
	var excess: float = offset.length() - actor.definition.attack_distance
	if excess <= 0.0:
		return Vector3.ZERO
	return offset.normalized() * minf(STEP_SPEED, excess / delta)

func _release_hit() -> void:
	if _spec:
		CombatResolver.encerrar(_spec.cast_id)
		_spec = null
	if is_instance_valid(_zone):
		_zone.monitoring = false
		_zone.queue_free()
	_zone = null
	_launched.clear()

func _tick_detached(delta: float) -> void:
	var data: BossDetachedAbility = _move
	if actor.action_elapsed < data.windup and not BossBrain.alive(_target):
		cancel("target_lost")
		return
	var previous: float = actor.action_elapsed
	actor.action_elapsed += delta
	if previous < data.windup and actor.action_elapsed >= data.windup:
		detached.launch(data, maxf(0, data.windup - previous))
	if actor.action_elapsed >= data.duration():
		cancel("finished")
	elif actor.action_elapsed >= data.windup + data.active:
		actor.state = "recovery"
	elif actor.action_elapsed >= data.windup:
		actor.state = "active"
	else:
		actor.state = "windup"

func cancel(_reason: String) -> void:
	if actor == null:
		return
	if _reason in ["death", "despawn"]:
		detached.reset()
	else:
		detached.return_now()
	if busy():
		# A pausa pós-combo (ou pós-interrupção) usa o cooldown do golpe em curso.
		if _move is BossSlashAbility:
			slash_cooldown_remaining = _move.cooldown
		else:
			cooldown_remaining = _move.cooldown if _move else actor.definition.ability.cooldown
	actor.action_id = ""
	actor.action_elapsed = 0.0
	actor.combo_index = -1
	if not actor.dead:
		actor.state = "guard"
	_release_hit()
	_target = null
	_move = null
