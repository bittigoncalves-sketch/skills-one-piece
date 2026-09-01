class_name FirefliesFX
extends Node

# Controla o spawn e a reação em cadeia dos vagalumes de fogo

static func cast_fireflies(world: Node, origin: Vector3, damage: float, caster: Node, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	
	var controller = FirefliesController.new(caster, damage, spec)
	world.add_child(controller)
	controller.global_position = origin + Vector3.UP * 1.5

class FirefliesController extends Node3D:
	# O C é controle de espaço: 15 brasas preservam a ameaça visual sem encher a
	# arena com 45 hitboxes concorrentes. É exatamente 1/3 da versão anterior.
	const QUANTIDADE_VAGALUMES := 15
	var caster: Node
	var damage: float
	var spec: DamageSpec
	var fireflies: Array = []
	var triggered: bool = false
	
	func _init(c: Node, d: float, s: DamageSpec) -> void:
		caster = c
		damage = d
		spec = s
		
	func _ready() -> void:
		for i in range(QUANTIDADE_VAGALUMES):
			var f = FireflyNode.new(self)
			add_child(f)
			# Posições aleatórias ao redor do jogador
			f.position = Vector3(randf_range(-8.0, 8.0), randf_range(-0.5, 2.0), randf_range(-8.0, 8.0))
			fireflies.append(f)
			
		# Autodestruição da habilidade caso não acerte em 20 segundos
		var t = Timer.new()
		t.wait_time = 20.0
		t.one_shot = true
		t.timeout.connect(func(): if not triggered: trigger_chain_reaction(null))
		add_child(t)
		t.start()

	var target: Node = null
	
	func trigger_chain_reaction(t: Node) -> void:
		if triggered: return
		triggered = true
		target = t
		
		var t2 = Timer.new()
		t2.wait_time = 2.0
		t2.one_shot = true
		t2.timeout.connect(_force_explode_all)
		add_child(t2)
		t2.start()
		
	func _force_explode_all() -> void:
		for i in range(fireflies.size()):
			var f = fireflies[i]
			if is_instance_valid(f) and not f.exploding:
				f.trigger(i * 0.05)
				
		var t2 = Timer.new()
		t2.wait_time = 3.0
		t2.one_shot = true
		t2.timeout.connect(queue_free)
		add_child(t2)
		t2.start()

	var drift_target: Node3D = null
	var time_since_scan: float = 0.0

	func _process(delta: float) -> void:
		if triggered: return
		time_since_scan += delta
		if time_since_scan > 0.5:
			time_since_scan = 0.0
			_scan_for_drift_target()

	func _scan_for_drift_target() -> void:
		var candidates = get_tree().get_nodes_in_group("enemy")
		candidates.append_array(get_tree().get_nodes_in_group("player"))
		candidates.append_array(get_tree().get_nodes_in_group("enemies"))
		
		var nearest: Node3D = null
		var min_dist: float = 20.0
		for c in candidates:
			if c == caster or not is_instance_valid(c): continue
			if not (c is Node3D): continue
			if c.has_method("take_damage") or (c.owner and c.owner.has_method("take_damage")):
				var dist = global_position.distance_to(c.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest = c
		drift_target = nearest

class FireflyNode extends Area3D:
	var controller: FirefliesController
	var time_passed: float = 0.0
	var offset: Vector3
	var exploding: bool = false
	var mesh_inst: MeshInstance3D
	var light: OmniLight3D
	
	func _init(ctrl: FirefliesController) -> void:
		controller = ctrl
		
	func _ready() -> void:
		offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		time_passed = randf() * 10.0
		
		# Colisão
		var col = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 2.5
		col.shape = shape
		add_child(col)
		
		# Visual
		mesh_inst = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.3, 0.3, 0.3)
		mesh_inst.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# A cor é escrita a cada quadro no `_process` (ver a nota lá).
		mesh_inst.material_override = mat
		add_child(mesh_inst)
		
		# Luz
		light = OmniLight3D.new()
		light.omni_range = 3.0
		add_child(light)
		
		# Conectar sinal de body entered para trigger
		# Para o Hitbox ser detectado, ou player, precisamos lidar com Area ou PhysicsBody
		body_entered.connect(_on_entered)
		area_entered.connect(_on_entered)
		
	func _on_entered(node: Node) -> void:
		if exploding: return
		# Ignorar o próprio caster
		if node == controller.caster or node.owner == controller.caster: return
		# Ignorar coisas estáticas de mundo se possível, checamos se é um corpo vivo
		var is_enemy = false
		if node.has_method("take_damage") or (node.owner and node.owner.has_method("take_damage")):
			is_enemy = true
		elif node.name.find("Player") != -1 or node.name.find("Enemy") != -1:
			is_enemy = true
			
		if is_enemy:
			if not controller.triggered:
				controller.trigger_chain_reaction(node)
			trigger(0.0)

	func _process(delta: float) -> void:
		if exploding: return
		time_passed += delta
		
		if controller.triggered and is_instance_valid(controller.target):
			var t_pos = controller.target.global_position if "global_position" in controller.target else controller.target.position
			if controller.target is Node3D:
				t_pos += Vector3.UP * 1.0 # Mirar no centro do corpo
			var dir = (t_pos - global_position).normalized()
			global_position += dir * 20.0 * delta
		else:
			# Movimento errático estilo vagalume
			var drift = Vector3.ZERO
			if is_instance_valid(controller.drift_target):
				var d_pos = controller.drift_target.global_position + Vector3.UP * 1.0
				drift = (d_pos - global_position).normalized() * 4.5
				
			position += (offset * sin(time_passed * 2.0) * 1.5 + drift) * delta
			position.y += cos(time_passed * 1.5) * delta * 1.5
		
		# ⚠️ A COR PERCORRE A RODA DE MATIZ INTEIRA — e o golpe se chama
		# "Vagalumes de FOGO". `Color.from_hsv(fmod(t * 0.5, 1), 1, 1)` passa por
		# verde, ciano, azul e roxo; em tela os vagalumes saem como cubos
		# ARCO-ÍRIS, não como brasas. Está registrado em
		# `docs/LISTA_DE_CORRECOES.md` — é decisão de arte do dono, não conserto
		# meu, então a linha fica como está.
		var c = Color.from_hsv(fmod(time_passed * 0.5, 1.0), 1.0, 1.0)
		if mesh_inst and mesh_inst.material_override:
			var mat = mesh_inst.material_override as StandardMaterial3D
			# Brilho pelo ALBEDO: o material é unshaded e descarta emissão.
			# Ver `FxUtil.brilho()`.
			mat.albedo_color = FxUtil.brilho(c, 3.0)
		if light:
			light.light_color = c

	func trigger(delay: float) -> void:
		exploding = true
		var t = Timer.new()
		t.wait_time = delay + 0.01
		t.one_shot = true
		t.timeout.connect(_explode)
		add_child(t)
		t.start()
		
	func _explode() -> void:
		if not is_inside_tree(): return
		var zone = DamageZone.new()
		get_parent().add_child(zone)
		zone.global_position = global_position
		
		# Utiliza partículas de fogo do sistema já existente se FireFX estiver disponível
		if Engine.has_singleton("FireFX") or load("res://src/effects/FireFX.gd"):
			var FireFX = load("res://src/effects/FireFX.gd")
			var pm = FireFX._flame_proc(Vector3.UP, 180.0, 3.0, 8.0, Vector3(0, 1.0, 0), 0.5, 1.5, 1.5)
			var fire = FxUtil.particles(100, 0.8, true, pm, FxUtil.grain(0.8), 0.85)
			fire.material_override = FxUtil.particle_material(Color(1, 0.4, 0.1), 4.0, true)
			zone.add_child(fire)
		
		# A explosão aplica uma fração do dano total, ou o total, dependendo do balanceamento
		# Como o dano é UNICO e a spec marca o zone, se um inimigo for pego por várias zonas
		# o DamageSpec garante que ele receba dano baseado no teto.
		zone.setup(controller.damage, 6.0, Vector3.ZERO, 0.8, controller.caster, 8.0)
		if controller.spec:
			controller.spec.marcar(zone)
			
		AudioFX.impact(get_tree().current_scene, global_position, 0.5)
		
		queue_free()
