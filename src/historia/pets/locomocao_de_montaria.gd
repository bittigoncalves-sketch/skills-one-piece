extends RefCounted
## LOCOMOÇÃO DA MONTARIA — a conta que move um pet montado, numa fonte só (06/10/2026).
##
## Saiu de `Montaria.conduzir` para os caranguejos rivais da corrida andarem pela MESMA
## física do jogador (corrida justa). Modificadores no próprio corpo, para quem não é o
## condutor influenciar sem conhecer a montaria:
##   • `Lentidao.fator(pet)` — a Noro Noro (e afins) também pega quem está montado;
##   • meta FATOR — lama (< 1) e impulso (> 1) da pista;
##   • meta ATORDOADO — segundos sem obedecer ao comando (trombada em obstáculo). O
##     próprio passo desconta: nada de relógio de parede.
## Empurrão vem de fora somando em `pet.velocity`; a aceleração (16 m/s²) o desfaz.

const FATOR := "locomocao_fator"
const ATORDOADO := "locomocao_atordoado"
const GRAVIDADE := 26.0
const ACELERACAO := 16.0
## Quina que o pet sobe andando. O corpo do caranguejo é um cilindro de FUNDO CHATO:
## subindo uma rampa ele se apoia pela borda da frente, e a quina do deck seguinte, na
## mesma altura (diferença de milímetros), virava parede (medido na corrida, 06/10/2026).
## Degrau de verdade (0,5 m na pista) continua pedindo pulo.
const DEGRAU_MAX := 0.15


## Move `pet` um passo e devolve a velocidade real (o cavaleiro copia). `direcao` no
## plano (comprimento até 1).
static func mover(pet: CharacterBody3D, perfil: Dictionary, direcao: Vector3, correr: bool, saltar: bool, delta: float) -> Vector3:
	var atordoado := float(pet.get_meta(ATORDOADO, 0.0))
	if atordoado > 0.0:
		pet.set_meta(ATORDOADO, maxf(0.0, atordoado - delta))
		direcao = Vector3.ZERO
		saltar = false
	var velocidade: float = perfil["correr"] if correr else perfil["andar"]
	velocidade *= Lentidao.fator(pet) * float(pet.get_meta(FATOR, 1.0))
	var altura: float = perfil["altura"] * pet.global_basis.get_scale().y
	var nivel := AguaDoMundo.nivel_em(pet.global_position.x, pet.global_position.z)
	var submerso := 0.0 if is_nan(nivel) else clampf((nivel - pet.global_position.y) / altura, 0, 1)
	if submerso > .65:
		velocidade *= .55
		pet.velocity.y = clampf((nivel - altura * .6 - pet.global_position.y) * 3.0, -2.5, 2.5)
	else:
		velocidade *= AguaDoMundo.fator_de_andar(submerso)
		# Subindo por empurrão (obstáculo), o chão não zera o impulso: a gravidade cuida.
		if pet.is_on_floor() and pet.velocity.y <= 0.5:
			pet.velocity.y = -0.5
		else:
			pet.velocity.y = maxf(-25, pet.velocity.y - GRAVIDADE * delta)
		if saltar and pet.is_on_floor():
			pet.velocity.y = perfil["salto"]
	var desejada := Vector3(direcao.x, 0, direcao.z).limit_length() * velocidade
	pet.velocity.x = move_toward(pet.velocity.x, desejada.x, delta * ACELERACAO)
	pet.velocity.z = move_toward(pet.velocity.z, desejada.z, delta * ACELERACAO)
	pet.move_and_slide()
	if pet.is_on_wall() and desejada.length() > 0.5 and pet.velocity.y <= 0.5:
		_subir_degrau(pet, desejada * delta)
	var real := pet.get_real_velocity()
	var visual := visual_de(pet, perfil)
	var rapidez := Vector2(real.x, real.z).length()
	if rapidez > .08:
		var yaw: float = atan2(-real.x, -real.z) + float(perfil["desvio_yaw"])
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, 1 - exp(-8 * delta))
		if not perfil["largo"]:
			pet.set("_yaw", visual.rotation.y - float(perfil["desvio_yaw"]))
	var local := visual.global_basis.inverse() * real
	if perfil["largo"]:
		pet.animador.animar(delta, local, pet.is_on_floor(), pet.velocity.y)
	else:
		pet.animador.animar(delta, local, perfil["andar"], perfil["correr"], "correndo" if correr and rapidez > .1 else ("andando" if rapidez > .1 else "parado"), 0.0)
	return real


## O nó que se vira e se anima (o caranguejo grande guarda em `visual`; os domados, em `_visual`).
static func visual_de(pet: Node3D, perfil: Dictionary) -> Node3D:
	return pet.get("visual") if perfil["largo"] else pet.get("_visual")


## Sobe uma quina baixa: só se couber subir, andar por cima e houver chão firme logo
## adiante (nunca sobe para o vazio nem atravessa parede).
static func _subir_degrau(pet: CharacterBody3D, passo: Vector3) -> void:
	var anda := passo.normalized() * maxf(passo.length(), 0.06)
	var t := pet.global_transform
	if pet.test_move(t, Vector3.UP * DEGRAU_MAX):
		return
	t.origin += Vector3.UP * DEGRAU_MAX
	if pet.test_move(t, anda):
		return
	t.origin += anda
	var chao := KinematicCollision3D.new()
	if not pet.test_move(t, Vector3.DOWN * (DEGRAU_MAX + 0.05), chao) or chao.get_normal().y < 0.7:
		return
	pet.global_position = t.origin + chao.get_travel()
