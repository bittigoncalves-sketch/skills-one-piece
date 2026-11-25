extends RefCounted
## Apresentação da Bara: marfim/magenta nas mãos e pólvora quente no canhão.
## Não cria colisores ou dano. O controller possui canhão, bala e aviso de área.

const AUDIO = preload("res://src/effects/BaraAudio.gd")
const CANNON := "res://assets/models/bara_bara/cannon.glb"
const BALL := "res://assets/models/bara_bara/buggy_ball.glb"
const IVORY := Color(1.0, 0.89, 0.70)
const MAGENTA := Color(0.87, 0.14, 0.39)
const POWDER := Color(1.0, 0.40, 0.065)

class Transient extends Node3D:
	var elapsed := 0.0
	var duration := 0.4
	var pieces: Array[Dictionary] = []
	func _process(delta: float) -> void:
		elapsed += delta
		for piece in pieces:
			var mesh := piece.node as MeshInstance3D
			var progress := clampf(elapsed / float(piece.life), 0.0, 1.0)
			mesh.visible = progress < 1.0
			if not mesh.visible:
				continue
			mesh.position = piece.origin + piece.velocity * elapsed
			mesh.position.y -= float(piece.gravity) * elapsed * elapsed * 0.5
			mesh.scale = piece.size * lerpf(1.0, float(piece.expansion), progress)
			var material := mesh.material_override as StandardMaterial3D
			material.albedo_color.a = float(piece.alpha) * (1.0 - progress) * (1.0 - progress)
		if elapsed >= duration:
			queue_free()

class CannonPresentation extends Node3D:
	var barrel: Node3D
	var recoil: Tween
	var barrel_rest := Vector3.ZERO
	func fire() -> void:
		if is_instance_valid(recoil):
			recoil.kill()
		if is_instance_valid(barrel):
			barrel.position = barrel_rest
			recoil = create_tween()
			recoil.tween_property(barrel, "position", barrel_rest + Vector3(0, 0, 0.22), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			recoil.tween_property(barrel, "position", barrel_rest, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func _material(color: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material

static func _mesh(parent: Node3D, shape: Mesh, color: Color, alpha: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = _material(color, alpha)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

static func _piece(effect: Transient, shape: Mesh, color: Color, size: Vector3,
		velocity: Vector3, life: float, expansion: float, alpha: float = 0.85,
		origin: Vector3 = Vector3.ZERO, gravity: float = 0.0) -> MeshInstance3D:
	var mesh := _mesh(effect, shape, color, alpha)
	mesh.scale = size
	mesh.position = origin
	effect.pieces.append({"node": mesh, "origin": origin, "velocity": velocity,
		"life": life, "expansion": expansion, "alpha": alpha, "size": size, "gravity": gravity})
	effect.duration = maxf(effect.duration, life)
	return mesh

static func _sphere() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	return sphere

static func _ring() -> TorusMesh:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.5
	ring.rings = 40
	ring.ring_segments = 8
	return ring

static func _attach(world: Node, effect: Node3D, at: Vector3) -> Node3D:
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion():
		effect.free()
		return null
	world.add_child(effect)
	effect.global_position = at
	return effect

static func impact(world: Node, at: Vector3, explosive: bool = false) -> Node3D:
	var effect := Transient.new()
	effect.name = "BaraBlast" if explosive else "BaraImpact"
	if _attach(world, effect, at) == null:
		return null
	var sphere := _sphere()
	var color := POWDER if explosive else IVORY
	_piece(effect, sphere, color, Vector3.ONE * (0.6 if explosive else 0.15),
		Vector3.ZERO, 0.16, 2.2, 0.8)
	# Thin expanding boundary shows the blast radius without hiding the target.
	_piece(effect, _ring(), color, Vector3.ONE * (0.5 if explosive else 0.18),
		Vector3.ZERO, 0.42 if explosive else 0.24, 14.0 if explosive else 5.0, 0.72)
	var count := 16 if explosive else 7
	for index in count:
		var angle := TAU * float(index) / float(count)
		var outward := Vector3(cos(angle), 0.25 + float(index % 3) * 0.25, sin(angle))
		var velocity := outward * (5.4 if explosive else 1.5)
		var spark := _piece(effect, sphere, color if index % 2 == 0 else MAGENTA,
			Vector3(0.055, 0.17, 0.055), velocity, 0.43 if explosive else 0.26,
			0.2, 0.9, Vector3.ZERO, 5.0)
		spark.quaternion = Quaternion(Vector3.UP, outward.normalized())
	if explosive:
		# Powder disperses into seven small soft-looking volumes; no opaque dome.
		for index in 7:
			var angle := TAU * float(index) / 7.0
			var offset := Vector3(cos(angle), 0.35, sin(angle)) * 0.65
			_piece(effect, sphere, Color(0.18, 0.13, 0.20), Vector3.ONE * 0.65,
				offset * 1.6 + Vector3.UP * 0.5, 0.8, 2.0, 0.26, offset)
	AUDIO.play(world, at, "blast" if explosive else "impact")
	return effect

static func trail(world: Node, from: Vector3, to: Vector3) -> Node3D:
	var distance := from.distance_to(to)
	if distance < 0.025:
		return null
	var effect := Transient.new()
	effect.name = "BaraHandTrail"
	effect.duration = 0.13
	if _attach(world, effect, (from + to) * 0.5) == null:
		return null
	var streak := CylinderMesh.new()
	streak.top_radius = 0.015
	streak.bottom_radius = 0.038
	streak.height = distance
	streak.radial_segments = 8
	var mesh := _piece(effect, streak, IVORY, Vector3.ONE, Vector3.ZERO, 0.13, 0.2, 0.38)
	mesh.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return effect

static func cannon(world: Node, at: Vector3, direction: Vector3) -> Node3D:
	var effect := CannonPresentation.new()
	effect.name = "BaraCannon"
	if _attach(world, effect, at) == null:
		return null
	if ResourceLoader.exists(CANNON):
		var packed := load(CANNON) as PackedScene
		if packed != null:
			var model := packed.instantiate() as Node3D
			effect.add_child(model)
			effect.barrel = model.find_child("Barrel", true, false) as Node3D
			if effect.barrel != null:
				effect.barrel_rest = effect.barrel.position
	var facing := direction.normalized()
	if facing.length_squared() > 0.001:
		effect.global_basis = Basis.looking_at(facing, Vector3.RIGHT if absf(facing.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	return effect

static func fire_cannon(cannon_node: Node3D) -> void:
	if not is_instance_valid(cannon_node):
		return
	if cannon_node.has_method("fire"):
		cannon_node.fire()
	var muzzle := cannon_node.find_child("Muzzle", true, false) as Node3D
	var at := muzzle.global_position if muzzle != null else cannon_node.to_global(Vector3(0, 0.69, -0.90))
	var effect := Transient.new()
	effect.name = "BaraMuzzle"
	effect.duration = 0.16
	if _attach(cannon_node.get_parent(), effect, at) == null:
		return
	var mesh := _piece(effect, _sphere(), IVORY, Vector3(0.3, 0.3, 0.7),
		-cannon_node.global_basis.z * 1.5, 0.14, 1.7, 0.8)
	mesh.global_basis = cannon_node.global_basis.scaled(Vector3(0.3, 0.3, 0.7))

static func ball(world: Node, at: Vector3) -> Node3D:
	var effect := Node3D.new()
	effect.name = "BaraBuggyBall"
	if _attach(world, effect, at) == null:
		return null
	if ResourceLoader.exists(BALL):
		var packed := load(BALL) as PackedScene
		if packed != null:
			effect.add_child(packed.instantiate())
	return effect

static func telegraph(world: Node, at: Vector3, direction: Vector3,
		length: float, width: float) -> Node3D:
	var effect := Node3D.new()
	effect.name = "BaraTrajectoryWarning"
	if _attach(world, effect, at + Vector3.UP * 0.035) == null:
		return null
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat.length_squared() < 0.001:
		flat = Vector3.FORWARD
	effect.global_basis = Basis.looking_at(flat)
	var strip := PlaneMesh.new()
	strip.size = Vector2(maxf(0.01, width), maxf(0.01, length))
	var fill := _mesh(effect, strip, Color(0.94, 0.06, 0.10), 0.16)
	fill.position.z = -length * 0.5
	for side in [-1.0, 1.0]:
		var edge := PlaneMesh.new()
		edge.size = Vector2(0.035, maxf(0.01, length))
		var mesh := _mesh(effect, edge, Color(1.0, 0.16, 0.18), 0.75)
		mesh.position = Vector3(float(side) * width * 0.5, 0.003, -length * 0.5)
	return effect
