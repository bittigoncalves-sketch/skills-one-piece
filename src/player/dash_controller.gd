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
var _passo: float = 0.0               # quanto do dash cabe NESTE quadro

func montar_em(dono: Node3D) -> void:
	_dono = dono

func ativo() -> bool:      return _t > 0.0
func direcao() -> Vector3: return _direcao
func passo() -> float:     return _passo
func recarga() -> float:   return _recarga
func tempo() -> float:     return _t

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
		if _t <= 0.0 and _dono:
			_dono.set_meta("damage_immune", false)   # acabou a invencibilidade

# A velocidade que a esquiva quer neste quadro. Sobrescrever o vetor INTEIRO
# zera o Y de propósito: durante o dash não há gravidade.
# O fator `_passo/delta` encurta SÓ o último quadro (nos demais é 1.0).
func velocidade(delta: float) -> Vector3:
	return _direcao * (DISTANCIA / TEMPO) * (_passo / delta)
