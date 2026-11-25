class_name PincelDeRelevo
extends RefCounted
# ============================================================================
#  PINCEL DE RELEVO — esculpir e pintar os blocos `terreno` no editor (01/10/2026).
#
#  Pedido do dono (decisões dele): modos ELEVAR/ABAIXAR (Shift inverte), APLAINAR
#  (nivela na altura onde a pincelada começou) e PINTAR SOLO; passar do topo da caixa
#  faz TODOS os blocos crescerem juntos; peças pousadas na área ACOMPANHAM o chão.
#
#  Lógica pura sobre o `DocumentoMapa` (sem nó, sem mouse): o editor chama `aplicar`
#  a cada quadro de uma pincelada, dentro de UMA transação do histórico.
#
#  ⚠️ EMENDAS: a altura nova de um ponto é função só da posição NO MUNDO e da altura
#  antiga. O ponto de borda que dois blocos dividem tem as duas iguais nos dois (mesma
#  fração, mesma base, mesmo Y) — então sai igual nos dois. É o que mantém a emenda
#  exata (ver `TerrenoDoMapa`); por isso o crescimento mexe em TODOS os blocos de
#  mesma base e Y, nunca num só.
# ============================================================================

enum Modo { ELEVAR, APLAINAR, PINTAR }

const RAIO_MIN := 1.0
const RAIO_MAX := 60.0
## Metros por segundo com força 1 (elevar/abaixar).
const VELOCIDADE := 6.0
## Folga acima do ponto mais alto quando a caixa cresce (m).
const FOLGA_DE_CRESCIMENTO := 4.0
## Peça "pousada": a base dela está a até isto do chão, no centro.
const POUSADA_ATE := 1.0

var modo: int = Modo.ELEVAR
var raio := 8.0
var forca := 0.5
var solo := 1          # código em TerrenoDoMapa.SOLOS (1 = grama; 0 = automático)


## Uma aplicação do pincel em `centro` (mundo). `inverter` = abaixar (Shift).
## `alvo` = altura do aplainar (a do começo da pincelada). Devolve os ids mudados.
func aplicar(doc: DocumentoMapa, centro: Vector3, delta: float, inverter := false, alvo := 0.0) -> Array[String]:
	var mudados: Array[String] = []
	var blocos := blocos_sob(doc, centro, raio)
	if blocos.is_empty():
		return mudados
	var terrenos := _terrenos(doc)
	if modo == Modo.PINTAR:
		for id in blocos:
			if _pintar(doc, id, centro):
				mudados.append(id)
		return mudados
	# 1) Alturas novas, em metros, ponto a ponto (índice da grade -> metros).
	var novas := {}
	var mais_alto := -INF
	for id in blocos:
		var mapa := _alturas_novas(doc.peca(id), centro, delta, inverter, alvo)
		if not mapa.is_empty():
			novas[id] = mapa
			for h in mapa.values():
				mais_alto = maxf(mais_alto, h)
	if novas.is_empty():
		return mudados
	# 2) Passou do topo? Todos os blocos de mesma base e Y crescem juntos ANTES.
	var exemplo := doc.peca(novas.keys()[0])
	var base := _base(exemplo)
	if mais_alto > base + (exemplo["tamanho"] as Vector3).y:
		mudados.append_array(crescer(doc, base, (exemplo["tamanho"] as Vector3).y,
			ceilf(mais_alto - base + FOLGA_DE_CRESCIMENTO)))
	# 3) Peças pousadas: chão ANTES, para acompanhar depois.
	var pousadas := _pecas_pousadas(doc, centro, terrenos)
	# 4) Grava.
	for id in novas:
		var p := doc.peca(id)
		var r: Dictionary = p["relevo"]
		var alturas: PackedInt32Array = r["alturas"]
		var t: Vector3 = p["tamanho"]
		var b := _base(p)
		for k in novas[id]:
			alturas[k] = clampi(roundi((float(novas[id][k]) - b) / t.y * TerrenoDoMapa.ESCALA), 0, TerrenoDoMapa.ESCALA)
		r["alturas"] = alturas
		p["relevo"] = r
		doc.definir_peca(id, p)
		if not mudados.has(id):
			mudados.append(id)
	# 5) As peças acompanham a diferença de chão no centro delas.
	terrenos = _terrenos(doc)
	for item in pousadas:
		var depois := chao_em(terrenos, item["xz"])
		if is_nan(depois):
			continue
		var d: float = depois - float(item["antes"])
		if absf(d) < 0.0005:
			continue
		if item["id"] == "@spawn":
			doc.definir_spawn(doc.spawn + Vector3(0, d, 0))
			continue
		var pc := doc.peca(item["id"])
		pc["posicao"] = (pc["posicao"] as Vector3) + Vector3(0, d, 0)
		doc.definir_peca(item["id"], pc)
		mudados.append(item["id"])
	return mudados


## Blocos de terreno cujo retângulo (girado) encosta no círculo do pincel.
static func blocos_sob(doc: DocumentoMapa, centro: Vector3, r: float) -> Array[String]:
	var lista: Array[String] = []
	for id in doc.ids():
		var p := doc.ler(id)
		if p["tipo"] != "terreno":
			continue
		var local := _local(p, centro)
		var t: Vector3 = p["tamanho"]
		var dx := maxf(absf(local.x) - t.x * 0.5, 0.0)
		var dz := maxf(absf(local.z) - t.z * 0.5, 0.0)
		if dx * dx + dz * dz <= r * r:
			lista.append(id)
	return lista


## Altura do chão (mundo) no ponto XZ, pelo bloco que o contém; NAN fora deles.
static func chao(doc: DocumentoMapa, xz: Vector2) -> float:
	return chao_em(_terrenos(doc), xz)


## Os blocos de terreno do mapa (leitura, sem cópia).
static func _terrenos(doc: DocumentoMapa) -> Array:
	var lista: Array = []
	for id in doc.ids():
		var p := doc.ler(id)
		if p["tipo"] == "terreno":
			lista.append(p)
	return lista


static func chao_em(terrenos: Array, xz: Vector2) -> float:
	var melhor := NAN
	for p: Dictionary in terrenos:
		var local := _local(p, Vector3(xz.x, 0, xz.y))
		var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], local.x, local.z)
		if not is_nan(y):
			var mundo := y + (p["posicao"] as Vector3).y
			melhor = mundo if is_nan(melhor) else maxf(melhor, mundo)
	return melhor


## Todos os blocos de base `base` e altura `y_antigo` passam a `y_novo`, mantendo a
## altura de cada ponto (fração recalculada; mesmo inteiro antigo -> mesmo inteiro
## novo, então as emendas continuam exatas). Devolve os ids mudados.
static func crescer(doc: DocumentoMapa, base: float, y_antigo: float, y_novo: float) -> Array[String]:
	var mudados: Array[String] = []
	var fator := y_antigo / y_novo
	for id in doc.ids():
		var p := doc.peca(id)
		if p["tipo"] != "terreno":
			continue
		var t: Vector3 = p["tamanho"]
		if not is_equal_approx(t.y, y_antigo) or not is_equal_approx(_base(p), base):
			continue
		var r: Dictionary = p["relevo"]
		r["alturas"] = _reescalar(r["alturas"], fator, false)
		if not (r["agua"] as PackedInt32Array).is_empty():
			r["agua"] = _reescalar(r["agua"], fator, true)
		p["relevo"] = r
		p["tamanho"] = Vector3(t.x, y_novo, t.z)
		p["posicao"] = Vector3((p["posicao"] as Vector3).x, base + y_novo * 0.5, (p["posicao"] as Vector3).z)
		doc.definir_peca(id, p)
		mudados.append(id)
	return mudados


# ------------------------------------------------------------------ internos
func _alturas_novas(p: Dictionary, centro: Vector3, delta: float, inverter: bool, alvo: float) -> Dictionary:
	var r: Dictionary = p["relevo"]
	var n: int = r["celulas"]
	var t: Vector3 = p["tamanho"]
	var b := _base(p)
	var alturas: PackedInt32Array = r["alturas"]
	var saida := {}
	var subir := VELOCIDADE * forca * delta * (-1.0 if inverter else 1.0)
	var puxar := clampf(forca * 8.0 * delta, 0.0, 1.0)
	for j in n + 1:
		for i in n + 1:
			var mundo := _mundo(p, Vector3((float(i) / n - 0.5) * t.x, 0, (float(j) / n - 0.5) * t.z))
			var d := Vector2(mundo.x - centro.x, mundo.z - centro.z).length()
			if d >= raio:
				continue
			var w := _queda(d / raio)
			var k := j * (n + 1) + i
			var h := b + float(alturas[k]) / TerrenoDoMapa.ESCALA * t.y
			var nova := h + subir * w if modo == Modo.ELEVAR else lerpf(h, alvo, puxar * w)
			saida[k] = maxf(nova, b)
	return saida


func _pintar(doc: DocumentoMapa, id: String, centro: Vector3) -> bool:
	var p := doc.peca(id)
	var r: Dictionary = p["relevo"]
	var n: int = r["celulas"]
	var t: Vector3 = p["tamanho"]
	var cel: PackedByteArray = r["solo"]
	var mudou := false
	for j in n:
		for i in n:
			var mundo := _mundo(p, Vector3(((i + 0.5) / n - 0.5) * t.x, 0, ((j + 0.5) / n - 0.5) * t.z))
			if Vector2(mundo.x - centro.x, mundo.z - centro.z).length() < raio and cel[j * n + i] != solo:
				cel[j * n + i] = solo
				mudou = true
	if mudou:
		r["solo"] = cel
		p["relevo"] = r
		doc.definir_peca(id, p)
	return mudou


## Peças com o centro na área do pincel e a base no chão (até POUSADA_ATE dele).
## Blocos de terreno não; spawn sim.
func _pecas_pousadas(doc: DocumentoMapa, centro: Vector3, terrenos: Array) -> Array:
	var lista: Array = []
	for id in doc.ids():
		var p := doc.ler(id)
		if p["tipo"] == "terreno":
			continue
		var c: Vector3 = p["posicao"]
		if Vector2(c.x - centro.x, c.z - centro.z).length() >= raio:
			continue
		var xz := Vector2(c.x, c.z)
		var antes := chao_em(terrenos, xz)
		if is_nan(antes):
			continue
		var fundo := c.y - (p["tamanho"] as Vector3).y * 0.5
		if absf(fundo - antes) <= POUSADA_ATE or fundo < antes:
			lista.append({"id": id, "xz": xz, "antes": antes})
	var s := doc.spawn
	if Vector2(s.x - centro.x, s.z - centro.z).length() < raio:
		var antes_s := chao_em(terrenos, Vector2(s.x, s.z))
		if not is_nan(antes_s):
			lista.append({"id": "@spawn", "xz": Vector2(s.x, s.z), "antes": antes_s})
	return lista


## Sino suave: 1 no centro, 0 na borda, sem quina.
static func _queda(x: float) -> float:
	var u := clampf(1.0 - x * x, 0.0, 1.0)
	return u * u


static func _base(p: Dictionary) -> float:
	return (p["posicao"] as Vector3).y - (p["tamanho"] as Vector3).y * 0.5


static func _giro(p: Dictionary) -> Basis:
	return Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0))


static func _local(p: Dictionary, mundo: Vector3) -> Vector3:
	return _giro(p).inverse() * (mundo - (p["posicao"] as Vector3))


static func _mundo(p: Dictionary, local: Vector3) -> Vector3:
	return (p["posicao"] as Vector3) + _giro(p) * local


static func _reescalar(valores: PackedInt32Array, fator: float, manter_negativo: bool) -> PackedInt32Array:
	var saida := valores.duplicate()
	for k in saida.size():
		if manter_negativo and saida[k] < 0:
			continue
		saida[k] = clampi(roundi(float(saida[k]) * fator), 0, TerrenoDoMapa.ESCALA)
	return saida
