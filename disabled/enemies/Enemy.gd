class_name Enemy
extends CharacterBody3D
## Inimigo básico (Fase 7) — Marine grunt voxel. AUTORIDADE DO SERVIDOR: a IA
## (perseguir/atacar), o movimento, o dano e a morte só rodam no servidor; os
## clientes replicam posição/vida/facing (MultiplayerSynchronizer) e só animam.
## Tem take_damage() -> as DamageZone das skills do jogador já o acertam.
## Convenção do projeto: FRENTE = -Z.

const SPEED := 3.6
const GRAVITY := 32.0
const SIGHT := 26.0
const ATTACK_RANGE := 2.4
const ATTACK_DAMAGE := 7.0
const ATTACK_CD := 1.3
const KNOCK_RESIST := 0.6

@export var max_health := 60.0
var health := 60.0
@export var net_facing := 0.0          # replicado p/ os clientes virarem o modelo

# Fase 8: por padrão os inimigos ficam DESATIVADOS (passivos, não atacam) — só
# existem pra serem DOMADOS (botão direito). Domado = segue o dono, vira aliado.
var hostile := false
@export var net_tamed := false
@export var net_owner := 0             # peer id do dono (quando domado)

var _mesh: Node3D
var _attack_t := 0.0
var _dead := false
var _moving := false
var _anim_t := 0.0

func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.5, 0.9)
	col.shape = shape
	add_child(col)
	_build_body()

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	# CONGELADO (Hie Hie): fica IMÓVEL (só gravidade); a IA não roda.
	if has_meta("is_frozen") and get_meta("is_frozen"):
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if (has_meta("in_vortex") and get_meta("in_vortex")) or (has_meta("in_kurouzu") and get_meta("in_kurouzu")) or (has_meta("in_black_hole") and get_meta("in_black_hole")):
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _is_authority():
		_ai(delta)
		move_and_slide()
		if _mesh:
			net_facing = _mesh.rotation.y
		if global_position.y < -40.0:   # jogado PRA FORA DO MAPA pelo knockback = morre
			_die()
			return
	else:
		# cliente: posição vem do sync; só vira pelo facing replicado
		if _mesh:
			_mesh.rotation.y = lerp_angle(_mesh.rotation.y, net_facing, 12.0 * delta)
	_animate(delta)

# ---- IA (só servidor) ----
func _ai(delta: float) -> void:
	_moving = false
	if net_tamed:
		_follow_owner(delta)      # domado: segue o dono como aliado
		return
	if not hostile:
		# DESATIVADO (Fase 8): fica parado, esperando ser domado.
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		return
	var target := _nearest_player()
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var dist := flat.length()
	if dist > SIGHT:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		return
	if dist > ATTACK_RANGE:
		var dir := flat.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_face(dir)
		_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		_face(flat.normalized())
		_attack_t -= delta
		if _attack_t <= 0.0:
			_attack_t = ATTACK_CD
			_attack(target)

func _attack(target: Node) -> void:
	if get_meta("yami_silenced", false) or get_meta("in_kurouzu", false) or get_meta("in_black_hole", false):
		return
	if target.has_method("take_damage"):
		var kb := global_position.direction_to(target.global_position)
		kb.y = 0.0
		kb = kb.normalized() * 6.0 + Vector3.UP * 2.0
		target.take_damage(ATTACK_DAMAGE, global_position, kb)
	if _mesh:                                   # lunge visual do soco
		var tw := create_tween()
		tw.tween_property(_mesh, "position:z", -0.3, 0.08)
		tw.tween_property(_mesh, "position:z", 0.0, 0.16)

# ---- dano/morte (chegam só no servidor: DamageZone é server-gated) ----
func take_damage(amount: float, _from_pos: Vector3 = Vector3.ZERO, knockback: Vector3 = Vector3.ZERO) -> void:
	if _dead or net_tamed or get_meta("damage_immune", false) or get_meta("custom_pose", "") == "hibashira" or get_meta("in_black_hole", false):
		return
	health -= amount
	# Feedback de dano (vale p/ qualquer ser): pisca vermelho, número flutuante e som.
	FxUtil.flash_red(_mesh)
	FxUtil.damage_number(get_tree().current_scene, global_position + Vector3.UP * 1.4, amount, Color(1.0, 0.9, 0.35))
	AudioFX.hurt(get_tree().current_scene, global_position + Vector3.UP * 1.0, 1.15)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_damage_dealt"):
		hud.add_damage_dealt(amount)
	if knockback.length() > 0.1:
		var kb := knockback * KNOCK_RESIST
		if not is_on_floor():
			kb *= 2.0
		velocity += kb
	if health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	_puff(Color(0.5, 0.55, 0.7, 0.9))
	queue_free()   # servidor libera -> o spawner remove nos clientes; Main repõe a contagem

func _nearest_player() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node3D):
			continue
		var d := global_position.distance_to((p as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

func _find_player(peer_id: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node3D and str(p.name).to_int() == peer_id:
			return p as Node3D
	return null

# Fase 8: DOMAR — vira aliado do dono. Servidor chama; o estado (net_tamed/owner)
# replica p/ todos via o MultiplayerSynchronizer do inimigo.
func tame(owner_peer: int) -> void:
	if net_tamed:
		return
	net_tamed = true
	net_owner = owner_peer
	remove_from_group("enemy")     # deixa de ser alvo (tornado/dano/outra doma)
	add_to_group("companion")
	_puff(Color(0.4, 1.0, 0.5, 0.9))   # poof verde de domesticação
	# olhos viram verdes p/ leitura visual
	if _mesh:
		for eye in ["Head/EyeL", "Head/EyeR"]:
			var e := _mesh.get_node_or_null(eye)
			if e and e is MeshInstance3D:
				var m := (e as MeshInstance3D).material_override as StandardMaterial3D
				if m:
					m.albedo_color = Color(0.3, 1.0, 0.4)
					m.emission = Color(0.3, 1.0, 0.4)

func _follow_owner(delta: float) -> void:
	var owner := _find_player(net_owner)
	if owner == null:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		return
	var to := owner.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 3.0:            # mantém distância de acompanhamento
		var dir := flat.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		_face(dir)
		_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

func _face(dir: Vector3) -> void:
	if _mesh and dir.length() > 0.01:
		_mesh.rotation.y = lerp_angle(_mesh.rotation.y, atan2(-dir.x, -dir.z), 12.0 * get_physics_process_delta_time())

# ---- animação leve (bob + inclinação ao andar) ----
func _animate(delta: float) -> void:
	if _mesh == null:
		return
	_anim_t += delta
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.2:
		_mesh.position.y = 0.06 * absf(sin(_anim_t * 9.0))
		_mesh.rotation.x = lerp_angle(_mesh.rotation.x, -0.12, 8.0 * delta)
	else:
		_mesh.position.y = lerpf(_mesh.position.y, 0.0, 6.0 * delta)
		_mesh.rotation.x = lerp_angle(_mesh.rotation.x, 0.0, 6.0 * delta)

# ---- corpo voxel (Marine grunt) — frente (-Z) tem os olhos ----
func _build_body() -> void:
	_mesh = Node3D.new()
	_mesh.name = "Mesh"
	add_child(_mesh)
	var navy := Color(0.16, 0.22, 0.42)
	var white := Color(0.9, 0.9, 0.92)
	var skin := Color(0.86, 0.68, 0.54)
	var red := Color(1.0, 0.15, 0.12)
	_box("Torso", Vector3(0.7, 0.7, 0.4), Vector3(0, 0.25, 0), navy)
	_box("Belt", Vector3(0.72, 0.12, 0.42), Vector3(0, -0.05, 0), white)
	var head := _box("Head", Vector3(0.42, 0.4, 0.4), Vector3(0, 0.82, 0), skin)
	_box("Cap", Vector3(0.5, 0.14, 0.48), Vector3(0, 0.28, 0), navy, head)
	_box("CapBrim", Vector3(0.5, 0.06, 0.16), Vector3(0, 0.2, -0.28), white, head)
	_box("EyeL", Vector3(0.08, 0.08, 0.05), Vector3(-0.1, 0.02, -0.2), red, head, true)
	_box("EyeR", Vector3(0.08, 0.08, 0.05), Vector3(0.1, 0.02, -0.2), red, head, true)
	_box("ArmL", Vector3(0.18, 0.6, 0.18), Vector3(-0.44, 0.28, 0), navy)
	_box("ArmR", Vector3(0.18, 0.6, 0.18), Vector3(0.44, 0.28, 0), navy)
	_box("LegL", Vector3(0.22, 0.55, 0.22), Vector3(-0.17, -0.35, 0), Color(0.1, 0.1, 0.14))
	_box("LegR", Vector3(0.22, 0.55, 0.22), Vector3(0.17, -0.35, 0), Color(0.1, 0.1, 0.14))

func _box(n: String, size: Vector3, pos: Vector3, color: Color, parent: Node3D = null, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.5
	mi.material_override = m
	(parent if parent else _mesh).add_child(mi)
	return mi

func _puff(color: Color) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color_ramp = FxUtil.gradient([color, Color(color.r, color.g, color.b, 0)])
	var burst := FxUtil.particles(60, 0.7, true, pm, FxUtil.grain(0.35), 1.0)
	world.add_child(burst)
	burst.global_position = global_position + Vector3.UP * 0.6
	FxUtil.autofree(burst, 1.0)
