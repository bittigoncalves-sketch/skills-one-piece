class_name BossBrain
extends RefCounted
const Sweep = preload("res://src/combat/SwordSweep.gd")
var target: Node3D
## Velocidade com que o ALVO se afasta do Boss (m/s, suavizada). Mede o
## deslocamento do próprio alvo projetado na direção Boss→alvo: o Boss sendo
## arremessado ou recuando não conta como fuga.
var flee_rate := 0.0
const FLEE_SMOOTHING := 10.0
var _tracked: Node3D
var _last_target_position := Vector3.ZERO
var _next_scan := 0.0

func tick(actor: CharacterBody3D, delta: float) -> void:
	_next_scan -= delta
	_track_flee(actor, delta)
	if actor.global_position.distance_to(actor.home_position) > actor.definition.leash_range:
		target = null
		return
	if is_instance_valid(target) and (not alive(target) or target.global_position.distance_to(actor.home_position) > actor.definition.leash_range):
		target = null
	if _next_scan > 0:
		return
	_next_scan = actor.definition.reaction_interval
	if is_instance_valid(target):
		return
	var nearest: float = actor.definition.aggro_range
	for candidate in actor.get_tree().get_nodes_in_group("player"):
		if not candidate is Node3D or not alive(candidate) or candidate.global_position.distance_to(actor.home_position) > actor.definition.leash_range:
			continue
		var distance: float = actor.global_position.distance_to(candidate.global_position)
		if distance < nearest and visible(actor, candidate):
			nearest = distance
			target = candidate

func _track_flee(actor: CharacterBody3D, delta: float) -> void:
	if not is_instance_valid(target) or delta <= 0:
		flee_rate = 0.0
		_tracked = null
		return
	if target != _tracked:
		_tracked = target
		_last_target_position = target.global_position
		flee_rate = 0.0
		return
	# Voar arremessado não é fugir: sem isto o 4º soco emendaria o corte num alvo
	# deitado, sem chance de desvio.
	if target.has_method("esta_arremessado") and target.call("esta_arremessado"):
		_last_target_position = target.global_position
		flee_rate = 0.0
		return
	var away := target.global_position - actor.global_position
	away.y = 0
	var moved := target.global_position - _last_target_position
	moved.y = 0
	_last_target_position = target.global_position
	var rate := moved.dot(away.normalized()) / delta if away.length_squared() > 0.0001 else 0.0
	flee_rate = lerpf(flee_rate, rate, 1.0 - exp(-FLEE_SMOOTHING * delta))

static func alive(candidate: Node) -> bool:
	return is_instance_valid(candidate) and float(candidate.get("health")) > 0 and not bool(candidate.get("_eliminado"))

static func visible(actor: CharacterBody3D, candidate: Node3D) -> bool:
	return Sweep.visible(actor.get_world_3d().direct_space_state, actor.global_position + Vector3.UP * 0.3,
		candidate.global_position + Vector3.UP * 0.3, 15, [actor.get_rid()])
