extends RefCounted
# ============================================================================
#  ILHA PROCEDURAL — relevo, solo, blocos de terreno e anel de praia de UMA ilha
#  quadrada, parametrizada (18/10/2026, docs/ESTRUTURAS_MINE_PIECE_PLANO.md, E3).
#
#  É a mesma conta do `gerar_ilha_east_blue.gd` (ruído suave + morros, praças planas com
#  borda suave, trilhas de terra, costa de areia, blocos de 64 m com 32 células, praia
#  descendo até −1,3 m), com centro, tamanho, semente, morros, praças e trilhas como dados.
#  Quem usa: `gerar_ilhas_mine_piece.gd` (8 ilhas).
#  22/10/2026: PLATÔS — sob cada construção o relevo é cortado/aterrado num retângulo do
#  tamanho e giro da pegada (altura média do chão ali), com talude curto; a terra batida
#  fica só no retângulo, sem os círculos das praças.
#  DÍVIDA COM GATILHO: `gerar_ilha_east_blue.gd` e `gerar_ilha_dos_macacos.gd` ainda têm
#  a cópia própria da conta. Migrar para esta classe na PRÓXIMA mudança de qualquer um
#  deles, conferindo que o mapa gerado sai idêntico (`--saida=` e comparar).
# ============================================================================

const BLOCO := 64.0
const CELULAS := 32
const PASSO := BLOCO / CELULAS
const BASE_DOS_BLOCOS := -1.5
const ACIMA_DA_BASE := 0.04
const LARGURA_PRAIA := 24.0
const COSTA := 30.0
const LARGURA_TRILHA := 3.0
## Do platô ao relevo natural. Construções mais longe que isso uma da outra não se mexem.
const TALUDE := 5.0

var centro := Vector2.ZERO
var meia := 128.0                # metade do lado da placa (múltiplo de 32 m)
var prefixo := ""                # id das peças: "<prefixo>relevo_i_j", "<prefixo>praia_n"
var grupo_relevo := ""
var grupo_praia := ""
## [[centro local, raio, altura extra]]
var morros: Array = []
## [{centro: Vector2 local, raio}] — chão plano (construções e acampamentos).
var pracas: Array = []
## [[a: Vector2, b: Vector2]] locais — terra batida.
var trilhas: Array = []
## [{centro: Vector2 local, meia: Vector2 (metade dos lados), giro: graus}] — chão plano
## retangular sob uma construção; `relevo()` grava a "altura" de cada um.
var platos: Array = []
var tamanho_y := 0.0             # altura dos blocos de terreno do mapa (todos iguais)

var pontos := 0
var H := PackedFloat32Array()
var S := PackedByteArray()
var D_trilha := PackedFloat32Array()
var ruido := FastNoiseLite.new()
var ruido_fino := FastNoiseLite.new()
var blocos := {}
var contagem := {}


func _init(centro_: Vector2, meia_: float, semente: int, prefixo_: String, tamanho_y_: float) -> void:
	centro = centro_
	meia = meia_
	prefixo = prefixo_
	tamanho_y = tamanho_y_
	pontos = int(2.0 * meia / PASSO) + 1
	ruido.seed = semente
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 1.0 / 70.0
	ruido_fino.seed = semente + 1
	ruido_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_fino.frequency = 1.0 / 24.0


# =================================================================== RELEVO
func relevo() -> void:
	H.resize(pontos * pontos)
	D_trilha.resize(pontos * pontos)
	for pl: Dictionary in platos:
		# Na grade do relevo em blocos (22/10/2026): topo do platô = topo de um bloco inteiro.
		pl["altura"] = maxf(snappedf(altura_do_plato(pl), RelevoEmBlocos.BLOCO), RelevoEmBlocos.BLOCO)
	for j in pontos:
		for i in pontos:
			var l := _local(i, j)
			var idx := j * pontos + i
			var h := _altura_bruta(l)
			for z: Dictionary in pracas:
				var c: Vector2 = z["centro"]
				var r: float = z["raio"]
				var alvo_h := altura_da_praca(c)
				h = lerpf(alvo_h, h, smoothstep(r * 1.05, r * 1.6, l.distance_to(c)))
			for pl: Dictionary in platos:
				h = lerpf(float(pl["altura"]), h, smoothstep(0.0, TALUDE, dist_plato(l, pl)))
			var d := INF
			for s in trilhas:
				d = minf(d, _dist_segmento(l, s[0], s[1]))
			D_trilha[idx] = d
			H[idx] = maxf(h, ACIMA_DA_BASE)
	_pintar_solo()


## Altura do chão plano de uma praça (a de antes do relevo, nunca abaixo de 1 m).
func altura_da_praca(c: Vector2) -> float:
	return maxf(_altura_bruta(c), 1.0) * smoothstep(0.0, COSTA, borda(c))


## Altura de um platô: a média do relevo natural sob a pegada (corta o alto, aterra o baixo).
func altura_do_plato(pl: Dictionary) -> float:
	var soma := 0.0
	for dx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for dz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			soma += _altura_bruta(pl["centro"] + (Vector2(dx, dz) * (pl["meia"] as Vector2)).rotated(-deg_to_rad(pl["giro"])))
	return maxf(soma / 25.0, 1.0) * smoothstep(0.0, COSTA, borda(pl["centro"]))


## Maior diferença do relevo natural sob a pegada (antes do platô).
func desnivel(pl: Dictionary) -> float:
	var lo := INF
	var hi := -INF
	for dx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for dz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var h := _altura_bruta(pl["centro"] + (Vector2(dx, dz) * (pl["meia"] as Vector2)).rotated(-deg_to_rad(pl["giro"])))
			lo = minf(lo, h)
			hi = maxf(hi, h)
	return hi - lo


## Distância de um ponto local à borda do platô (0 dentro). O giro é o da peça
## (`Basis(Vector3.UP, giro)`): do mundo para o molde gira +giro no plano xz.
func dist_plato(l: Vector2, pl: Dictionary) -> float:
	var q := ((l - (pl["centro"] as Vector2)).rotated(deg_to_rad(pl["giro"]))).abs() - (pl["meia"] as Vector2)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()


## Lugar para uma árvore: fora da areia, das trilhas, das praças e longe `folga` dos platôs.
func livre(l: Vector2, folga: float) -> bool:
	if borda(l) < 10.0:
		return false
	for s in trilhas:
		if _dist_segmento(l, s[0], s[1]) < LARGURA_TRILHA + folga * 0.5:
			return false
	for z: Dictionary in pracas:
		if l.distance_to(z["centro"]) < float(z["raio"]) + folga:
			return false
	for pl: Dictionary in platos:
		if dist_plato(l, pl) < folga:
			return false
	return true


func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _local(i: int, j: int) -> Vector2:
	return Vector2(-meia + i * PASSO, -meia + j * PASSO)


func borda(l: Vector2) -> float:
	return minf(meia - absf(l.x), meia - absf(l.y))


func _altura_bruta(l: Vector2) -> float:
	var h := 1.2 + 1.6 * (ruido.get_noise_2dv(l) * 0.5 + 0.5)
	for m in morros:
		var d := l.distance_to(m[0]) * (1.0 + 0.2 * ruido_fino.get_noise_2dv(l))
		h += float(m[2]) * (1.0 - smoothstep(0.0, float(m[1]), d))
	return h * smoothstep(0.0, COSTA, borda(l))


## Solo: 0 grama, 2 terra (praças e trilhas), 3 areia (costa).
func _pintar_solo() -> void:
	var n := pontos - 1
	S.resize(n * n)
	for j in n:
		for i in n:
			var l := _local(i, j) + Vector2(PASSO, PASSO) * 0.5
			var d_trilha := (D_trilha[j * pontos + i] + D_trilha[(j + 1) * pontos + i + 1]) * 0.5
			var na_praca := false
			for z: Dictionary in pracas:
				if l.distance_to(z["centro"]) < float(z["raio"]):
					na_praca = true
			for pl: Dictionary in platos:
				if dist_plato(l, pl) < 1.0:
					na_praca = true
			var codigo := 0
			if borda(l) < 5.0 + 3.0 * (ruido_fino.get_noise_2dv(l) * 0.5 + 0.5):
				codigo = 3
			elif d_trilha < LARGURA_TRILHA or na_praca:
				codigo = 2
			S[j * n + i] = codigo


func _fracao(h: float) -> int:
	return clampi(int(round((h - BASE_DOS_BLOCOS) / tamanho_y * TerrenoDoMapa.ESCALA)), 0, TerrenoDoMapa.ESCALA)


# =================================================================== PEÇAS
func blocos_de_terreno(grupo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var por_lado := int(2.0 * meia / BLOCO)
	for tj in por_lado:
		for ti in por_lado:
			var alturas := PackedInt32Array()
			alturas.resize((CELULAS + 1) * (CELULAS + 1))
			for j in CELULAS + 1:
				for i in CELULAS + 1:
					alturas[j * (CELULAS + 1) + i] = _fracao(H[(tj * CELULAS + j) * pontos + (ti * CELULAS + i)])
			var solo := PackedByteArray()
			solo.resize(CELULAS * CELULAS)
			for j in CELULAS:
				for i in CELULAS:
					solo[j * CELULAS + i] = S[(tj * CELULAS + j) * (pontos - 1) + ti * CELULAS + i]
			var p := {"id": "%srelevo_%d_%d" % [prefixo, ti, tj], "tipo": "terreno", "grupo": grupo,
				"posicao": Vector3(centro.x - meia + (ti + 0.5) * BLOCO, BASE_DOS_BLOCOS + tamanho_y * 0.5,
					centro.y - meia + (tj + 0.5) * BLOCO),
				"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(BLOCO, tamanho_y, BLOCO),
				"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true,
				"relevo": {"celulas": CELULAS, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}}
			lista.append(p)
			blocos["%d_%d" % [ti, tj]] = p
	contagem["blocos"] = lista.size()
	return lista


## Y do mundo do chão como a MALHA desenha (l: posição local).
func chao(l: Vector2) -> float:
	var ti := clampi(int(floor((l.x + meia) / BLOCO)), 0, int(2.0 * meia / BLOCO) - 1)
	var tj := clampi(int(floor((l.y + meia) / BLOCO)), 0, int(2.0 * meia / BLOCO) - 1)
	var p: Dictionary = blocos["%d_%d" % [ti, tj]]
	var pos: Vector3 = p["posicao"]
	var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], clampf(centro.x + l.x - pos.x, -BLOCO * 0.5, BLOCO * 0.5),
		clampf(centro.y + l.y - pos.z, -BLOCO * 0.5, BLOCO * 0.5))
	return pos.y + y


## O maior chão sob uma pegada retangular (meia = metade dos lados, giro em graus).
func chao_maximo(c: Vector2, meia_: Vector2, giro := 0.0) -> float:
	var y := -INF
	for dx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for dz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			y = maxf(y, chao(c + Vector2(dx * meia_.x, dz * meia_.y).rotated(-deg_to_rad(giro))))
	return y


func anel_de_praia(grupo: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var por_lado := int(2.0 * meia / BLOCO)
	var w := LARGURA_PRAIA
	var faixas: Array = []
	for k in por_lado:
		var ao_longo := -meia + (k + 0.5) * BLOCO
		faixas.append([Vector2(meia + w * 0.5, ao_longo), Vector2(w, BLOCO)])
		faixas.append([Vector2(-meia - w * 0.5, ao_longo), Vector2(w, BLOCO)])
		faixas.append([Vector2(ao_longo, -meia - w * 0.5), Vector2(BLOCO, w)])
		faixas.append([Vector2(ao_longo, meia + w * 0.5), Vector2(BLOCO, w)])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			faixas.append([Vector2(sx * (meia + w * 0.5), sz * (meia + w * 0.5)), Vector2(w, w)])
	for f in faixas:
		var c: Vector2 = f[0]
		var t: Vector2 = f[1]
		var alturas := PackedInt32Array()
		alturas.resize((CELULAS + 1) * (CELULAS + 1))
		for j in CELULAS + 1:
			for i in CELULAS + 1:
				var l := Vector2(c.x + (float(i) / CELULAS - 0.5) * t.x, c.y + (float(j) / CELULAS - 0.5) * t.y)
				alturas[j * (CELULAS + 1) + i] = _fracao(_altura_praia(l))
		var solo := PackedByteArray()
		solo.resize(CELULAS * CELULAS)
		solo.fill(3)
		lista.append({"id": "%spraia_%d" % [prefixo, lista.size()], "tipo": "terreno", "grupo": grupo,
			"posicao": Vector3(centro.x + c.x, BASE_DOS_BLOCOS + tamanho_y * 0.5, centro.y + c.y),
			"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(t.x, tamanho_y, t.y), "cor": Color.WHITE,
			"material": "liso", "grade_celula": 4.0, "colisao": true,
			"relevo": {"celulas": CELULAS, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}})
	contagem["praia"] = lista.size()
	return lista


func _altura_praia(l: Vector2) -> float:
	var b := Vector2(clampf(l.x, -meia, meia), clampf(l.y, -meia, meia))
	var na_borda := H[int(round((b.y + meia) / PASSO)) * pontos + int(round((b.x + meia) / PASSO))]
	var d := l.distance_to(b)
	if d <= 0.0:
		return na_borda
	var alcance := LARGURA_PRAIA * (0.75 + 0.35 * (ruido.get_noise_2d(l.x * 2.0, l.y * 2.0) * 0.5 + 0.5))
	return lerpf(na_borda, -1.3, smoothstep(0.0, alcance, d))
