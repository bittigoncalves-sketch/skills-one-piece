class_name GomuRedHawk
extends Node3D

const FIRE_COLOR := Color(1.0, 0.4, 0.05)
const CORE_COLOR := Color(1.0, 0.9, 0.4)
const TRAIL_COLOR := Color(0.8, 0.1, 0.0)

var _world: Node
var _caster: Node3D
var _fwd: Vector3
var _damage: float
var _on_recover: Callable
var _target_pos: Vector3
var _start_pos: Vector3
var _shoulder: Node3D
var _arm_visual: GomuArm

func setup(world: Node, caster: Node3D, shoulder: Node3D, fwd: Vector3, damage: float, on_recover: Callable) -> void:
	_world = world
	_caster = caster
	_fwd = fwd
	_damage = damage
	_on_recover = on_recover
	_shoulder = shoulder
	
	if _caster and _caster.has_method("lock_movement"):
		_caster.lock_movement(0.6, "V")
	
	_start_pos = _caster.global_position
	
	# 1. Target Acquisition
	var target_info = load("res://src/utils/TargetSystem.gd").get_target(world, _start_pos, fwd, 35.0, 45.0)
	var base_target_pos = target_info.position
	
	if target_info.found_enemy:
		# Ligeiramente à frente
		base_target_pos -= _fwd * 1.5
	
	# 2. Seguro Teleport Pos (muito mais alto: 8 a 12 metros acima)
	_target_pos = load("res://src/utils/TargetSystem.gd").get_safe_teleport_pos(world, base_target_pos, randf_range(8.0, 12.0))
	
	# 3. Executa o Blink
	_blink()

func _blink() -> void:
	# Som de deslocamento
	AudioFX.whoosh(_world, _start_pos, 0.8)
	
	# Rastro no ponto de origem
	_spawn_blink_trail(_start_pos, _target_pos)
	
	# Move o jogador
	_caster.global_position = _target_pos
	
	# Gira o jogador para olhar para baixo/alvo
	if _caster.has_method("look_at"):
		pass # Caster geralmente é CharacterBody3D, pode bugar com look_at direto se o eixo Y travar.
	
	# Inicia a descida rapidamente
	get_tree().create_timer(0.05).timeout.connect(_plunge)

func _spawn_blink_trail(from: Vector3, to: Vector3) -> void:
	var dist = from.distance_to(to)
	var dir = (to - from).normalized()
	
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 2.0
	pm.initial_velocity_min = dist * 2.0
	pm.initial_velocity_max = dist * 2.5
	pm.scale_min = 1.0
	pm.scale_max = 2.5
	pm.color_ramp = FxUtil.gradient([TRAIL_COLOR, Color(1,0,0,0)])
	
	var trail := FxUtil.particles(40, 0.4, true, pm, FxUtil.grain(0.8))
	_world.add_child(trail)          # add_child ANTES: global_position fora da árvore erra
	trail.global_position = from
	FxUtil.autofree(trail, 0.5)

func _plunge() -> void:
	var ground_pos = _target_pos
	
	# Raycast para achar o chão exato
	var space_state = _world.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(_target_pos, _target_pos + Vector3.DOWN * 20.0)
	query.collision_mask = 1
	var hit = space_state.intersect_ray(query)
	
	if hit:
		ground_pos = hit.position
	else:
		ground_pos = _target_pos + Vector3.DOWN * 5.0
		
	# Som do fogo
	AudioFX.whoosh(_world, _target_pos, 0.5) # Temporário, ideal é som de chamas
	
	# Instancia o GomuArm apenas visual para o braço de fogo esticado
	if _shoulder:
		_arm_visual = GomuArm.new()
		_world.add_child(_arm_visual)
		var punch_dir = (ground_pos - _shoulder.global_position).normalized()
		var dist = _shoulder.global_position.distance_to(ground_pos)
		
		# Apenas visual. Não aciona on_recover nem hitbox no GomuArm.
		_arm_visual.setup(_world, _caster, _shoulder, _shoulder, punch_dir, dist + 1.5, 0.35, 0.0, Callable(), false)
		
		_attach_fire_to_fist(_arm_visual, punch_dir)

	# Jogador fica paralisado no ar enquanto o braço estica.
	# GomuArm demora EXTEND_TIME (0.09) para chegar na ponta. Vamos dar 0.1s.
	get_tree().create_timer(0.12).timeout.connect(func():
		_impact(ground_pos)
	)

func _attach_fire_to_fist(arm: GomuArm, dir: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = -dir
	pm.spread = 30.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 12.0
	pm.scale_min = 1.0
	pm.scale_max = 2.5
	pm.color_ramp = FxUtil.gradient([CORE_COLOR, FIRE_COLOR, Color(0.2, 0.0, 0.0, 0.0)])
	
	var fire := FxUtil.particles(150, 0.5, false, pm, FxUtil.grain(0.8))
	arm.add_child(fire) # Segue o braço
	
func _impact(pos: Vector3) -> void:
	# O soco acertou o chão. Agora o jogador sai do ar puxado violentamente para a cratera.
	if _caster:
		_caster.global_position = pos
		
	# Hitstop / Camera Shake
	if _world.has_method("camera_shake"):
		_world.camera_shake(1.5, 0.3)
		
	# Audio explosão pesada
	AudioFX.impact(_world, pos, 1.8)
	
	# Limpa o braço
	if is_instance_valid(_arm_visual):
		_arm_visual.queue_free()
	
	if _shoulder: _shoulder.visible = true
	
	# Explosão visual épica
	_spawn_explosion(pos)
	
	# Hitbox radial massiva
	var zone := DamageZone.new()
	_world.add_child(zone)
	zone.global_position = pos
	
	# Usando raio 8.0 para area de efeito
	var shockwave_dir = _fwd # Direção do knockback (para trás)
	zone.setup(_damage * 2.5, 30.0, Vector3.ZERO, 0.2, _caster, 8.0)
	
	# Aplicar queimadura nos inimigos próximos (Fake, adicionamos dano via sinal se tivéssemos, ou script anexado)
	_apply_burn_aoe(pos, 8.0)
	
	if _on_recover.is_valid():
		_on_recover.call()
		
	# Trava de movimento estendida para garantir que fique ajoelhado após o impacto
	if _caster and _caster.has_method("lock_movement"):
		_caster.lock_movement(0.5, "V")
		
	queue_free()

func _spawn_explosion(pos: Vector3) -> void:
	# Flash
	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.light_energy = 15.0
	light.omni_range = 25.0
	_world.add_child(light)
	light.global_position = pos + Vector3.UP * 1.0
	# O tween TEM que nascer na própria luz, não em `self`: este método é chamado
	# de dentro de _impact(), que termina com queue_free() no GomuRedHawk. Um tween
	# criado em `self` morre junto com o nó no fim do frame, o tween_callback nunca
	# roda e a OmniLight3D fica ACESA no mapa para sempre (1 luz por uso do V).
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.4)
	tw.tween_callback(light.queue_free)
	# Rede de segurança: se o tween for interrompido por qualquer motivo, a luz
	# ainda sai de cena. 0.6 > 0.4 do fade, então não corta o efeito.
	FxUtil.autofree(light, 0.6)
	
	# Explosão de chamas
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.0
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 15.0
	pm.initial_velocity_max = 35.0
	pm.scale_min = 1.5
	pm.scale_max = 4.0
	pm.color_ramp = FxUtil.gradient([CORE_COLOR, FIRE_COLOR, Color(0.1, 0.1, 0.1, 0.5), Color(0,0,0,0)])
	
	var exp := FxUtil.particles(400, 1.0, true, pm, FxUtil.grain(0.8))
	_world.add_child(exp)            # add_child ANTES: global_position fora da árvore erra
	exp.global_position = pos
	FxUtil.autofree(exp, 1.2)
	
	# Cratera / Marca no chão (Mesh decal)
	var decal = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(8, 8)
	decal.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.0, 0.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.material_override = mat
	_world.add_child(decal)
	decal.global_position = pos + Vector3.UP * 0.05
	FxUtil.autofree(decal, 5.0)

func _apply_burn_aoe(pos: Vector3, radius: float) -> void:
	var enemies = _world.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not enemy is Node3D or not enemy.has_method("take_damage"): continue
		if enemy == _caster: continue
		var dist = enemy.global_position.distance_to(pos)
		if dist <= radius:
			# Adiciona script de queimadura
			var burn = load("res://src/effects/BurnStatus.gd").new()
			burn.name = "RedHawkBurn"
			enemy.add_child(burn)
			burn.setup(enemy, 3.0, _damage * 0.1)
