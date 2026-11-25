extends RefCounted
## ONDE O GOLPE DA ROCKET VAI CAIR — uma conta só, usada por quem aplica o dano
## (`rocket_controller.gd`) e por quem desenha antes (`src/player/mira_de_fruta.gd`).
##
## Duas contas separadas virariam duas verdades: o indicador mostrando um ponto e a
## explosão saindo em outro. Tudo aqui é estático e puro de estado — recebe o mundo, a
## origem, a direção e o alcance, e devolve pontos.


static func raio(mundo: World3D, de: Vector3, ate: Vector3,
		excluir: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, ate, 15)
	q.exclude = excluir
	return mundo.direct_space_state.intersect_ray(q)


## O chão DE VERDADE: corpo que toma dano não é chão. Sem isso o alvo vira piso e a
## explosão marca a cabeça dele em vez do terreno.
static func solo(mundo: World3D, de: Vector3, ate: Vector3,
		excluir: Array[RID]) -> Dictionary:
	var fora := excluir.duplicate()
	for _i in 16:
		var hit := raio(mundo, de, ate, fora)
		if hit.is_empty():
			return {}
		if hit.collider.has_method("take_damage"):
			fora.append(hit.rid)
		else:
			return hit
	return {}


## O ponto do chão para onde a mira aponta, limitado por `alcance` (o salto do C).
static func ponto_mirado(mundo: World3D, de: Vector3, direcao: Vector3, alcance: float,
		excluir: Array[RID]) -> Vector3:
	var ate := de + direcao * alcance
	var hit := raio(mundo, de, ate, excluir)
	var alvo: Vector3 = hit.position if not hit.is_empty() else ate
	var chao := solo(mundo, alvo + Vector3.UP * 6.0, alvo + Vector3.DOWN * 30.0, excluir)
	return chao.position + chao.normal * 0.05 if not chao.is_empty() else alvo


## Air Strike: quanto duas explosões vizinhas se sobrepõem (fração do diâmetro) e a folga
## entre o corpo e a borda da primeira. Decisão do dono (30/09/2026): explosões
## ENCOSTADAS, logo à frente, sempre na mesma distância — sem depender da mira. Com o
## raio da ficha (2 m) os centros caem a 2,5 / 5,7 / 8,9 m e a faixa cobre de 0,5 a 10,9 m.
const BOMBARDEIO_SOBREPOSICAO := 0.2
const BOMBARDEIO_FOLGA := 0.5


## A distância de cada centro ao corpo. Deriva do RAIO: mexer no raio da ficha mantém as
## explosões encostadas, em vez de reabrir buraco entre elas.
static func distancias_do_bombardeio(raio: float, pontos: int) -> Array[float]:
	var passo: float = 2.0 * raio * (1.0 - BOMBARDEIO_SOBREPOSICAO)
	var saida: Array[float] = []
	for i in pontos:
		saida.append(BOMBARDEIO_FOLGA + raio + passo * float(i))
	return saida


## Os pontos do Air Strike: em LINHA na direção do golpe (só o rumo no plano — a
## distância não vem da mira), do mais perto ao mais longe, cada um pousado no chão por um
## raio de cima.
static func pontos_do_bombardeio(mundo: World3D, posicao: Vector3, direcao: Vector3,
		raio: float, pontos: int, excluir: Array[RID]) -> Array[Vector3]:
	var plano := Vector3(direcao.x, 0.0, direcao.z)
	plano = plano.normalized() if plano.length_squared() > 0.001 else Vector3.FORWARD
	var saida: Array[Vector3] = []
	for d in distancias_do_bombardeio(raio, pontos):
		var alvo := posicao + plano * d
		var chao := solo(mundo, alvo + Vector3.UP * 8.0, alvo + Vector3.DOWN * 20.0, excluir)
		saida.append(chao.position + chao.normal * 0.1 if not chao.is_empty() else alvo)
	return saida


## Onde o foguete do Z para: no primeiro corpo da linha, ou no fim do alcance.
static func fim_do_missil(mundo: World3D, de: Vector3, direcao: Vector3, alcance: float,
		excluir: Array[RID]) -> Vector3:
	var ate := de + direcao * alcance
	var hit := raio(mundo, de, ate, excluir)
	return hit.position if not hit.is_empty() else ate
