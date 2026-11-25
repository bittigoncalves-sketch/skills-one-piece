extends RefCounted
## SUBIR DEGRAU (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E3). Decisão do dono: no
## relevo em blocos o jogador sobe MEIO BLOCO sozinho, como no Minecraft — meio bloco e
## escada se sobem andando; bloco inteiro (0,88 m) pede pulo. Só no Modo História (quem
## chama é `Player._etapa_mover`, com `colisor_capsula`).
##
## Antes do `move_and_slide`: andando no chão e batendo numa parede, testa o corpo
## ALTURA acima, o passo à frente lá em cima e a descida até o piso. Se tudo cabe e o
## piso é chão (não rampa íngreme), o corpo vai para cima do degrau e o passo horizontal
## deste quadro está dado. Não escreve `velocity`.

## Meio bloco (0,44 m) + folga. Bloco inteiro (0,88 m) não passa.
const ALTURA := 0.5
## Contato com normal mais em pé que isto é chão/rampa, não degrau.
const NORMAL_Y_DE_CHAO := 0.7


## Tenta subir o degrau à frente neste quadro. true = subiu (o passo horizontal foi dado).
## `raio` = raio da cápsula: lá em cima o corpo avança o passo + o raio, para o centro
## ficar SOBRE o degrau — com só o passo do quadro, a cápsula (raio 0,5 m) pousava na
## quina, com o chão inclinado, e escorregava de volta (medido no teste).
static func tentar(dono: CharacterBody3D, delta: float, raio: float) -> bool:
	if not dono.is_on_floor() or dono.velocity.y > 0.1:
		return false
	var passo := Vector3(dono.velocity.x, 0.0, dono.velocity.z) * delta
	if passo.length_squared() < 0.000001:
		return false
	var t := dono.global_transform
	var bate := KinematicCollision3D.new()
	if not dono.test_move(t, passo, bate):
		return false
	if bate.get_normal().y > NORMAL_Y_DE_CHAO:
		return false
	# Espaço em cima (teto) e o passo lá em cima livre (senão a parede é mais alta).
	if dono.test_move(t, Vector3.UP * ALTURA):
		return false
	var em_cima := t.translated(Vector3.UP * ALTURA)
	var avanco := passo + passo.normalized() * raio
	if dono.test_move(em_cima, avanco):
		return false
	var a_frente := em_cima.translated(avanco)
	var piso := KinematicCollision3D.new()
	if not dono.test_move(a_frente, Vector3.DOWN * (ALTURA + 0.05), piso):
		return false                      # sem piso: seria uma queda, não um degrau
	if piso.get_normal().y < NORMAL_Y_DE_CHAO:
		return false
	var subida := ALTURA - piso.get_travel().length()
	if subida < 0.02:
		return false                      # era rampa/borda baixa: o `move_and_slide` resolve
	dono.global_position = a_frente.origin + piso.get_travel()
	return true
