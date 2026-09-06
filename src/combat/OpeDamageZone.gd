extends "res://src/effects/DamageZone.gd"
## A ROOM limita o acerto, inclusive se o adversário cruzar a borda enquanto
## a rocha voa. O funil DamageZone mantém orçamento, hitstun e crédito de kill.

var room_ref: WeakRef
var stop_on_collision := false


func _room_valid() -> bool:
	var room: Node = room_ref.get_ref() if room_ref != null else null
	return is_instance_valid(room) and not room.is_queued_for_deletion() \
		and is_instance_valid(caster) and room.contains_point(caster.global_position)


func _physics_process(delta: float) -> void:
	if not _room_valid():
		queue_free()
		return
	super._physics_process(delta)
	var room: Node = room_ref.get_ref()
	if not room.contains_point(global_position):
		queue_free()


func _on_body(body: Node3D) -> void:
	if body == caster or not _room_valid():
		return
	var room: Node = room_ref.get_ref()
	if not room.contains_point(body.global_position):
		return
	super._on_body(body)
	if stop_on_collision:
		queue_free()
