class_name Estamina
extends RefCounted
## ESTAMINA do Epic Fight (10/11/2026). Números lidos de `PlayerPatch`/`EpicFightAttributes` decompilados:
## máximo 15, regeneração 1,0, espera de 30 ticks (1,5 s) depois de gastar; por tick (20/s) regenera
## `máx × 0,01 × (1 + (e / (máx − e×0,5))²) × regen` — mais rápido quanto mais cheia. Custo pelo peso:
## `custo × ((peso/40 − 1) × atenuação + 1)`. Rolar custa 4, passo 3, levantar do chão 6.
## Sem os JSON locais do mod os padrões abaixo valem — a regra de jogo não pode depender de asset ignorado pelo git.

const MAXIMO_PADRAO := 15.0
const REGENERACAO_PADRAO := 1.0
const ESPERA_PADRAO := 1.5            # 30 ticks / 20
const TICKS_POR_SEGUNDO := 20.0
const CUSTO_PADRAO := {"roll": 4.0, "step": 3.0, "knockdown_wakeup": 6.0}
const META := "estamina_epic_fight"
## Atenuação do peso (regra WEIGHT_PENALTY do mod, em %): 0 = peso não pesa, 100 = pesa inteiro.
const ATENUACAO_DO_PESO := 0.4

var maximo := MAXIMO_PADRAO
var regeneracao := REGENERACAO_PADRAO
var espera := ESPERA_PADRAO
var atual := MAXIMO_PADRAO
## Peso total carregado. 40 é o NEUTRO da fórmula do mod (custo base); abaixo disso a esquiva sai mais barata, acima mais cara.
const PESO_NEUTRO := 40.0
var peso := PESO_NEUTRO
var _espera_restante := 0.0
var _resto_de_tick := 0.0


## A estamina de um corpo (criada na primeira consulta e guardada em metadado).
static func de(corpo: Node) -> Estamina:
	if corpo == null:
		return null
	if not corpo.has_meta(META):
		corpo.set_meta(META, Estamina.new())
	return corpo.get_meta(META)


func custo(habilidade: String) -> float:
	var base := EpicFightDados.custo_de(habilidade)
	if base <= 0.0:
		base = float(CUSTO_PADRAO.get(habilidade, 0.0))
	return base * ((peso / 40.0 - 1.0) * ATENUACAO_DO_PESO + 1.0)


func tem(quantidade: float) -> bool:
	return atual + 0.0001 >= quantidade


## Gasta se houver; devolve se gastou. A espera de regeneração recomeça a cada gasto.
func gastar(quantidade: float) -> bool:
	if quantidade <= 0.0:
		return true
	if not tem(quantidade):
		return false
	atual = maxf(atual - quantidade, 0.0)
	_espera_restante = espera
	return true


func gastar_habilidade(habilidade: String) -> bool:
	return gastar(custo(habilidade))


func fracao() -> float:
	return clampf(atual / maximo, 0.0, 1.0) if maximo > 0.0 else 0.0


## Regeneração do mod: em passos de tick (1/20 s) para a conta bater com a original.
func passar_tempo(delta: float) -> void:
	if _espera_restante > 0.0:
		_espera_restante = maxf(_espera_restante - delta, 0.0)
		return
	_resto_de_tick += delta * TICKS_POR_SEGUNDO
	while _resto_de_tick >= 1.0:
		_resto_de_tick -= 1.0
		if atual < maximo:
			var fator := 1.0 + pow(atual / (maximo - atual * 0.5), 2.0)
			atual = minf(atual + maximo * 0.01 * fator * regeneracao, maximo)
