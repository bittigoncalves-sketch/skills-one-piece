class_name VidaEmBarras
extends RefCounted
## VIDA DOS CHEFES EM 10 BARRAS (10/11/2026, pedido do dono). Um chefe nunca morre em menos de 10 golpes:
##  • golpe que NÃO esvazia a barra atual → o dano é descontado dela, inteiro;
##  • golpe que a esvazia (ou passa dela) → só ESSA barra cai; o que sobrou do dano é descartado;
##  • depois de uma barra cair o dano não conta por 1 s (`IMUNE_APOS_BARRA`) — o chefe ainda recebe o golpe
##    (atordoamento, empurrão, flash), só a vida não diminui. Passado 1 s o dano volta a contar.
## A última barra esvaziada é a morte: não há janela depois dela.
## Estado em metadados do corpo (`barra_dano`, `barra_imune_ate`), sem componente novo; `agora_ms` entra por parâmetro para teste.

const BARRAS := 10
const IMUNE_APOS_BARRA_MS := 1000
const META_DANO := "barra_dano"           # dano já tirado da barra ATUAL
const META_IMUNE := "barra_imune_ate"
## Morte que ignora as barras (queda no vazio, comando kill): quem mata põe esta meta antes do `take_damage`.
const META_MORTE_ABSOLUTA := "morte_absoluta"


## Quanto do `dano` realmente sai da vida (0 dentro da janela). `vida` e `vida_max` são a vida ANTES do golpe.
static func filtrar(corpo: Node, dano: float, vida: float, vida_max: float, agora_ms := -1) -> float:
	if dano <= 0.0 or vida_max <= 0.0 or corpo.get_meta(META_MORTE_ABSOLUTA, false):
		return maxf(dano, 0.0)
	if agora_ms < 0:
		agora_ms = Time.get_ticks_msec()
	if agora_ms < int(corpo.get_meta(META_IMUNE, 0)):
		return 0.0
	var tamanho := vida_max / BARRAS
	# A barra atual é o que sobra da vida até o próximo múltiplo de `tamanho` (cobre vida alterada de fora, ex. cura).
	var resta_na_barra := vida - tamanho * floorf((vida - 0.0001) / tamanho) if vida > 0.0 else 0.0
	if resta_na_barra <= 0.0:
		resta_na_barra = minf(tamanho, vida)
	if dano < resta_na_barra:
		return dano
	# esvaziou a barra: só ela cai
	if vida - resta_na_barra > 0.001:                 # ainda sobra vida → abre a janela
		corpo.set_meta(META_IMUNE, agora_ms + IMUNE_APOS_BARRA_MS)
	return resta_na_barra


## Quantas barras (inteiras ou parcial) ainda restam — para o HUD.
static func barras_restantes(vida: float, vida_max: float) -> int:
	if vida_max <= 0.0 or vida <= 0.0:
		return 0
	return clampi(ceili(vida / (vida_max / BARRAS) - 0.0001), 1, BARRAS)
