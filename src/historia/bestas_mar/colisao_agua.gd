extends RefCounted
## Volume varrido compartilhado pelos dois ataques; o primeiro obstáculo para a água.
static func varrer(atirador: CollisionObject3D, de: Vector3, viagem: Vector3, raio: float) -> Dictionary:
	var q := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = raio
	q.shape = esfera
	q.transform.origin = de
	q.motion = viagem
	q.collision_mask = 15
	q.exclude = [atirador.get_rid()]
	var hb := HurtboxDeCombate.rid_de(atirador)
	if hb.is_valid():
		q.exclude.append(hb)
	var espaco := atirador.get_world_3d().direct_space_state
	var contatos := espaco.intersect_shape(q, 16)
	var fracao := espaco.cast_motion(q)
	if contatos.is_empty() and fracao[0] >= 1.0:
		return {"posicao": de + viagem, "colidiu": false, "alvo": null}
	q.transform.origin = de if not contatos.is_empty() else de + viagem * fracao[1]
	q.motion = Vector3.ZERO
	if contatos.is_empty():
		# Margem de 1 mm apenas para recuperar o contato no limite numérico do sweep.
		esfera.radius += .001
		contatos = espaco.intersect_shape(q, 16)
	var alvo: Node = null
	for contato in contatos:
		var dono := HurtboxDeCombate.dono_de(contato.collider)
		# Barco também é alvo (14/10/2026, E5 do mar: a besta navegando ataca o casco).
		if dono != atirador and (dono.is_in_group("player") or dono.is_in_group("alvo_de_besta")) and dono.has_method("take_damage"):
			alvo = dono
		else:
			# Sobreposição simultânea com cenário não permite atravessar uma parede.
			return {"posicao": q.transform.origin, "colidiu": true, "alvo": null}
	return {"posicao": q.transform.origin, "colidiu": true, "alvo": alvo}
