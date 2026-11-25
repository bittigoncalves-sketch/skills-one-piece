class_name TransformacaoElemental
extends RefCounted
# ============================================================================
#  A TRANSFORMAÇÃO ELEMENTAL DAS LOGIAS — regra do Skills One Piece, NÃO do mod.
#
#  Decisão do dono (18/10/2026): aqui não existe intangibilidade permanente das
#  logias (no Mine Piece, ataque físico sem haki atravessa). No lugar: sob pressão,
#  o corpo vira o elemento. Levar GOLPES ataques seguidos dentro de JANELA segundos
#  — ou perder FRACAO_DE_VIDA da vida máxima nessa janela — transforma o corpo: fica
#  mais rápido e é forçado a voar (o voo das logias do mod, `VooLogiaMinePiece`).
#  Disparar uma técnica desfaz a transformação e o corpo volta ao normal.
#  Valores escolhidos pelo dono entre três propostas (18/10/2026).
#
#  Feita para servir a qualquer logia: a Goro Goro (Mine Piece) é a primeira. A Pika
#  (luz) foi o exemplo do dono e ainda não usa isto — GATILHO: o dono pedir a regra
#  para outra logia.
# ============================================================================

const JANELA := 3.0
const GOLPES := 4
const FRACAO_DE_VIDA := 0.25
const BONUS_DE_VELOCIDADE := 1.35

var ativa := false
var _golpes: Array[Vector2] = []   # (instante, dano)
var _vida_anterior := -1.0


## Lê a vida do corpo a cada passo. Cada queda de vida é um golpe recebido.
## Devolve verdadeiro no passo em que o corpo se transforma.
func observar(vida: float, vida_maxima: float, agora: float) -> bool:
	var dano := _vida_anterior - vida if _vida_anterior >= 0.0 else 0.0
	_vida_anterior = vida
	if ativa or vida <= 0.0 or dano <= 0.0:
		return false
	_golpes.append(Vector2(agora, dano))
	var soma := 0.0
	for i in range(_golpes.size() - 1, -1, -1):
		if agora - _golpes[i].x > JANELA:
			_golpes.remove_at(i)
		else:
			soma += _golpes[i].y
	if _golpes.size() >= GOLPES or soma >= FRACAO_DE_VIDA * vida_maxima:
		ativa = true
		_golpes.clear()
		return true
	return false


func golpes_na_janela() -> int:
	return _golpes.size()


func desfazer() -> void:
	ativa = false
	_golpes.clear()
