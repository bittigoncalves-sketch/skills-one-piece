class_name GomuFX
extends RefCounted
# Geração visual e física procedural da Gomu Gomu no Mi (Borracha / Gear 3rd).
# Os ataques esticam LITERAMENTE os membros (braços e pernas) do próprio modelo 3D do jogador!

const RUBBER_COLOR := Color(0.96, 0.58, 0.45, 0.95)
const IMPACT_GOLD  := Color(1.0, 0.85, 0.35, 0.95)
const AIR_PRESSURE := Color(0.85, 0.92, 1.0, 0.75)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	var body_pos := (caster as Node3D).global_position + Vector3.UP * 1.0 if caster is Node3D else origin
	var fwd := dir.normalized()

	match variant:
		0: _pistol(world, body_pos, fwd, damage, caster)
		1: _bazooka(world, body_pos, fwd, damage, caster)
		2: _gatling(world, body_pos, fwd, damage, caster)
		3: _red_hawk(world, body_pos, fwd, damage, caster)

# ---------- Helper: Encontra nó do rig do jogador pelo nome ----------
static func _find_rig_node(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	if root.name == node_name or root.name.find(node_name) != -1:
		if root is Node3D:
			return root as Node3D
	for child in root.get_children():
		var res := _find_rig_node(child, node_name)
		if res != null:
			return res
	return null

# ---------- Helper: Braço de Borracha caso o nó não seja encontrado ----------
static func _create_rubber_limb(local_start: Vector3, fwd: Vector3, length: float, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(radius * 2.0, radius * 2.0, length)
	mi.mesh = box
	mi.material_override = FxUtil.particle_material(color, 2.5, true)

	var center := local_start + fwd * (length * 0.5)
	var up_ref := Vector3.UP if abs(fwd.y) < 0.95 else Vector3.FORWARD
	var right := fwd.cross(up_ref).normalized()
	var up := right.cross(fwd).normalized()

	mi.transform = Transform3D(Basis(right, up, -fwd), center)
	return mi

# ---------- Z: Gomu Gomu no Pistol — Estica o Braço do Próprio Jogador ----------
static func _pistol(world: Node, body_pos: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	# ELÁSTICO CORRETO: braço cresce só p/ frente a partir do OMBRO FIXO (GomuArm).
	# Nada de scale.z no nó do braço. GomuArm cuida de dano/knockback/partículas/som/
	# speed-lines no impacto e chama a recepção (chicote) quando o punho volta.
	var shoulder := _find_rig_node(caster, "UpperArm_R")
	if shoulder == null:
		shoulder = _find_rig_node(caster, "UpperArm_L")

	if shoulder:
		var on_recover := Callable()
		if caster and caster.has_method("trigger_recovery_anim"):
			on_recover = Callable(caster, "trigger_recovery_anim")
		var arm := GomuArm.new()
		world.add_child(arm)
		arm.setup(world, caster, shoulder, shoulder, fwd, 12.0, 0.22, damage, on_recover)
		return

	# Fallback (sem rig): punho voador simples com dano na ponta.
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = body_pos + fwd * 12.0
	var fist := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.9, 1.3)
	fist.mesh = box
	fist.material_override = FxUtil.particle_material(IMPACT_GOLD, 3.0, true)
	zone.add_child(fist)
	zone.setup(damage, 25.0, fwd * 28.0, 0.6, caster, 1.0)

# ---------- X: Gomu Gomu no Bazooka — Estica Ambos os Braços do Jogador ----------
static func _bazooka(world: Node, body_pos: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	var length := 16.0
	var arm_r := _find_rig_node(caster, "UpperArm_R")
	var arm_l := _find_rig_node(caster, "UpperArm_L")

	if arm_r and arm_l:
		var on_recover := Callable()
		if caster and caster.has_method("trigger_recovery_anim"):
			on_recover = Callable(caster, "trigger_recovery_anim").bind("X")
			
		var gomu_r := GomuArm.new()
		world.add_child(gomu_r)
		gomu_r.setup(world, caster, arm_r, arm_r, fwd, length, 0.28, damage, on_recover, true, 2.2, 1.8)
		
		var gomu_l := GomuArm.new()
		world.add_child(gomu_l)
		gomu_l.setup(world, caster, arm_l, arm_l, fwd, length, 0.28, damage, Callable(), false, 2.2, 1.8)
		
		# Agendamos a explosão de ar comprimido para o exato frame de impacto (EXTEND_TIME = 0.09s)
		world.get_tree().create_timer(0.09).timeout.connect(func():
			if not world or not is_instance_valid(world): return
			var pm := ParticleProcessMaterial.new()
			pm.direction = fwd
			pm.spread = 45.0
			pm.initial_velocity_min = 15.0
			pm.initial_velocity_max = 30.0
			pm.scale_min = 1.0
			pm.scale_max = 3.0
			pm.color_ramp = FxUtil.gradient([IMPACT_GOLD, AIR_PRESSURE, Color(1, 1, 1, 0)])

			var blast := FxUtil.particles(280, 0.6, true, pm, FxUtil.grain(0.8))
			var tip := arm_r.global_position + fwd * length
			# add_child ANTES de posicionar: `global_position` num nó fora da árvore
			# não tem espaço global para resolver, e o Godot devolve Transform3D()
			# com erro. O efeito nascia em (0,0,0) — no CENTRO DO MAPA, não na ponta
			# do braço. Mesmo padrão corrigido em GomuRedHawk.gd.
			world.add_child(blast)
			blast.global_position = tip
			FxUtil.autofree(blast, 0.8)
		)
		return

	# Fallback (sem rig): 
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = body_pos
	
	var up_ref := Vector3.UP if abs(fwd.y) < 0.95 else Vector3.FORWARD
	var right := fwd.cross(up_ref).normalized()
	for side in [-0.5, 0.5]:
		var arm := _create_rubber_limb(right * float(side), fwd, length, 0.4, RUBBER_COLOR)
		zone.add_child(arm)

	# Blast de ar comprimido na ponta dos punhos duplos
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 45.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 22.0
	pm.scale_min = 0.8
	pm.scale_max = 2.4
	pm.color_ramp = FxUtil.gradient([IMPACT_GOLD, AIR_PRESSURE, Color(1, 1, 1, 0)])
	var blast := FxUtil.particles(280, 0.6, true, pm, FxUtil.grain(0.8))
	blast.position = fwd * length
	zone.add_child(blast)

	zone.setup(damage, 45.0, fwd * 36.0, 1.8, caster, 1.4)

# ---------- C: Gomu Gomu no Gatling — Barragem Frenética com os Braços do Jogador ----------
static func _gatling(world: Node, body_pos: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	var arm_r := _find_rig_node(caster, "UpperArm_R")
	var arm_l := _find_rig_node(caster, "UpperArm_L")
	
	if arm_r and arm_l:
		var on_recover := Callable()
		if caster and caster.has_method("trigger_recovery_anim"):
			on_recover = Callable(caster, "trigger_recovery_anim").bind("C")
			
		var gatling = load("res://src/effects/GomuGatling.gd").new()
		world.add_child(gatling)
		gatling.setup(world, caster, arm_r, arm_l, fwd, damage, on_recover)
		return

	# Fallback (sem rig)
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = body_pos

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 50.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 24.0
	pm.scale_min = 0.7
	pm.scale_max = 1.8
	pm.color_ramp = FxUtil.gradient([RUBBER_COLOR, IMPACT_GOLD, Color(1, 0.4, 0.2, 0)])

	var barrage := FxUtil.particles(550, 1.2, true, pm, FxUtil.grain(0.5))
	barrage.position = Vector3.ZERO
	zone.add_child(barrage)

	zone.setup(damage, 30.0, fwd * 20.0, 1.5, caster, 1.8)

# ---------- V: Gomu Gomu no Red Hawk — Ultimate Skill (Teleport + Fire + Plunge) ----------
static func _red_hawk(world: Node, body_pos: Vector3, fwd: Vector3, damage: float, caster: Node) -> void:
	var shoulder := _find_rig_node(caster, "UpperArm_R")
	var on_recover := Callable()
	if caster and caster.has_method("trigger_recovery_anim"):
		on_recover = Callable(caster, "trigger_recovery_anim").bind("V")
		
	# Usa explícito "load" para evitar problemas de cache de classes do Godot em runtime
	var red_hawk = load("res://src/effects/GomuRedHawk.gd").new()
	world.add_child(red_hawk)
	red_hawk.setup(world, caster, shoulder, fwd, damage, on_recover)
