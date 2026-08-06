class_name Tumbleweed
extends Node3D

var _velocity := Vector3.ZERO
var _center := Vector3.ZERO
var _radius := 20.0
var _time_to_change := 0.0

func setup(center: Vector3, radius: float) -> void:
	_center = center
	_radius = radius
	global_position = _center + Vector3(randf_range(-_radius, _radius), 1.0, randf_range(-_radius, _radius))
	_pick_new_direction()
	
func _pick_new_direction() -> void:
	var angle := randf() * TAU
	_velocity = Vector3(cos(angle), 0, sin(angle)) * randf_range(3.0, 7.0)
	_time_to_change = randf_range(2.0, 5.0)

func _physics_process(delta: float) -> void:
	_time_to_change -= delta
	if _time_to_change <= 0:
		_pick_new_direction()
	
	_velocity.y -= 25.0 * delta
	var step = _velocity * delta
	
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + step + Vector3(0, -2.0, 0))
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			global_position.x += step.x
			global_position.z += step.z
			# Apenas 0.5 de raio da bola (o deserto agora é físico)
			global_position.y = hit["position"].y + 0.5
			_velocity.y = 0.0
			# Rotação visual baseada no movimento
			var horiz := Vector3(step.x, 0, step.z)
			if horiz.length_squared() > 0.001:
				var axis = Vector3.UP.cross(horiz.normalized())
				var angle = horiz.length() / 0.5 # dist / raio
				rotate(axis.normalized(), angle)
		else:
			global_position += step
			
	# Se sair muito do raio, volta pro centro
	var horiz_pos := Vector3(global_position.x, 0, global_position.z)
	var horiz_center := Vector3(_center.x, 0, _center.z)
	if horiz_pos.distance_to(horiz_center) > _radius + 5.0:
		var dir_to_center = (horiz_center - horiz_pos).normalized()
		_velocity.x = dir_to_center.x * randf_range(3.0, 7.0)
		_velocity.z = dir_to_center.z * randf_range(3.0, 7.0)
