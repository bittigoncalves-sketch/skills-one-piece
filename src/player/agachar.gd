extends RefCounted
## Agachar inspirado no Minecraft Java (20/10/2026). Não escreve velocity:
## a locomoção aplica o limite antes de somar empurrões externos.
const FATOR_ALTURA := 1.5 / 1.8
const FATOR_VELOCIDADE := 0.3
const QUEDA_PERMITIDA := 0.5 / 1.8

var ativo := false
var _dono: CharacterBody3D
var _colisor: CollisionShape3D
var _forma_inteira: Shape3D
var _pos_inteira := Vector3.ZERO
var _altura := 0.0
var _hurtbox_inteira := Vector3.ZERO


func montar(dono: CharacterBody3D, colisor: CollisionShape3D) -> void:
	_dono = dono
	_colisor = colisor


func atualizar(pedido: bool, permitido: bool) -> void:
	# Soltar Ctrl sob um teto mantém a postura até haver espaço para levantar.
	var alvo := pedido and permitido
	if ativo and not alvo and not pode_levantar():
		alvo = true
	aplicar(alvo)


func aplicar(alvo: bool) -> void:
	if alvo == ativo or not is_instance_valid(_colisor):
		return
	if alvo:
		_forma_inteira = _colisor.shape.duplicate()
		_pos_inteira = _colisor.position
		_altura = altura_da_forma(_forma_inteira)
		var hurtbox := _dono.get_node_or_null("Hurtbox/Forma") as CollisionShape3D
		if hurtbox != null and hurtbox.shape is BoxShape3D:
			_hurtbox_inteira = hurtbox.shape.size
		var baixa: Shape3D = _forma_inteira.duplicate()
		if baixa is BoxShape3D:
			baixa.size.y = _altura * FATOR_ALTURA
		elif baixa is CapsuleShape3D:
			baixa.height = maxf(_altura * FATOR_ALTURA, baixa.radius * 2.0)
		_colisor.shape = baixa
		_colisor.position.y = _pos_inteira.y - (_altura - altura_da_forma(baixa)) * 0.5
	else:
		_colisor.shape = _forma_inteira
		_colisor.position = _pos_inteira
	ativo = alvo
	_atualizar_hurtbox()


func cancelar() -> void:
	aplicar(false)


func pode_levantar() -> bool:
	if not ativo:
		return true
	# Consulta o volume inteiro, inclusive os cantos. Raios verticais deixavam
	# vigas estreitas entre as amostras passarem despercebidas.
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = _forma_inteira
	consulta.transform = _dono.global_transform * Transform3D(_colisor.basis, _pos_inteira)
	consulta.transform.origin += Vector3.UP * 0.005
	consulta.margin = 0.001
	consulta.collision_mask = _dono.collision_mask & ~HurtboxDeCombate.CAMADA
	consulta.exclude = [_dono.get_rid()]
	return _dono.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func limitar_borda(vel: Vector3, delta: float) -> Vector3:
	# Pular e ser empurrado ainda permitem cair; agachar não é uma parede
	# invisível no ar. O apoio é testado separadamente em X, Z e na diagonal.
	if not ativo or not _dono.is_on_floor() or vel.y > 0.0 or delta <= 0.0:
		return vel
	var passo := Vector3(vel.x, 0.0, vel.z) * delta
	var reducao := maxf(_altura / 1.8 * 0.05, 0.01)
	while absf(passo.x) > 0.00001 and not _tem_apoio(Vector3(passo.x, 0, 0)):
		passo.x = move_toward(passo.x, 0.0, reducao)
	while absf(passo.z) > 0.00001 and not _tem_apoio(Vector3(0, 0, passo.z)):
		passo.z = move_toward(passo.z, 0.0, reducao)
	while passo.length_squared() > 0.00000001 and not _tem_apoio(passo):
		passo.x = move_toward(passo.x, 0.0, reducao)
		passo.z = move_toward(passo.z, 0.0, reducao)
	return Vector3(passo.x / delta, vel.y, passo.z / delta)


func _tem_apoio(passo: Vector3) -> bool:
	var consulta := PhysicsTestMotionParameters3D.new()
	consulta.from = _dono.global_transform
	consulta.from.origin += passo
	consulta.motion = Vector3.DOWN * (_altura * QUEDA_PERMITIDA)
	consulta.margin = _dono.safe_margin
	consulta.max_collisions = 8
	var resultado := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(_dono.get_rid(), consulta, resultado):
		for i in resultado.get_collision_count():
			if resultado.get_collision_normal(i).dot(Vector3.UP) >= cos(_dono.floor_max_angle):
				return true
	# A cápsula pode tocar primeiro a quina do degrau de cima: esse contato
	# lateral encerra a varredura antes do piso de baixo. Confere também o chão
	# sob o centro para permitir descer meio bloco sem liberar uma borda vazia.
	var altura_atual := altura_da_forma(_colisor.shape)
	var de := _colisor.global_transform * Vector3(0, -altura_atual * 0.5 + 0.03, 0) + passo
	var raio := PhysicsRayQueryParameters3D.create(de, de + consulta.motion)
	raio.collision_mask = _dono.collision_mask & ~HurtboxDeCombate.CAMADA
	raio.exclude = [_dono.get_rid()]
	var apoio := _dono.get_world_3d().direct_space_state.intersect_ray(raio)
	return not apoio.is_empty() and (apoio.normal as Vector3).dot(Vector3.UP) >= cos(_dono.floor_max_angle)


func queda_da_camera() -> float:
	# Olhos 1,62 → 1,27 blocos, na escala física deste personagem.
	return _altura * (0.35 / 1.8) if ativo else 0.0


func _atualizar_hurtbox() -> void:
	if not _dono.get("colisor_capsula"):
		return
	# Usa o corpo deste ator, não a raça local de Visual (que pode diferir
	# da raça do jogador remoto).
	var caixa := _hurtbox_inteira
	if caixa == Vector3.ZERO:
		return
	caixa.y = altura_da_forma(_colisor.shape)
	HurtboxDeCombate.redimensionar(_dono, caixa, _colisor.position.y)


static func altura_da_forma(forma: Shape3D) -> float:
	return forma.size.y if forma is BoxShape3D else forma.height
