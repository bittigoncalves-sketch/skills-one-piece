class_name BatidaDoCoracao
extends RefCounted
# ============================================================================
#  O MINIGAME DO CORAÇÃO (04/11/2026) — a "tensão da linha" da pesca, adaptada.
#
#  Pedido do dono: com a vida em zero o jogador não morre — vê um coração voxel e joga um minigame
#  no estilo da pesca para fazê-lo voltar a bater. Escolhas dele: pesca adaptada, 15 s, nota = o
#  quanto a barra encheu, volta com NO MÁXIMO 50 % de vida × nota.
#
#    SEGURAR o clique  → bombeia (a pressão sobe);  SOLTAR → dá folga (a pressão cai);
#    pressão na ZONA VERDE → a barra do coração enche; fora dela, esvazia devagar;
#    o coração dá ARRITMIAS: um puxão forte para cima, anunciado `PREAVISO` s antes (como as
#    corridas do peixe) — solte quando o "!" piscar, senão a pressão estoura a zona;
#    termina quando a barra enche (nota 100 %) ou aos `DURACAO` s (nota = barra naquele instante).
#
#  Diferenças da pesca, de propósito: nada "arrebenta" (pressão a 100 % só fica fora da zona e a
#  barra desce), e a barra começa vazia (nota é o que o jogador ENCHEU, sem ponto de graça).
#  Determinística pela semente: `test_coracao.gd` joga com robôs (esperto, sempre segura, nunca
#  segura, metade do tempo) e mede a nota — os números saíram dessas medições.
# ============================================================================

const DURACAO := 15.0
const ZONA_MIN := 0.35
const ZONA_MAX := 0.75
const RECOLHE := 0.90          # pressão por segundo segurando
const SOLTA := 0.90            # e soltando
const PRESSAO_INICIAL := 0.50
## Segundos DENTRO da zona para encher a barra: sobra folga para errar (15 s de janela).
const SEGUNDOS_PARA_ENCHER := 10.5
const PERDE_FORA := 0.07       # barra por segundo fora da zona
const PERDE_FROUXA := 0.14     # com a pressão quase zero
const FORCA := 0.34            # puxão contínuo do coração (pressão/s)
const FORCA_DA_ARRITMIA := 2.6 # extra durante a arritmia, em múltiplos da força
const INTERVALO := Vector2(2.2, 3.4)
const TEMPO_DA_ARRITMIA := Vector2(0.5, 0.75)
const PREAVISO := 0.45
## Menos que isto o coração não volta (o dono: nota < 10 % = morte).
const NOTA_MINIMA := 0.10
## O máximo de vida que se recupera (fração da vida máxima), na nota 100 %.
const VIDA_MAXIMA := 0.50

var pressao := PRESSAO_INICIAL
var progresso := 0.0
var tempo := 0.0
var terminou := false
## Arritmia chegando (o HUD pisca o "!"): solte agora.
var avisando := false
var arritmia := false

var _rng := RandomNumberGenerator.new()
var _fase := 0.0
var _proxima := 0.0
var _fim_da_arritmia := 0.0


func _init(semente: int = 0) -> void:
	_rng.seed = semente
	_fase = _rng.randf() * TAU
	_proxima = _sortear(INTERVALO)


func na_zona() -> bool:
	return pressao >= ZONA_MIN and pressao <= ZONA_MAX


func restante() -> float:
	return maxf(DURACAO - tempo, 0.0)


## Puxão do coração agora (pressão/s), com a arritmia se estiver nela.
func puxao() -> float:
	var p := FORCA * (0.75 + 0.25 * sin(tempo * 2.3 + _fase))
	if arritmia:
		p += FORCA * FORCA_DA_ARRITMIA
	return p


## Um passo. `segurando` = clique pressionado. Devolve `true` quando acabou.
func passo(delta: float, segurando: bool) -> bool:
	if terminou:
		return true
	tempo += delta
	if not arritmia and tempo >= _proxima:
		arritmia = true
		_fim_da_arritmia = tempo + _sortear(TEMPO_DA_ARRITMIA)
	elif arritmia and tempo >= _fim_da_arritmia:
		arritmia = false
		_proxima = tempo + _sortear(INTERVALO)
	avisando = not arritmia and _proxima - tempo <= PREAVISO

	pressao += ((RECOLHE if segurando else -SOLTA) + puxao()) * delta
	pressao = clampf(pressao, 0.0, 1.0)
	if na_zona():
		progresso += delta / SEGUNDOS_PARA_ENCHER
	else:
		progresso -= (PERDE_FROUXA if pressao <= 0.02 else PERDE_FORA) * delta
	progresso = clampf(progresso, 0.0, 1.0)
	if progresso >= 1.0 or tempo >= DURACAO:
		terminou = true
	return terminou


## A nota (0..1): quanto a barra encheu.
func nota() -> float:
	return progresso


## O coração voltou a bater?
func voltou() -> bool:
	return nota() >= NOTA_MINIMA


## Vida devolvida, em fração da vida MÁXIMA do jogador: no máximo 50 %, compatível com a nota.
func vida_devolvida() -> float:
	return VIDA_MAXIMA * nota() if voltou() else 0.0


func _sortear(faixa: Vector2) -> float:
	return _rng.randf_range(faixa.x, faixa.y)
