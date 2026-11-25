class_name PistaDosCaranguejos
extends RefCounted
# ============================================================================
#  PISTA DOS CARANGUEJOS — o circuito da corrida, em DADO (06/10/2026).
#
#  Pedido do dono: "pista de corrida gigante… corrida de caranguejos… obstáculos na
#  pista e parkour". Decisão dele: mapa próprio (região só da corrida, longe da ilha).
#
#  A pista é uma sequência de TRECHOS percorrida como uma tartaruga (anda, sobe, vira à
#  direita). Deste dado sai tudo numa passada só, sem segunda fonte:
#    • `pecas`      — peças estáticas no formato do mapa (montadas pelo `MapaMontador`);
#    • `portoes`    — os portões em ordem (o último é a linha de chegada);
#    • `caminho`    — os pontos que a IA segue, com os pulos marcados;
#    • `obstaculos` — toras, martelos, braços, paredes e plataformas móveis;
#    • `zonas`      — lama (lento) e impulsos (rápido);
#    • `largada`    — as seis vagas do grid.
#  Coordenadas LOCAIS da pista: a linha de largada/chegada é a origem, olhando para −Z,
#  com o deck em y = 0. O mar fica `ALTURA_DO_DECK` abaixo (é um píer gigante).
#  Quatro curvas de 90° à direita: o teste confere que o circuito FECHA na largada e que
#  cada vão e degrau cabe no pulo do caranguejo.
# ============================================================================

const LARGURA := 16.0
const ESPESSURA := 0.8
const ALTURA_DO_DECK := 4.0
const RAIO_DAS_CURVAS := 34.0
const PASSO_DO_CAMINHO := 5.0
const SEGMENTOS_DA_CURVA := 9
const ALTURA_DA_GRADE := 0.9

const COR_DECK := "#a87d55"      # madeira de píer (o laranja de antes saturava no sol)
const COR_DECK_CLARO := "#c9bb9c"  # largada/chegada (o claro de antes estourava em branco)
const COR_LAMA := "#5e4430"
const COR_POCA := "#3f2c1e"
const COR_PEDRA := "#a39782"
const COR_PEDRA_ESCURA := "#6f6556"
const COR_PILAR := "#5a4632"
const COR_PASSARELA := "#8a5a36"
const COR_METAL := "#3d4652"
const COR_PORTAO := "#24303d"
const COR_IMPULSO := "#2fd0a8"
const ZEBRA := ["#f2efe8", "#d6453b"]

## A ordem da volta. Comprimentos fecham o retângulo: lados de 220, 270, 260 e 270 m
## + chegada de 40 m + 4 curvas de raio 34 m ≈ 1,27 km.
const TRECHOS: Array[Dictionary] = [
	{"tipo": "reta", "nome": "Largada", "comprimento": 90.0, "cor": COR_DECK_CLARO},
	{"tipo": "toras", "nome": "Toras rolantes", "comprimento": 130.0, "quantidade": 5},
	{"tipo": "curva", "nome": "Curva da praia", "angulo": -90.0},
	{"tipo": "ilhotas", "nome": "Ilhotas"},
	{"tipo": "rampa", "nome": "Subida", "comprimento": 30.0, "subida": 5.0},
	{"tipo": "passarela", "nome": "Passarela dos martelos", "comprimento": 130.0, "largura": 8.0, "quantidade": 5},
	{"tipo": "rampa", "nome": "Descida", "comprimento": 30.0, "subida": -5.0},
	{"tipo": "curva", "nome": "Curva dos braços", "angulo": -90.0, "bracos": 2},
	{"tipo": "lama", "nome": "Lamaçal", "comprimento": 70.0},
	{"tipo": "degraus", "nome": "Degraus", "degraus": 5, "altura": 0.5, "fundo": 5.0},
	{"tipo": "plataformas", "nome": "Plataformas móveis"},
	{"tipo": "paredes", "nome": "Paredes móveis", "comprimento": 90.0},
	{"tipo": "curva", "nome": "Curva do farol", "angulo": -90.0},
	{"tipo": "impulsos", "nome": "Reta dos impulsos", "comprimento": 270.0},
	{"tipo": "curva", "nome": "Última curva", "angulo": -90.0},
	{"tipo": "reta", "nome": "Chegada", "comprimento": 40.0, "cor": COR_DECK_CLARO},
]

## Ilhotas: 9 ilhas de 6 m entre 10 vãos (somam 26 m) = 80 m. Altura e desvio de cada uma.
const VAOS_DAS_ILHOTAS := [2.2, 2.5, 2.8, 2.4, 2.9, 2.6, 2.3, 2.8, 2.7, 2.8]
const ALTURAS_DAS_ILHOTAS := [0.3, 0.6, 0.3, 0.0, 0.4, 0.8, 0.4, 0.2, 0.0]
## De uma ilha para a outra o desvio vai até 3,5 m: o zigue-zague se lê de longe e cabe
## numa ilha de 6 m a 8,5 m/s (com 6 m de desvio nem a IA nem gente acertava a linha).
const DESVIOS_DAS_ILHOTAS := [0.0, 1.5, -1.0, 2.0, -1.5, 1.0, -2.0, 1.5, 0.0]
const ILHOTA := Vector2(8.0, 6.0)          # largura × comprimento
## Plataformas móveis: deck de 9 m, 3 fileiras de 7 m entre 4 vãos de 2,5 m, deck de 10 m.
const PLATAFORMA := Vector2(8.0, 7.0)
const VAO_DAS_PLATAFORMAS := 2.5
## Onde a IA pula: quase NA borda (o caranguejo, 0,86 m de raio, ainda está apoiado).
const BORDA_DO_PULO := 0.15
const FAIXA_SECA := 3.5
## Portões cuja volta fica ANTES deles: logo depois do portão há um vão (ilhotas) ou um
## degrau (cairia dentro do bloco) — volta no chão firme, com corrida para o pulo.
const VOLTA_ANTES := {"Ilhotas": -3.5, "Degraus": -3.0}

var pos := Vector3.ZERO
var rumo := 0.0                 # radianos; 0 = −Z; virar à direita diminui
var pecas: Array[Dictionary] = []
var portoes: Array[Dictionary] = []
var caminho: Array[Dictionary] = []
var obstaculos: Array[Dictionary] = []
var zonas: Array[Dictionary] = []
var _n := 0
var _andado := 0.0


## O circuito inteiro (ver o cabeçalho).
static func gerar() -> Dictionary:
	var g := PistaDosCaranguejos.new()
	return g._gerar()


## Mapa no formato do editor (`MapaArquivo`), pronto para validar e montar.
static func mapa(dados: Dictionary) -> Dictionary:
	return {"formato": MapaArquivo.FORMATO, "versao": MapaArquivo.VERSAO, "nome": "Pista dos Caranguejos",
		"spawn": {"posicao": [0, 2, -10]}, "pecas": dados.pecas}


func _gerar() -> Dictionary:
	for i in TRECHOS.size():
		var t: Dictionary = TRECHOS[i]
		_portao(str(t.nome), float(t.get("largura", LARGURA)), i)
		match str(t.tipo):
			"reta": _reta(t)
			"toras": _toras(t)
			"curva": _curva(t)
			"ilhotas": _ilhotas()
			"rampa": _rampa(t)
			"passarela": _passarela(t)
			"lama": _lama(t)
			"degraus": _degraus(t)
			"plataformas": _plataformas()
			"paredes": _paredes(t)
			"impulsos": _impulsos(t)
	# A linha de chegada é o último portão (de volta à origem).
	_portao("Chegada", LARGURA, TRECHOS.size())
	_arco_de_chegada()
	return {"pecas": pecas, "portoes": portoes, "caminho": caminho, "obstaculos": obstaculos,
		"zonas": zonas, "largada": _largada(), "fim": pos, "rumo_final": rumo, "comprimento": _andado}


# ------------------------------------------------------------------ eixos

func frente(r := rumo) -> Vector3:
	return Vector3(-sin(r), 0, -cos(r))


func direita(r := rumo) -> Vector3:
	return Vector3(cos(r), 0, -sin(r))


func _id(base: String) -> String:
	_n += 1
	return "%s_%d" % [base, _n]


## Peça no formato do mapa. `centro` = centro da caixa; rumo/inclinação em radianos.
func _peca(tipo: String, base: String, centro: Vector3, tamanho: Vector3, cor: String,
		r := 0.0, inclinacao := 0.0, colisao := true) -> void:
	pecas.append({"id": _id(base), "tipo": tipo,
		"posicao": [snappedf(centro.x, 0.001), snappedf(centro.y, 0.001), snappedf(centro.z, 0.001)],
		"rotacao_graus": [snappedf(rad_to_deg(inclinacao), 0.01), snappedf(wrapf(rad_to_deg(r), -180.0, 180.0), 0.01), 0],
		"tamanho": [tamanho.x, tamanho.y, tamanho.z], "cor": cor, "material": "liso", "colisao": colisao})


## Deck reto de `comp` metros a partir de `de`, com o topo na altura de `de`.
func _deck(de: Vector3, comp: float, largura: float, cor: String, r := rumo) -> void:
	var c := de + frente(r) * comp * 0.5 + Vector3.DOWN * ESPESSURA * 0.5
	_peca("caixa", "deck", c, Vector3(largura, ESPESSURA, comp + 0.04), cor, r)


## Grade em zebra dos dois lados (blocos de 6 m), do ponto `de` ao longo de `comp`.
func _grades(de: Vector3, comp: float, largura: float, r := rumo, inclinacao := 0.0) -> void:
	var n := maxi(1, int(round(comp / 6.0)))
	var bloco := comp / n
	var sobe := tan(inclinacao)
	for lado: float in [-1.0, 1.0]:
		for k in n:
			var meio := (k + 0.5) * bloco
			var c := de + frente(r) * meio + direita(r) * lado * (largura * 0.5 + 0.25) \
				+ Vector3.UP * (ALTURA_DA_GRADE * 0.5 + meio * sobe)
			_peca("caixa", "grade", c, Vector3(0.5, ALTURA_DA_GRADE, bloco / cos(inclinacao) + 0.02), ZEBRA[k % 2], r, inclinacao)


## Pilares do píer até o mar, a cada 20 m, nos dois lados.
func _pilares(de: Vector3, comp: float, largura: float, r := rumo, sobe := 0.0) -> void:
	var n := maxi(1, int(comp / 20.0))
	for k in n:
		var meio := (k + 0.5) * comp / n
		var topo := de.y + sobe * meio / comp - ESPESSURA
		var altura := topo + ALTURA_DO_DECK + 1.0
		for lado: float in [-1.0, 1.0]:
			var p := de + frente(r) * meio + direita(r) * lado * (largura * 0.5 - 1.0)
			p.y = topo - altura * 0.5
			_peca("cilindro", "pilar", p, Vector3(1.0, altura, 1.0), COR_PILAR, r, 0.0, false)


func _pontos(de: Vector3, comp: float, livre: float, r := rumo, sobe := 0.0) -> void:
	var n := maxi(1, int(ceil(comp / PASSO_DO_CAMINHO)))
	for k in n:
		var d := (k + 1) * comp / n
		caminho.append({"p": de + frente(r) * d + Vector3.UP * (sobe * d / comp), "livre": livre, "salto": false})


func _avancar(comp: float, sobe := 0.0) -> void:
	pos += frente() * comp + Vector3.UP * sobe
	_andado += comp


# ------------------------------------------------------------------ portões

func _portao(nome: String, largura: float, indice: int) -> void:
	# `volta`: onde quem cai reaparece, em metros à frente do portão (negativo = antes).
	var volta := float(VOLTA_ANTES.get(nome, 4.0))
	portoes.append({"nome": nome, "p": pos, "frente": frente(), "direita": direita(), "largura": largura, "indice": indice,
		"caminho": caminho.size(), "volta": volta})
	if indice == 0:
		return                      # a largada ganha o arco de chegada
	for lado: float in [-1.0, 1.0]:
		var p := pos + direita() * lado * (largura * 0.5 + 0.9) + Vector3.UP * 3.25
		_peca("cilindro", "portao", p, Vector3(0.6, 6.5, 0.6), COR_PORTAO, rumo)
	_peca("caixa", "portao", pos + Vector3.UP * 6.4, Vector3(largura + 2.4, 0.7, 0.7), COR_PORTAO, rumo, 0.0, false)


func _arco_de_chegada() -> void:
	var o := Vector3.ZERO
	for lado: float in [-1.0, 1.0]:
		_peca("caixa", "arco", o + Vector3(lado * (LARGURA * 0.5 + 1.4), 4.0, 0), Vector3(1.6, 8.0, 1.6), COR_PORTAO)
	_peca("caixa", "arco", o + Vector3(0, 7.7, 0), Vector3(LARGURA + 4.4, 1.0, 1.2), COR_PORTAO, 0.0, 0.0, false)
	# Faixa quadriculada (16 × 2) logo abaixo da trave, e a linha no chão.
	for i in 16:
		for j in 2:
			var cor := "#111111" if (i + j) % 2 == 0 else "#f4f4f4"
			_peca("caixa", "xadrez", o + Vector3(-7.5 + i, 6.75 - j * 0.9, 0.0), Vector3(1.0, 0.9, 0.3), cor, 0.0, 0.0, false)
			_peca("caixa", "linha", o + Vector3(-7.5 + i, 0.03, -0.5 + j * 1.0), Vector3(1.0, 0.06, 1.0), cor, 0.0, 0.0, false)


func _largada() -> Array[Dictionary]:
	var vagas: Array[Dictionary] = []
	for fila in 2:
		for coluna in 3:
			vagas.append({"p": Vector3((coluna - 1) * 5.0, 0.2, -7.0 - fila * 7.0), "rumo": 0.0})
	return vagas


# ------------------------------------------------------------------ trechos

func _reta(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	var largura := float(t.get("largura", LARGURA))
	_deck(pos, comp, largura, str(t.get("cor", COR_DECK)))
	_grades(pos, comp, largura)
	_pilares(pos, comp, largura)
	_pontos(pos, comp, largura * 0.5 - 2.0)
	_avancar(comp)


## Toras rolando de um lado ao outro da pista (empurram e atordoam).
func _toras(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	var n := int(t.quantidade)
	for k in n:
		var d := comp * (k + 1.0) / (n + 1.0)
		obstaculos.append({"tipo": "tora", "p": pos + frente() * d + Vector3.UP * 0.75, "frente": frente(), "direita": direita(),
			"amplitude": LARGURA * 0.5 - 1.6, "periodo": 3.2 + 0.45 * (k % 3), "fase": k * 1.7, "raio": 0.75, "comprimento": 3.2})
	_reta({"comprimento": comp})


func _curva(t: Dictionary) -> void:
	var ang := deg_to_rad(float(t.angulo))
	var lado := signf(ang)                       # −1 = direita
	var centro := pos - direita() * lado * RAIO_DAS_CURVAS
	var passo := ang / SEGMENTOS_DA_CURVA
	var corda := 2.0 * RAIO_DAS_CURVAS * sin(absf(passo) * 0.5)
	var bracos := int(t.get("bracos", 0))
	var inicio := pos
	for k in SEGMENTOS_DA_CURVA:
		var r_meio := rumo + passo * (k + 0.5)
		var de := pos
		var ate := centro + (de - centro).rotated(Vector3.UP, passo)
		var meio := (de + ate) * 0.5
		_peca("caixa", "deck", meio + Vector3.DOWN * ESPESSURA * 0.5, Vector3(LARGURA, ESPESSURA, corda + 0.6), COR_DECK, r_meio)
		_peca("cilindro", "junta", ate + Vector3.DOWN * ESPESSURA * 0.5, Vector3(LARGURA, ESPESSURA, LARGURA), COR_DECK, 0.0, 0.0, true)
		# Grades: a de fora mais comprida que a de dentro.
		for s: float in [-1.0, 1.0]:
			var raio_grade := RAIO_DAS_CURVAS + s * lado * -(LARGURA * 0.5 + 0.25)
			var c_grade := centro + (meio - centro).normalized() * raio_grade * cos(absf(passo) * 0.5) + Vector3.UP * ALTURA_DA_GRADE * 0.5
			_peca("caixa", "grade", c_grade, Vector3(0.5, ALTURA_DA_GRADE, 2.0 * raio_grade * sin(absf(passo) * 0.5) + 0.3), ZEBRA[k % 2], r_meio)
		if k % 3 == 1:
			for s: float in [-1.0, 1.0]:
				var p_pilar := meio + direita(r_meio) * s * (LARGURA * 0.5 - 1.0)
				p_pilar.y = pos.y - ESPESSURA - (pos.y - ESPESSURA + ALTURA_DO_DECK + 1.0) * 0.5
				_peca("cilindro", "pilar", p_pilar, Vector3(1.0, pos.y - ESPESSURA + ALTURA_DO_DECK + 1.0, 1.0), COR_PILAR, 0.0, 0.0, false)
		caminho.append({"p": ate, "livre": LARGURA * 0.5 - 2.0, "salto": false})
		pos = ate
		_andado += corda
	rumo += ang
	# Braços giratórios: postes no meio da curva varrendo a pista.
	for b in bracos:
		var a := ang * (b + 1.0) / (bracos + 1.0)
		var r_b := rumo - ang + a
		var p_b := centro + (inicio - centro).rotated(Vector3.UP, a)
		obstaculos.append({"tipo": "braco", "p": p_b, "frente": frente(r_b), "direita": direita(r_b),
			"comprimento": LARGURA * 0.5 - 0.6, "velocidade": deg_to_rad(75.0) * (1.0 if b % 2 == 0 else -1.0), "fase": b * 1.3})


## Parkour 1: ilhas de pedra sobre o mar; só se passa pulando (correndo).
## Caminho da IA: em cada ilha, pousa no meio da sobreposição com a anterior, alinha 2,6 m
## antes da borda no meio da sobreposição com a próxima e pula NA borda (o corpo de 0,86 m
## de raio ainda está apoiado ali). Pulo de lado não dá: virar no ar encurta o pulo.
func _ilhotas() -> void:
	var de := pos
	var n := ALTURAS_DAS_ILHOTAS.size()
	var lados: Array[float] = []
	for k in n:
		lados.append(float(DESVIOS_DAS_ILHOTAS[k]))
	var entra := lados[0]
	# O último ponto da curva cai na borda: atrapalharia o alinhamento antes do pulo.
	while not caminho.is_empty() and ((caminho[-1].p as Vector3) - pos).length() < 2.7:
		caminho.pop_back()
	portoes[-1].caminho = caminho.size()
	caminho.append({"p": pos - frente() * 2.6 + direita() * entra, "livre": 0.0, "salto": false})
	caminho.append({"p": pos - frente() * BORDA_DO_PULO + direita() * entra, "livre": 0.0, "salto": true})
	var d := 0.0
	for k in n:
		d += float(VAOS_DAS_ILHOTAS[k])
		var h := float(ALTURAS_DAS_ILHOTAS[k])
		var c := de + frente() * (d + ILHOTA.y * 0.5) + direita() * lados[k]
		_peca("caixa", "ilhota", c + Vector3.UP * (h - ESPESSURA * 0.5), Vector3(ILHOTA.x, ESPESSURA, ILHOTA.y), COR_PEDRA, rumo)
		var base := h - ESPESSURA + ALTURA_DO_DECK + 1.0
		_peca("caixa", "rocha", c + Vector3.UP * (h - ESPESSURA - base * 0.5), Vector3(ILHOTA.x - 1.2, base, ILHOTA.y - 1.0), COR_PEDRA_ESCURA, rumo, 0.0, false)
		var inicio := de + frente() * d + Vector3.UP * h
		var fim := inicio + frente() * ILHOTA.y
		var pousa := (lados[k - 1] + lados[k]) * 0.5 if k > 0 else lados[0]
		var sai := (lados[k] + lados[k + 1]) * 0.5 if k + 1 < n else lados[k] * 0.5
		caminho.append({"p": inicio + frente() * 1.4 + direita() * pousa, "livre": 0.0, "salto": false})
		if k == 4:
			# Portão no meio: quem cai volta para o começo da 5ª ilha (com corrida para o
			# pulo), e a IA retoma do alinhamento dela.
			var guardado := pos
			pos = inicio + direita() * lados[k]
			_portao_simples("Ilhotas (meio)")
			pos = guardado
		caminho.append({"p": fim - frente() * 2.6 + direita() * sai, "livre": 0.0, "salto": false})
		caminho.append({"p": fim - frente() * BORDA_DO_PULO + direita() * sai, "livre": 0.0, "salto": true})
		d += ILHOTA.y
	d += float(VAOS_DAS_ILHOTAS[-1])
	_andado += d
	pos = de + frente() * d


## Portão sem arco (o meio das ilhotas): só o ponto de volta.
func _portao_simples(nome: String) -> void:
	portoes.append({"nome": nome, "p": pos, "frente": frente(), "direita": direita(), "largura": ILHOTA.x, "indice": -1,
		"caminho": caminho.size(), "volta": 0.9})


func _rampa(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	var sobe := float(t.subida)
	var inclinacao := atan2(sobe, comp)
	var compr := sqrt(comp * comp + sobe * sobe)
	var c := pos + frente() * comp * 0.5 + Vector3.UP * (sobe * 0.5 - ESPESSURA * 0.5 / cos(inclinacao))
	# +0,6 m em cada ponta: subindo, o caranguejo (cilindro de fundo chato) se apoia pela
	# borda da frente, que batia NA QUINA do deck de cima (mesma altura) e travava como
	# parede. Prolongada, a rampa passa ~10 cm por cima da quina e ele só desce para o
	# deck; embaixo, o excesso fica sob o deck de baixo.
	_peca("caixa", "rampa", c, Vector3(LARGURA, ESPESSURA, compr + 1.2), COR_DECK, rumo, inclinacao)
	_grades(pos, comp, LARGURA, rumo, inclinacao)
	_pilares(pos, comp, LARGURA, rumo, sobe)
	_pontos(pos, comp, LARGURA * 0.5 - 2.0, rumo, sobe)
	_avancar(comp, sobe)


## Passarela estreita e alta, sem grade, com martelos balançando de lado.
func _passarela(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	var largura := float(t.largura)
	# Transição: o fim da rampa tem 16 m; a passarela afunila em 8 m de deck largo.
	_deck(pos, 8.0, LARGURA, COR_DECK)
	_deck(pos + frente() * 8.0, comp - 8.0, largura, COR_PASSARELA)
	_pilares(pos + frente() * 8.0, comp - 8.0, largura + 2.0)
	_pontos(pos, comp, largura * 0.5 - 1.5)
	var n := int(t.quantidade)
	for k in n:
		var d := 8.0 + (comp - 8.0) * (k + 0.75) / (n + 0.5)
		var base := pos + frente() * d
		for lado: float in [-1.0, 1.0]:
			_peca("caixa", "portico", base + direita() * lado * (largura * 0.5 + 1.2) + Vector3.UP * 3.75, Vector3(0.7, 7.5, 0.7), COR_METAL, rumo)
		_peca("caixa", "portico", base + Vector3.UP * 7.6, Vector3(largura + 3.1, 0.6, 0.7), COR_METAL, rumo, 0.0, false)
		obstaculos.append({"tipo": "martelo", "p": base + Vector3.UP * 7.3, "frente": frente(), "direita": direita(),
			"comprimento": 6.1, "amplitude": deg_to_rad(68.0), "periodo": 2.6 + 0.3 * (k % 3), "fase": k * 1.1})
	_avancar(comp)


## Lamaçal: deixa lento, menos numa faixa seca de 3,5 m do lado esquerdo.
func _lama(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	_deck(pos, comp, LARGURA, COR_DECK)
	var seca := FAIXA_SECA
	var largura_lama := LARGURA - seca
	# Camadas do chão: lama (topo 0,06), poças (topo 0,09) — o formato pede ≥ 5 cm.
	var centro := pos + frente() * comp * 0.5 + direita() * (seca * 0.5) + Vector3.UP * 0.03
	_peca("caixa", "lama", centro, Vector3(largura_lama, 0.06, comp), COR_LAMA, rumo, 0.0, false)
	for k in 7:
		var p := pos + frente() * comp * (k + 0.5) / 7.0 + direita() * (seca * 0.5 + sin(k * 2.3) * 3.0) + Vector3.UP * 0.06
		_peca("cilindro", "poca", p, Vector3(4.0 + (k % 3), 0.06, 4.0 + (k % 3)), COR_POCA, 0.0, 0.0, false)
	zonas.append({"tipo": "lama", "centro": centro, "tamanho": Vector3(largura_lama, 3.0, comp), "frente": frente(), "direita": direita(), "fator": 0.5})
	_grades(pos, comp, LARGURA)
	_pilares(pos, comp, LARGURA)
	# A IA conhece a faixa seca: corre por ela.
	var n := int(ceil(comp / PASSO_DO_CAMINHO))
	for k in n:
		caminho.append({"p": pos + frente() * (k + 1) * comp / n - direita() * (LARGURA * 0.5 - seca * 0.5), "livre": 1.0, "salto": false})
	_avancar(comp)


## Parkour 2: degraus que só se sobem pulando, e depois a descida.
func _degraus(t: Dictionary) -> void:
	var n := int(t.degraus)
	var h := float(t.altura)
	var fundo := float(t.fundo)
	var base_y := pos.y
	# Os pulos seguem na raia da faixa seca do lamaçal (lado esquerdo): cruzar a lama na
	# diagonal logo antes do 1º degrau tirava a velocidade para a frente e o pulo não subia.
	var raia := -direita() * (LARGURA * 0.5 - FAIXA_SECA * 0.5)
	for k in n * 2:
		var nivel := (k + 1) if k < n else (n * 2 - k - 1)
		var topo := base_y + nivel * h
		var de := pos + frente() * k * fundo
		var altura := topo - base_y + ESPESSURA
		var c := de + frente() * fundo * 0.5
		c.y = topo - altura * 0.5
		_peca("caixa", "degrau", c, Vector3(LARGURA, altura, fundo + 0.02), COR_DECK if k % 2 == 0 else COR_PEDRA, rumo)
		for lado: float in [-1.0, 1.0]:
			var g := c + direita() * lado * (LARGURA * 0.5 + 0.25)
			g.y = topo + ALTURA_DA_GRADE * 0.5
			_peca("caixa", "grade", g, Vector3(0.5, ALTURA_DA_GRADE, fundo + 0.02), ZEBRA[k % 2], rumo)
		if k < n:
			caminho.append({"p": Vector3(de.x, topo - h, de.z) - frente() * 2.3 + raia, "livre": 1.5, "salto": true})
		caminho.append({"p": Vector3(c.x, topo, c.z) + raia, "livre": 1.5, "salto": false})
	_pilares(pos, fundo * n * 2, LARGURA)
	_avancar(fundo * n * 2)


## Parkour 3: fileiras de plataformas que deslizam de lado sobre o mar.
func _plataformas() -> void:
	_deck(pos, 9.0, LARGURA, COR_DECK)
	_grades(pos, 9.0, LARGURA)
	_pilares(pos, 9.0, LARGURA)
	_pontos(pos, 9.0, LARGURA * 0.5 - 2.0)
	var de := pos + frente() * 9.0
	var d := 0.0
	for k in 3:
		d += VAO_DAS_PLATAFORMAS
		var c := de + frente() * (d + PLATAFORMA.y * 0.5)
		# Até ~4,4 m/s de lado (3,5 m em 5 s): dá para ler e cronometrar o pulo.
		obstaculos.append({"tipo": "plataforma", "p": c + Vector3.DOWN * ESPESSURA * 0.5, "frente": frente(), "direita": direita(),
			"tamanho": Vector3(PLATAFORMA.x, ESPESSURA, PLATAFORMA.y), "amplitude": 3.5, "periodo": [5.0, 4.4, 5.6][k], "fase": k * 2.1})
		# Pulo PARA a plataforma k (a IA espera ela alinhar) e o meio dela (segue ela).
		caminho.append({"p": c - frente() * (PLATAFORMA.y * 0.5 + VAO_DAS_PLATAFORMAS + BORDA_DO_PULO), "livre": 0.0, "salto": true, "mira_plataforma": obstaculos.size() - 1})
		caminho.append({"p": c, "livre": 0.0, "salto": false, "plataforma": obstaculos.size() - 1})
		d += PLATAFORMA.y
	d += VAO_DAS_PLATAFORMAS
	var fim := de + frente() * d
	# Último pulo: de cima da plataforma para o deck largo (sempre cabe).
	caminho.append({"p": fim - frente() * (VAO_DAS_PLATAFORMAS + BORDA_DO_PULO), "livre": 0.0, "salto": true, "plataforma": obstaculos.size() - 1})
	_deck(fim, 10.0, LARGURA, COR_DECK)
	_grades(fim, 10.0, LARGURA)
	_pilares(fim, 10.0, LARGURA)
	_pontos(fim, 10.0, LARGURA * 0.5 - 2.0)
	_andado += 9.0 + d + 10.0
	pos = fim + frente() * 10.0


## Paredes que deslizam de lado deixando uma passagem que anda.
func _paredes(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	for k in 3:
		var d := comp * (k + 1.0) / 4.0
		obstaculos.append({"tipo": "parede", "p": pos + frente() * d, "frente": frente(), "direita": direita(),
			"abertura": 6.0, "amplitude": 4.5, "periodo": 3.6 + 0.5 * k, "fase": k * 1.9, "altura": 2.6})
	_reta({"comprimento": comp})


## Reta longa com impulsos (setas no chão: mais rápido por 1,4 s).
func _impulsos(t: Dictionary) -> void:
	var comp := float(t.comprimento)
	for k in 6:
		var d := 25.0 + k * 40.0
		var lado := -3.5 if k % 2 == 0 else 3.5
		var c := pos + frente() * d + direita() * lado + Vector3.UP * 0.03
		_peca("caixa", "impulso", c, Vector3(5.0, 0.06, 4.0), COR_IMPULSO, rumo, 0.0, false)
		for s in 2:
			var seta := c + frente() * (0.8 - s * 1.4) + Vector3.UP * 0.03
			for m: float in [-1.0, 1.0]:
				_peca("caixa", "seta", seta + direita() * m * 0.7, Vector3(0.35, 0.06, 1.9), "#f4fff9", rumo + m * deg_to_rad(40.0), 0.0, false)
		zonas.append({"tipo": "impulso", "centro": c, "tamanho": Vector3(5.0, 3.0, 4.0), "frente": frente(), "direita": direita(), "fator": 1.5, "segundos": 1.4})
	_reta({"comprimento": comp})
