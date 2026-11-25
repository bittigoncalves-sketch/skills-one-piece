class_name EscaladaDeMob
extends RefCounted
## SUBIR O RELEVO (08/11/2026, pedido do dono: "os mobs e inimigos não estão subindo pelos terrenos, empacam ao passar de um relevo para o
## outro ao subir"). No relevo em blocos (`RelevoEmBlocos`, bloco = 0,88 m) um CharacterBody3D de cápsula bate na quina do degrau e para:
## só o jogador tinha `SubirDegrau`. Aqui mobs e inimigos ganham o mesmo, como no Minecraft:
##   • degrau de até meio bloco: sobe andando (o `SubirDegrau` do jogador);
##   • bloco inteiro (até `ALTURA_DO_PULO`): pula — impulso vertical que passa por cima, com o passo livre lá em cima;
##   • parede mais alta que isso, ou sem espaço em cima: não faz nada (é obstáculo, quem contorna é a navegação).
## Chamar ANTES do `move_and_slide`, com o `velocity` horizontal já escrito. Só mexe em `velocity.y` (no pulo) e na posição (degrau).

const SubirDegrau := preload("res://src/player/subir_degrau.gd")
## Um bloco inteiro (0,88 m) + folga.
const ALTURA_DO_PULO := 1.05
## m/s vertical. Com a gravidade de 24–32 m/s² dos mobs passa de 1,1 m com folga.
const IMPULSO := 8.5
const RAIO_PADRAO := 0.35
## Desligar só em medição/controle de teste.
static var ligada := true


## Raio da cápsula do corpo (o primeiro CollisionShape3D cápsula/esfera/caixa que achar).
static func raio_de(dono: CharacterBody3D) -> float:
	for filho in dono.get_children():
		if filho is CollisionShape3D and (filho as CollisionShape3D).shape != null:
			var forma := (filho as CollisionShape3D).shape
			if forma is CapsuleShape3D:
				return (forma as CapsuleShape3D).radius
			if forma is SphereShape3D:
				return (forma as SphereShape3D).radius
			if forma is BoxShape3D:
				return minf((forma as BoxShape3D).size.x, (forma as BoxShape3D).size.z) * 0.5
	return RAIO_PADRAO


## `delta` = o tempo que o `move_and_slide` vai andar (quem anda "em dobro" passa o delta já multiplicado).
## true = subiu ou pulou neste quadro.
static func ajudar(dono: CharacterBody3D, delta: float) -> bool:
	if not ligada or dono == null or not dono.is_on_floor() or dono.velocity.y > 0.1:
		return false
	var plano := Vector3(dono.velocity.x, 0.0, dono.velocity.z)
	if plano.length_squared() < 0.04:
		return false
	var raio := raio_de(dono)
	if SubirDegrau.tentar(dono, delta, raio):
		return true
	var passo := plano * delta
	var t := dono.global_transform
	var bate := KinematicCollision3D.new()
	if not dono.test_move(t, passo, bate) or bate.get_normal().y > SubirDegrau.NORMAL_Y_DE_CHAO:
		return false                       # nada à frente, ou é rampa/chão: o `move_and_slide` resolve
	if dono.test_move(t, Vector3.UP * ALTURA_DO_PULO):
		return false                       # sem espaço em cima
	var em_cima := t.translated(Vector3.UP * ALTURA_DO_PULO)
	if dono.test_move(em_cima, passo + plano.normalized() * raio):
		return false                       # a parede é mais alta que um bloco
	dono.velocity.y = IMPULSO
	return true
