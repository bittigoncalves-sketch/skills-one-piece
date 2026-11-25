extends "res://src/effects/DamageZone.gd"
## Pulso cancelável: reutiliza o funil de dano, sem timer de gameplay.
var restante := 0.06

func configurar(ator: Node3D, spec: DamageSpec, raio: float, impulso: float,
		tranco: float, origem: Vector3, direcao: Vector3 = Vector3.ZERO) -> void:
	caster = ator
	feedback_global = false
	damage = spec.dano
	knockback = impulso
	hitstun = tranco
	override_kb_dir = direcao
	spec.marcar(self)
	collision_layer = 0
	collision_mask = 15
	exige_linha_de_visao = true
	origem_linha_de_visao = origem
	_forma_varredura = SphereShape3D.new()
	_forma_varredura.radius = raio
	var col := CollisionShape3D.new()
	col.shape = _forma_varredura
	add_child(col)
	add_to_group("hitbox")
	add_to_group("rocket_hitbox")
	# Consulta imediata: não perde o impacto entre dois quadros de Area3D.
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = col.shape
	consulta.transform = global_transform
	consulta.collision_mask = collision_mask
	consulta.exclude = [ator.get_rid()] if ator is CollisionObject3D else []
	for resultado in get_world_3d().direct_space_state.intersect_shape(consulta, 64):
		_on_body(resultado.collider)

func _physics_process(delta: float) -> void:
	restante -= delta
	if restante <= 0.0 or not is_instance_valid(caster):
		queue_free()
