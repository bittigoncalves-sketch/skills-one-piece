class_name PXThrusterLance
extends Node3D
## C do Pacifista. Preserva o cilindro amarelo de 15 m, a velocidade de 35 m/s
## e a vida de 1,5 s do efeito aprovado, mas faz a colisao ocupar o MESMO
## segmento visivel. A cauda e a ponta sao recortadas na primeira parede.

const COMPRIMENTO := 15.0
const VELOCIDADE := 35.0
const DURACAO := 1.5
const RECUPERACAO_DO_CASTER := 0.32
const RAIO_NUCLEO := 0.30
const RAIO_HALO := 0.48
const COR_NUCLEO := Color(1.0, 0.88, 0.12, 0.96)
const COR_HALO := Color(1.0, 0.68, 0.02, 0.22)
const EPSILON_PAREDE := 0.025

var _caster: Node3D
var _origem := Vector3.ZERO
var _dir := Vector3.FORWARD
var _dano := 0.0
var _spec = null
var _cast_token := 0
var _tempo := 0.0
var _cauda := Vector3.ZERO
var _preparado := false
var _estado_finalizado := false
var _nucleo: MeshInstance3D
var _halo: MeshInstance3D
var _zona: DamageZone
var _forma: CylinderShape3D
var _colisor: CollisionShape3D
var _ultimo_inicio := Vector3.ZERO
var _ultimo_fim := Vector3.ZERO


static func criar(mundo: Node, caster: Node3D, origem: Vector3, aim: Vector3,
		dano: float, spec = null, cast_token: int = 0) -> PXThrusterLance:
	var no := PXThrusterLance.new()
	no._caster = caster
	no._origem = origem
	no._cauda = origem
	no._dir = aim.normalized() if aim.length_squared() > 0.0001 else Vector3.FORWARD
	no._dano = dano
	no._spec = spec
	no._cast_token = cast_token
	no.set_meta("px_thruster_lance", true)
	mundo.add_child(no)
	no.call_deferred("_preparar")
	return no


func _preparar() -> void:
	if _preparado or not is_inside_tree() or not is_instance_valid(_caster):
		return
	_preparado = true
	_halo = BeamVisual3D.criar(self, _cauda, _cauda + _dir * COMPRIMENTO,
		RAIO_HALO, COR_HALO, 4.0, true)
	_nucleo = BeamVisual3D.criar(self, _cauda, _cauda + _dir * COMPRIMENTO,
		RAIO_NUCLEO, COR_NUCLEO, 5.0, true)
	_nucleo.set_meta("px_lance_core", true)

	_zona = DamageZone.new()
	add_child(_zona)
	_forma = CylinderShape3D.new()
	_forma.radius = RAIO_HALO
	_forma.height = COMPRIMENTO
	_zona.setup(_dano, 16.0, Vector3.ZERO, DURACAO + 0.12, _caster,
		RAIO_HALO, _forma, 0.28)
	_zona.override_kb_dir = _dir
	if _spec != null:
		_spec.marcar(_zona)
	_colisor = _zona.get_child(0) as CollisionShape3D
	# O projétil já nasce com presença visual e física no primeiro quadro. O
	# recorte inicial impede tanto o "piscar" de comprimento zero quanto atravessar
	# uma parede próxima durante o frame anterior ao primeiro _physics_process.
	var dist_barreira := _distancia_ate_barreira(
		_cauda, _cauda + _dir * COMPRIMENTO)
	var comprimento_inicial := COMPRIMENTO
	if dist_barreira >= 0.0:
		comprimento_inicial = maxf(dist_barreira, 0.0)
	_atualizar_segmento(_cauda, comprimento_inicial)


func _physics_process(delta: float) -> void:
	if not _preparado:
		return
	if not is_instance_valid(_caster):
		queue_free()
		return

	_tempo += delta
	if not _estado_finalizado and _tempo >= RECUPERACAO_DO_CASTER:
		_finalizar_estado()
	if _tempo >= DURACAO:
		_encerrar()
		return

	var passo := VELOCIDADE * delta
	# Consulta inclui o passo seguinte. Se a cauda alcancaria a barreira neste
	# quadro, o projetil termina nela em vez de teleportar para o outro lado.
	var ate_consulta := _cauda + _dir * (COMPRIMENTO + passo)
	var dist_barreira := _distancia_ate_barreira(_cauda, ate_consulta)
	if dist_barreira >= 0.0 and dist_barreira <= passo + EPSILON_PAREDE:
		_encerrar()
		return

	_cauda += _dir * passo
	var comprimento := COMPRIMENTO
	if dist_barreira >= 0.0:
		comprimento = minf(COMPRIMENTO, dist_barreira - passo)
	_atualizar_segmento(_cauda, comprimento)


## Sete raios cobrem nucleo, bordas e diagonais do cilindro. Atores sao
## atravessaveis para esta consulta (a DamageZone cuida deles); apenas cenario
## recorta a geometria. Isso evita que um alvo esconda uma parede logo atras.
func _distancia_ate_barreira(de: Vector3, ate: Vector3) -> float:
	var espaco := get_world_3d().direct_space_state
	if espaco == null:
		return -1.0
	var direita := _dir.cross(Vector3.UP).normalized()
	if direita.length_squared() < 0.01:
		direita = Vector3.RIGHT
	var cima := direita.cross(_dir).normalized()
	var diagonal := RAIO_HALO * 0.70710678
	var offsets: Array[Vector3] = [
		Vector3.ZERO,
		direita * RAIO_HALO, -direita * RAIO_HALO,
		cima * RAIO_HALO, -cima * RAIO_HALO,
		(direita + cima) * diagonal, (-direita + cima) * diagonal,
	]
	var melhor := INF
	for offset in offsets:
		var distancia := _raio_de_cenario(de + offset, ate + offset)
		if distancia >= 0.0:
			melhor = minf(melhor, distancia)
	return -1.0 if is_inf(melhor) else melhor


func _raio_de_cenario(de: Vector3, ate: Vector3) -> float:
	var excluidos: Array[RID] = []
	if _caster is CollisionObject3D:
		excluidos.append((_caster as CollisionObject3D).get_rid())
	# Um raio pode encontrar mais de um combatente antes da parede. Iterar com
	# exclusoes preserva perfuracao de atores sem perder a barreira posterior.
	for _i in 16:
		var par := PhysicsRayQueryParameters3D.create(de, ate)
		par.collision_mask = 15
		par.collide_with_areas = false
		par.collide_with_bodies = true
		par.exclude = excluidos
		var hit := get_world_3d().direct_space_state.intersect_ray(par)
		if hit.is_empty():
			return -1.0
		var corpo = hit.get("collider")
		if corpo is CollisionObject3D and corpo.has_method("take_damage"):
			excluidos.append((corpo as CollisionObject3D).get_rid())
			continue
		return maxf((hit.position - de).dot(_dir), 0.0)
	return -1.0


func _atualizar_segmento(inicio: Vector3, comprimento: float) -> void:
	var fim := inicio + _dir * maxf(comprimento, 0.0)
	_ultimo_inicio = inicio
	_ultimo_fim = fim
	var visivel := BeamVisual3D.atualizar(_nucleo, inicio, fim, RAIO_NUCLEO)
	BeamVisual3D.atualizar(_halo, inicio, fim, RAIO_HALO)
	if not visivel or comprimento <= EPSILON_PAREDE:
		if is_instance_valid(_colisor):
			_colisor.disabled = true
		return
	_forma.height = comprimento
	_forma.radius = RAIO_HALO
	_zona.global_transform = Transform3D(_nucleo.global_basis, inicio.lerp(fim, 0.5))
	if is_instance_valid(_colisor):
		_colisor.disabled = false


func _finalizar_estado() -> void:
	if _estado_finalizado:
		return
	_estado_finalizado = true
	if is_instance_valid(_caster) and _caster.has_method("finalizar_skill_pacifista"):
		_caster.finalizar_skill_pacifista("C", _cast_token)


func _encerrar() -> void:
	_finalizar_estado()
	queue_free()
