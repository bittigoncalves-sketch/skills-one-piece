class_name VoxelizadorDeMalha
extends RefCounted
# Transforma uma malha qualquer (com ou sem esqueleto) numa malha de CUBOS que mantém a
# silhueta e a cor da original. Usado para os animais (tools/voxelizar_animais.gd).
#
# Como funciona (e por que assim):
#  1. Cada triângulo é amostrado em grade fina; cada amostra marca o voxel que ela cai e
#     acumula cor (textura x cor do material) e osso dominante. Assim o voxel herda a
#     TEXTURA — quem olha de perto vê o desenho do pelo/penas em blocos.
#  2. O interior é preenchido por inundação a partir de fora: só a casca visível gera face.
#  3. Cada voxel leva a mistura dos 4 ossos mais fortes que o cobrem (a do triângulo que o
#     gerou): todos os cantos do cubo deformam juntos, vizinhos deformam quase igual, e o
#     `Skin` e as animações do .glb original continuam valendo sem tocar neles. (Osso único
#     por cubo foi testado e rasga nas articulações; voxelizar na pose de repouso também falhou:
#     em rigs com a malha em T-pose o repouso comprime a geometria e a animação abre buracos.)
# O espaço é o da própria malha, como modelada (pose de bind): o `Skin` não muda.

const VIZINHOS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## `lado`: aresta do voxel em unidades do espaço da malha. Devolve null se não houver triângulos.
static func voxelizar(malha: Mesh, lado: float, rigido := true, com_interior := false) -> ArrayMesh:
	var casca := {}   # Vector3i -> {"cor": Color, "n": int, "ossos": {osso: peso}}
	var com_osso := false
	for s in malha.get_surface_count():
		if malha.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := malha.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var cores: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		var passo_osso := (ossos.size() / v.size()) if (v.size() > 0 and ossos.size() > 0) else 0
		com_osso = com_osso or passo_osso > 0
		var mat := malha.surface_get_material(s)
		var base := Color.WHITE
		var textura: Image = null
		var cor_de_vertice := false
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			base = bm.albedo_color
			cor_de_vertice = bm.vertex_color_use_as_albedo
			if bm.albedo_texture != null:
				textura = bm.albedo_texture.get_image()
				if textura != null and textura.is_compressed():
					textura.decompress()
		for t in range(0, idx.size(), 3):
			var i0 := idx[t]
			var i1 := idx[t + 1]
			var i2 := idx[t + 2]
			var a := v[i0]
			var b := v[i1]
			var c := v[i2]
			var maior := maxf((b - a).length(), maxf((c - b).length(), (a - c).length()))
			var n := maxi(1, ceili(maior / (lado * 0.5)))
			for i in n + 1:
				for j in n + 1 - i:
					var bu := i / float(n)
					var bv := j / float(n)
					var bw := 1.0 - bu - bv
					var p := a * bw + b * bu + c * bv
					var cel := Vector3i((p / lado).floor())
					var cor := base
					if textura != null and uv.size() == v.size():
						var q := uv[i0] * bw + uv[i1] * bu + uv[i2] * bv
						var tx := clampi(int(floorf(fposmod(q.x, 1.0) * textura.get_width())), 0, textura.get_width() - 1)
						var ty := clampi(int(floorf(fposmod(q.y, 1.0) * textura.get_height())), 0, textura.get_height() - 1)
						cor *= textura.get_pixel(tx, ty)
					if cor_de_vertice and cores.size() == v.size():
						cor *= cores[i0] * bw + cores[i1] * bu + cores[i2] * bv
					var dado: Dictionary = casca.get(cel, {})
					if dado.is_empty():
						dado = {"cor": Color(0, 0, 0, 0), "n": 0, "ossos": {}}
						casca[cel] = dado
					dado["cor"] = (dado["cor"] as Color) + cor
					dado["n"] += 1
					if passo_osso > 0:
						# Pesos do ponto = mistura (baricêntrica) dos pesos dos 3 vértices.
						var acc: Dictionary = dado["ossos"]
						for par in [[i0, bw], [i1, bu], [i2, bv]]:
							for k in passo_osso:
								var w: float = pesos[par[0] * passo_osso + k]
								if w > 0.0:
									var osso: int = ossos[par[0] * passo_osso + k]
									acc[osso] = acc.get(osso, 0.0) + w * par[1]
	if casca.is_empty():
		return null
	var solido := _preencher(casca)
	var resultado := _construir(casca, solido, lado, com_osso, rigido)
	if com_interior:
		_gravar_interior(resultado, casca, solido, lado)
	return resultado

## Células vazias que não alcançam o lado de fora = interior. Devolve um dicionário de TODAS as
## células sólidas (casca + interior); o interior vale `true`, só para cortar faces.
static func _preencher(casca: Dictionary) -> Dictionary:
	var mn := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var mx := Vector3i(-(1 << 30), -(1 << 30), -(1 << 30))
	for p: Vector3i in casca:
		mn = mn.min(p)
		mx = mx.max(p)
	mn -= Vector3i.ONE
	mx += Vector3i.ONE
	var fora := {}
	var fila: Array[Vector3i] = [mn]
	fora[mn] = true
	while not fila.is_empty():
		var p: Vector3i = fila.pop_back()
		for d in VIZINHOS:
			var q := p + d
			if q.x < mn.x or q.y < mn.y or q.z < mn.z or q.x > mx.x or q.y > mx.y or q.z > mx.z:
				continue
			if fora.has(q) or casca.has(q):
				continue
			fora[q] = true
			fila.append(q)
	var solido := {}
	for x in range(mn.x, mx.x + 1):
		for y in range(mn.y, mx.y + 1):
			for z in range(mn.z, mx.z + 1):
				var p := Vector3i(x, y, z)
				if not fora.has(p):
					solido[p] = true
	return solido

## Para a DESTRUIÇÃO (src/world/destrutivel): guarda na própria malha o `lado` do cubo e as células de interior até
## `PROFUNDIDADE_INTERIOR` camadas abaixo da casca (com a cor da célula de casca que as alcançou). Sem elas, quebrar uma parede
## de 1 cubo deixaria ver o vazio atrás; mais fundo que isso o interior é tratado como vazio (a parede "acaba" ali).
const PROFUNDIDADE_INTERIOR := 2

static func _gravar_interior(malha: ArrayMesh, casca: Dictionary, solido: Dictionary, lado: float) -> void:
	var coords := PackedInt32Array()
	var cores := PackedColorArray()
	var visto := {}
	var fronteira: Array = []
	for p: Vector3i in casca:
		var dado: Dictionary = casca[p]
		var cor: Color = (dado["cor"] as Color) / float(dado["n"])
		cor.a = 1.0
		fronteira.append([p, cor])
	for _camada in PROFUNDIDADE_INTERIOR:
		var proxima: Array = []
		for par in fronteira:
			for d in VIZINHOS:
				var q: Vector3i = (par[0] as Vector3i) + d
				if casca.has(q) or visto.has(q) or not solido.has(q):
					continue
				visto[q] = true
				coords.append_array(PackedInt32Array([q.x, q.y, q.z]))
				cores.append(par[1])
				proxima.append([q, par[1]])
		fronteira = proxima
	malha.set_meta("voxel_lado", lado)
	malha.set_meta("voxel_interior", coords)
	malha.set_meta("voxel_interior_cor", cores)


static func _construir(casca: Dictionary, solido: Dictionary, lado: float, com_osso: bool, rigido: bool) -> ArrayMesh:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var bs := PackedInt32Array()
	var ws := PackedFloat32Array()
	var ix := PackedInt32Array()
	for p: Vector3i in casca:
		var dado: Dictionary = casca[p]
		var cor: Color = (dado["cor"] as Color) / float(dado["n"])
		cor.a = 1.0
		# Os 4 ossos mais fortes do voxel, normalizados: o cubo inteiro leva a MESMA mistura, então
		# vizinhos deformam quase igual (sem rasgar) e o cubo continua um cubo (inclinado).
		var quatro: Array = (dado["ossos"] as Dictionary).keys()
		quatro.sort_custom(func(x: int, y: int) -> bool: return dado["ossos"][x] > dado["ossos"][y])
		quatro = quatro.slice(0, 1 if rigido else 4)
		var soma := 0.0
		for o in quatro:
			soma += dado["ossos"][o]
		var ids: Array[int] = [0, 0, 0, 0]
		var pes: Array[float] = [0.0, 0.0, 0.0, 0.0]
		for i in quatro.size():
			ids[i] = quatro[i]
			pes[i] = dado["ossos"][quatro[i]] / soma if soma > 0.0 else (1.0 if i == 0 else 0.0)
		for n in VIZINHOS:
			if solido.has(p + n):
				continue
			var nf := Vector3(n)
			var u := Vector3.UP if n.y == 0 else Vector3.RIGHT
			var w := nf.cross(u)
			var f := (Vector3(p) + Vector3(0.5, 0.5, 0.5) + nf * 0.5)
			var q := [f - u * 0.5 - w * 0.5, f + u * 0.5 - w * 0.5, f + u * 0.5 + w * 0.5, f - u * 0.5 + w * 0.5]
			var base := vs.size()
			for k in 4:
				vs.append(q[k] * lado)
				ns.append(nf)
				cs.append(cor)
				if com_osso:
					bs.append_array(ids)
					ws.append_array(pes)
			# Godot: face frontal = ordem HORÁRIA vista de fora (produto vetorial contra a normal).
			var tri := [0, 1, 2, 0, 2, 3]
			if (q[1] - q[0]).cross(q[2] - q[0]).dot(nf) > 0.0:
				tri = [0, 2, 1, 0, 3, 2]
			for k in tri:
				ix.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	arrays[Mesh.ARRAY_COLOR] = cs
	if com_osso:
		arrays[Mesh.ARRAY_BONES] = bs
		arrays[Mesh.ARRAY_WEIGHTS] = ws
	arrays[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	# Os dois lados desenham: com osso espelhado (escala negativa) o Godot não inverte o sentido
	# dos triângulos de malha com esqueleto, e as faces sumiriam.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.resource_name = "voxel_cor_por_cubo"
	m.surface_set_material(0, mat)
	return m


## Voxeliza TODAS as malhas visíveis do modelo `id` da biblioteca e grava
## `<pasta>/<id>.voxel.scn` (uma MeshInstance3D por malha, nome = caminho do nó com "/" -> "|"),
## que `BibliotecaDeModelos.instanciar` aplica por cima do .glb sem alterá-lo. `resolucao` =
## voxels no maior lado do modelo. Devolve "" ou o motivo da falha. Usado por
## tools/voxelizar_animais.gd e tools/voxelizar_casas.gd.
static func gravar_modelo(bib: BibliotecaDeModelos, id: String, pasta: String, resolucao: int, com_interior := false) -> String:
	var cena := BibliotecaDeModelos.carregar_glb(bib.caminho_do_arquivo(id))
	if cena == null:
		return "não abriu o .glb"
	var caixa: AABB = BibliotecaDeModelos.medir(cena)["aabb"]
	var maior := maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
	if maior <= 0.0:
		cena.free()
		return "modelo sem tamanho"
	var lado_mundo := maior / resolucao
	var saida := Node3D.new()
	saida.name = "Voxel"
	var n_malhas := 0
	for no in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null or BibliotecaDeModelos.e_malha_de_colisao(mi):
			continue
		var escala := BibliotecaDeModelos._transformacao_ate(mi, cena).basis.get_scale()
		var lado_local := lado_mundo / maxf(escala.x, 0.000001)
		var malha := voxelizar(mi.mesh, lado_local, true, com_interior)
		if malha == null:
			continue
		var filho := MeshInstance3D.new()
		filho.name = str(cena.get_path_to(mi)).replace("/", "|")
		filho.mesh = malha
		saida.add_child(filho)
		filho.owner = saida
		n_malhas += 1
	cena.free()
	if n_malhas == 0:
		saida.free()
		return "nenhuma malha voxelizada"
	var pacote := PackedScene.new()
	pacote.pack(saida)
	saida.free()
	var destino := pasta.path_join(id + ".voxel.scn")
	if ResourceSaver.save(pacote, destino, ResourceSaver.FLAG_COMPRESS) != OK:
		return "falhou ao gravar " + destino
	return ""
