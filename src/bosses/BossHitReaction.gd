class_name BossHitReaction
extends RefCounted
## Recepção do corpo a corpo (M1) do jogador. Autoridade do servidor.
##
## Acertos SEGUIDOS do mesmo atacante: o 1º e o 2º paralisam o Boss no lugar, sem
## empurrão; o 3º o arremessa para longe. Depois do voo ele cai de costas e se
## levanta, e só então volta a agir. Golpes que não são M1 seguem o caminho antigo
## (impulso + hitstun) em `BossActor.take_damage`.
##
## A fase fica em `actor.reaction`/`reaction_elapsed`/`reaction_count`, replicados;
## a animação (`BossReactionPose`) só lê esses campos.
const STAGGER := "stagger"
const LAUNCHED := "launched"
const KNOCKDOWN := "knockdown"
const GETUP := "getup"

const LAUNCH_HIT := 3
## Tempo máximo entre dois acertos para contarem como seguidos. Um pouco maior que
## a paralisia: o Boss não tem janela para agir entre golpes de um combo contínuo.
const CHAIN_WINDOW := 1.0
const STAGGER_TIME := 0.9
const LAUNCH_HORIZONTAL := 13.0
const LAUNCH_VERTICAL := 9.0
## Evita ler o chão do quadro do arremesso como pouso.
const MIN_AIR := 0.12
const GROUND_FRICTION := 30.0
const KNOCKDOWN_TIME := 0.9
const GETUP_TIME := 0.7

var _attacker := 0
var _count := 0
var _since_hit := INF

## Voo, chão e levantar não recomeçam por novo acerto: o dano entra, a reação não
## muda. Impede prender o Boss caído num laço de M1.
static func locked(actor: Node) -> bool:
	return actor.reaction in [LAUNCHED, KNOCKDOWN, GETUP]

## `attacker_id` = instance_id do atacante (0 = golpe que não é M1).
## Devolve true quando o golpe é tratado aqui e o impulso original deve ser ignorado.
func receive(actor: CharacterBody3D, attacker_id: int) -> bool:
	if attacker_id == 0:
		return false
	if locked(actor):
		return true
	if attacker_id != _attacker or _since_hit > CHAIN_WINDOW:
		_count = 0
	_attacker = attacker_id
	_count += 1
	_since_hit = 0.0
	var away := actor.global_basis.z
	var attacker := instance_from_id(attacker_id) as Node3D
	if is_instance_valid(attacker):
		var offset := actor.global_position - attacker.global_position
		offset.y = 0
		if offset.length_squared() > 0.0001:
			away = offset.normalized()
	# Encara quem bateu: a reação lê de frente e o voo sai de costas.
	actor.rotation.y = atan2(away.x, away.z)
	actor.reaction_count = _count
	actor.reaction_elapsed = 0.0
	if _count >= LAUNCH_HIT:
		_count = 0
		actor.reaction = LAUNCHED
		actor.velocity = Vector3(away.x * LAUNCH_HORIZONTAL, LAUNCH_VERTICAL, away.z * LAUNCH_HORIZONTAL)
	else:
		actor.reaction = STAGGER
		actor.velocity.x = 0
		actor.velocity.z = 0
	actor.state = actor.reaction
	return true

## Devolve true enquanto a reação controla o corpo. Gravidade e move_and_slide
## continuam com o BossController.
func tick(actor: CharacterBody3D, delta: float) -> bool:
	_since_hit += delta
	if actor.reaction == "" or actor.dead:
		return false
	actor.reaction_elapsed += delta
	actor.combat.cancel("reaction")
	match actor.reaction:
		STAGGER:
			actor.velocity.x = 0
			actor.velocity.z = 0
			if actor.reaction_elapsed >= STAGGER_TIME:
				clear(actor)
				return false
		LAUNCHED:
			if actor.is_on_floor() and actor.reaction_elapsed >= MIN_AIR and actor.velocity.y <= 0:
				_enter(actor, KNOCKDOWN)
		KNOCKDOWN:
			actor.velocity.x = move_toward(actor.velocity.x, 0, GROUND_FRICTION * delta)
			actor.velocity.z = move_toward(actor.velocity.z, 0, GROUND_FRICTION * delta)
			if actor.reaction_elapsed >= KNOCKDOWN_TIME:
				_enter(actor, GETUP)
		GETUP:
			actor.velocity.x = 0
			actor.velocity.z = 0
			if actor.reaction_elapsed >= GETUP_TIME:
				clear(actor)
				return false
	actor.state = actor.reaction
	return true

func clear(actor: Node) -> void:
	actor.reaction = ""
	actor.reaction_elapsed = 0.0
	if not actor.dead:
		actor.state = "guard"

func _enter(actor: Node, phase: String) -> void:
	actor.reaction = phase
	actor.reaction_elapsed = 0.0
