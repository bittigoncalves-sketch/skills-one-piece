class_name DashController
extends RefCounted
# ============================================================================
#  DASH — a esquiva do Q.
#
#  Fase 4 de docs/ARQUITETURA_PLAYER.md. Primeiro dos três cortes do ciclo
#  físico, e o primeiro de propósito: a medição mostrou que **todos** os campos
#  de dash eram usados só dentro do `_etapa_locomocao` (8 de 9 usos de `_dash_t`,
#  4 de 5 de `_dash_dir` — o resto era a linha de declaração). Nada de fora
#  dependia deles.
#
#  ------------------------------------------------------------------ COMO FUNCIONA
#  Segurar Q MIRA; soltar DISPARA. A direção é travada no disparo: a esquiva vai
#  aonde o jogador apontou, e girar a câmera no meio do dash não a curva.
#
#  Durante o dash não há gravidade — nem queda, nem subida, só o plano.
#
#  ---------------------------------------------------------------- A FRONTEIRA
#  Este controlador é dono de: mira, recarga, tempo restante e direção travada.
#  Ele NÃO escreve `velocity` — devolve a velocidade que quer, e quem combina é
#  a etapa. É o princípio da arquitetura: cada componente é dono do seu estado,
#  o Player combina os resultados.
#
#  Os dois efeitos que transbordam para fora são PEDIDOS, não escritas:
#   • a janela de ROLAMENTO (`pedir_rolamento`) — que o pouso de precisão também
#     usa. Era um campo com dois donos;
#   • a imunidade a dano durante a esquiva, que é meta do corpo.
# ============================================================================

const DISTANCIA := 12.0       # metros percorridos por dash
const TEMPO := 0.28           # segundos de deslocamento
const RECARGA := 1.5          # recarga entre dashes

var _dono: Node3D = null

var _mirando: bool = false            # segurando Q
var _recarga: float = 0.0             # tempo até poder de novo
var _t: float = 0.0                   # tempo restante do deslocamento
var _direcao: Vector3 = Vector3.FORWARD  # travada no disparo

## Para que lado a esquiva saiu, RELATIVO ao corpo. Não é enfeite: é o que
## decide a pose, e a pose é o que faz o adversário LER a esquiva. Antes tudo
## usava a mesma animação de rolamento — dar um passo para trás e mergulhar para
## a frente pareciam a mesma coisa na tela.
enum Rumo { FRENTE, TRAS, ESQUERDA, DIREITA }
var _rumo: int = Rumo.FRENTE

## Quanto do giro do rolamento de costas já passou (0..1). Só o dash para TRÁS
## usa: é ele que gira o corpo de verdade, e não só encolhe.
var _giro: float = 0.0
var _passo: float = 0.0               # quanto do dash cabe NESTE quadro

func montar_em(dono: Node3D) -> void:
	_dono = dono

func ativo() -> bool:      return _t > 0.0
func direcao() -> Vector3: return _direcao
func passo() -> float:     return _passo
func recarga() -> float:   return _recarga
func tempo() -> float:     return _t
func rumo() -> int:        return _rumo

## Nome do rumo, para o animador escolher a pose sem conhecer o enum.
func rumo_nome() -> String:
	match _rumo:
		Rumo.TRAS:     return "tras"
		Rumo.ESQUERDA: return "esquerda"
		Rumo.DIREITA:  return "direita"
		_:             return "frente"

## 0 no começo do rolamento de costas, 1 no fim. Fora do dash para trás, 0.
func giro_do_rolamento() -> float:
	return _giro

# Chamado uma vez por quadro, ANTES de a etapa escrever `velocity`.
# `bloqueado` = o combate está usando o corpo (carregando, rajada, pistola do
# Yami): não dá pra armar a esquiva no meio disso.
func atualizar(delta: float, q: MoveFrame, bloqueado: bool) -> void:
	if _recarga > 0.0:
		_recarga = maxf(_recarga - delta, 0.0)

	if q.dash_segurado and _recarga <= 0.0 and _t <= 0.0 and not bloqueado:
		_mirando = true
	elif not q.dash_segurado and _mirando:
		_mirando = false
		_t = TEMPO
		_recarga = RECARGA
		if _dono:
			_dono.pedir_rolamento(TEMPO)          # dispara a animação de rolamento
			_dono.set_meta("damage_immune", true)
		# Direção = TECLA segurada (W frente, D lado, S ré...). Sem tecla nenhuma,
		# usa a frente da câmera. Os dois já vêm do yaw puro, sem pitch: o dash é
		# sempre horizontal, e a suspensão da gravidade não vira empuxo.
		_direcao = q.dir.normalized() if q.dir.length_squared() > 0.01 else q.frente
		_rumo = _classificar(_direcao, q)
		_giro = 0.0
		if _dono:
			var cena := _dono.get_tree().current_scene
			FxUtil.dash_effect(cena, _dono.global_position, _direcao)
			# SOM DA ESQUIVA (2026-08-23). Nasce aqui, junto do anel de choque, e
			# não num observador de estado: o disparo é ESTE instante, e é o único
			# ponto do ciclo que sabe que a esquiva SAIU (mirar não faz barulho).
			#
			# É LOCAL, como o `dash_effect` logo acima: o dash não tem RPC — quem
			# não é a autoridade nem chega a rodar `atualizar`. Dar som ao dash
			# alheio é trabalho de replicar o dash, não deste ponto.
			#
			# O pitch varia ±6% para dois dashes seguidos não soarem colados.
			AudioFX.dash(cena, _dono.global_position, randf_range(0.94, 1.06))

	# Consome o tempo DEPOIS do gatilho, para o disparo já andar neste quadro.
	# `_passo` é quanto do dash cabe no quadro: no último ele é MENOR que o delta.
	# Sem isso o dash anda um quadro inteiro a mais (o `_t` não zera exato — 1/60
	# não tem representação binária finita) e passa ~4% da distância pedida.
	_passo = 0.0
	if _t > 0.0:
		_passo = minf(_t, delta)
		_t = maxf(_t - delta, 0.0)
		# O giro anda com o tempo RESTANTE, não com um contador próprio: assim ele
		# fecha exatamente quando a esquiva acaba, sem sobra nem corte.
		_giro = clampf(1.0 - (_t / TEMPO), 0.0, 1.0)
		if _t <= 0.0 and _dono:
			_dono.set_meta("damage_immune", false)   # acabou a invencibilidade
	else:
		_giro = 0.0

## Em que rumo a esquiva saiu, comparando a direção com a FRENTE e a DIREITA do
## corpo. As duas vêm do `MoveFrame`, que as tira da base canônica
## (`RosaDosVentos.base_do_corpo`) — a mesma da mira e da hitbox.
##
## ⚠️ Frente e trás decidem PRIMEIRO, e por um limiar generoso (|para_frente| >
## 0,5, ou seja o cone de 60° em torno do eixo). Uma diagonal como W+D é dash
## para a FRENTE inclinado, não um dash lateral — tratá-la como lateral faria a
## esquiva mais comum do jogo escolher a pose errada.
func _classificar(dir: Vector3, q: MoveFrame) -> int:
	var para_frente := dir.dot(q.frente)
	var para_lado := dir.dot(q.direita)
	if para_frente > 0.5:
		return Rumo.FRENTE
	if para_frente < -0.5:
		return Rumo.TRAS
	return Rumo.DIREITA if para_lado >= 0.0 else Rumo.ESQUERDA


# A velocidade que a esquiva quer neste quadro. Sobrescrever o vetor INTEIRO
# zera o Y de propósito: durante o dash não há gravidade.
# O fator `_passo/delta` encurta SÓ o último quadro (nos demais é 1.0).
func velocidade(delta: float) -> Vector3:
	return _direcao * (DISTANCIA / TEMPO) * (_passo / delta)
