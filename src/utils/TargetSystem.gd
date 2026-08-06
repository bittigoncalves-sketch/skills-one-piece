class_name TargetSystem

# Sistema Genérico de Aquisição de Alvo
# Pode ser reutilizado para Soru, Geppo, Red Hawk, habilidades da Yami, etc.

# Procura o inimigo mais próximo na direção da mira.
# Se não encontrar, retorna um alvo no cenário baseado no max_range.
static func get_target(world: Node, origin: Vector3, fwd: Vector3, max_range: float = 30.0, angle_limit: float = 45.0) -> Dictionary:
	var result := {
		"found_enemy": false,
		"node": null,
		"position": origin + fwd * max_range
	}
	
	var best_dist := max_range
	var best_enemy: Node3D = null
	
	# Busca todos os inimigos (assumindo que estariam num grupo "enemies" ou que tenham "take_damage")
	var candidates := world.get_tree().get_nodes_in_group("enemies")
	
	for enemy in candidates:
		if not enemy is Node3D or not enemy.has_method("take_damage"): continue
		
		# Verifica se está vivo
		if enemy.has_method("is_dead") and enemy.is_dead(): continue
		if enemy.get("health") != null and enemy.get("health") <= 0: continue
		
		var dir_to_enemy = (enemy.global_position - origin)
		var dist = dir_to_enemy.length()
		
		if dist > max_range: continue
		
		var dir_norm = dir_to_enemy.normalized()
		var angle = rad_to_deg(acos(clampf(fwd.dot(dir_norm), -1.0, 1.0)))
		
		if angle > angle_limit: continue
		
		# Verifica linha de visão básica (RayCast)
		if _has_line_of_sight(world, origin, enemy.global_position):
			if dist < best_dist:
				best_dist = dist
				best_enemy = enemy
				
	if best_enemy:
		result.found_enemy = true
		result.node = best_enemy
		result.position = best_enemy.global_position
	else:
		# Se não encontrou inimigo, tenta encontrar a posição no cenário onde a mira bate
		var space_state = world.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(origin, origin + fwd * max_range)
		query.collision_mask = 1 # assumindo 1 para cenário
		var hit = space_state.intersect_ray(query)
		
		if hit:
			result.position = hit.position
			
	return result

static func _has_line_of_sight(world: Node, from: Vector3, to: Vector3) -> bool:
	var space_state = world.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Ignorando corpos de inimigos para ver apenas se há cenário no meio
	query.collision_mask = 1 
	var hit = space_state.intersect_ray(query)
	return hit.is_empty()

# Garante que a posição de destino seja válida (não dentro de parede/chão)
static func get_safe_teleport_pos(world: Node, target_pos: Vector3, offset_y: float = 4.0) -> Vector3:
	var pos = target_pos + Vector3(0, offset_y, 0)
	var space_state = world.get_world_3d().direct_space_state
	
	# Raycast do alto para baixo para achar o chão e evitar teleportar para debaixo do mapa
	var query = PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 10.0, pos + Vector3.DOWN * 20.0)
	query.collision_mask = 1
	var hit = space_state.intersect_ray(query)
	
	if hit:
		# Retorna o ponto mais alto entre o offset desejado e o chão
		return hit.position + Vector3(0, maxf(offset_y, 0.1), 0)
		
	return pos
