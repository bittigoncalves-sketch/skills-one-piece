class_name EstruturaDestrutivel
extends Node3D
## Uma construção do mapa dividida em bloquinhos (08/11/2026). Vive como filho do corpo da peça (StaticBody3D) SÓ enquanto
## está "aberta": a peça fica intacta (modelo voxel + colisão do catálogo) até o primeiro golpe; nesse instante `abrir`
## troca o desenho por uma malha por CHUNK de `CHUNK` células e a colisão por uma forma por chunk — assim quebrar um cubo
## refaz só o chunk dele e os vizinhos, e dá para atravessar o buraco. `restaurar` desfaz tudo e devolve a peça original.
##
## Limites declarados: o interior guardado é raso (2 camadas, ver `BlocosVoxel`) e as células quebradas não caem — viram
## poeira de cubos (CPUParticles3D). GATILHO: se o dono pedir que os blocos caiam e rolem, trocar a poeira por RigidBody3D
## com teto de corpos vivos (hoje seria um custo de física sem teto).

const CHUNK := 8
const MAX_CHUNKS_POR_QUADRO := 6
const FRAGMENTOS_MAX := 14

var corpo: StaticBody3D
var _partes: Array[Dictionary] = []     # {malha: MeshInstance3D, blocos: BlocosVoxel, xf: Transform3D (parte→corpo), raiz: Node3D, chunks: {}}
var _sujos := {}                        # Vector4i(parte, chunk.xyz) -> true (conjunto: quebrar mexe em milhares de vizinhos)
var _colisao: StaticBody3D
var _colisoes_originais: Array[CollisionShape3D] = []
var _aberta := false


## Cria e abre a estrutura de `corpo`. null se a peça não tem malha voxel com dado de interior (ex.: modelo não voxelizado).
static func abrir_em(corpo_da_peca: StaticBody3D) -> EstruturaDestrutivel:
	var modelo := corpo_da_peca.get_node_or_null("Modelo") as Node3D
	if modelo == null:
		return null
	var e := EstruturaDestrutivel.new()
	e.name = "Destrutivel"
	e.corpo = corpo_da_peca
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		var blocos := BlocosVoxel.de_malha(mi.mesh as ArrayMesh)
		if blocos == null:
			continue
		e._partes.append({"malha": mi, "blocos": blocos, "chunks": {}})
	if e._partes.is_empty():
		e.free()
		return null
	corpo_da_peca.add_child(e)
	e._abrir()
	return e


func _abrir() -> void:
	_aberta = true
	var inversa := corpo.global_transform.affine_inverse()
	for i in _partes.size():
		var parte := _partes[i]
		var mi: MeshInstance3D = parte["malha"]
		parte["xf"] = inversa * mi.global_transform
		var raiz := Node3D.new()
		raiz.name = "Parte_%d" % i
		raiz.transform = parte["xf"]
		add_child(raiz)
		parte["raiz"] = raiz
		mi.visible = false
		var blocos: BlocosVoxel = parte["blocos"]
		var chunks := {}
		for p: Vector3i in blocos.celulas:
			chunks[Vector3i((Vector3(p) / CHUNK).floor())] = true
		for c: Vector3i in chunks:
			_sujos[Vector4i(i, c.x, c.y, c.z)] = true
	# Colisão: a do catálogo sai, entra a dos blocos (mesma camada e máscara do corpo).
	for no in corpo.get_children():
		if no is CollisionShape3D and not (no.get_parent() is EstruturaDestrutivel):
			_colisoes_originais.append(no)
			(no as CollisionShape3D).set_deferred("disabled", true)
	_colisao = StaticBody3D.new()
	_colisao.name = "ColisaoDosBlocos"
	_colisao.collision_layer = corpo.collision_layer
	_colisao.collision_mask = corpo.collision_mask
	add_child(_colisao)
	reconstruir(true)       # a 1ª vez é inteira: o jogador viu a peça intacta e ela tem de continuar igual


func esta_aberta() -> bool:
	return _aberta


func celulas_vivas() -> int:
	var n := 0
	for p in _partes:
		n += (p["blocos"] as BlocosVoxel).vivas()
	return n


## Reconstrói os chunks sujos; `tudo` ignora o teto por quadro (abertura e testes).
func reconstruir(tudo := false) -> int:
	var feitos := 0
	while not _sujos.is_empty() and (tudo or feitos < MAX_CHUNKS_POR_QUADRO):
		var chave: Vector4i = _sujos.keys()[0]
		_sujos.erase(chave)
		_reconstruir_chunk(chave.x, Vector3i(chave.y, chave.z, chave.w))
		feitos += 1
	return feitos


func pendentes() -> int:
	return _sujos.size()


func _process(_delta: float) -> void:
	if _aberta and not _sujos.is_empty():
		reconstruir()


func _reconstruir_chunk(i: int, chunk: Vector3i) -> void:
	var parte := _partes[i]
	var blocos: BlocosVoxel = parte["blocos"]
	var chunks: Dictionary = parte["chunks"]
	var f := blocos.faces_do_chunk(chunk, CHUNK)
	var vazio := (f["indices"] as PackedInt32Array).is_empty()
	var entrada: Dictionary = chunks.get(chunk, {})
	if vazio:
		if not entrada.is_empty():
			(entrada["mi"] as MeshInstance3D).queue_free()
			(entrada["cs"] as CollisionShape3D).queue_free()
			chunks.erase(chunk)
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = f["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = f["normais"]
	arrays[Mesh.ARRAY_COLOR] = f["cores"]
	arrays[Mesh.ARRAY_INDEX] = f["indices"]
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malha.surface_set_material(0, blocos.material)
	# Colisão no espaço do CORPO (a escala da parte entra nos vértices: forma com escala no nó é ignorada/avisada pela física).
	var xf: Transform3D = parte["xf"]
	var tri := PackedVector3Array()
	var vs: PackedVector3Array = f["vertices"]
	for k in (f["indices"] as PackedInt32Array):
		tri.append(xf * vs[k])
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(tri)
	if entrada.is_empty():
		var mi := MeshInstance3D.new()
		mi.layers |= MapaMontador.CAMADA_CENARIO
		(parte["raiz"] as Node3D).add_child(mi)
		var cs := CollisionShape3D.new()
		_colisao.add_child(cs)
		entrada = {"mi": mi, "cs": cs}
		chunks[chunk] = entrada
	(entrada["mi"] as MeshInstance3D).mesh = malha
	(entrada["cs"] as CollisionShape3D).shape = forma


## Quebra os cubos a até `raio` metros (MUNDO) de `centro` (mundo). Devolve quantos quebrou.
func quebrar(centro: Vector3, raio: float) -> int:
	var total := 0
	var cor_media := Color(0, 0, 0, 0)
	var onde := Vector3.ZERO
	for i in _partes.size():
		var parte := _partes[i]
		var mi: MeshInstance3D = parte["malha"]
		var local := mi.global_transform.affine_inverse() * centro
		var escala := maxf(mi.global_basis.get_scale().x, 0.000001)
		var blocos: BlocosVoxel = parte["blocos"]
		var quebradas := blocos.quebrar_esfera(local, raio / escala)
		for q in quebradas:
			var c: Vector3i = q["celula"]
			cor_media += q["cor"]
			onde += mi.global_transform * ((Vector3(c) + Vector3(0.5, 0.5, 0.5)) * blocos.lado)
			_sujar(i, c)
			for d in BlocosVoxel.VIZINHOS:
				_sujar(i, c + d)
		total += quebradas.size()
	if total > 0:
		_poeira(onde / total, cor_media / total, total)
	return total


func _sujar(i: int, p: Vector3i) -> void:
	var c := Vector3i((Vector3(p) / CHUNK).floor())
	_sujos[Vector4i(i, c.x, c.y, c.z)] = true


## Fragmentos de cubos que voam e somem (sem física: ver o GATILHO no topo).
func _poeira(onde: Vector3, cor: Color, quebrados: int) -> void:
	var lado_mundo := 0.3
	for p in _partes:
		var mi: MeshInstance3D = p["malha"]
		lado_mundo = (p["blocos"] as BlocosVoxel).lado * mi.global_basis.get_scale().x
		break
	var particulas := CPUParticles3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3.ONE * lado_mundo * 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(cor.r, cor.g, cor.b, 1.0)
	mat.roughness = 1.0
	cubo.material = mat
	particulas.mesh = cubo
	particulas.amount = clampi(quebrados, 4, FRAGMENTOS_MAX)
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.lifetime = 1.1
	particulas.direction = Vector3.UP
	particulas.spread = 80.0
	particulas.initial_velocity_min = 2.0
	particulas.initial_velocity_max = 6.0
	particulas.gravity = Vector3(0, -22.0, 0)
	particulas.angular_velocity_min = -360.0
	particulas.angular_velocity_max = 360.0
	particulas.emitting = true
	var cena := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	cena.add_child(particulas)
	particulas.global_position = onde
	get_tree().create_timer(particulas.lifetime + 0.3).timeout.connect(particulas.queue_free)


## Devolve a peça ao que era: desenho e colisão originais, sem blocos e sem buracos.
func restaurar() -> void:
	if not _aberta:
		return
	_aberta = false
	for p in _partes:
		(p["malha"] as MeshInstance3D).visible = true
	for cs in _colisoes_originais:
		if is_instance_valid(cs):
			(cs as CollisionShape3D).set_deferred("disabled", false)
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
