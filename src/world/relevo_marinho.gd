class_name RelevoMarinho
extends RefCounted
# ============================================================================
#  RELEVO MARINHO — a altura do fundo do mar em qualquer ponto do MUNDO
#  (14/10/2026, docs/MAR_HISTORIA_PLANO.md, etapa E1). Puro: não cria nó.
#
#  Decisão do dono (14/10): plataforma de 5–25 m perto das ilhas (bancos de areia,
#  dunas, rochas, recifes) + mar aberto de 60–80 m entre as ilhas, com uma fossa no
#  meio do caminho; naufrágios a 8–22 m, ao alcance do fôlego de 30 s.
#
#  UM campo para o mundo todo, que conhece TODAS as ilhas: quem desenha o fundo
#  (`FundoDoMar`, um por ilha) só amostra este campo. A emenda entre os fundos de duas
#  ilhas é contínua por construção (antes ela dependia de os dois chegarem a −30 m).
#
#  Perfil por distância `d` à placa da ilha mais perto:
#    d < 60 m    o perfil de ANTES (praia → rampa); preserva o porto e as vagas do cais
#                (medidas a 28–55 m da borda) e a costa sem degrau.
#    60–160 m    plataforma (~−12 → −16 m) com ondulação, baixios, dunas e rochas.
#    160–360 m   talude até o mar aberto, com ravinas.
#    > 360 m     mar aberto (~−64 m); fossa até ~−80 m na linha do meio entre ilhas.
#  Nada do que SOBE o fundo passa de `nivel − FOLGA_DE_NAVEGACAO` depois dos 60 m: o
#  galeão (calado 3,9 m) nunca encalha num baixio novo.
# ============================================================================

const SEMENTE := 14102026
## A rampa de ANTES (01/10/2026): da praia a −30 m em 150 m. Vale só para d < 60 m.
const RAMPA_ANTIGA := 150.0
const FUNDO_ANTIGO := -30.0
const COSTA_PRESERVADA := 60.0
const PLATAFORMA := -16.0
const FIM_PLATAFORMA := 160.0
const INICIO_ABERTO := 360.0
const MAR_ABERTO := -64.0
const FOSSA := -80.0
## Largura da fossa medida em |d1 − d2| (diferença das distâncias às duas ilhas, que
## cresce 2 m por metro andado): 170 → ~85 m para cada lado da linha do meio, fundo
## chato nos ~30 m centrais.
const LARGURA_FOSSA := 170.0
const FOLGA_DE_NAVEGACAO := 5.0
## Altura em que o campo termina na borda do mundo: o plano do abismo (`FundoDoMar`)
## fica logo abaixo dela.
const BORDA_DO_MUNDO := -66.0

var nivel := -0.65
## Placa (x, z) de cada ilha.
var ilhas: Array[Rect2] = []
## Retângulo onde existe fundo detalhado; fora dele, `BORDA_DO_MUNDO`.
var limite := Rect2()
## Altura da praia num ponto da borda de uma placa (lida do relevo). Sem ela, 0.
var relevo_em: Callable

var _ondulacao := FastNoiseLite.new()
var _baixios := FastNoiseLite.new()
var _rochas := FastNoiseLite.new()
var _deriva := FastNoiseLite.new()
var _ravinas := FastNoiseLite.new()
var _borda := {}


func _init() -> void:
	_ondulacao.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ondulacao.seed = SEMENTE
	_ondulacao.frequency = 1.0 / 240.0
	_ondulacao.fractal_octaves = 3
	_baixios.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_baixios.seed = SEMENTE + 1
	_baixios.frequency = 1.0 / 130.0
	_baixios.fractal_octaves = 2
	_rochas.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rochas.seed = SEMENTE + 2
	# Manchas de simplex comum (1/55 m, 2 oitavas), não "ridged": a crista do ridged
	# subia 0,5 em 4 m e virava quina que a grade de 4 m não desenha (teste E1, 14/10).
	_rochas.frequency = 1.0 / 55.0
	_rochas.fractal_octaves = 2
	_deriva.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_deriva.seed = SEMENTE + 3
	_deriva.frequency = 1.0 / 260.0
	_deriva.fractal_octaves = 2
	_ravinas.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ravinas.seed = SEMENTE + 4
	_ravinas.frequency = 1.0 / 140.0
	_ravinas.fractal_octaves = 1


## Ilhas = placas que se tocam (`FundoDoMar.agrupar`); `alcance` = quanto o fundo
## detalhado avança mar adentro além da ilha mais externa.
func configurar(placas: Array[Rect2], alcance: float, nivel_do_mar: float) -> void:
	ilhas = placas
	nivel = nivel_do_mar
	_borda.clear()
	limite = Rect2()
	for k in ilhas.size():
		limite = ilhas[k] if k == 0 else limite.merge(ilhas[k])
	limite = limite.grow(alcance)


## Uma cópia INDEPENDENTE (mesmos ruídos pela semente, mesmas ilhas, cache da praia própria), para cada thread amostrar sem
## dividir estado com as outras (o `_borda` é escrito durante a amostragem). Mesmas entradas, mesmos números.
func duplicar() -> RelevoMarinho:
	var c := RelevoMarinho.new()
	c.ilhas = ilhas.duplicate()      # buffer PRÓPRIO: ler um array compartilhado de várias threads disputa o mesmo contador atômico
	c.nivel = nivel
	c.limite = limite
	c.relevo_em = relevo_em
	return c


## Altura (y do mundo) do fundo em (x, z).
func altura(x: float, z: float) -> float:
	return amostra(x, z).x


## (altura, rocha 0–1, recife 0–1, crista de duna 0–1) em (x, z), numa passada só: as
## máscaras saem dos MESMOS ruídos da altura (o material e os corais leem daqui).
func amostra(x: float, z: float) -> Vector4:
	var p := Vector2(x, z)
	if ilhas.is_empty():
		return Vector4(BORDA_DO_MUNDO, 0.0, 0.0, 0.0)
	var d1 := INF
	var d2 := INF
	var mais_perto := 0
	for k in ilhas.size():
		var d := _fora(ilhas[k], p)
		if d < d1:
			d2 = d1
			d1 = d
			mais_perto = k
		elif d < d2:
			d2 = d
	var praia := _praia(ilhas[mais_perto], p)
	if d1 <= 0.0:
		return Vector4(praia - 3.0, 0.0, 0.0, 0.0)     # embaixo da ilha: escondido sob a praia
	var antigo := lerpf(praia, FUNDO_ANTIGO, smoothstep(0.0, RAMPA_ANTIGA, d1))
	if d1 < COSTA_PRESERVADA:
		return Vector4(antigo, 0.0, 0.0, 0.0)
	var s := _perfil(p, d1, d2, praia)
	# Emenda suave com a rampa de antes (a rampa desce mais rápido que a plataforma).
	var w := smoothstep(COSTA_PRESERVADA, COSTA_PRESERVADA + 35.0, d1)
	s.x = lerpf(antigo, s.x, w)
	s.y *= w
	s.z *= w
	s.w *= w
	# Borda do mundo: o campo encosta no plano do abismo.
	var ate_borda := minf(minf(p.x - limite.position.x, limite.end.x - p.x), minf(p.y - limite.position.y, limite.end.y - p.y))
	s.x = lerpf(BORDA_DO_MUNDO, s.x, smoothstep(0.0, 80.0, ate_borda))
	return s


## Profundidade (m, positiva) da água em (x, z).
func profundidade(x: float, z: float) -> float:
	return nivel - altura(x, z)


## Quanto (0–1) o ponto é zona de recife: baixio da plataforma com 4–18 m de água.
## Fonte única para os corais (E2): quem planta lê daqui, não recalcula.
func recife(x: float, z: float) -> float:
	return amostra(x, z).z


func _perfil(p: Vector2, d1: float, d2: float, praia: float) -> Vector4:
	var deriva := _deriva.get_noise_2d(p.x, p.y)
	# Plataforma: desce devagar até −16 m, com ondulação larga.
	var plataforma := lerpf(lerpf(praia, FUNDO_ANTIGO, smoothstep(0.0, RAMPA_ANTIGA, COSTA_PRESERVADA)), PLATAFORMA, smoothstep(COSTA_PRESERVADA, FIM_PLATAFORMA, d1))
	plataforma += _ondulacao.get_noise_2d(p.x, p.y) * 3.0
	# Baixios (onde os recifes crescem): sobem até ~6 m da superfície.
	var b := _baixios.get_noise_2d(p.x, p.y)
	plataforma += smoothstep(-0.05, 0.7, b) * 8.0
	# Dunas de areia: cristas paralelas ao vento, entortadas pela deriva; somem nos
	# baixios (ali é recife) e na rocha.
	var rumo := Vector2(0.83, 0.56).rotated(deriva * 0.9)
	var duna := sin(p.dot(rumo) * TAU / 26.0 + deriva * 6.0)
	duna = duna * duna * signf(duna) * 0.5 + 0.5
	var crista := duna * (1.0 - smoothstep(0.0, 0.35, b))
	plataforma += (duna - 0.5) * 0.8 * (1.0 - smoothstep(0.0, 0.35, b))   # 0,8 m: com 1,3 m a luz em faixas listrava o fundo (foto E1)
	# Afloramentos de rocha: manchas do ruído onde ele passa do limiar.
	var rocha := _rochas.get_noise_2d(p.x, p.y)
	plataforma += smoothstep(0.3, 0.7, rocha) * 3.5
	# Talude: da borda da plataforma ao mar aberto, com ravinas.
	var aberto := MAR_ABERTO + _ondulacao.get_noise_2d(p.x * 0.5, p.y * 0.5) * 4.0
	var t := smoothstep(FIM_PLATAFORMA + deriva * 25.0, INICIO_ABERTO + deriva * 25.0, d1)
	# Ravinas: vales onde o ruído próprio cruza o zero (|r| pequeno), mais fundos no meio
	# do talude; largos o bastante para a grade de 4 m (~30° de encosta).
	var vale := 1.0 - smoothstep(0.0, 0.5, absf(_ravinas.get_noise_2d(p.x, p.y)))
	var ravina := vale * 4.0 * t * (1.0 - t) * 4.0
	var y := lerpf(plataforma, aberto, t) - ravina
	# Fossa no meio do caminho entre duas ilhas: |d1 − d2| pequeno = linha do meio.
	if d2 < INF:
		var fora_do_meio := absf(d1 - d2 + deriva * 120.0)     # a deriva faz a fossa serpentear
		var fossa := (1.0 - smoothstep(LARGURA_FOSSA * 0.35, LARGURA_FOSSA, fora_do_meio)) * smoothstep(INICIO_ABERTO, INICIO_ABERTO + 90.0, d1)
		y = lerpf(y, FOSSA + _ondulacao.get_noise_2d(p.y, p.x) * 3.0, fossa)
	# Folga de navegação: o que sobe não chega perto da superfície.
	y = minf(y, nivel - FOLGA_DE_NAVEGACAO)
	var plat := 1.0 - t
	var mascara_rocha := maxf(smoothstep(0.3, 0.7, rocha) * plat, vale * t * (1.0 - t) * 4.0)
	var prof := nivel - y
	var mascara_recife := smoothstep(0.05, 0.35, b) * smoothstep(3.5, 5.0, prof) * (1.0 - smoothstep(16.0, 19.0, prof)) * plat
	return Vector4(y, mascara_rocha, mascara_recife, crista * plat)


## Distância do ponto até a placa (0 dentro).
static func _fora(r: Rect2, p: Vector2) -> float:
	var q := Vector2(maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0), maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0))
	return q.length()


## Altura da praia no ponto da borda da placa mais perto de p (cache por 0,5 m).
func _praia(r: Rect2, p: Vector2) -> float:
	var na_borda := Vector2(clampf(p.x, r.position.x + 0.01, r.end.x - 0.01), clampf(p.y, r.position.y + 0.01, r.end.y - 0.01))
	var chave := na_borda.snapped(Vector2.ONE * 0.5)
	if not _borda.has(chave):
		_borda[chave] = float(relevo_em.call(na_borda)) if relevo_em.is_valid() else 0.0
	return _borda[chave]
