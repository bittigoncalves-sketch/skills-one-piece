class_name AutoDummy
extends TrainingDummy

var _target: Node3D = null
var _attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	# Colorir o dummy de vermelho para diferenciar
	_recolor_model(Color(1.0, 0.2, 0.2))

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if has_meta("is_frozen") and get_meta("is_frozen"):
		return
	if health <= 0.0:
		return
		
	if not is_instance_valid(_target):
		_find_target()
		
	if is_instance_valid(_target):
		var to_target: Vector3 = _target.global_position - global_position
		var dist: float = to_target.length()
		
		# Move towards target
		if dist > 2.0:
			var dir = to_target.normalized()
			velocity.x = dir.x * 3.5
			velocity.z = dir.z * 3.5
			
			# Face target
			if _model:
				_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 10.0 * delta)
		else:
			# Attack
			_attack_timer += delta
			if _attack_timer >= 1.5:
				_attack()
				_attack_timer = 0.0
				
func _find_target() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			_target = node
			break

func _attack() -> void:
	var fwd = -global_transform.basis.z
	if _model:
		fwd = -_model.global_transform.basis.z
	
	var atk_pos = global_position + Vector3.UP * 1.5 + fwd * 1.0
	
	# Simples hitscan punch
	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, atk_pos + fwd * 1.5)
	q.exclude = [get_rid()]
	var hit = space.intersect_ray(q)
	
	if not hit.is_empty():
		var col = hit.collider
		if col.has_method("take_damage"):
			col.take_damage(10.0, global_position, fwd * 5.0)

func _recolor_model(c: Color) -> void:
	if not _model:
		return
	for child in _meshes(_model):
		if child is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c
			child.material_override = mat

