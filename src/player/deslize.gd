extends RefCounted
# ============================================================================
#  DESLIZE (Ctrl) — 03/10/2026.
#
#  Pedido do dono: deslizar no Ctrl, "somado à necessidade da velocidade de estar
#  em movimento"; decisão: PASSA POR BAIXO de obstáculos baixos (o corpo encolhe).
#  Estilo Mirror's Edge: o embalo da corrida vira deslize, perde velocidade aos
#  poucos, e levantar só acontece quando há espaço em cima.
#
#  ESTADOS
#    "deslizando"  corpo baixo (o Player encolhe a colisão e a hurtbox pela metade).
#                  Ganha até +10 % de velocidade (decisão do dono, 03/10); acaba
#                  no tempo — se o TETO deixar; preso sob teto, continua.
#    "levantando"  já de pé (colisão inteira), o clipe termina de levantar.
#  Espaço deslizando = pulo com o embalo (o pulo em si é do `aplicar_pulos`).
#  Ctrl na parede continua sendo "soltar" (o parkour consome antes).
#
#  Clipe "Running Slide" (Mixamo, 1,57 s): desce 0,07→0,39 s, desliza
#  0,39→0,85 s (quadril a 24 % da altura), levanta 0,85→1,44 s. O tempo do clipe
#  sai da física (`tempo_do_clipe`), não do relógio.
#
#  Mesmo molde dos outros componentes: devolve a velocidade, não a escreve.
# ============================================================================

const CLIPE := "res://assets/animations/running_slide.res"
## Só desliza quem está correndo (a corrida é 4,2 m/s).
const VEL_MIN := 3.5
## Deslizando a velocidade SOBE, não cai (decisão do dono, 03/10/2026: "aumentar
## a velocidade em 0.1 enquanto desliza ao invés de reduzir"): entra na velocidade
## da corrida e chega a +10 % ao fim do DURACAO. Preso sob teto, mantém o ganho.
const GANHO := 0.1
const DURACAO := 0.75
const LEVANTAR := 0.3

var estado := ""
var _t := 0.0
var _t_lev := 0.0
var _vel := 0.0
var _vel_entrada := 0.0
var _dir := Vector3.ZERO


func ativo() -> bool:
	return estado != ""


## Corpo baixo: o Player mantém a colisão encolhida.
func encolhido() -> bool:
	return estado == "deslizando"


func direcao() -> Vector3:
	return _dir


## Ctrl apertado: entra se está no chão e correndo. Devolve true se entrou.
func tentar(vel: Vector3, no_chao: bool) -> bool:
	if ativo() or not no_chao:
		return false
	var plano := Vector3(vel.x, 0.0, vel.z)
	var v := plano.length()
	if v < VEL_MIN:
		return false
	estado = "deslizando"
	_t = 0.0
	_t_lev = 0.0
	_dir = plano / v
	_vel_entrada = v
	_vel = v
	return true


## A velocidade HORIZONTAL deste quadro. `teto_livre`: cabe de pé aqui.
## `saltou`: o Espaço virou pulo neste quadro (o deslize acaba).
func atualizar(delta: float, no_chao: bool, teto_livre: bool, saltou: bool) -> Vector3:
	if not ativo():
		return Vector3.ZERO
	if estado == "deslizando":
		_t += delta
		_vel = _vel_entrada * (1.0 + GANHO * clampf(_t / DURACAO, 0.0, 1.0))
		if (saltou or not no_chao) and teto_livre:
			_acabar()                     # pulou ou saiu de uma beirada: embalo segue
			return _dir * _vel
		if _t >= DURACAO and teto_livre:
			estado = "levantando"         # sob teto baixo continua deslizando
			_t_lev = 0.0
		return _dir * _vel
	# levantando: o embalo se mantém — a corrida retoma dele quando acabar.
	_t_lev += delta
	if _t_lev >= LEVANTAR or saltou:
		_acabar()
	return _dir * _vel


## Larga o deslize sem mais nada (arremesso, morte, outro sistema tomou o corpo).
func cancelar() -> void:
	_acabar()


## Tempo do clipe "Running Slide" neste quadro.
func tempo_do_clipe() -> float:
	if estado == "deslizando":
		if _t < 0.2:
			return lerpf(0.07, 0.39, _t / 0.2)
		return minf(0.39 + (_t - 0.2) * 0.6, 0.85)
	if estado == "levantando":
		return lerpf(0.85, 1.44, clampf(_t_lev / LEVANTAR, 0.0, 1.0))
	return 0.0


func _acabar() -> void:
	estado = ""
	_t = 0.0
	_t_lev = 0.0
