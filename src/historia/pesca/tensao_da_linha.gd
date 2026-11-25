class_name TensaoDaLinha
extends RefCounted
# ============================================================================
#  TENSÃO DA LINHA — a briga com o peixe fisgado, sem nada de cena (03/10/2026).
#
#  Decisão do dono ("Tensão da linha"): SEGURAR o clique recolhe (a tensão sobe),
#  SOLTAR dá linha (a tensão cai). A barra de captura enche enquanto a tensão fica
#  na ZONA VERDE; fora dela esvazia. Passou do limite, a linha ARREBENTA; a barra
#  zerou, o peixe ESCAPA. Peixes raros puxam mais forte.
#
#  O peixe puxa sempre (a tensão sobe sozinha um pouco) e dá CORRIDAS: um puxão
#  forte, anunciado `PREAVISO` segundos antes (`avisando`) para dar tempo de soltar.
#  Segurar durante a corrida arrebenta a linha dos peixes fortes.
#
#  Determinística pela semente: o teste joga com robôs (esperto, sempre segura,
#  nunca segura) e mede o resultado. Os números abaixo saíram dessas medições
#  (tools/dev_tests/test_pesca.gd).
# ============================================================================

enum Fim { NENHUM, PEGOU, ARREBENTOU, ESCAPOU }

const ZONA_MIN := 0.35
const ZONA_MAX := 0.75
## Tensão por segundo: segurando sobe isto; solto, cai isto (antes do puxão do peixe).
const RECOLHE := 0.55
const SOLTA := 0.75
const TENSAO_INICIAL := 0.5
const PROGRESSO_INICIAL := 0.2
## Fora da zona a barra perde isto por segundo; com a linha frouxa (tensão ~0), o dobro.
const PERDE_FORA := 0.10
const PERDE_FROUXA := 0.20
const PREAVISO := 0.4
## Fichas por raridade:
##   forca     — puxão contínuo (tensão/s somada sempre);
##   corrida   — puxão EXTRA durante a corrida, em múltiplos da força;
##   duracao   — segundos na zona verde para encher a barra;
##   intervalo — segundos entre corridas [mín, máx];
##   tempo     — duração de cada corrida [mín, máx].
const RARIDADES := {
	"comum": {"forca": 0.15, "corrida": 1.4, "duracao": 5.0, "intervalo": Vector2(3.0, 4.5), "tempo": Vector2(0.4, 0.6)},
	"incomum": {"forca": 0.25, "corrida": 1.4, "duracao": 6.5, "intervalo": Vector2(2.5, 4.0), "tempo": Vector2(0.5, 0.7)},
	"raro": {"forca": 0.38, "corrida": 1.4, "duracao": 8.5, "intervalo": Vector2(2.2, 3.5), "tempo": Vector2(0.55, 0.8)},
	"lendario": {"forca": 0.50, "corrida": 1.2, "duracao": 11.0, "intervalo": Vector2(2.0, 3.0), "tempo": Vector2(0.5, 0.8)},
}

var raridade := "comum"
var tensao := TENSAO_INICIAL
var progresso := PROGRESSO_INICIAL
var fim: Fim = Fim.NENHUM
## Corrida chegando (o HUD pisca o "!"): solte agora.
var avisando := false
var correndo := false

var _ficha: Dictionary
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fase := 0.0
var _proxima_corrida := 0.0
var _fim_da_corrida := 0.0


func _init(raridade_do_peixe: String = "comum", semente: int = 0) -> void:
	raridade = raridade_do_peixe if RARIDADES.has(raridade_do_peixe) else "comum"
	_ficha = RARIDADES[raridade]
	_rng.seed = semente
	_fase = _rng.randf() * TAU
	_proxima_corrida = _sortear(_ficha["intervalo"])


func na_zona() -> bool:
	return tensao >= ZONA_MIN and tensao <= ZONA_MAX


## Puxão do peixe agora (tensão/s), com a corrida se estiver nela.
func puxao() -> float:
	var forca: float = _ficha["forca"]
	var p := forca * (0.75 + 0.25 * sin(_t * 2.3 + _fase))
	if correndo:
		p += forca * float(_ficha["corrida"])
	return p


## Um passo da briga. `segurando` = clique pressionado. Devolve o `Fim` (NENHUM segue).
func passo(delta: float, segurando: bool) -> Fim:
	if fim != Fim.NENHUM:
		return fim
	_t += delta
	# Corridas: aviso, puxão forte, volta ao normal e agenda a próxima.
	if not correndo and _t >= _proxima_corrida:
		correndo = true
		_fim_da_corrida = _t + _sortear(_ficha["tempo"])
	elif correndo and _t >= _fim_da_corrida:
		correndo = false
		_proxima_corrida = _t + _sortear(_ficha["intervalo"])
	avisando = not correndo and _proxima_corrida - _t <= PREAVISO

	tensao += ((RECOLHE if segurando else -SOLTA) + puxao()) * delta
	tensao = maxf(tensao, 0.0)
	if tensao >= 1.0:
		tensao = 1.0
		fim = Fim.ARREBENTOU
		return fim
	if na_zona():
		progresso += delta / float(_ficha["duracao"])
	else:
		progresso -= (PERDE_FROUXA if tensao <= 0.02 else PERDE_FORA) * delta
	if progresso >= 1.0:
		progresso = 1.0
		fim = Fim.PEGOU
	elif progresso <= 0.0:
		progresso = 0.0
		fim = Fim.ESCAPOU
	return fim


func _sortear(faixa: Vector2) -> float:
	return _rng.randf_range(faixa.x, faixa.y)
