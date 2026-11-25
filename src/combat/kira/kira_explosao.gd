extends Node3D
## Estilhaços visíveis e suas colisões compartilham a mesma trajetória.
const VELOCIDADE := 16.0
const DURACAO := 0.75
const RAIO_DE_CONTATO := 0.38
const KiraVfx = preload("res://src/combat/kira/kira_vfx.gd")
static var _cristal: ArrayMesh
var _tempo := 0.0
var direcoes := PackedVector3Array()
var autor: Node3D
var dano := 0.0
var _posicoes := PackedVector3Array()
var _ativos := PackedByteArray()
var _atingidos := {}
var _instancias: MultiMesh


static func criar(pai: Node, posicao: Vector3, rumos: PackedVector3Array, dono: Node3D = null, dano_por_fragmento := 0.0, forte := false) -> void:
	if not is_instance_valid(pai):
		return
	var efeito := (load("res://src/combat/kira/kira_explosao.gd") as Script).new() as Node3D
	efeito.direcoes = rumos
	efeito.autor = dono
	efeito.dano = dano_por_fragmento
	pai.add_child(efeito)
	efeito.global_position = posicao
	KiraVfx.impacto(pai, posicao, forte)


static func malha() -> ArrayMesh:
	if _cristal != null:
		return _cristal
	var ferramenta := SurfaceTool.new()
	ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cima := Vector3(0, 0.7, 0)
	var baixo := Vector3(0, -0.7, 0)
	var anel := [Vector3(0.36, 0, 0), Vector3(0, 0, 0.36), Vector3(-0.36, 0, 0), Vector3(0, 0, -0.36)]
	for i in 4:
		var a: Vector3 = anel[i]
		var b: Vector3 = anel[(i + 1) % 4]
		for v in [cima, b, a, baixo, a, b]:
			ferramenta.add_vertex(v)
	ferramenta.generate_normals()
	_cristal = ferramenta.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.78, 0.94)
	material.metallic = 0.25
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = Color(0.12, 0.38, 0.5)
	material.emission_energy_multiplier = 0.65
	_cristal.surface_set_material(0, material)
	return _cristal


func _ready() -> void:
	_posicoes.resize(direcoes.size())
	_ativos.resize(direcoes.size())
	_ativos.fill(1)
	_instancias = MultiMesh.new()
	_instancias.transform_format = MultiMesh.TRANSFORM_3D
	_instancias.mesh = malha()
	_instancias.instance_count = direcoes.size()
	var fragmentos := MultiMeshInstance3D.new()
	fragmentos.name = "EstilhacosDeDiamante"
	fragmentos.multimesh = _instancias
	fragmentos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fragmentos.custom_aabb = AABB(Vector3(-13, -13, -13), Vector3(26, 26, 26))
	add_child(fragmentos)
	add_to_group("kira_explosao_visual")
	_atualizar_malhas()


func _physics_process(delta: float) -> void:
	var dt := minf(delta, maxf(DURACAO - _tempo, 0.0))
	_tempo += delta
	var alvos: Array[Node] = AlvosDeGolpe.todos(get_tree()) if is_instance_valid(autor) and dano > 0.0 else []
	var candidatos: Array[Node] = []
	var excluir: Array[RID] = []
	if is_instance_valid(autor) and autor is CollisionObject3D:
		excluir.append((autor as CollisionObject3D).get_rid())
	for alvo in alvos:
		if is_instance_valid(alvo) and alvo is CollisionObject3D:
			excluir.append((alvo as CollisionObject3D).get_rid())
		if MundoMinePiece.atacavel(autor, alvo) and not CombatResolver.e_fogo_amigo(alvo, autor) \
				and AlvosDeGolpe.distancia_ao_corpo(alvo, global_position) <= VELOCIDADE * DURACAO + RAIO_DE_CONTATO:
			candidatos.append(alvo)
	for i in direcoes.size():
		if _ativos[i] == 0:
			continue
		var de: Vector3 = global_position + _posicoes[i]
		var ate: Vector3 = de + direcoes[i] * VELOCIDADE * dt
		var parede := _parede(de, ate, excluir)
		if not parede.is_empty():
			ate = (parede.position as Vector3) - direcoes[i] * 0.02
		var primeiro: Node3D
		var menor := INF
		for alvo in candidatos:
			if not is_instance_valid(alvo) or not MundoMinePiece.atacavel(autor, alvo):
				continue
			var perto := Geometry3D.get_closest_point_to_segment(AlvosDeGolpe.centro(alvo), de, ate)
			if AlvosDeGolpe.distancia_ao_corpo(alvo, perto) <= RAIO_DE_CONTATO:
				if not _parede(perto, AlvosDeGolpe.centro(alvo), excluir).is_empty():
					continue
				var distancia := de.distance_squared_to(perto)
				if distancia < menor:
					menor = distancia
					primeiro = alvo
		if primeiro != null:
			if not _atingidos.has(primeiro):
				_atingidos[primeiro] = true
				CombatResolver.aplicar(primeiro, dano, 0, 0.0, global_position,
					direcoes[i] * 4.0 + Vector3.UP * 1.0, 0.15, 0.0, false, null, autor)
			_ativos[i] = 0
		elif not parede.is_empty():
			_ativos[i] = 0
		_posicoes[i] = ate - global_position
	_atualizar_malhas()
	if _tempo >= DURACAO:
		queue_free()


func _parede(de: Vector3, ate: Vector3, excluir: Array[RID]) -> Dictionary:
	if de.distance_squared_to(ate) < 0.000001:
		return {}
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(de, ate, 1, excluir))


func _atualizar_malhas() -> void:
	for i in direcoes.size():
		var escala := (0.4 + 0.07 * float(i % 5)) if _ativos[i] != 0 else 0.0
		var giro := Basis.from_euler(Vector3(_tempo * 5.0 + i, _tempo * 3.0, i * 0.8)).scaled(Vector3.ONE * escala)
		_instancias.set_instance_transform(i, Transform3D(giro, _posicoes[i]))
