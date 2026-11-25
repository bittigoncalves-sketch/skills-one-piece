class_name ArvoreVoxel
extends RefCounted
# Árvores de cubos (voxels) geradas por código, em seis formas + toco.
#
# Por que código e não .glb autorado: cada forma é uma função curta, a malha sai
# com as faces internas removidas, e o MESMO gerador serve a arena (malha fixa de
# 16 voxels) e o Modo História (~60 modelos, cada um com altura/largura próprias,
# ver tools/trocar_arvores_por_voxel.gd). Gatilho: se uma forma precisar de pintura
# por voxel (textura/AO) ou de silhueta que o código não alcance, autorar só essa
# forma no Blender.
#
# Contrato da malha: superfícies NOMEADAS — "tronco", "copa", "copa_clara" (um quarto
# dos voxels da copa, tom mais claro, dá a textura sem shader) e "corte" (topo do
# toco). Só existem as superfícies que a forma usa; procure pelo nome, não pelo índice.

const TAMANHO := 0.4            # lado do voxel na arena, em metros
const FORMAS: Array[String] = ["carvalho", "pinheiro", "palmeira", "acacia", "baobab", "salgueiro"]
const TRONCO := 0
const COPA := 1
const CORTE := 3
const COCO_VERDE := 4
const COCO_SECO := 5
const NOMES: Array[String] = ["tronco", "copa", "copa_clara", "corte", "coco_verde", "coco_seco"]
const _CLARA := 2

static var _cache: Dictionary = {}   # forma -> ArrayMesh (arena)

# ------------------------------------------------------------------ arena ----

## Altura (voxels) e raios x/z da copa da árvore da arena, por forma.
const _ARENA := {
	"carvalho": [16, 4.4, 4.4], "pinheiro": [16, 4.0, 4.0], "palmeira": [16, 6.0, 6.0],
	"acacia": [15, 5.5, 5.5], "baobab": [16, 5.5, 5.5], "salgueiro": [15, 4.5, 4.5]}

static func posicao_da_fruta(forma: String) -> Vector3:
	var d := 1.3 if forma == "baobab" else 0.6
	return Vector3(d, 0.38, d)

static func malha(forma: String) -> ArrayMesh:
	if not _cache.has(forma):
		var d: Array = _ARENA.get(forma, _ARENA["carvalho"])
		_cache[forma] = construir(celulas(forma, d[0], d[1], d[2]), AABB(), TAMANHO)
	return _cache[forma]

# ---------------------------------------------------------------- formas ----

## Células (Vector3i -> parte) de uma forma com `h` voxels de altura e raios de copa
## `rx`/`rz` em voxels. A coluna do tronco fica em (0, y, 0); y começa em 0.
static func celulas(forma: String, h: int, rx: float, rz: float, semente := 0) -> Dictionary:
	var c := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([forma, h, int(rx), int(rz), semente])
	h = maxi(h, 4)
	rx = maxf(rx, 1.0)
	rz = maxf(rz, 1.0)
	match forma:
		"carvalho": _carvalho(c, h, rx, rz)
		"pinheiro": _pinheiro(c, h, rx, rz)
		"palmeira": _palmeira(c, h, rx, rz, rng, semente)
		"acacia": _acacia(c, h, rx, rz)
		"baobab": _baobab(c, h, rx, rz)
		"salgueiro": _salgueiro(c, h, rx, rz, rng)
		"toco": _toco(c, h, rx, rz)
		_: _carvalho(c, h, rx, rz)
	return c

# Raio do tronco em voxels conforme o tamanho da árvore.
static func _raio_tronco(h: int) -> float:
	return 0.0 if h < 11 else (0.9 if h < 17 else 1.5)

static func _tronco(c: Dictionary, h: int, ate: int, raio_extra := 0.0) -> void:
	var r := maxf(_raio_tronco(h) + raio_extra, 0.0)
	for y in range(0, ate + 1):
		_disco(c, y, r, r, TRONCO)
	if h >= 11:   # raízes
		_disco(c, 0, r + 1.0, r + 1.0, TRONCO)

static func _carvalho(c: Dictionary, h: int, rx: float, rz: float) -> void:
	var t := maxi(2, roundi(h * 0.4))
	_tronco(c, h, t + 1)
	var ry := (h - t) / 2.0
	var cy := t + ry - 0.5
	_elipsoide(c, Vector3(0, cy, 0), rx * 0.82, ry, rz * 0.82, COPA)
	for s in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_elipsoide(c, Vector3(s.x * rx * 0.5, cy - ry * 0.25, s.y * rz * 0.5),
			rx * 0.5, ry * 0.7, rz * 0.5, COPA)

static func _pinheiro(c: Dictionary, h: int, rx: float, rz: float) -> void:
	_tronco(c, h, int(h * 0.55), -0.6)
	var y0 := roundi(h * 0.14)
	var passo := maxf(2.0, (h - y0) / float(clampi(h / 4, 3, 7)))   # altura de cada andar
	for y in range(y0, h):
		# Cone de fundo que afina até a ponta; cada andar começa largo e afina (saia em degraus).
		var env := 1.0 - (y - y0) / float(h - y0)
		var fase := (y - y0) / passo
		fase -= floorf(fase)
		var f := env * (1.0 - 0.4 * fase)
		_disco(c, y, rx * f, rz * f, COPA)

static func _palmeira(c: Dictionary, h: int, rx: float, rz: float, rng: RandomNumberGenerator, variante := 0) -> void:
	# Copa limitada em largura: palmeira larga demais vira guarda-chuva (o encaixe no .glb
	# estica o resto, então o limite só evita o exagero).
	rx = minf(rx, h * 0.7)
	rz = minf(rz, h * 0.7)
	var tt := roundi(h * 0.62)
	var lean := minf(rx * 0.2, h * 0.12)
	var topo := Vector3i.ZERO
	for y in tt + 1:
		topo = Vector3i(roundi(lean * pow(y / float(tt), 1.6)), y, 0)
		_poe(c, topo, TRONCO)
		if h >= 9:
			_poe(c, topo + Vector3i(1, 0, 0), TRONCO)
			_poe(c, topo + Vector3i(0, 0, 1), TRONCO)
			_poe(c, topo + Vector3i(1, 0, 1), TRONCO)
	topo.y += 1
	var comp := maxf(rx, rz)
	var n_folhas := 11 if h >= 12 else 9
	for ang in n_folhas:
		var a := TAU * ang / n_folhas + 0.2 + rng.randf_range(-0.12, 0.12)
		var dir := Vector2(cos(a), sin(a))
		var lado := Vector3i(0, 0, 1) if absf(dir.x) > absf(dir.y) else Vector3i(1, 0, 0)
		var cai := h * rng.randf_range(0.58, 0.7)
		for k in range(1, int(comp) + 1):
			var u := k / comp
			# Nervura central em arco: sobe até ~1/3 do comprimento e cai até a ponta.
			var p := topo + Vector3i(roundi(dir.x * u * rx), roundi(h * 0.5 * u - cai * u * u),
				roundi(dir.y * u * rz))
			_poe(c, p, COPA)
			# Largura da folha: fina na base, larga no meio, afina na ponta.
			var larg := roundi((0.6 + 1.9 * sin(u * PI)) * clampf(h / 14.0, 0.7, 1.6))
			for w in range(1, larg + 1):
				var queda := Vector3i(0, -roundi(w * 0.5 * u), 0)   # as pontas dos folíolos pendem
				_poe(c, p + lado * w + queda, COPA)
				_poe(c, p - lado * w + queda, COPA)
			if h >= 12 and u > 0.15 and u < 0.8:
				_poe(c, p + Vector3i(0, 1, 0), COPA)
	for y in range(0, 2):   # tufo central
		_poe(c, topo + Vector3i(0, y, 0), COPA)
		if h >= 12:
			_poe(c, topo + Vector3i(1, y, 0), COPA)
	_cocos(c, topo, h, rng, variante)

## Cocos sob a copa, junto ao topo do tronco. `variante` (a semente da palmeira) escolhe:
## 0 = verdes, 1 = secos, 2 = mistos. Fixo por palmeira, então ela é sempre igual.
static func _cocos(c: Dictionary, topo: Vector3i, h: int, rng: RandomNumberGenerator, variante: int) -> void:
	if h < 8:
		return
	var n := 7 if h >= 14 else 4
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.6
		var p := topo + Vector3i(roundi(cos(a) * 1.8), -2 - (i % 3), roundi(sin(a) * 1.8))
		var tipo := COCO_VERDE
		match posmod(variante, 3):
			1: tipo = COCO_SECO
			2: tipo = COCO_SECO if i % 2 == 0 else COCO_VERDE
		for q in ([Vector3i.ZERO, Vector3i(0, -1, 0)] if h >= 14 else [Vector3i.ZERO]):   # coco de 2 voxels nas grandes
			if c.get(p + q, -1) != TRONCO:
				c[p + q] = tipo

static func _acacia(c: Dictionary, h: int, rx: float, rz: float) -> void:
	var t := roundi(h * 0.5)
	_tronco(c, h, t)
	var yc := roundi(h - maxf(2.0, h * 0.24))
	var d := maxi(2, roundi(h * 0.2))   # os galhos abrem em diagonal até a copa
	for i in range(1, d + 1):
		var sx := roundi(i * rx * 0.35 / d)
		var sz := roundi(i * rz * 0.35 / d)
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_poe(c, Vector3i(dir.x * sx, t + i * (yc - t - 1) / d, dir.y * sz), TRONCO)
	# Copa achatada e irregular: três elipsoides baixos, o do meio mais alto.
	var ry := maxf(2.0, h * 0.24)
	var cy := h - ry
	_elipsoide(c, Vector3(0, cy, 0), rx * 0.85, ry, rz * 0.85, COPA)
	_elipsoide(c, Vector3(rx * 0.4, cy - ry * 0.35, rz * 0.2), rx * 0.6, ry * 0.8, rz * 0.7, COPA)
	_elipsoide(c, Vector3(-rx * 0.4, cy - ry * 0.35, -rz * 0.2), rx * 0.6, ry * 0.8, rz * 0.7, COPA)

static func _baobab(c: Dictionary, h: int, rx: float, rz: float) -> void:
	var t := roundi(h * 0.6)
	var rt := maxf(1.0, minf(rx, rz) * 0.38)
	for y in t + 1:
		var r := rt * (1.35 - 0.6 * y / float(t))
		_disco(c, y, r, r, TRONCO)
	var cy := h * 0.78
	_elipsoide(c, Vector3(0, cy, 0), rx * 0.6, h * 0.2, rz * 0.6, COPA)
	for s in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var cx: float = s.x * rx * 0.6
		var cz: float = s.y * rz * 0.6
		for k in range(0, 4):   # galho até o tufo
			_poe(c, Vector3i(roundi(cx * k / 3.0), roundi(t + (cy - t - h * 0.05) * k / 3.0), roundi(cz * k / 3.0)), TRONCO)
		_elipsoide(c, Vector3(cx, cy - h * 0.06, cz), rx * 0.42, h * 0.16, rz * 0.42, COPA)

static func _salgueiro(c: Dictionary, h: int, rx: float, rz: float, rng: RandomNumberGenerator) -> void:
	var t := roundi(h * 0.5)
	_tronco(c, h, t + 1, -0.3)
	var cy := h * 0.66
	var ry := h * 0.3
	_elipsoide(c, Vector3(0, cy, 0), rx * 0.75, ry, rz * 0.75, COPA)
	var nx := ceili(rx)
	var nz := ceili(rz)
	for x in range(-nx, nx + 1):
		for z in range(-nz, nz + 1):
			var d := Vector2(x / rx, z / rz).length()
			if d < 0.35 or d > 0.95 or rng.randf() > 0.4:
				continue
			var fundo := cy - ry * sqrt(maxf(0.0, 1.0 - (d / 0.75) * (d / 0.75)))
			var comp := rng.randi_range(maxi(1, int(h * 0.1)), maxi(2, int(h * 0.3)))
			for k in comp:
				_poe(c, Vector3i(x, roundi(fundo) - k, z), COPA)

static func _toco(c: Dictionary, h: int, rx: float, rz: float) -> void:
	for y in h:
		var f := 1.12 if y == 0 else 1.0
		_disco(c, y, rx * f, rz * f, CORTE if y == h - 1 else TRONCO)

# ------------------------------------------------------------- primitivas ----

static func _poe(c: Dictionary, p: Vector3i, parte: int) -> void:
	if p.y < 0:
		return
	if c.has(p) and c[p] == TRONCO and parte == COPA:
		return   # a copa envolve o galho, não o apaga
	c[p] = parte

static func _elipsoide(c: Dictionary, centro: Vector3, rx: float, ry: float, rz: float, parte: int) -> void:
	for x in range(floori(centro.x - rx), ceili(centro.x + rx) + 1):
		for y in range(floori(centro.y - ry), ceili(centro.y + ry) + 1):
			for z in range(floori(centro.z - rz), ceili(centro.z + rz) + 1):
				var d := Vector3((x - centro.x) / maxf(rx, 0.5), (y - centro.y) / maxf(ry, 0.5),
					(z - centro.z) / maxf(rz, 0.5))
				if d.length_squared() <= 1.0:
					_poe(c, Vector3i(x, y, z), parte)

static func _disco(c: Dictionary, y: int, rx: float, rz: float, parte: int) -> void:
	var nx := ceili(rx)
	var nz := ceili(rz)
	for x in range(-nx, nx + 1):
		for z in range(-nz, nz + 1):
			if Vector2(x / maxf(rx, 0.5), z / maxf(rz, 0.5)).length_squared() <= 1.001:
				_poe(c, Vector3i(x, y, z), parte)

# ------------------------------------------------------------------ malha ----

const _VIZINHOS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

## Caixa das células em unidades de voxel (a célula p ocupa x,z ± 0,5 e y de p.y a p.y+1).
static func limites(c: Dictionary) -> AABB:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for p: Vector3i in c:
		mn = mn.min(Vector3(p.x - 0.5, p.y, p.z - 0.5))
		mx = mx.max(Vector3(p.x + 0.5, p.y + 1, p.z + 0.5))
	return AABB(mn, mx - mn)

static func _superficie_da(p: Vector3i, parte: int) -> int:
	if parte == COPA and absi(hash(p)) % 100 < 26:
		return _CLARA
	return parte

## Escala por eixo (`k`) e deslocamento (`origem`) que levam a coordenada de voxel à da malha.
static func ajuste(c: Dictionary, destino := AABB(), lado := TAMANHO) -> Dictionary:
	if destino.size == Vector3.ZERO:
		return {"k": Vector3(lado, lado, lado), "origem": Vector3.ZERO}
	var caixa := limites(c)
	var k := destino.size / caixa.size
	return {"k": k, "origem": destino.position - caixa.position * k}

## Malha das células. `destino` vazio = voxel de `lado` metros com o pivô em (0,0,0);
## com `destino`, a caixa das células é esticada até ele (encaixa no .glb que está
## sendo substituído sem mexer em catálogo, escala nem colisão). `a_local` leva o espaço
## de `destino` (espaço do modelo) ao da malha, se o nó da malha estiver girado/escalado.
static func construir(c: Dictionary, destino := AABB(), lado := TAMANHO, a_local := Transform3D.IDENTITY) -> ArrayMesh:
	var aj := ajuste(c, destino, lado)
	var k: Vector3 = aj["k"]
	var origem: Vector3 = aj["origem"]
	var st: Array[SurfaceTool] = []
	var usada: Array[bool] = []
	for i in NOMES.size():
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append(s)
		usada.append(false)
	for p: Vector3i in c:
		var i := _superficie_da(p, c[p])
		for n in _VIZINHOS:
			if not c.has(p + n):
				_face(st[i], p, n, k, origem, a_local)
				usada[i] = true
	var m := ArrayMesh.new()
	for i in NOMES.size():
		if usada[i]:
			st[i].index()
			st[i].commit(m)
			m.surface_set_name(m.get_surface_count() - 1, NOMES[i])
	return m

static func _face(s: SurfaceTool, p: Vector3i, n: Vector3i, k: Vector3, origem: Vector3, a_local: Transform3D) -> void:
	var nf := Vector3(n)
	var u := Vector3.UP if n.y == 0 else Vector3.RIGHT
	var v := nf.cross(u)
	var f := Vector3(p) + Vector3(0, 0.5, 0) + nf * 0.5
	var q := [f - u * 0.5 - v * 0.5, f + u * 0.5 - v * 0.5, f + u * 0.5 + v * 0.5, f - u * 0.5 + v * 0.5]
	# O Godot trata a ordem HORÁRIA (vista de fora) como face frontal: o produto vetorial dos
	# lados tem de apontar CONTRA a normal. Giro com determinante negativo inverte a regra.
	var ordem := [0, 1, 2, 0, 2, 3]
	var contra := 1.0 if a_local.basis.determinant() >= 0.0 else -1.0
	if (q[1] - q[0]).cross(q[2] - q[0]).dot(nf) * contra > 0.0:
		ordem = [0, 2, 1, 0, 3, 2]
	var normal := (a_local.basis.inverse().transposed() * nf).normalized()
	for i in ordem:
		s.set_normal(normal)
		s.add_vertex(a_local * (origem + q[i] * k))

## Pontos (em unidades de voxel) na parte de baixo da copa, bem espalhados — onde
## penduram as frutas. Amostragem do ponto mais distante, para não amontoar.
static func pontos_de_fruta(c: Dictionary, quantos: int) -> Array[Vector3]:
	var cand: Array[Vector3] = []
	var topo := 0
	for p: Vector3i in c:
		topo = maxi(topo, p.y)
	for p: Vector3i in c:
		# Faixa de altura de 30% a 80%: abaixo disso a fruta ficaria na saia da copa, quase no chão.
		if c[p] == COPA and not c.has(p + Vector3i(0, -1, 0)) \
				and p.y >= 0.3 * (topo + 1) and p.y <= 0.8 * (topo + 1):
			cand.append(Vector3(p.x, p.y, p.z))
	var saida: Array[Vector3] = []
	if cand.is_empty() or quantos <= 0:
		return saida
	cand.sort_custom(func(a: Vector3, b: Vector3) -> bool: return hash(a) < hash(b))
	saida.append(cand[0])
	while saida.size() < quantos and saida.size() < cand.size():
		var melhor := cand[0]
		var dist := -1.0
		for q in cand:
			var d := INF
			for s in saida:
				d = minf(d, q.distance_squared_to(s))
			if d > dist:
				dist = d
				melhor = q
		saida.append(melhor)
	return saida

## Triângulos cuja face de frente aponta para DENTRO (ordem anti-horária vista de fora).
## No Godot a face frontal é a horária; qualquer valor > 0 aqui deixa a árvore "transparente".
static func faces_invertidas(m: Mesh) -> int:
	var ruins := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for t in range(0, ix.size(), 3):
			var cr := (v[ix[t + 1]] - v[ix[t]]).cross(v[ix[t + 2]] - v[ix[t]])
			if cr.length_squared() == 0.0:
				continue
			var d := cr.normalized().dot(n[ix[t]])
			# |d| baixo = a normal lida do .glb não bate com o eixo do triângulo (a
			# decodificação da normal comprimida erra em malhas minúsculas): não é o sentido.
			if d >= 0.5:
				ruins += 1
	return ruins
