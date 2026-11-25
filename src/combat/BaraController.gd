extends Node3D
## Uma ação corporal autoritativa; as cópias recebem o estado das mesmas mãos.
const BINDING := preload("res://src/characters/BaraHandBinding.gd")
const VFX := preload("res://src/effects/BaraVfx.gd")
const AUDIO := preload("res://src/effects/BaraAudio.gd")
const SWEEP := preload("res://src/combat/SwordSweep.gd")
const DURATIONS := {"Z": 1.12, "X": 1.5, "C": 2.3, "V": 3.15}
const STARTS := [0.60, 0.95, 1.30, 1.65, 2.10]
const BLAST_RADIUS := 3.5
var owner_actor: Node3D
var slot := "Z"
var aim := Vector3.FORWARD
var origin := Vector3.ZERO
var cast_token := 0
var elapsed := 0.0
var damage_spec: DamageSpec
var binding: RefCounted
var hands: Array[Dictionary] = []
var _zones: Array[DamageZone] = []
var _emitted := 0
var _sync_time := 0.0
var _cancelled := false
var _cancel_time := 0.0
var _finished := false
var _cannon: Node3D
var _ball: Node3D
var _ball_position := Vector3.ZERO
var _ball_start := Vector3.ZERO
var _ball_active := false
var _warning: Node3D
var _last_visual: Array[Transform3D] = []

static func action_for(actor: Node) -> Node:
	if not is_instance_valid(actor): return null
	var action = (actor.get_meta("bara_action") if actor.has_meta("bara_action") else null)
	return action if is_instance_valid(action) and not action.is_queued_for_deletion() else null

static func binding_for(actor: Node3D) -> RefCounted:
	var model = actor.get("_char_model")
	var old = (actor.get_meta("bara_binding") if actor.has_meta("bara_binding") else null)
	if old != null and (actor.get_meta("bara_binding_model") if actor.has_meta("bara_binding_model") else null) == model:
		return old
	if old != null: old.dispose()
	var next: RefCounted = BINDING.new()
	next.setup(actor)
	actor.set_meta("bara_binding", next)
	actor.set_meta("bara_binding_model", model)
	return next

static func validation_reason(actor: Node3D, wanted: String, direction: Vector3) -> String:
	if not DURATIONS.has(wanted): return "Técnica desconhecida."
	if not direction.is_finite() or direction.length_squared() < 0.001: return "Mira inválida."
	if str(actor.get("current_fruit_id")) != "bara_bara" or str(actor.get("combat_mode")) != "fruit": return "Equipe a Bara Bara."
	if float(actor.get("health")) <= 0 or actor.get("is_suppressed") == true: return "Poder indisponível."
	if actor.get_meta("is_frozen", false) or actor.get_meta("in_black_hole", false) or actor.get_meta("in_kurouzu", false) or actor.get_meta("in_vortex", false): return "Movimento impedido."
	if actor.has_method("fruta_bloqueada_por_dano") and actor.fruta_bloqueada_por_dano(): return "Recuperando do dano."
	if action_for(actor) != null or actor.get_meta("is_casting", false): return "Aguarde a recomposição."
	if wanted != "C" and not binding_for(actor).valid: return "Avatar sem mãos separáveis."
	return ""

static func cast(parent: Node, wanted: String, direction: Vector3, at: Vector3,
		actor: Node3D, spec: DamageSpec, token: int) -> Node3D:
	var existing := action_for(actor)
	if existing != null: return existing
	var effect: Node3D = load("res://src/combat/BaraController.gd").new()
	effect.name = "Bara_" + wanted
	effect.owner_actor = actor
	effect.slot = wanted
	effect.aim = direction.normalized()
	effect.origin = at
	effect.cast_token = token
	effect.damage_spec = spec
	parent.add_child(effect)
	return effect

func _ready() -> void:
	add_to_group("bara_effect")
	owner_actor.set_meta("bara_action", self)
	owner_actor.set_meta("bara_pending_until", 0)
	owner_actor.set_meta("is_casting", true)
	owner_actor.set_meta("active_skill", slot)
	owner_actor.set_meta("custom_pose", "bara_" + slot.to_lower())
	owner_actor.set_meta("bara_pose_t", 0.0)
	if owner_actor.has_method("pausar_animacao"): owner_actor.pausar_animacao(false)
	if slot != "C":
		binding = binding_for(owner_actor)
		if not binding.valid:
			cancel()
			return
		for side in 2:
			var socket: Transform3D = binding.socket(side)
			hands.append({"state": "attached", "transform": socket, "start": socket, "end": socket.origin, "time": 0.0, "out": 0.35, "back": 0.35, "curve": 0.0, "zone": -1})
			_last_visual.append(socket)
	else:
		var flat := Vector3(aim.x, 0, aim.z).normalized()
		var feet := owner_actor.global_position + Vector3.DOWN * 0.8
		_cannon = VFX.cannon(self, feet + flat * 0.5, flat)
		_ball_start = _cannon.global_transform * Vector3(0, 0.69, -0.90)
		_ball_position = _ball_start
		_warning = VFX.telegraph(self, feet + flat * 1.4, flat, 24.0, 0.6)
	AUDIO.play(self, owner_actor.global_position, "split")

func _server() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_actor):
		queue_free()
		return
	if _server():
		if binding != null and binding.model != owner_actor.get("_char_model"):
			finish()
			return
		if not _cancelled and (float(owner_actor.get("health")) <= 0 or str(owner_actor.get("current_fruit_id")) != "bara_bara" or str(owner_actor.get("combat_mode")) != "fruit" or owner_actor.get("is_suppressed") == true or not owner_actor.get_meta("is_casting", false)):
			cancel()
		elapsed += delta
		if not _cancelled:
			if slot == "C": _tick_cannon(delta)
			else: _tick_attacks()
		for side in hands.size(): _tick_hand(side, delta)
		_sync_time += delta
		if _sync_time >= 0.05:
			_sync_time = 0.0
			owner_actor.bara_snapshot(snapshot())
		if (_cancelled and elapsed >= _cancel_time + 0.36) or elapsed >= float(DURATIONS[slot]):
			finish()
	else:
		elapsed += delta
	if not _cancelled:
		owner_actor.set_meta("bara_pose_t", elapsed)
	_present(delta)

func _tick_attacks() -> void:
	if slot == "Z" and _emitted == 0 and elapsed >= 0.24:
		_emitted = 1
		_launch([1], 7.0, 0.35, 0.35, 0, false)
	elif slot == "X" and _emitted == 0 and elapsed >= 0.38:
		_emitted = 1
		_launch([0, 1], 6.0, 0.42, 0.40, 1.2, false)
	elif slot == "V":
		while _emitted < STARTS.size() and elapsed >= STARTS[_emitted]:
			var final := _emitted == 4
			_launch([0, 1] if final else [_emitted % 2], 8.0, 0.22, 0.22, 0.25, final)
			_emitted += 1

func _zone(final: bool, radius: float, kb: float = 0.0) -> DamageZone:
	var zone := DamageZone.new()
	add_child(zone)
	var amount := float(damage_spec.partes.get("final", 192.0)) if final else damage_spec.dano
	zone.setup(amount, kb, Vector3.ZERO, 5.0, owner_actor, radius, null, 0.10)
	zone.set_physics_process(false)
	zone.monitoring = false
	zone.exige_linha_de_visao = true
	damage_spec.marcar(zone, final)
	_zones.append(zone)
	return zone

func _launch(sides: Array, distance: float, out_time: float, back_time: float, curve: float, final: bool) -> void:
	var zone := _zone(final, 0.24, 10.0 if final else (3.0 if slot == "X" else 0.0))
	# Um volume compartilhado deduplica as duas mãos da pinça/finalizador.
	zone.set_meta("bara_final", final)
	# Cada mão vai do PRÓPRIO encaixe até o ponto que o RETÍCULO marca, e segue até o
	# alcance. Antes o fim era "corpo + mira × alcance": a mira sai da linha da câmera
	# (de ombro), então a reta era paralela à do retículo e a mão passava ~1,2 m ao
	# lado do alvo, mergulhando até 0,3 m do chão — o Z, o X e o V da Bara não
	# acertavam ninguém (medido em 05/10/2026).
	# Mão em CURVA (a pinça do X) fecha no ponto mirado: com alcance cheio as duas mãos
	# passavam ~1 m de cada lado de um alvo a 4 m e só se encontravam aos 6 m.
	var ponto := _ponto_mirado(distance)
	var no_alvo := ponto.distance_to(_origem_da_mira() + aim * distance) > 0.05
	for side in sides:
		var socket: Transform3D = binding.socket(side)
		var h := hands[side]
		h.state = "outbound"
		h.start = socket
		h.transform = socket
		var rumo: Vector3 = ponto - socket.origin
		var alcance := distance
		if curve > 0.0 and no_alvo:
			alcance = minf(distance, rumo.length() + 0.3)
		h.end = socket.origin + (rumo.normalized() if rumo.length_squared() > 0.01 else aim) * alcance
		h.time = 0.0
		h.out = out_time
		h.back = back_time
		h.curve = curve * (-1 if side == 0 else 1)
		h.zone = _zones.size() - 1
	AUDIO.play(self, owner_actor.global_position, "split")

func _tick_hand(side: int, delta: float) -> void:
	var h := hands[side]
	if h.state == "attached": return
	h.time += delta
	var transform: Transform3D = h.transform
	if h.state == "returning":
		var socket: Transform3D = binding.socket(side)
		var t := clampf(h.time / h.back, 0, 1)
		transform = h.start.interpolate_with(socket, smoothstep(0, 1, t))
		h.transform = transform
		if t >= 1:
			h.state = "attached"
			AUDIO.play(self, socket.origin, "return")
		return
	var t := clampf(h.time / h.out, 0, 1)
	var right := aim.cross(Vector3.UP).normalized()
	var desired: Vector3 = h.start.origin.lerp(h.end, t) + right * sin(t * PI) * h.curve
	var stopped := stop_at_wall(transform.origin, desired, 0.24)
	var blocked := stopped.distance_squared_to(desired) > 0.000001
	var zone := _zones[h.zone]
	zone.global_position = stopped
	zone.origem_linha_de_visao = transform.origin
	var contacts := SWEEP.contacts(get_world_3d().direct_space_state, transform.origin, stopped, 0.24, 15, [owner_actor.get_rid()])
	contacts.sort_custom(func(a, b): return transform.origin.distance_squared_to(a.position) < transform.origin.distance_squared_to(b.position))
	for contact in contacts:
		var victim: Node3D = contact.body
		var before := float(victim.get("health"))
		zone._on_body(victim)
		if float(victim.get("health")) < before:
			owner_actor.bara_impact(contact.position, false)
			if zone.get_meta("bara_final", false) and victim.has_method("receber_arremesso"):
				victim.receber_arremesso(Vector3(aim.x, 0, aim.z).normalized() * 10.0 + Vector3.UP * 6.0)
		stopped = contact.position
		blocked = true
		break
	transform.origin = stopped
	h.transform = transform
	if blocked or t >= 1: _return_hand(h)

func stop_at_wall(from: Vector3, to: Vector3, radius: float) -> Vector3:
	var exclusions: Array[RID] = [owner_actor.get_rid()]
	# Corpos não são parede: a mão para NELES (contato), não antes deles. Com o grupo
	# "alvo_de_golpe" o animal manso deixa de ser tratado como parede (05/10/2026).
	for actor in AlvosDeGolpe.todos(get_tree()):
		if actor is CollisionObject3D: exclusions.append(actor.get_rid())
	var space := get_world_3d().direct_space_state
	if not SWEEP.query_segment(space, from, from, radius, 15, exclusions).is_empty(): return from
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, from)
	q.motion = to - from
	q.collision_mask = 15
	q.exclude = exclusions
	q.margin = 0.0
	var fractions := space.cast_motion(q)
	return from.lerp(to, maxf(0, fractions[0] - 0.001)) if fractions[0] < 1 else to

## O ponto que o retículo marca: o primeiro corpo na linha da mira (que sai de
## `origin`, na linha da câmera) até o alcance; sem nada na frente, o fim do alcance.
func _ponto_mirado(distance: float) -> Vector3:
	var de := _origem_da_mira()
	var fora: Array[RID] = []
	if owner_actor is CollisionObject3D:
		fora.append((owner_actor as CollisionObject3D).get_rid())
	return AlvosDeGolpe.ponto_mirado(get_world_3d(), de, aim, distance, fora)


func _origem_da_mira() -> Vector3:
	return origin if origin.is_finite() and origin != Vector3.ZERO else owner_actor.global_position + Vector3.UP * 0.30


func _return_hand(h: Dictionary) -> void:
	h.state = "returning"
	h.start = h.transform
	h.time = 0.0

func _tick_cannon(_delta: float) -> void:
	if _emitted == 0 and elapsed >= 0.65:
		_emitted = 1
		_ball_active = true
		VFX.fire_cannon(_cannon)
		AUDIO.play(self, _ball_start, "shot")
		# A boca não pode atravessar uma parede próxima ao conjurador.
		var start := owner_actor.global_position + Vector3.UP * 0.15
		var safe := stop_at_wall(start, _ball_start, 0.21)
		if safe.distance_to(_ball_start) > 0.03:
			_ball_position = safe
			_explode()
	if not _ball_active: return
	var t := minf(elapsed - 0.65, 24.0 / 26.0)
	var wanted := _ball_start + aim * 26.0 * t + Vector3.DOWN * 2.0 * t * t
	var stop := stop_at_wall(_ball_position, wanted, 0.21)
	var blocked := stop.distance_squared_to(wanted) > 0.000001
	var contacts := SWEEP.contacts(get_world_3d().direct_space_state, _ball_position, stop, 0.21, 15, [owner_actor.get_rid()])
	contacts.sort_custom(func(a, b): return _ball_position.distance_squared_to(a.position) < _ball_position.distance_squared_to(b.position))
	if not contacts.is_empty():
		stop = contacts[0].position
		blocked = true
	_ball_position = stop
	if blocked or t >= 24.0 / 26.0: _explode()

func _explode() -> void:
	if not _ball_active: return
	_ball_active = false
	var zone := _zone(false, BLAST_RADIUS, 9.0)
	zone.global_position = _ball_position
	zone.origem_linha_de_visao = _ball_position
	for hit in SWEEP.query_segment(get_world_3d().direct_space_state, _ball_position, _ball_position, BLAST_RADIUS, 15, [owner_actor.get_rid()]):
		zone._on_body(hit.collider)
	owner_actor.bara_impact(_ball_position, true)

func _present(delta: float) -> void:
	for side in hands.size():
		var h := hands[side]
		var target: Transform3D = h.transform
		var transform := target if _server() else _last_visual[side].interpolate_with(target, minf(1, delta * 35))
		if h.state != "attached" and _last_visual[side].origin.distance_to(transform.origin) > 0.09:
			VFX.trail(self, _last_visual[side].origin, transform.origin)
		binding.present(side, h.state != "attached", transform)
		_last_visual[side] = transform
	if slot == "C":
		if _ball_active and not is_instance_valid(_ball): _ball = VFX.ball(self, _ball_position)
		if is_instance_valid(_ball):
			_ball.global_position = _ball_position
			_ball.visible = _ball_active
		if is_instance_valid(_warning): _warning.visible = _emitted == 0 and not _cancelled

func snapshot() -> Dictionary:
	var data: Array = []
	for h in hands: data.append({"state": h.state, "transform": h.transform})
	return {"slot": slot, "token": cast_token, "aim": aim, "origin": origin, "elapsed": elapsed, "hands": data, "cancelled": _cancelled, "ball": _ball_position, "ball_active": _ball_active, "emitted": _emitted}

func receive(data: Dictionary) -> void:
	elapsed = float(data.elapsed)
	_cancelled = data.cancelled
	if _cancelled: _release_pose()
	_ball_position = data.ball
	_ball_active = data.ball_active
	if slot == "C" and _emitted == 0 and data.emitted > 0 and is_instance_valid(_cannon):
		VFX.fire_cannon(_cannon)
		AUDIO.play(self, _ball_start, "shot")
	_emitted = data.emitted
	for i in mini(hands.size(), data.hands.size()):
		hands[i].state = data.hands[i].state
		hands[i].transform = data.hands[i].transform

func cancel() -> void:
	if _cancelled: return
	_cancelled = true
	_cancel_time = elapsed
	_ball_active = false
	for h in hands:
		if h.state != "attached": _return_hand(h)
	_release_pose()

func _release_pose() -> void:
	if is_instance_valid(owner_actor) and (owner_actor.get_meta("bara_action") if owner_actor.has_meta("bara_action") else null) == self:
		owner_actor.set_meta("is_casting", false)
		owner_actor.set_meta("active_skill", "")
		if str(owner_actor.get_meta("custom_pose", "")).begins_with("bara_"): owner_actor.remove_meta("custom_pose")

func finish() -> void:
	if _finished: return
	_finished = true
	if _server() and is_instance_valid(owner_actor): owner_actor.bara_finished(cast_token)
	_release_pose()
	queue_free()

func _exit_tree() -> void:
	_release_pose()
	if binding != null: binding.restore()
	if is_instance_valid(owner_actor) and (owner_actor.get_meta("bara_action") if owner_actor.has_meta("bara_action") else null) == self: owner_actor.remove_meta("bara_action")
	if damage_spec != null: CombatResolver.encerrar(damage_spec.cast_id)
