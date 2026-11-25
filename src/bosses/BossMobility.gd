class_name BossMobility
extends RefCounted
## Dash de esquiva e pulo duplo do Boss. Autoridade do servidor.
##
## - DASH: quando a área de detecção vê um projétil do jogador que vai acertar, o
##   Boss dispara de lado (perpendicular ao voo), para longe da linha. Recarga
##   própria; não sai no meio do próprio golpe, paralisado ou no ar.
## - PULO DUPLO: segundo impulso no ar. Usado para (1) pular projétil rasteiro
##   quando o dash está em recarga ou sem lado seguro, (2) alcançar jogador em lugar
##   alto e (3) cruzar buraco que o alvo deixou do outro lado.
##
## Estado replicado em BossActor: `mobility`, `mobility_elapsed`, `jumps_used`,
## `dash_direction`. A apresentação só lê esses campos.
const DASH := "dash"
const JUMP := "jump"

const DASH_DISTANCE := 4.0
const DASH_TIME := 0.22
const DASH_COOLDOWN := 3.0
const JUMP_VELOCITY := 12.0
const DOUBLE_JUMP_VELOCITY := 10.0
## Um projétil com o ponto de passagem até esta altura acima dos pés é "rasteiro".
const LOW_HEIGHT := 1.3
## Diferença de piso a partir da qual o alvo está "no alto" e o Boss pula.
const HIGH_GROUND := 0.7
const HIGH_GROUND_REACH := 4.0
## Maior buraco que o pulo duplo cruza (os pequenos da arena têm 10 m).
const MAX_GAP := 11.0
const GAP_SCAN := 14.0
const LANDING_CLEARANCE := 1.2
const MAX_LEAP_SPEED := 11.0

var dash_cooldown := 0.0
var _jump_horizontal := Vector3.ZERO
var _double_at_apex := false
var _was_airborne := false

func controlling(actor: Node) -> bool:
	return actor.mobility != ""

## Chamado todo tick antes da decisão. Devolve true quando a mobilidade dirige o
## deslocamento horizontal neste quadro.
func tick(actor: CharacterBody3D, delta: float, sensor: BossProjectileSensor, can_react: bool) -> bool:
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if actor.mobility != "":
		actor.mobility_elapsed += delta
	match actor.mobility:
		DASH:
			actor.velocity.x = actor.dash_direction.x * DASH_DISTANCE / DASH_TIME
			actor.velocity.z = actor.dash_direction.z * DASH_DISTANCE / DASH_TIME
			if actor.mobility_elapsed >= DASH_TIME:
				actor.mobility = ""
				actor.velocity.x = 0.0
				actor.velocity.z = 0.0
		JUMP:
			actor.velocity.x = _jump_horizontal.x
			actor.velocity.z = _jump_horizontal.z
			if _double_at_apex and actor.jumps_used == 1 and actor.velocity.y <= 0.0:
				double_jump(actor)
	if can_react and sensor != null:
		_react(actor, sensor)
	return actor.mobility != ""

## Depois do move_and_slide: pouso encerra o pulo e devolve os dois impulsos.
func after_move(actor: CharacterBody3D) -> void:
	var airborne := not actor.is_on_floor()
	if actor.mobility == JUMP and not airborne and _was_airborne and actor.velocity.y <= 0.0:
		land(actor)
	elif not airborne and actor.mobility != JUMP:
		actor.jumps_used = 0
	_was_airborne = airborne

func cancel(actor: Node) -> void:
	if actor.mobility == DASH:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
	actor.mobility = ""
	_jump_horizontal = Vector3.ZERO
	_double_at_apex = false

func land(actor: Node) -> void:
	actor.mobility = ""
	actor.jumps_used = 0
	_jump_horizontal = Vector3.ZERO
	_double_at_apex = false

# ---------------------------------------------------------------- esquiva
func _react(actor: CharacterBody3D, sensor: BossProjectileSensor) -> void:
	var threat := sensor.most_urgent()
	if threat.is_empty():
		return
	var low: bool = float(threat.height) <= LOW_HEIGHT
	if actor.is_on_floor() and actor.mobility == "":
		if dash_cooldown <= 0.0:
			var side := dodge_direction(actor, threat)
			if side != Vector3.ZERO:
				start_dash(actor, side)
				return
		if low:
			jump(actor, Vector3.ZERO, true)
	elif actor.mobility == JUMP and actor.jumps_used == 1 and low:
		# Ainda vai acertar no ar: o segundo impulso tira os pés da linha.
		double_jump(actor)

## Lado da esquiva: perpendicular ao voo, para longe da linha; o outro lado se o
## primeiro cai em buraco ou bate em parede. ZERO = sem lado seguro.
static func dodge_direction(actor: CharacterBody3D, threat: Dictionary) -> Vector3:
	var flight: Vector3 = Vector3(threat.velocity.x, 0.0, threat.velocity.z)
	if flight.length_squared() < 0.0001:
		return Vector3.ZERO
	var side := Vector3.UP.cross(flight.normalized())
	var from_line: Vector3 = actor.global_position - threat.point
	from_line.y = 0.0
	var first := side if from_line.dot(side) >= 0.0 else -side
	for candidate in [first, -first]:
		if dash_is_safe(actor, candidate):
			return candidate
	return Vector3.ZERO

static func dash_is_safe(actor: CharacterBody3D, direction: Vector3) -> bool:
	var width: float = actor.definition.width
	for step in [0.5, 1.0]:
		var point: Vector3 = actor.global_position + direction * DASH_DISTANCE * step
		if MapBuilder.is_hole_area(point.x, point.z, width, width):
			return false
	# Levantado 8 cm: apoiada no chão, a cápsula acusa colisão com o próprio piso e
	# todo lado parecia bloqueado (medido: nenhum dash saía).
	var raised := actor.global_transform.translated(Vector3.UP * 0.08)
	return not actor.test_move(raised, direction * DASH_DISTANCE)

func start_dash(actor: CharacterBody3D, direction: Vector3) -> void:
	actor.combat.cancel("dash")
	actor.mobility = DASH
	actor.mobility_elapsed = 0.0
	actor.dash_direction = direction
	dash_cooldown = DASH_COOLDOWN
	actor.state = DASH

# ---------------------------------------------------------------- pulo
func jump(actor: CharacterBody3D, horizontal: Vector3, double_at_apex: bool) -> void:
	actor.combat.cancel("jump")
	actor.mobility = JUMP
	actor.mobility_elapsed = 0.0
	actor.jumps_used = 1
	actor.velocity.y = JUMP_VELOCITY
	_jump_horizontal = horizontal
	_double_at_apex = double_at_apex
	_was_airborne = false
	actor.state = JUMP

func double_jump(actor: CharacterBody3D) -> bool:
	if actor.mobility != JUMP or actor.jumps_used >= 2:
		return false
	actor.jumps_used = 2
	actor.velocity.y = DOUBLE_JUMP_VELOCITY
	_double_at_apex = false
	return true

## Tempo de voo até cair de volta à altura `height` (acima do ponto de partida),
## com ou sem o segundo impulso no ápice. INF se não alcança.
static func air_time(gravity: float, height: float, use_double: bool) -> float:
	var apex_time := JUMP_VELOCITY / gravity
	var peak := JUMP_VELOCITY * JUMP_VELOCITY / (2.0 * gravity)
	var elapsed := apex_time
	if use_double:
		elapsed += DOUBLE_JUMP_VELOCITY / gravity
		peak += DOUBLE_JUMP_VELOCITY * DOUBLE_JUMP_VELOCITY / (2.0 * gravity)
	if peak < height:
		return INF
	return elapsed + sqrt(2.0 * (peak - height) / gravity)

static func peak_height(gravity: float, use_double: bool) -> float:
	var peak := JUMP_VELOCITY * JUMP_VELOCITY / (2.0 * gravity)
	if use_double:
		peak += DOUBLE_JUMP_VELOCITY * DOUBLE_JUMP_VELOCITY / (2.0 * gravity)
	return peak

## Alvo num lugar alto e perto: pula até ele (duplo se preciso). true se pulou.
func try_high_ground(actor: CharacterBody3D, target: Node3D) -> bool:
	if not actor.is_on_floor() or actor.mobility != "":
		return false
	var rise := ground_below(actor, target) - floor_height(actor)
	var offset := target.global_position - actor.global_position
	offset.y = 0.0
	var distance := offset.length()
	if rise < HIGH_GROUND or distance > HIGH_GROUND_REACH or distance < 0.05:
		return false
	var gravity: float = actor.definition.gravity
	var use_double := peak_height(gravity, false) < rise + 0.4
	var time := air_time(gravity, rise + 0.2, use_double)
	if not is_finite(time):
		return false
	# Pousa ao lado do alvo, dentro do alcance dos punhos.
	var travel := maxf(0.0, distance - actor.definition.attack_distance * 0.8)
	jump(actor, offset.normalized() * minf(MAX_LEAP_SPEED, travel / time), use_double)
	return true

## Buraco no caminho do alvo: cruza com o pulo duplo se ele cabe e o outro lado é
## chão firme. true se pulou.
func try_cross_gap(actor: CharacterBody3D, target: Node3D) -> bool:
	if not actor.is_on_floor() or actor.mobility != "":
		return false
	var offset := target.global_position - actor.global_position
	offset.y = 0.0
	if offset.length() < 2.0:
		return false
	var direction := offset.normalized()
	var gap := gap_ahead(actor.global_position, direction, actor.definition.width)
	if gap.is_empty() or float(gap.start) > 1.5 or float(gap.width) > MAX_GAP or offset.length() < float(gap.end):
		return false
	var gravity: float = actor.definition.gravity
	var time := air_time(gravity, 0.0, true)
	var travel: float = float(gap.end) + LANDING_CLEARANCE
	var speed := travel / time
	if speed > MAX_LEAP_SPEED:
		return false
	jump(actor, direction * speed, true)
	return true

## Primeiro trecho de buraco à frente: {start, end, width} em metros, ou {} se o
## caminho é firme ou se o outro lado não tem LANDING_CLEARANCE de chão.
static func gap_ahead(origin: Vector3, direction: Vector3, width: float) -> Dictionary:
	var step := 0.25
	var start := -1.0
	var distance := 0.0
	while distance <= GAP_SCAN:
		var point: Vector3 = origin + direction * distance
		var hole := MapBuilder.is_hole_area(point.x, point.z, width, width)
		if hole and start < 0.0:
			start = distance
		elif not hole and start >= 0.0:
			for extra in [0.5, LANDING_CLEARANCE]:
				var landing: Vector3 = origin + direction * (distance + extra)
				if MapBuilder.is_hole_area(landing.x, landing.z, width, width):
					return {}
			return {"start": start, "end": distance, "width": distance - start}
		distance += step
	return {}

## Altura do CHÃO embaixo do corpo (raio para baixo, ignorando personagens). Um
## jogador no meio de um pulo continua "no nível" do chão de onde saiu: sem isto o
## Boss pularia junto toda vez que o alvo pulasse perto dele.
static func ground_below(actor: CharacterBody3D, body: Node3D) -> float:
	var space := actor.get_world_3d().direct_space_state
	var exclude: Array[RID] = [actor.get_rid()]
	var from := body.global_position
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0, 15, exclude)
	for _i in 8:
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			return floor_height(body)
		if hit.collider.has_method("take_damage"):
			var skip := ray.exclude
			skip.append(hit.rid)
			ray.exclude = skip
			continue
		return (hit.position as Vector3).y
	return floor_height(body)

static func floor_height(body: Node3D) -> float:
	if body.has_method("topo_da_cabeca"):
		# Colisor do jogador centrado na origem: piso = y − (topo − y). Respeita a
		# escala da raça sem ler constante do Player.
		return 2.0 * body.global_position.y - float(body.call("topo_da_cabeca"))
	if "definition" in body:
		return body.global_position.y - body.definition.height * 0.5
	return body.global_position.y
