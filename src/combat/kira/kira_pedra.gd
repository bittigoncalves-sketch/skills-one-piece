extends Node3D
## Pedra cúbica do Stone Throwing (X) e do Giant Rock Throwing (C).
## O visual É a hitbox: um cubo de aresta `tamanho`, só girado em torno do eixo vertical
## (yaw do voo). O acerto mede o cubo orientado contra a cápsula/caixa/esfera do Hurtbox do alvo,
## não uma esfera em volta do centro. Só o servidor passa `dano > 0`; os outros peers só desenham.
const KiraVfx = preload("res://src/combat/kira/kira_vfx.gd")
const SURGIMENTO := 0.16
const GRAVIDADE := 5.0

var tamanho := 0.8
var textura := "pedra_x"
var autor: Node3D
var dano := 0.0
var raio_de_explosao := 0.0     # > 0: a pedra explode no impacto (C)
var empurrao := 14.0
var velocidade := 42.0
var alcance := 48.0
var destino := Vector3.ZERO     # ponto para onde a pedra é lançada
var atraso := 0.0               # espera antes de aparecer (sequência do X)
var espera_de_voo := 0.14       # tempo parada, já visível, antes de partir
var altura_de_subida := 0.0     # > 0: nasce enterrada e sobe essa altura (C)
var tempo_de_subida := 0.0

var _tempo := 0.0
var _vel := Vector3.ZERO
var _percorrido := 0.0
var _voando := false
var _acabou := false
var _spec: DamageSpec
var _malha: MeshInstance3D
var _base_y := 0.0
var _yaw := 0.0


func _ready() -> void:
	_malha = MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE * tamanho
	caixa.material = KiraVfx.material(textura, 0.1)
	_malha.mesh = caixa
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_malha)
	add_to_group("kira_pedra")
	var rumo := destino - global_position
	rumo.y = 0.0
	_yaw = atan2(-rumo.x, -rumo.z) if rumo.length_squared() > 0.001 else 0.0
	rotation.y = _yaw
	_base_y = global_position.y
	if altura_de_subida > 0.0:
		global_position.y = _base_y - altura_de_subida
	_malha.visible = atraso <= 0.0
	if dano > 0.0:
		_spec = DamageSpec.avulso(dano).para_cast()


func _physics_process(delta: float) -> void:
	if _acabou:
		return
	if atraso > 0.0:
		atraso -= delta
		if atraso > 0.0:
			return
		_malha.visible = true
		delta = 0.0
	_tempo += delta
	if not _voando:
		_surgir()
		if _tempo >= espera_de_voo + maxf(tempo_de_subida, SURGIMENTO):
			_partir()
		return
	_voar(delta)


func _surgir() -> void:
	var k := clampf(_tempo / SURGIMENTO, 0.0, 1.0)
	if tempo_de_subida > 0.0:
		var s := clampf(_tempo / tempo_de_subida, 0.0, 1.0)
		global_position.y = _base_y - altura_de_subida * (1.0 - s * s * (3.0 - 2.0 * s))
		_malha.scale = Vector3.ONE
		_malha.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.03 * (1.0 - s)  # treme saindo do chão
	else:
		_malha.scale = Vector3.ONE * lerpf(0.15, 1.0, k * k * (3.0 - 2.0 * k))


func _partir() -> void:
	_voando = true
	var rumo := destino - global_position
	if altura_de_subida > 0.0:
		rumo.y = maxf(rumo.y, 0.0)          # a pedra gigante sai do chão: não mergulha de volta nele
	_vel = (rumo.normalized() if rumo.length_squared() > 0.001 else -global_basis.z) * velocidade
	_malha.position = Vector3.ZERO
	_malha.scale = Vector3.ONE
	var yaw_plano := Vector3(_vel.x, 0.0, _vel.z)
	if yaw_plano.length_squared() > 0.001:
		_yaw = atan2(-yaw_plano.x, -yaw_plano.z)
		rotation.y = _yaw


func _voar(delta: float) -> void:
	var passo := _vel * delta
	var n := maxi(1, ceili(passo.length() / maxf(tamanho * 0.45, 0.05)))   # nunca anda mais que ~metade do cubo por vez
	var sub := passo / float(n)
	for i in n:
		var proximo := global_position + sub
		if _tocou_no_mundo(proximo):
			_quebrar(global_position)
			return
		global_position = proximo
		_percorrido += sub.length()
		var alvo := _alvo_tocado()
		if alvo != null:
			_quebrar(global_position, alvo)
			return
		if _percorrido >= alcance:
			_quebrar(global_position)
			return
	_vel.y -= (0.0 if altura_de_subida > 0.0 else GRAVIDADE) * delta   # a gigante voa reta: a de 3 m já raspa o chão


func _excluidos() -> Array[RID]:
	var r: Array[RID] = []
	if is_instance_valid(autor) and autor is CollisionObject3D:
		r.append((autor as CollisionObject3D).get_rid())
	for a in AlvosDeGolpe.todos(get_tree()):
		if a is CollisionObject3D:
			r.append((a as CollisionObject3D).get_rid())
	return r


## O cenário (camada 1) contra o CUBO inteiro, não contra um raio: pedra larga não atravessa quina.
func _tocou_no_mundo(onde: Vector3) -> bool:
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * tamanho * 0.98
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(Vector3.UP, _yaw), onde)
	q.collision_mask = 1
	q.exclude = _excluidos()
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _alvo_tocado() -> Node3D:
	if dano <= 0.0 or not is_instance_valid(autor):
		return null
	var melhor: Node3D = null
	var menor := INF
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(autor, alvo) or CombatResolver.e_fogo_amigo(alvo, autor):
			continue
		if not cubo_toca_alvo(alvo, global_position, _yaw, tamanho * 0.5):
			continue
		var d := global_position.distance_squared_to(AlvosDeGolpe.centro(alvo))
		if d < menor:
			menor = d
			melhor = alvo
	return melhor


## Cubo orientado (centro, yaw, meia aresta) contra o corpo do alvo. Cápsula = pontos ao longo do eixo
## com o raio; esfera = um ponto; caixa = grade de pontos dentro dela; sem Hurtbox = esfera de 0,45 m no centro.
static func cubo_toca_alvo(alvo: Node3D, centro: Vector3, yaw: float, meia: float) -> bool:
	var inv := Transform3D(Basis(Vector3.UP, yaw), centro).affine_inverse()
	var hb := alvo.get_node_or_null("Hurtbox")
	if hb != null:
		var usou := false
		for filho in hb.get_children():
			var cs := filho as CollisionShape3D
			if cs == null or cs.disabled or cs.shape == null:
				continue
			var xf := cs.global_transform
			var escala := xf.basis.get_scale().x
			if cs.shape is CapsuleShape3D:
				var c := cs.shape as CapsuleShape3D
				var eixo := maxf(0.0, c.height * 0.5 - c.radius)
				for i in 7:
					var y := lerpf(-eixo, eixo, float(i) / 6.0)
					if _dist_ao_cubo(inv * (xf * Vector3(0, y, 0)), meia) <= c.radius * escala:
						return true
				usou = true
			elif cs.shape is SphereShape3D:
				if _dist_ao_cubo(inv * xf.origin, meia) <= (cs.shape as SphereShape3D).radius * escala:
					return true
				usou = true
			elif cs.shape is BoxShape3D:
				var h := (cs.shape as BoxShape3D).size * 0.5
				for ix in 3:
					for iy in 3:
						for iz in 3:
							var p := Vector3(lerpf(-h.x, h.x, ix * 0.5), lerpf(-h.y, h.y, iy * 0.5), lerpf(-h.z, h.z, iz * 0.5))
							if _dist_ao_cubo(inv * (xf * p), meia) <= 0.0:
								return true
				usou = true
		if usou:
			return false
	return _dist_ao_cubo(inv * AlvosDeGolpe.centro(alvo), meia) <= 0.45


## Distância de um ponto (já no espaço do cubo) até o cubo de meia aresta `meia`; 0 se estiver dentro.
static func _dist_ao_cubo(local: Vector3, meia: float) -> float:
	return (local.abs() - Vector3.ONE * meia).max(Vector3.ZERO).length()


func _quebrar(onde: Vector3, principal: Node3D = null) -> void:
	_acabou = true
	var forte := raio_de_explosao > 0.0
	if dano > 0.0 and is_instance_valid(autor):
		var rumo := _vel.normalized() if _vel.length_squared() > 0.01 else -global_basis.z
		if principal != null:
			CombatResolver.aplicar(principal, dano, _spec.cast_id, 0.0, onde,
				rumo * empurrao + Vector3.UP * (4.0 if forte else 2.0), 0.5 if forte else 0.3, 0.0, false, null, autor)
		if forte:
			for alvo in AlvosDeGolpe.todos(get_tree()):
				if alvo == principal or not MundoMinePiece.atacavel(autor, alvo) or CombatResolver.e_fogo_amigo(alvo, autor):
					continue
				if AlvosDeGolpe.distancia_ao_corpo(alvo, onde) > raio_de_explosao:
					continue
				var fora := AlvosDeGolpe.centro(alvo) - onde
				fora.y = 0.0
				if fora.length_squared() < 0.001:
					fora = rumo
				CombatResolver.aplicar(alvo, dano * 0.6, _spec.cast_id, 0.0, onde,
					fora.normalized() * empurrao * 0.7 + Vector3.UP * 5.0, 0.4, 0.0, false, null, autor)
		CombatResolver.encerrar(_spec.cast_id)
	_estilhacar(onde, forte)
	queue_free()


## Pedaços cúbicos da própria pedra e poeira; o C ainda abre o chão.
func _estilhacar(onde: Vector3, forte: bool) -> void:
	var pai := get_tree().current_scene
	if pai == null:
		return
	var p := CPUParticles3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE * clampf(tamanho * 0.22, 0.12, 0.6)
	caixa.material = KiraVfx.material(textura, 0.1)
	p.mesh = caixa
	p.amount = 60 if forte else 14
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 90.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 14.0 if forte else 7.0
	p.gravity = Vector3(0, -20.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	pai.add_child(p)
	p.global_position = onde
	p.emitting = true
	pai.get_tree().create_timer(1.5, false).timeout.connect(p.queue_free)
	PoderVfx.impacto(pai, onde, Color(0.75, 0.8, 0.88), (raio_de_explosao if forte else 1.4 + tamanho), PoderVfx.Forma.QUADRADO)
	if forte:
		PoderVfx.solo(pai, onde - Vector3.UP * 0.5, raio_de_explosao * 0.8)
	PoderVfx.tremor(pai, 0.7 if forte else 0.15)
