class_name VooLogiaMinePiece
extends RefCounted
# ============================================================================
#  O VOO DAS LOGIAS DO MINE PIECE v14 (FlyActiveProcedure + a física do Minecraft).
#
#  A cada 3 ticks, com comando: sem W/S sobe (aceleração × velocidade × 1,5); com W
#  acelera na direção da mira, com S para trás. Cada eixo só ganha velocidade até o
#  teto (`velocidade` blocos/tick) — quem freia é o ar do Minecraft, entre os ticks:
#  horizontal × 0,91 e vertical × 0,98, com a gravidade da Queda Lenta (0,01).
#  Logia: velocidade 1, aceleração 0,75 (Magu 0,75 de velocidade; não é o caso).
#
#  Adaptação: no mod o voo exige Espaço segurado no ar. Na transformação elemental
#  (regra do dono) o voo é forçado: W/S também comandam, e parado o corpo plana.
# ============================================================================

const ACELERACAO := 0.75
const VELOCIDADE_LOGIA := 1.0
const GRAVIDADE_QUEDA_LENTA := 0.01
const ARRASTO_HORIZONTAL := 0.91
const ARRASTO_VERTICAL := 0.98
## Impulso da decolagem quando a transformação começa (o "sobe" de um FlyActive).
const DECOLAGEM := ACELERACAO * VELOCIDADE_LOGIA * 1.5

var v := Vector3.ZERO          # blocos/tick


func comecar(velocidade_ms: Vector3) -> void:
	v = velocidade_ms / MundoMinePiece.VELOCIDADE
	v.y = maxf(v.y, DECOLAGEM)


## Um tick. `frente`: +1 W, −1 S, 0 nenhum. Devolve a velocidade em m/s.
func tick(n: int, subir: bool, frente: float, olhar: Vector3, bonus: float, no_chao: bool) -> Vector3:
	if n % 3 == 1 and (subir or frente != 0.0):
		var teto := VELOCIDADE_LOGIA * bonus
		var novo := v
		if frente == 0.0:
			novo.y += ACELERACAO * teto * 1.5
		else:
			novo += ACELERACAO * olhar * teto * signf(frente)
		v = Vector3(_limitar(v.x, novo.x, teto), _limitar(v.y, novo.y, teto), _limitar(v.z, novo.z, teto))
	v.y = (v.y - GRAVIDADE_QUEDA_LENTA) * ARRASTO_VERTICAL
	v.x *= ARRASTO_HORIZONTAL
	v.z *= ARRASTO_HORIZONTAL
	if no_chao and v.y < 0.0:
		v.y = 0.0
	return v * MundoMinePiece.VELOCIDADE


## A regra de cada eixo do FlyActive: sobe até o teto, mas nunca tira o que já havia.
static func _limitar(antes: float, novo: float, teto: float) -> float:
	if novo < 0.0:
		return minf(antes, maxf(novo, -teto))
	return maxf(antes, minf(novo, teto))
