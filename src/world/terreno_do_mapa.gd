class_name TerrenoDoMapa
extends RefCounted
# ============================================================================
#  TERRENO DO MAPA — a peça `terreno`: relevo por alturas, em blocos (30/09/2026).
#
#  Pedido do dono: relevo por cima da baseplate, DIVIDIDO EM BLOCOS para editar por
#  partes. Cada bloco é uma peça comum do mapa (move, gira, estica, duplica, apaga
#  e desfaz como as outras); o que ele tem a mais é o campo "relevo":
#
#    "relevo": {
#      "celulas": 32,                     células por lado (a grade tem celulas+1 pontos)
#      "alturas": "0 125 130 ...",        (celulas+1)² inteiros 0..10000
#      "solo": "0001200...",              celulas² dígitos (opcional; ausente = automático)
#      "agua": "-1 -1 4200 ..."           (celulas+1)² inteiros -1..10000 (opcional)
#    }
#
#  ALTURA = fração do TAMANHO Y da peça, em 1/10000: 0 é a base da caixa da peça,
#  10000 o topo. Por isso esticar o bloco no gizmo estica o relevo, como qualquer
#  peça. Linhas da grade vão de −Z (norte) para +Z; cada linha, de −X para +X.
#  ÁGUA = nível da água no ponto, na mesma escala; −1 = sem água. Uma célula com os
#  quatro cantos molhados ganha superfície de água (o rio).
#  SOLO por célula: ver `SOLOS`. 0 = automático (rocha no íngreme, areia no baixo,
#  grama no resto).
#
#  ⚠️ EMENDAS: dois blocos vizinhos só fecham sem fresta se o ponto da borda der o
#  MESMO número nos dois — mesma altura inteira e mesmo tamanho Y. O gerador põe
#  todos os blocos com o mesmo tamanho Y. Fresta de submilímetro aparece como
#  pontinho preto (foi o defeito da areia em 30/09/2026).
#
#  Texto e não lista JSON: o `MapaArquivo` grava com indentação, e uma lista de
#  1.089 números viraria 1.089 linhas por bloco.
#
#  A colisão e o clique do editor usam a MESMA malha (trimesh): o jogador pisa
#  exatamente na face que vê, e uma casa em cima do bloco continua clicável — a
#  caixa do bloco engoliria o clique dela.
# ============================================================================

const ESCALA := 10000
const CELULAS_MIN := 1
const CELULAS_MAX := 128

## Solo pintado por célula. A cor é sRGB (como se escolhe), convertida para a
## malha. A ordem é o código gravado no arquivo — só acrescentar no fim.
## ⚠️ Cores CONTIDAS de propósito: o ambiente do jogo (`WorldEnv`) soma +18 % de
## saturação e +14 % de contraste em tudo; o verde "normal" virava neon ao lado dos
## modelos do kit (captura de 30/09/2026).
const SOLOS: Array[String] = ["auto", "grama", "terra", "areia", "rocha", "mata", "leito"]
const COR_SOLO := {
	"grama": Color("#71965a"),
	"terra": Color("#8e7a60"),
	"areia": Color("#d8c8a0"),
	"rocha": Color("#8a877e"),
	"mata": Color("#4c7444"),
	"leito": Color("#857559"),
}
## Regras do automático: face mais inclinada que isso vira rocha; abaixo desta
## altura (metros acima da base), areia.
const NORMAL_Y_ROCHA := 0.72
const AREIA_ATE := 0.9
## Variação por célula (low poly vivo, sem textura): ±3 % no brilho.
const VARIACAO := 0.03


# ------------------------------------------------------------------- formato
## Valida o "relevo" cru do JSON e devolve o normalizado:
## {celulas: int, alturas: PackedInt32Array, solo: PackedByteArray, agua: PackedInt32Array}
## (`agua` vazio = bloco sem água). Erros vão para `erros`; com erro devolve {}.
static func validar(bruto: Variant, onde: String, erros: Array[String]) -> Dictionary:
	if not (bruto is Dictionary):
		erros.append("%s: terreno precisa de \"relevo\": { celulas, alturas, ... }" % onde)
		return {}
	var d: Dictionary = bruto
	var n := 0
	if (d.get("celulas") is float or d.get("celulas") is int) and float(d["celulas"]) == floorf(float(d["celulas"])):
		n = int(d["celulas"])
	if n < CELULAS_MIN or n > CELULAS_MAX:
		erros.append("%s.relevo.celulas tem que ser inteiro de %d a %d" % [onde, CELULAS_MIN, CELULAS_MAX])
		return {}
	var pontos := (n + 1) * (n + 1)
	var alturas := _inteiros(d.get("alturas"), pontos, 0, ESCALA, onde + ".relevo.alturas", erros)
	var solo := PackedByteArray()
	if d.has("solo"):
		solo = _digitos(d["solo"], n * n, SOLOS.size() - 1, onde + ".relevo.solo", erros)
	else:
		solo.resize(n * n)
	var agua := PackedInt32Array()
	if d.has("agua"):
		agua = _inteiros(d["agua"], pontos, -1, ESCALA, onde + ".relevo.agua", erros)
	if alturas.is_empty() or solo.size() != n * n or (d.has("agua") and agua.is_empty()):
		return {}
	return {"celulas": n, "alturas": alturas, "solo": solo, "agua": agua}


## Normalizado → o que vai para o JSON (textos compactos).
static func para_json(r: Dictionary) -> Dictionary:
	var saida := {"celulas": r["celulas"], "alturas": _texto_inteiros(r["alturas"])}
	var solo: PackedByteArray = r["solo"]
	var algum := false
	for v in solo:
		if v != 0:
			algum = true
			break
	if algum:
		var digitos := PackedStringArray()
		digitos.resize(solo.size())
		for i in solo.size():
			digitos[i] = str(solo[i])
		saida["solo"] = "".join(digitos)
	if not (r["agua"] as PackedInt32Array).is_empty():
		saida["agua"] = _texto_inteiros(r["agua"])
	return saida


## Relevo plano (tudo na altura `fracao`): ponto de partida de um bloco novo.
static func plano(celulas: int, fracao: int = 0) -> Dictionary:
	var alturas := PackedInt32Array()
	alturas.resize((celulas + 1) * (celulas + 1))
	alturas.fill(clampi(fracao, 0, ESCALA))
	var solo := PackedByteArray()
	solo.resize(celulas * celulas)
	return {"celulas": celulas, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}


## Muda quando o desenho do relevo muda — entra na chave de geometria do montador.
static func assinatura(r: Dictionary) -> String:
	return "%d|%d|%d|%d" % [r["celulas"], hash(r["alturas"]), hash(r["solo"]), hash(r["agua"])]


# ------------------------------------------------------------------- geometria
## Altura (em metros, no espaço LOCAL da peça: o centro da caixa é 0) do ponto
## (i, j) da grade.
static func _y(r: Dictionary, tamanho: Vector3, indice: int) -> float:
	return float((r["alturas"] as PackedInt32Array)[indice]) / ESCALA * tamanho.y - tamanho.y * 0.5


static func _ponto(r: Dictionary, tamanho: Vector3, i: int, j: int) -> Vector3:
	var n: int = r["celulas"]
	return Vector3((float(i) / n - 0.5) * tamanho.x, _y(r, tamanho, j * (n + 1) + i),
		(float(j) / n - 0.5) * tamanho.z)


## Os dois triângulos da célula (i, j), na ordem que a malha e a colisão usam.
## A diagonal alterna em xadrez: sem isso o relevo ganha faixas regulares.
static func _triangulos(r: Dictionary, tamanho: Vector3, i: int, j: int) -> Array[PackedVector3Array]:
	var n: int = r["celulas"]
	var idx := _indices(n, i, j)
	var pts: Array[Vector3] = []
	for q in idx:
		pts.append(_ponto(r, tamanho, q % (n + 1), q / (n + 1)))
	return [PackedVector3Array([pts[0], pts[1], pts[2]]), PackedVector3Array([pts[3], pts[4], pts[5]])]


## Pontos da grade no espaço local, calculados uma vez por bloco (antes eram
## recalculados por triângulo: 7 ms por bloco, a ilha tem 64).
static func _grade(r: Dictionary, tamanho: Vector3) -> PackedVector3Array:
	var n: int = r["celulas"]
	var alturas: PackedInt32Array = r["alturas"]
	var g := PackedVector3Array()
	g.resize((n + 1) * (n + 1))
	var fator := tamanho.y / ESCALA
	var base := -tamanho.y * 0.5
	for j in n + 1:
		var z := (float(j) / n - 0.5) * tamanho.z
		for i in n + 1:
			var k := j * (n + 1) + i
			g[k] = Vector3((float(i) / n - 0.5) * tamanho.x, float(alturas[k]) * fator + base, z)
	return g


## Índices (na grade) dos 6 vértices dos 2 triângulos da célula, na ordem da malha.
## HORÁRIO visto de cima: no Godot a face da frente é a horária para quem olha.
static func _indices(n: int, i: int, j: int) -> PackedInt32Array:
	var a := j * (n + 1) + i
	var b := a + 1
	var c := a + n + 1
	var d := c + 1
	if (i + j) % 2 == 0:
		return PackedInt32Array([a, d, c, a, b, d])
	return PackedInt32Array([a, b, c, b, d, c])


## Malha do relevo: faces chapadas, cor do solo em cada face.
static func malha(r: Dictionary, tamanho: Vector3) -> ArrayMesh:
	var n: int = r["celulas"]
	var solo: PackedByteArray = r["solo"]
	var agua: PackedInt32Array = r["agua"]
	var g := _grade(r, tamanho)
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var tris := n * n * 2
	vertices.resize(tris * 3)
	normais.resize(tris * 3)
	cores.resize(tris * 3)
	var meio_y := tamanho.y * 0.5
	var k := 0
	for j in n:
		for i in n:
			var codigo: int = solo[j * n + i]
			var molhada := false
			if not agua.is_empty():
				molhada = agua[j * (n + 1) + i] >= 0 and agua[j * (n + 1) + i + 1] >= 0 \
					and agua[(j + 1) * (n + 1) + i] >= 0 and agua[(j + 1) * (n + 1) + i + 1] >= 0
			# Mesma ordem de `_indices`, escrita à mão: alocar uma lista por célula
			# custava metade do tempo do bloco.
			var a := j * (n + 1) + i
			var c := a + n + 1
			var fator := _fator_da_celula(i, j)
			for lado in 2:
				var v0: Vector3
				var v1: Vector3
				var v2: Vector3
				if (i + j) % 2 == 0:
					v0 = g[a]
					v1 = g[c + 1] if lado == 0 else g[a + 1]
					v2 = g[c] if lado == 0 else g[c + 1]
				else:
					v0 = g[a] if lado == 0 else g[a + 1]
					v1 = g[a + 1] if lado == 0 else g[c + 1]
					v2 = g[c]
				var normal := (v2 - v0).cross(v1 - v0).normalized()
				var cor := _cor_da_face(codigo, normal, (v0.y + v1.y + v2.y) / 3.0 + meio_y, molhada) * fator
				cor.a = 1.0
				vertices[k] = v0
				vertices[k + 1] = v1
				vertices[k + 2] = v2
				normais[k] = normal
				normais[k + 1] = normal
				normais[k + 2] = normal
				cores[k] = cor
				cores[k + 1] = cor
				cores[k + 2] = cor
				k += 3
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_COLOR] = cores
	var m := ArrayMesh.new()
	# SEM compressão de atributos (flags = 0): vértice quantizado abre fresta entre
	# blocos vizinhos (ver o cabeçalho).
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	return m


## Superfície da água: uma por célula com os quatro cantos molhados; null sem água.
static func malha_agua(r: Dictionary, tamanho: Vector3) -> ArrayMesh:
	var agua: PackedInt32Array = r["agua"]
	if agua.is_empty():
		return null
	var n: int = r["celulas"]
	var vertices := PackedVector3Array()
	var nivel := func(i: int, j: int) -> Vector3:
		return Vector3((float(i) / n - 0.5) * tamanho.x,
			float(agua[j * (n + 1) + i]) / ESCALA * tamanho.y - tamanho.y * 0.5,
			(float(j) / n - 0.5) * tamanho.z)
	for j in n:
		for i in n:
			if agua[j * (n + 1) + i] < 0 or agua[j * (n + 1) + i + 1] < 0 \
					or agua[(j + 1) * (n + 1) + i] < 0 or agua[(j + 1) * (n + 1) + i + 1] < 0:
				continue
			var a: Vector3 = nivel.call(i, j)
			var b: Vector3 = nivel.call(i + 1, j)
			var c: Vector3 = nivel.call(i, j + 1)
			var d: Vector3 = nivel.call(i + 1, j + 1)
			vertices.append_array([a, d, c, a, b, d])   # horário visto de cima
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normais := PackedVector3Array()
	normais.resize(vertices.size())
	normais.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normais
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	return m


## Colisão = os mesmos triângulos da malha (o jogador pisa na face que vê).
static func forma(r: Dictionary, tamanho: Vector3) -> ConcavePolygonShape3D:
	var n: int = r["celulas"]
	var g := _grade(r, tamanho)
	var faces := PackedVector3Array()
	faces.resize(n * n * 6)
	var k := 0
	for j in n:
		for i in n:
			# Mesma ordem da malha (ver `_indices`) — é o que o `create_trimesh_shape`
			# do Godot faz. Escrita à mão pelo mesmo motivo da malha (sem lista por célula).
			var a := j * (n + 1) + i
			var c := a + n + 1
			if (i + j) % 2 == 0:
				faces[k] = g[a]; faces[k + 1] = g[c + 1]; faces[k + 2] = g[c]
				faces[k + 3] = g[a]; faces[k + 4] = g[a + 1]; faces[k + 5] = g[c + 1]
			else:
				faces[k] = g[a]; faces[k + 1] = g[a + 1]; faces[k + 2] = g[c]
				faces[k + 3] = g[a + 1]; faces[k + 4] = g[c + 1]; faces[k + 5] = g[c]
			k += 6
	var s := ConcavePolygonShape3D.new()
	s.set_faces(faces)
	return s


## Altura do CHÃO (metros, espaço local da peça) sob o ponto local (x, z): a mesma
## conta da malha, triângulo por triângulo. Fora do bloco devolve NAN.
static func altura_local(r: Dictionary, tamanho: Vector3, x: float, z: float) -> float:
	var n: int = r["celulas"]
	var u := (x / tamanho.x + 0.5) * n
	var w := (z / tamanho.z + 0.5) * n
	if u < 0.0 or w < 0.0 or u > n or w > n:
		return NAN
	var i := clampi(int(floor(u)), 0, n - 1)
	var j := clampi(int(floor(w)), 0, n - 1)
	var p := Vector2(x, z)
	for t in _triangulos(r, tamanho, i, j):
		var y := _no_triangulo(t, p)
		if not is_nan(y):
			return y
	# Borda numérica exata entre os dois triângulos: o mais próximo serve.
	return (_ponto(r, tamanho, i, j).y + _ponto(r, tamanho, i + 1, j + 1).y) * 0.5


## Código do SOLO da célula sob o ponto local (x, z) — índice de `SOLOS` (0 = automático);
## -1 fora do bloco ou sem solo pintado. Quem planta árvore usa para fugir de estrada
## (terra) e da areia da margem.
static func solo_local(r: Dictionary, tamanho: Vector3, x: float, z: float) -> int:
	var solo := r.get("solo", PackedByteArray()) as PackedByteArray
	var n: int = r["celulas"]
	var u := (x / tamanho.x + 0.5) * n
	var w := (z / tamanho.z + 0.5) * n
	if solo.is_empty() or u < 0.0 or w < 0.0 or u > n or w > n:
		return -1
	return solo[clampi(int(floor(w)), 0, n - 1) * n + clampi(int(floor(u)), 0, n - 1)]


## Nível da água do RIO sob o ponto local (x, z), em metros no espaço local da peça;
## NAN se a célula não tem água. Média dos cantos molhados da célula (na margem, onde só
## parte dos cantos tem água, o nível ainda vale para quem pisa ali).
static func agua_local(r: Dictionary, tamanho: Vector3, x: float, z: float) -> float:
	var agua := r.get("agua", PackedInt32Array()) as PackedInt32Array
	if agua.is_empty():
		return NAN
	var n: int = r["celulas"]
	var u := (x / tamanho.x + 0.5) * n
	var w := (z / tamanho.z + 0.5) * n
	if u < 0.0 or w < 0.0 or u > n or w > n:
		return NAN
	var i := clampi(int(floor(u)), 0, n - 1)
	var j := clampi(int(floor(w)), 0, n - 1)
	var soma := 0.0
	var quantos := 0
	for k in [j * (n + 1) + i, j * (n + 1) + i + 1, (j + 1) * (n + 1) + i, (j + 1) * (n + 1) + i + 1]:
		if agua[k] >= 0:
			soma += float(agua[k])
			quantos += 1
	if quantos == 0:
		return NAN
	return soma / quantos / ESCALA * tamanho.y - tamanho.y * 0.5


## O ponto local (x, z) está na ÁGUA (algum canto da célula dele com água acima do
## chão)? O leito do rio é chão de verdade para a física: quem sorteia onde nasce um
## bicho terrestre usa isto para não pô-lo debaixo d'água.
static func molhado_local(r: Dictionary, tamanho: Vector3, x: float, z: float) -> bool:
	var agua := r.get("agua", PackedInt32Array()) as PackedInt32Array
	if agua.is_empty():
		return false
	var n: int = r["celulas"]
	var u := (x / tamanho.x + 0.5) * n
	var w := (z / tamanho.z + 0.5) * n
	if u < 0.0 or w < 0.0 or u > n or w > n:
		return false
	var i := clampi(int(floor(u)), 0, n - 1)
	var j := clampi(int(floor(w)), 0, n - 1)
	var alturas := r["alturas"] as PackedInt32Array
	for k in [j * (n + 1) + i, j * (n + 1) + i + 1, (j + 1) * (n + 1) + i, (j + 1) * (n + 1) + i + 1]:
		if agua[k] >= 0 and agua[k] > alturas[k]:
			return true
	return false


static func _no_triangulo(t: PackedVector3Array, p: Vector2) -> float:
	var a := Vector2(t[0].x, t[0].z)
	var b := Vector2(t[1].x, t[1].z)
	var c := Vector2(t[2].x, t[2].z)
	var det := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(det) < 1e-9:
		return NAN
	var l1 := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / det
	var l2 := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / det
	var l3 := 1.0 - l1 - l2
	var folga := -1e-5
	if l1 < folga or l2 < folga or l3 < folga:
		return NAN
	return l1 * t[0].y + l2 * t[1].y + l3 * t[2].y


# ------------------------------------------------------------------- internos
## Cor (linear, já pronta para a malha) de cada solo — convertida UMA vez.
static var _lineares: Array[Color] = []


static func _cor_da_face(codigo: int, normal: Vector3, altura: float, molhada: bool) -> Color:
	if _lineares.is_empty():
		for nome in SOLOS:
			_lineares.append((COR_SOLO.get(nome, Color.WHITE) as Color).srgb_to_linear())
	if codigo == 0:
		if molhada:
			codigo = 6        # leito
		elif normal.y < NORMAL_Y_ROCHA:
			codigo = 4        # rocha
		elif altura < AREIA_ATE:
			codigo = 3        # areia
		else:
			codigo = 1        # grama
	return _lineares[codigo]


## Variação determinística por CÉLULA (os dois triângulos juntos): variar por face
## desenhava um xadrez de diagonais no chão plano (captura de 30/09/2026).
static func _fator_da_celula(i: int, j: int) -> float:
	var ruido := float(((i * 73856093) ^ (j * 19349663)) & 0xffff) / 65535.0
	return 1.0 + (ruido * 2.0 - 1.0) * VARIACAO


static func _inteiros(bruto: Variant, quantos: int, minimo: int, maximo: int, onde: String,
		erros: Array[String]) -> PackedInt32Array:
	var saida := PackedInt32Array()
	if not (bruto is String):
		erros.append("%s tem que ser texto com %d inteiros separados por espaço" % [onde, quantos])
		return saida
	var partes := (bruto as String).split(" ", false)
	if partes.size() != quantos:
		erros.append("%s tem %d valores; o bloco precisa de %d" % [onde, partes.size(), quantos])
		return saida
	saida.resize(quantos)
	for i in quantos:
		var txt := partes[i]
		if not txt.is_valid_int():
			erros.append("%s[%d] \"%s\" não é inteiro" % [onde, i, txt])
			return PackedInt32Array()
		var v := txt.to_int()
		if v < minimo or v > maximo:
			erros.append("%s[%d] = %d fora de %d..%d" % [onde, i, v, minimo, maximo])
			return PackedInt32Array()
		saida[i] = v
	return saida


static func _digitos(bruto: Variant, quantos: int, maximo: int, onde: String,
		erros: Array[String]) -> PackedByteArray:
	var saida := PackedByteArray()
	if not (bruto is String) or (bruto as String).length() != quantos:
		erros.append("%s tem que ser texto com %d dígitos (0 a %d)" % [onde, quantos, maximo])
		return saida
	saida.resize(quantos)
	var txt: String = bruto
	for i in quantos:
		var v := txt.unicode_at(i) - 48
		if v < 0 or v > maximo:
			erros.append("%s[%d] \"%s\" fora de 0..%d" % [onde, i, txt[i], maximo])
			return PackedByteArray()
		saida[i] = v
	return saida


static func _texto_inteiros(valores: PackedInt32Array) -> String:
	var partes := PackedStringArray()
	partes.resize(valores.size())
	for i in valores.size():
		partes[i] = str(valores[i])
	return " ".join(partes)
