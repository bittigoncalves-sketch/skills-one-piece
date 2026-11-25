class_name BlocosVoxel
extends RefCounted
## As células (cubos) de UMA malha voxel e a remoção delas (08/11/2026, destruição de construções por blocos).
##
## A fonte é a malha que `VoxelizadorDeMalha` já gravou em `<id>.voxel.scn`: cada face é um quadrado `lado × lado` em múltiplos
## de `lado`, então dá para recuperar a célula e a cor de cada face, e os metadados `voxel_*` trazem o interior raso (2 camadas).
## Aqui só há DADOS e geometria: quem tem nós (malha, colisão) é `EstruturaDestrutivel`.
##
## Regra de face (a mesma da voxelização): um cubo mostra a face `d` se o vizinho `p+d` não existe. Exceção: o cubo da camada
## mais funda do interior (`FUNDO`) só mostra a face se o vizinho foi DESTRUÍDO — o que está atrás dele não foi guardado, e sem
## esta regra todo o miolo da parede viraria faces internas (o dobro de triângulos, tudo escondido).

const FUNDO := 2
const VIZINHOS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var lado := 1.0
var material: Material
## Vector3i -> int: cor RGB nos 24 bits altos, profundidade (0 casca, 1–2 interior) no byte baixo.
var celulas := {}
var destruidas := {}          # Vector3i -> true: células que já existiram e foram quebradas
var total := 0                # células vivas no começo


static func de_malha(malha: ArrayMesh) -> BlocosVoxel:
	if malha == null or malha.get_surface_count() == 0 or not malha.has_meta("voxel_lado"):
		return null
	var b := BlocosVoxel.new()
	b.lado = float(malha.get_meta("voxel_lado"))
	b.material = malha.surface_get_material(0)
	var arr := malha.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	for i in range(0, v.size(), 4):
		var centro := (v[i] + v[i + 1] + v[i + 2] + v[i + 3]) * 0.25 - n[i] * (b.lado * 0.5)
		var p := Vector3i((centro / b.lado).floor())
		if not b.celulas.has(p):
			b.celulas[p] = _empacotar(c[i], 0)
	var coords: PackedInt32Array = malha.get_meta("voxel_interior", PackedInt32Array())
	var cores: PackedColorArray = malha.get_meta("voxel_interior_cor", PackedColorArray())
	# As duas camadas do interior vêm em ordem de alcance: a 1ª até o fim da 1ª fronteira. Sem guardar o corte, a profundidade é
	# recalculada: vizinho de casca = 1, o resto = FUNDO.
	for k in cores.size():
		var q := Vector3i(coords[k * 3], coords[k * 3 + 1], coords[k * 3 + 2])
		if b.celulas.has(q):
			continue
		var raso := false
		for d in VIZINHOS:
			if b.celulas.has(q + d) and (int(b.celulas[q + d]) & 0xFF) == 0:
				raso = true
				break
		b.celulas[q] = _empacotar(cores[k], 1 if raso else FUNDO)
	b.total = b.celulas.size()
	return b


static func _empacotar(cor: Color, profundidade: int) -> int:
	return (cor.to_rgba32() & 0xFFFFFF00) | profundidade


static func cor_de(valor: int) -> Color:
	return Color.hex(valor | 0xFF)


func vivas() -> int:
	return celulas.size()


## Quebra as células cujo CENTRO fica a até `raio` (espaço da malha) de `centro`. Devolve [{celula, cor}] das quebradas.
func quebrar_esfera(centro: Vector3, raio: float) -> Array:
	var quebradas: Array = []
	var minimo := Vector3i(((centro - Vector3.ONE * raio) / lado).floor())
	var maximo := Vector3i(((centro + Vector3.ONE * raio) / lado).floor())
	var r2 := raio * raio
	for x in range(minimo.x, maximo.x + 1):
		for y in range(minimo.y, maximo.y + 1):
			for z in range(minimo.z, maximo.z + 1):
				var p := Vector3i(x, y, z)
				if not celulas.has(p):
					continue
				if ((Vector3(p) + Vector3(0.5, 0.5, 0.5)) * lado).distance_squared_to(centro) > r2:
					continue
				quebradas.append({"celula": p, "cor": cor_de(int(celulas[p]))})
				celulas.erase(p)
				destruidas[p] = true
	return quebradas


func tem_face(p: Vector3i, d: Vector3i) -> bool:
	if not celulas.has(p):
		return false
	var q := p + d
	if celulas.has(q):
		return false
	if (int(celulas[p]) & 0xFF) >= FUNDO and not destruidas.has(q):
		return false
	return true


## Faces (cubo, direção) do bloco de células `chunk` (índice = célula / tamanho). Devolve {vertices, normais, cores, indices}
## no espaço da malha, no formato que `ArrayMesh` e a colisão consomem.
func faces_do_chunk(chunk: Vector3i, tamanho: int) -> Dictionary:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var ix := PackedInt32Array()
	var base_celula := chunk * tamanho
	for dx in tamanho:
		for dy in tamanho:
			for dz in tamanho:
				var p := base_celula + Vector3i(dx, dy, dz)
				if not celulas.has(p):
					continue
				var cor := cor_de(int(celulas[p]))
				for n in VIZINHOS:
					if not tem_face(p, n):
						continue
					var nf := Vector3(n)
					var u := Vector3.UP if n.y == 0 else Vector3.RIGHT
					var w := nf.cross(u)
					var f := Vector3(p) + Vector3(0.5, 0.5, 0.5) + nf * 0.5
					var q := [f - u * 0.5 - w * 0.5, f + u * 0.5 - w * 0.5, f + u * 0.5 + w * 0.5, f - u * 0.5 + w * 0.5]
					var inicio := vs.size()
					for k in 4:
						vs.append(q[k] * lado)
						ns.append(nf)
						cs.append(cor)
					var tri := [0, 1, 2, 0, 2, 3]
					if (q[1] - q[0]).cross(q[2] - q[0]).dot(nf) > 0.0:
						tri = [0, 2, 1, 0, 3, 2]
					for k in tri:
						ix.append(inicio + k)
	return {"vertices": vs, "normais": ns, "cores": cs, "indices": ix}
