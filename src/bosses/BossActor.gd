class_name BossActor
extends CharacterBody3D
signal died(actor_id: int)
signal health_changed(current: float, maximum: float)
var definition: BossDefinition
var actor_id := 10001
var encounter_id := 1
var health := -1.0
var dead := false
var state := "idle"
var action_id := ""
var action_elapsed := 0.0
var action_sequence := 0
var combo_index := -1
var part_state := "attached"
var part_transform := Transform3D.IDENTITY
## Recepção de M1 (BossHitReaction): fase, tempo na fase e nº do acerto seguido.
var reaction := ""
var reaction_elapsed := 0.0
var reaction_count := 0
## Mobilidade (BossMobility): "", "dash" ou "jump"; replicado para a pose no cliente.
var mobility := ""
var mobility_elapsed := 0.0
var jumps_used := 0
var dash_direction := Vector3.ZERO
var sensor: BossProjectileSensor
var net_velocity := Vector3.ZERO
var home_position := Vector3.ZERO
var controller := BossController.new()
var combat: BossCombat
var presentation: BossVisual
var _collision: CollisionShape3D
var _death_emitted := false
var _last_health := -1.0

func _ready() -> void:
	if definition == null or not definition.valid():
		push_error("Boss sem definição válida")
		set_physics_process(false)
		return
	add_to_group("enemy")
	add_to_group("boss")
	home_position = global_position
	if health < 0:
		health = definition.max_health
	_collision = CollisionShape3D.new()
	# Cápsula, não caixa: a caixa girava com o Boss e a diagonal (~0,78 m) mudava a
	# distância de contato com a rotação. A cápsula encosta igual em qualquer ângulo.
	# (Não era a causa dos socos errando — ver BossCombat.step_velocity.)
	var shape := CapsuleShape3D.new()
	shape.radius = definition.width * 0.5
	shape.height = definition.height
	_collision.shape = shape
	add_child(_collision)
	presentation = BossVisual.new()
	add_child(presentation)
	presentation.setup(self)
	combat = BossCombat.new()
	add_child(combat)
	combat.setup(self)
	sensor = BossProjectileSensor.new()
	add_child(sensor)
	sensor.setup(self)

## Contrato lido por golpes de corpo a corpo com impulsos extras (lançamento,
## counter, sustento): o Boss resolve o M1 em BossHitReaction e dispensa esses extras.
func reage_ao_corpo_a_corpo() -> bool:
	return true

func authoritative() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _physics_process(delta: float) -> void:
	if authoritative() and not dead:
		controller.tick(self, delta)
		combat.tick(delta)
		combat.detached.tick(delta)
		net_velocity = velocity
	presentation.present(delta)
	if dead and not _death_emitted:
		_death_emitted = true
		_collision.set_deferred("disabled", true)
		remove_from_group("enemy")
		died.emit(actor_id)
	if health != _last_health:
		# Vida replicada: a queda aparece em toda cópia, então o flash também.
		if health < _last_health and _last_health >= 0 and not dead and is_instance_valid(presentation):
			FxUtil.flash_dano(presentation.model)
		_last_health = health
		health_changed.emit(health, definition.max_health)

## Esquiva com dash contra a Buki Buki (22/11/2026). O Boss JÁ tinha dash esquivo (`BossMobility`, recarga 3 s) acionado pelo sensor de projétil;
## este aviso usa o MESMO dash e a MESMA recarga (a da `BossMobility`), então não há segunda esquiva por cima. Só a cópia autoritativa decide.
func esquivar_de_disparo(rumo: Vector3, _chegada_em := 0.0) -> bool:
	if not authoritative() or dead or controller.stun_remaining > 0.0 or mobility != "" or not is_on_floor():
		return false
	if controller.mobility.dash_cooldown > 0.0:
		return false
	var jogador := get_tree().get_first_node_in_group("player") as Node3D
	var ponto := jogador.global_position if jogador != null else global_position - rumo
	var lado := BossMobility.dodge_direction(self, {"velocity": rumo, "point": ponto})
	if lado == Vector3.ZERO:
		return false
	controller.mobility.start_dash(self, lado)
	return true


func take_damage(amount: float, _origin: Vector3 = Vector3.ZERO, impulse: Vector3 = Vector3.ZERO, hitstun: float = 0.0) -> void:
	if not authoritative() or dead or not is_finite(amount) or amount < 0:
		return
	if get_meta("damage_immune", false) or get_meta("in_black_hole", false):
		return
	amount = VidaEmBarras.filtrar(self, amount, health, definition.max_health)   # chefe: 10 barras (10/11/2026)
	health = maxf(0, health - amount)
	# M1 do jogador: paralisa ou arremessa em vez de empurrar (BossHitReaction).
	var melee: bool = health > 0 and controller.reaction.receive(self, int(get_meta(CombatResolver.META_CORPO_A_CORPO, 0)))
	if amount > 0 or hitstun > 0:
		combat.cancel("damage")
		if not melee:
			controller.stun_remaining = maxf(controller.stun_remaining, clampf(hitstun, 0.15, 3.0))
			RecepcaoDeDano.aplicar(self)
	if impulse.is_finite() and not melee:
		velocity += impulse.limit_length(30)
	if health <= 0:
		dead = true
		controller.reaction.clear(self)
		controller.mobility.cancel(self)
		state = "dead"
		velocity = Vector3.ZERO
		net_velocity = Vector3.ZERO
		combat.cancel("death")

func _exit_tree() -> void:
	if is_instance_valid(combat):
		combat.cancel("despawn")
