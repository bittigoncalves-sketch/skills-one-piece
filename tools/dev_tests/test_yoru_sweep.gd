extends SceneTree
## Física real: consultas de formas e passagem coletiva, sem invocar callbacks
## de contato diretamente. SOP_PORTA pode isolar os autoloads do projeto.

var failures: Array[String] = []
var world: Node3D

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("OK " if condition else "FAIL ") + message)
	if not condition:
		failures.append(message)

func settle() -> void:
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame

func clear_world() -> void:
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
	world = Node3D.new()
	root.add_child(world)

func actor(position: Vector3) -> Dummy:
	var body := Dummy.new()
	world.add_child(body)
	body.position = position
	return body

func blade(body: Dummy, offset := Vector3.ZERO) -> SwordBlade:
	var sword := SwordBlade.new()
	sword.dono = body
	body.add_child(sword)
	sword.position = offset
	return sword

func arm(sword: SwordBlade, id: int = 0) -> void:
	sword.armar(40.0, 0.0, 0.0, id, 0.0)

func wall(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	body.position = position

func run() -> void:
	await clear_world()
	var attacker := actor(Vector3(0, -2, 0))
	var target := actor(Vector3(0, 1.1, 0))
	var sword := blade(attacker, Vector3(0, 2, 0))
	await settle()
	arm(sword, 101)
	await settle()
	check(target.hits == 1 and is_equal_approx(target.damage, 40), "overlap inicial causa um acerto")
	await settle()
	arm(sword, 101)
	await settle()
	check(target.hits == 1, "sete zonas e rearmar a mesma ação não duplicam")
	sword.desarmar()
	arm(sword, 101)
	check(not sword.esta_armada(), "ação cancelada não ressuscita ao repetir armar")
	arm(sword, 102)
	await settle()
	check(target.hits == 2, "nova ação pode acertar o mesmo alvo")

	await clear_world()
	attacker = actor(Vector3(0, -2, 0))
	target = actor(Vector3(0, 1.1, 0))
	sword = blade(attacker, Vector3(-4, 2, 0))
	await settle()
	arm(sword)
	sword.position.x = 4
	await settle()
	check(target.hits == 1, "salto de 8m entre ticks atravessa alvo e acerta")
	sword.desarmar()
	sword.position.x = -4
	await settle()
	check(target.hits == 1, "cancelamento impede dano na trajetória seguinte")

	await clear_world()
	attacker = actor(Vector3(-2, -2, 0))
	target = actor(Vector3(2, 1.1, 0))
	sword = blade(attacker, Vector3(0, 2, 0))
	wall(Vector3(0, 0, 0), Vector3(0.15, 8, 8))
	await settle()
	arm(sword)
	sword.position.x = 4
	await settle()
	check(target.hits == 0, "sweep rápido não causa dano atrás de parede")
	sword.desarmar()
	arm(sword)
	await settle()
	check(target.hits == 0, "overlap inicial atrás de parede também é barrado")

	await clear_world()
	attacker = actor(Vector3(-2, 0, 0))
	target = actor(Vector3(2, 0, 0))
	var a := blade(attacker, Vector3(2, 0, 0))
	var b := blade(target, Vector3(-2, 0, 0))
	var victim := actor(Vector3(0, 1.1, 0))
	await settle()
	arm(a)
	arm(b)
	await settle()
	check(not a.esta_armada() and not b.esta_armada(), "clash desarma ambas atomicamente")
	check(attacker._yoru_combat.cancels == 1 and target._yoru_combat.cancels == 1, "clash cancela uma vez por atacante")
	check(victim.hits == 0, "clash tem prioridade sobre corpo sobreposto no mesmo tick")

	await clear_world()
	attacker = actor(Vector3(-4, -2, 0))
	target = actor(Vector3(4, -2, 0))
	a = blade(attacker, Vector3(0, 2, 0))
	b = blade(target, Vector3(0, 2, 0))
	await settle()
	arm(a)
	arm(b)
	a.position.x = 8
	b.position.x = -8
	await settle()
	check(not a.esta_armada() and not b.esta_armada(), "duas lâminas rápidas se cruzando entre ticks chocam")

	await clear_world()
	attacker = actor(Vector3(-2, 0, 0))
	target = actor(Vector3(2, 0, 0))
	a = blade(attacker, Vector3(2, 0, 0))
	b = blade(target, Vector3(-2, 0, 0))
	await settle()
	arm(a)
	await settle()
	check(a.esta_armada() and attacker._yoru_combat.cancels == 0, "lâmina inativa não gera clash")

	await clear_world()
	attacker = actor(Vector3(0, -2, 0))
	target = actor(Vector3(0, 1.1, 0))
	sword = blade(attacker, Vector3(0, 2, 0))
	target._yoru_combat.parrying = true
	await settle()
	arm(sword)
	await settle()
	check(target.hits == 0 and target._yoru_combat.parries == 1, "aparo confirmado recebe zero dano")
	check(not sword.esta_armada() and attacker._yoru_combat.reason == "parried", "aparo cancela o atacante")
	target._yoru_combat.parrying = false
	target._yoru_combat.multiplier = 0.35
	arm(sword)
	await settle()
	check(target.hits == 1 and is_equal_approx(target.damage, 14), "guarda tardia aplica multiplicador antes do resolver")

	await clear_world()
	attacker = actor(Vector3(0, -2, 0))
	target = actor(Vector3(0, 1.1, 0))
	sword = blade(attacker, Vector3(0, 2, 0))
	await settle()
	var peer := ENetMultiplayerPeer.new()
	var port := int(OS.get_environment("SOP_PORTA")) + 5
	if port < 1024:
		port = 24735
	var err := peer.create_client("127.0.0.1", port)
	check(err == OK, "cliente de teste iniciou")
	get_multiplayer().multiplayer_peer = peer
	arm(sword)
	await settle()
	check(target.hits == 0, "cliente não aplica dano")
	var other := blade(target, Vector3(0, -1.1, 0))
	arm(other)
	await settle()
	check(sword.esta_armada() and other.esta_armada() and attacker._yoru_combat.cancels == 0, "cliente não resolve clash")
	get_multiplayer().multiplayer_peer = null
	peer.close()
	world.queue_free()
	await process_frame
	print("YORU SWEEP: %d falhas" % failures.size())
	quit(0 if failures.is_empty() else 1)

class Guard extends Node:
	var cancels := 0
	var parries := 0
	var parrying := false
	var multiplier := 1.0
	var reason := ""
	func cancel(why: String = "") -> void:
		cancels += 1
		reason = why
	func is_parrying(_origin: Vector3) -> bool:
		return parrying
	func on_parry(_attacker: Node, _position: Vector3) -> void:
		parries += 1
	func guard_multiplier(_origin: Vector3) -> float:
		return multiplier

class Dummy extends CharacterBody3D:
	var _yoru_combat := Guard.new()
	var hits := 0
	var damage := 0.0
	func _ready() -> void:
		add_child(_yoru_combat)
		var shape := SphereShape3D.new()
		shape.radius = 0.3
		var collision := CollisionShape3D.new()
		collision.shape = shape
		add_child(collision)
	func take_damage(amount: float, _origin: Vector3 = Vector3.ZERO,
			_knockback: Vector3 = Vector3.ZERO, _hitstun: float = 0.0) -> void:
		hits += 1
		damage += amount
