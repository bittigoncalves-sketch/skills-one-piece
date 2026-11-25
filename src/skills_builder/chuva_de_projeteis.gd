extends RefCounted
## Projéteis em CHUVA (07/10/2026, C da Pika). Pedido do dono: "C deve ocorrer em uma
## ampla área, uma ampla dispersão de bolinhas de laser amarelas"; decisão: "chuva na
## área mirada — as bolinhas sobem e caem espalhadas num círculo largo em volta do ponto
## mirado".
##
## Cada bolinha sai da mão em arco (balístico) e cai num ponto sorteado do círculo. O
## sorteio usa a semente do lançamento (a mesma em todos os peers): quem vê a chuva vê
## as bolinhas caírem onde o servidor fere.

## Gravidade da chuva quando o bloco não tem a sua (m/s²).
const GRAVIDADE := 30.0
## Tempo de voo de cada bolinha (s), sorteado entre estes.
const VOO_MIN := 0.55
const VOO_MAX := 0.95


## O centro da chuva: o chão embaixo do ponto mirado (mirar no céu ou longe demais traz
## o centro para dentro do Alcance, no chão).
static func centro(mundo: World3D, de: Vector3, mirado: Vector3, alcance: float, excluir: Array[RID]) -> Vector3:
	var alvo := mirado
	var plano := Vector2(alvo.x - de.x, alvo.z - de.z)
	if not alvo.is_finite():
		return de
	if plano.length() > alcance:
		plano = plano.normalized() * alcance
		alvo = Vector3(de.x + plano.x, alvo.y, de.z + plano.y)
	if mundo == null:
		return alvo
	var q := PhysicsRayQueryParameters3D.create(alvo + Vector3.UP * 2.0, alvo + Vector3.DOWN * 60.0, 1, excluir)
	var hit := mundo.direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else alvo


## `n` pontos de queda espalhados por IGUAL no círculo de raio `raio` em volta de `meio`
## ("ampla dispersão"; concentrar no meio dava 13 estouros num alvo parado em 1,1 s).
static func quedas(rng: RandomNumberGenerator, meio: Vector3, raio: float, n: int) -> Array[Vector3]:
	var saida: Array[Vector3] = []
	for i in n:
		var a := rng.randf() * TAU
		var r := raio * sqrt(rng.randf())
		saida.append(meio + Vector3(cos(a) * r, 0.0, sin(a) * r))
	return saida


## Velocidade inicial para ir de `de` a `ate` em `t` segundos com a gravidade `g`.
static func arremesso(de: Vector3, ate: Vector3, g: float, t: float) -> Vector3:
	return (ate - de) / t + Vector3.UP * 0.5 * g * t
