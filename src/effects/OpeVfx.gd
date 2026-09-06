extends RefCounted
## Visual API. Gameplay owns hit detection, authority and ROOM lifetime.
const RoomEffect = preload("res://src/effects/OpeRoomField.gd")
const BurstEffect = preload("res://src/effects/OpeSurgicalBurst.gd")
const TaktEffect = preload("res://src/effects/OpeTaktVolley.gd")

static func room(parent: Node, center: Vector3, radius: float = 18.0, duration: float = 18.0) -> Node3D:
	var effect := RoomEffect.new()
	effect.radius = radius
	effect.duration = duration
	parent.add_child(effect)
	effect.global_position = center
	return effect

static func shambles(parent: Node, a: Vector3, b: Vector3) -> Node3D:
	var effect := BurstEffect.new()
	effect.mode = "shambles"
	effect.destination = b - a
	parent.add_child(effect)
	effect.global_position = a
	return effect

static func takt_start(center: Vector3, index: int) -> Vector3:
	var angle := TAU * float(index) / 5.0
	return center + Vector3(cos(angle) * 3.2, 2.6 + float(index % 2) * 0.45, sin(angle) * 3.2)

static func takt(parent: Node, center: Vector3, target: Vector3) -> Node3D:
	var effect := TaktEffect.new()
	effect.target = target - center
	parent.add_child(effect)
	effect.global_position = center
	return effect

static func gamma(parent: Node, origin: Vector3, direction: Vector3, length: float = 8.0) -> Node3D:
	var effect := BurstEffect.new()
	effect.mode = "gamma"
	effect.direction = direction.normalized()
	effect.reach = length
	parent.add_child(effect)
	effect.global_position = origin
	return effect
