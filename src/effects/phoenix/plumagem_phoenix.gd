extends RefCounted
## Fonte editável da plumagem: volumes fechados, sem cartões nem deformação.
## Penas crescem em +Y; largura é a meia largura máxima, curva arqueia em +Z.
## COLOR contém veios suaves e deve multiplicar o albedo do material.

const SEGMENTOS_PENA := 28
const LADOS_PENA := 20
const SUBDIVISOES_TUBO := 4

static func pena(comprimento: float, largura: float, curva: float, mat: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var altura := maxf(comprimento, 0.001)
	var meia_largura := maxf(largura, 0.0001)
	# A seção elíptica fecha as duas faces; a quilha engrossa o centro.
	for i in SEGMENTOS_PENA:
		var t := float(i) / SEGMENTOS_PENA
		var envelope := (0.10 + 0.90 * pow(sin(PI * t), 0.62)) * (1.0 - 0.31 * t)
		var serrilha := 1.0 - 0.035 * pow(sin(t * PI * 14.0), 6.0) * sin(PI * t)
		var w := meia_largura * envelope * serrilha
		for j in LADOS_PENA:
			var ang := TAU * float(j) / LADOS_PENA
			var lateral := cos(ang)
			var quilha := exp(-absf(lateral) * 9.0)
			var nervuras := 0.5 + 0.5 * cos((t * 11.0 - absf(lateral) * 3.0) * TAU)
			var espessura := meia_largura * (0.055 + 0.095 * quilha + 0.009 * nervuras) * envelope
			vertices.append(Vector3(lateral * w, altura * t, curva * t * t + sin(ang) * espessura))
			var valor := (0.78 + 0.13 * nervuras + 0.09 * quilha) * lerpf(1.0,0.68,smoothstep(0.82,1.0,absf(lateral)))
			cores.append(Color(valor, valor, valor, 1.0))
			uvs.append(Vector2(lateral * 0.5 + 0.5, t))
	_connect_rings(indices, SEGMENTOS_PENA, LADOS_PENA)
	_cap(vertices, cores, uvs, indices, Vector3.ZERO, 0, LADOS_PENA, true)
	_cap(vertices, cores, uvs, indices, Vector3(0, altura, curva), (SEGMENTOS_PENA - 1) * LADOS_PENA, LADOS_PENA, false)
	return _mesh(vertices, cores, uvs, indices, mat)


## Loft Catmull-Rom com referencial transportado, perpendicular à tangente.
## Raios.x/y são os semieixos locais; aceita curvas em qualquer direção.
static func tubo(pontos: PackedVector3Array, raios: PackedVector2Array, mat: Material, lados := 24) -> MeshInstance3D:
	if pontos.size() < 2 or raios.size() != pontos.size():
		push_error("Plumagem.tubo exige dois pontos e um par de raios por ponto.")
		return MeshInstance3D.new()
	lados = maxi(lados, 8)
	var centros := PackedVector3Array()
	var seccoes := PackedVector2Array()
	for i in pontos.size() - 1:
		for k in SUBDIVISOES_TUBO:
			var t := float(k) / SUBDIVISOES_TUBO
			centros.append(_catmull(pontos[maxi(i-1, 0)], pontos[i], pontos[i+1], pontos[mini(i+2, pontos.size()-1)], t))
			var r := _catmull(Vector3(raios[maxi(i-1, 0)].x, raios[maxi(i-1, 0)].y, 0), Vector3(raios[i].x, raios[i].y, 0), Vector3(raios[i+1].x, raios[i+1].y, 0), Vector3(raios[mini(i+2, raios.size()-1)].x, raios[mini(i+2, raios.size()-1)].y, 0), t)
			seccoes.append(Vector2(maxf(r.x, 0.0001), maxf(r.y, 0.0001)))
	centros.append(pontos[-1])
	seccoes.append(Vector2(maxf(raios[-1].x, 0.0001), maxf(raios[-1].y, 0.0001)))
	var vertices := PackedVector3Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var lateral := Vector3.RIGHT
	for i in centros.size():
		var tangente := (centros[mini(i+1, centros.size()-1)] - centros[maxi(i-1, 0)]).normalized()
		if tangente.length_squared() < 0.1:
			tangente = Vector3.UP
		lateral = lateral - tangente * lateral.dot(tangente)
		if lateral.length_squared() < 0.001:
			lateral = tangente.cross(Vector3.FORWARD if absf(tangente.z) < 0.9 else Vector3.UP)
		lateral = lateral.normalized()
		var profundidade := lateral.cross(tangente).normalized()
		for j in lados:
			var ang := TAU * float(j) / lados
			vertices.append(centros[i] + lateral * cos(ang) * seccoes[i].x + profundidade * sin(ang) * seccoes[i].y)
			cores.append(Color.WHITE)
			uvs.append(Vector2(float(j)/lados, float(i)/(centros.size()-1)))
	_connect_rings(indices, centros.size(), lados)
	_cap(vertices, cores, uvs, indices, centros[0], 0, lados, true)
	_cap(vertices, cores, uvs, indices, centros[-1], (centros.size()-1)*lados, lados, false)
	return _mesh(vertices, cores, uvs, indices, mat)


static func _catmull(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	return 0.5 * ((2.0*b) + (-a+c)*t + (2.0*a-5.0*b+4.0*c-d)*t*t + (-a+3.0*b-3.0*c+d)*t*t*t)


static func _connect_rings(indices: PackedInt32Array, aneis: int, lados: int) -> void:
	for i in aneis - 1:
		for j in lados:
			var a := i*lados+j
			var b := i*lados+(j+1)%lados
			var c := (i+1)*lados+j
			var d := (i+1)*lados+(j+1)%lados
			# Godot usa triângulos horários para a face frontal.
			indices.append_array(PackedInt32Array([a,b,c,b,d,c]))


static func _cap(vertices: PackedVector3Array, cores: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, centro: Vector3, inicio: int, lados: int, base: bool) -> void:
	var indice := vertices.size()
	vertices.append(centro)
	cores.append(Color.WHITE)
	uvs.append(Vector2(0.5, 0.0 if base else 1.0))
	for j in lados:
		var a := inicio+j
		var b := inicio+(j+1)%lados
		indices.append_array(PackedInt32Array([indice,b,a] if base else [indice,a,b]))


static func _mesh(vertices: PackedVector3Array, cores: PackedColorArray, uvs: PackedVector2Array, indices: PackedInt32Array, mat: Material) -> MeshInstance3D:
	var normais := PackedVector3Array()
	normais.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var a := indices[i]
		var b := indices[i+1]
		var c := indices[i+2]
		var normal := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normais[a] += normal
		normais[b] += normal
		normais[c] += normal
	for i in normais.size():
		normais[i] = normais[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_COLOR] = cores
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instancia := MeshInstance3D.new()
	instancia.mesh = mesh
	instancia.material_override = mat
	return instancia


## Junta somente folhas MeshInstance3D estáticas diretamente sob este pivô.
## Chamar uma vez após construir cada articulação; nunca atravessa outros nós.
static func consolidar(raiz: Node3D) -> void:
	var grupos: Dictionary = {}
	for filho in raiz.get_children():
		if not filho is MeshInstance3D:
			continue
		var folha := filho as MeshInstance3D
		if not folha.visible or folha.mesh == null or folha.get_child_count() != 0 or folha.skin != null:
			continue
		if folha.mesh.get_surface_count() != 1 or folha.mesh is PointMesh:
			continue
		if folha.mesh is ArrayMesh:
			if folha.mesh.get_blend_shape_count() != 0 or folha.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
				continue
		elif not folha.mesh is PrimitiveMesh:
			continue
		var material := folha.get_active_material(0)
		var chave := "%s:%s:%s:%s" % [material.get_instance_id() if material else 0, folha.cast_shadow, folha.layers, folha.transparency]
		if not grupos.has(chave):
			grupos[chave] = []
		grupos[chave].append(folha)
	for grupo: Array in grupos.values():
		if grupo.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for folha: MeshInstance3D in grupo:
			var arrays := folha.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normais: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var cores: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for i in vertices.size(): indices.append(i)
			var normal_xform := folha.transform.basis.inverse().transposed()
			var espelhado := folha.transform.basis.determinant() < 0.0
			for i in range(0, indices.size(), 3):
				for j in ([0,2,1] if espelhado else [0,1,2]):
					var indice := indices[i+j]
					st.set_normal((normal_xform * normais[indice]).normalized() if not normais.is_empty() else Vector3.UP)
					st.set_color(cores[indice] if not cores.is_empty() else Color.WHITE)
					st.set_uv(uvs[indice] if not uvs.is_empty() else Vector2.ZERO)
					st.add_vertex(folha.transform * vertices[indice])
		st.index()
		var nova := MeshInstance3D.new()
		nova.name = "PlumagemConsolidada"
		nova.mesh = st.commit()
		nova.material_override = grupo[0].get_active_material(0)
		nova.cast_shadow = grupo[0].cast_shadow
		nova.layers = grupo[0].layers
		nova.transparency = grupo[0].transparency
		raiz.add_child(nova)
		for folha: MeshInstance3D in grupo:
			raiz.remove_child(folha)
			folha.free()
