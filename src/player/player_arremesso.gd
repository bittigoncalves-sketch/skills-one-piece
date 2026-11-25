class_name PlayerArremesso
extends RefCounted
## Arremesso com derrubada do JOGADOR (4º soco do Boss): voa de costas, cai
## deitado, levanta. Mesmo desenho da recepção do Boss (`BossHitReaction` +
## `BossReactionPose`), do lado do Player.
##
## ⚠️ QUEM MOVE É O DONO DO CORPO. O servidor chama `Player.receber_arremesso`,
## que dispara `net_arremesso` em TODAS as cópias: o dono aplica a velocidade e
## controla as fases pela própria física; as cópias remotas só animam, lendo o
## `net_on_floor` replicado para saber quando o corpo pousou.
##
## A origem do modelo do Player fica nos PÉS; girar `rotation.x` gira em volta
## deles. Positivo em X leva o topo do corpo para TRÁS (+Z, frente = −Z).
const LAUNCHED := "launched"
const KNOCKDOWN := "knockdown"
const GETUP := "getup"

## Evita ler o chão do quadro do arremesso como pouso.
const MIN_AIR := 0.12
## Teto do voo: um buraco sem fundo termina pela morte, mas nada fica preso.
const MAX_AIR := 3.0
const GROUND_FRICTION := 30.0
const KNOCKDOWN_TIME := 0.9
const GETUP_TIME := 0.7
const LIE_LIFT := 0.12
const ENTER := 30.0
const EXIT := 14.0

var fase := ""
var tempo := 0.0
var _impulso := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _lift := 0.0
## Altura de repouso do modelo (o rig posiciona os pés; não é zero).
var _rest_y := 0.0
## Só restaura a pose que este controlador tomou em `iniciar`. A parede e a
## cambalhota também inclinam o modelo; inclinação sozinha não é arremesso.
var _pose_pendente := false

func ativo() -> bool:
	return fase != ""

## Todas as cópias. `dono` = esta cópia tem a autoridade do corpo.
func iniciar(player: CharacterBody3D, impulso: Vector3, dono: bool, modelo: Node3D) -> void:
	if not _pose_pendente and modelo:
		_rest_y = modelo.position.y
	_pose_pendente = modelo != null
	_impulso = impulso
	fase = LAUNCHED
	tempo = 0.0
	var plano := Vector3(impulso.x, 0.0, impulso.z)
	# Encara quem bateu (costas para o voo): frente do modelo = −Z = −plano.
	_yaw = atan2(plano.x, plano.z) if plano.length_squared() > 0.0001 else player._yaw
	if dono:
		player.velocity = impulso

## Só o dono: fases pela física real e movimento. Chamado no lugar da locomoção.
func tick_dono(player: CharacterBody3D, delta: float) -> void:
	tempo += delta
	if not player.is_on_floor():
		player.velocity.y -= player.GRAVITY * delta
	match fase:
		LAUNCHED:
			if (player.is_on_floor() and tempo >= MIN_AIR and player.velocity.y <= 0.0) or tempo >= MAX_AIR:
				_entrar(KNOCKDOWN)
		KNOCKDOWN:
			_frear(player, delta)
			if tempo >= KNOCKDOWN_TIME:
				_entrar(GETUP)
		GETUP:
			_frear(player, delta)
			if tempo >= GETUP_TIME:
				fase = ""
	player.move_and_slide()

## Cópias remotas: mesmas fases, com o pouso vindo do `net_on_floor` replicado.
func tick_remoto(delta: float, no_chao: bool) -> void:
	tempo += delta
	match fase:
		LAUNCHED:
			if (no_chao and tempo >= MIN_AIR) or tempo >= MAX_AIR:
				_entrar(KNOCKDOWN)
		KNOCKDOWN:
			if tempo >= KNOCKDOWN_TIME:
				_entrar(GETUP)
		GETUP:
			if tempo >= GETUP_TIME:
				fase = ""

## Pose do corpo inteiro. Chamado em toda cópia depois de a orientação normal ser
## escrita; com a fase vazia, solta suavemente de volta ao repouso.
func apresentar(modelo: Node3D, delta: float) -> void:
	if modelo == null or not _pose_pendente:
		return
	var alvo_pitch := 0.0
	var alvo_lift := 0.0
	var rigidez := EXIT
	match fase:
		LAUNCHED:
			alvo_pitch = lerpf(0.35, 1.0, smoothstep(0.0, 0.55, tempo))
			rigidez = ENTER
		KNOCKDOWN:
			var quique := sin(minf(tempo / 0.22, 1.0) * PI) * 0.10
			alvo_pitch = PI * 0.5 - quique
			alvo_lift = LIE_LIFT + quique * 0.05
			rigidez = 32.0
		GETUP:
			var g := smoothstep(0.0, GETUP_TIME, tempo)
			alvo_pitch = PI * 0.5 * (1.0 - g)
			alvo_lift = LIE_LIFT * (1.0 - g)
			rigidez = 24.0
	var k := 1.0 - exp(-rigidez * delta) if delta > 0.0 else 1.0
	_pitch = lerpf(_pitch, alvo_pitch, k)
	_lift = lerpf(_lift, alvo_lift, k)
	if ativo():
		modelo.rotation.y = _yaw
	if ativo() or absf(_pitch) > 0.001 or absf(_lift) > 0.001:
		modelo.rotation.x = _pitch
		modelo.position.y = _rest_y + _lift
	else:
		modelo.rotation.x = 0.0
		modelo.position.y = _rest_y
		_pitch = 0.0
		_lift = 0.0
		_pose_pendente = false

## Pose de membros durante a fase: o tranco de dano no voo; neutro deitado.
func pose_de_membros() -> String:
	return RecepcaoDeDano.POSE if fase == LAUNCHED else ""

## Morte, respawn: nada do arremesso sobrevive.
func cancelar(modelo: Node3D) -> void:
	fase = ""
	tempo = 0.0
	_pitch = 0.0
	_lift = 0.0
	if modelo and _pose_pendente:
		modelo.rotation.x = 0.0
		modelo.position.y = _rest_y
	_pose_pendente = false

func inclinacao() -> float:
	return _pitch

func _entrar(nova: String) -> void:
	fase = nova
	tempo = 0.0

func _frear(player: CharacterBody3D, delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0.0, GROUND_FRICTION * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, GROUND_FRICTION * delta)
