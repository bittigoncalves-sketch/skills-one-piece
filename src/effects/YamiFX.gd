class_name YamiFX
extends RefCounted
# Geração visual e mecânica procedural da Yami Yami no Mi (Trevas / Gravidade Abissal).
# Habilidades reformuladas: Disparo de Pistola (Z), Espiral Negra (X), Black Hole (C) e Liberation (V).

const DARK_PURPLE  := Color(0.18, 0.08, 0.28, 0.95)
const VOID_BLACK   := Color(0.04, 0.02, 0.06, 1.0)
const GLOW_VIOLET  := Color(0.65, 0.25, 0.95, 0.85)
const CONCRETE_GRY := Color(0.42, 0.44, 0.48, 1.0)
const LIB_CYAN     := Color(0.20, 0.75, 1.00, 0.90)
const LIB_BLUE     := Color(0.10, 0.45, 0.95, 0.85)
const LIB_WHITE    := Color(0.95, 0.98, 1.00, 1.00)

# Limites de otimização de performance do abismo
const MAX_ABSORBED_BLOCKS := 30 # Máximo de blocos armazenados na escuridão
const MAX_SPAWN_PER_CAST := 25  # Limite máximo de blocos gerados por conjuração no Liberation
const MAX_SCENE_BLOCKS    := 35 # Limite máximo simultâneo de blocos na cena inteira (evita queda de FPS)

# ---- Calibragem das hitboxes (raio/vida casados com o que aparece na tela) ----
const KUROUZU_DURATION  := 3.2   # trava do conjurador == vida da hitbox do vórtice
const KUROUZU_RADIUS    := 1.9   # esfera do vórtice (0.9) + anéis de acréscimo (até 1.8)
const LIBERATION_RADIUS := 25.0  # alcance do repelão — o mesmo da varredura manual antiga
const DEBRIS_LIFETIME   := 6.0   # escombro caído some sozinho se o Black Hole não absorver

static var _shared_block_mesh: BoxMesh = null
static var _shared_block_mat: StandardMaterial3D = null

static func get_shared_block_mesh() -> BoxMesh:
	if _shared_block_mesh == null:
		_shared_block_mesh = BoxMesh.new()
		_shared_block_mesh.size = Vector3(1.0, 1.0, 1.0)
	return _shared_block_mesh

static func get_shared_block_mat() -> StandardMaterial3D:
	if _shared_block_mat == null:
		_shared_block_mat = StandardMaterial3D.new()
		_shared_block_mat.albedo_color = CONCRETE_GRY
		_shared_block_mat.roughness = 0.9
	return _shared_block_mat

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _pistol_shot(world, origin, dir, damage, caster, spec)
		1: _kurouzu(world, origin, dir, damage, caster, spec)
		2: _black_hole(world, origin, damage, caster, spec)
		_: _liberation(world, origin, dir, damage, caster, spec)

# ---------- Z: Disparo de Pistola (Tiro de Trevas) ----------
# Chamado tanto no clique esquerdo com a pistola empunhada quanto na execução do slot Z.
static func _pistol_shot(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	bullet(world, origin, dir, damage, caster, spec)

static func bullet(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	var fwd: Vector3 = dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	if fwd != Vector3.ZERO:
		zone.look_at(origin + fwd, Vector3.UP)

	# Efeito de clarão de disparo (Muzzle Flash) e faísca de pólvora na saída do cano
	var flash_pm := ParticleProcessMaterial.new()
	flash_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	flash_pm.emission_sphere_radius = 0.15
	flash_pm.direction = fwd
	flash_pm.spread = 35.0
	flash_pm.initial_velocity_min = 3.0
	flash_pm.initial_velocity_max = 8.0
	flash_pm.scale_min = 0.3
	flash_pm.scale_max = 0.6
	flash_pm.color_ramp = FxUtil.gradient([Color(1.0, 0.9, 0.4, 1.0), Color(0.9, 0.4, 0.1, 0.8), Color(0.5, 0.5, 0.5, 0.3), Color(0, 0, 0, 0)])
	var muzzle := FxUtil.particles(35, 0.25, true, flash_pm, FxUtil.grain(0.45))
	var muzzle_root := Node3D.new()
	muzzle_root.position = origin
	muzzle_root.add_child(muzzle)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 4.0
	light.omni_range = 5.0
	muzzle_root.add_child(light)
	world.add_child(muzzle_root)
	var tw_l := world.create_tween()
	tw_l.tween_property(light, "light_energy", 0.0, 0.08)
	tw_l.tween_interval(0.2)
	tw_l.tween_callback(muzzle_root.queue_free)

	# Projétil: LITERALMENTE bala de arma de fogo (metal latão/chumbo extremamente rápida)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.04
	cap.height = 0.35
	body.mesh = cap
	body.rotation_degrees.x = 90
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.78, 0.3, 1.0) # Latão / Chumbo polido
	m.metallic = 0.9
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.35)
	m.emission_energy_multiplier = 3.0           # Efeito traçante (tracer) de tiro real
	body.material_override = m
	zone.add_child(body)

	# Rastro fino de fumaça clara de pólvora
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1) # para trás em espaço local
	pm.spread = 5.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.scale_min = 0.15
	pm.scale_max = 0.45
	pm.color_ramp = FxUtil.gradient([Color(0.85, 0.85, 0.85, 0.6), Color(0.6, 0.6, 0.6, 0.3), Color(0.4, 0.4, 0.4, 0.0)])
	zone.add_child(FxUtil.particles(20, 0.25, false, pm, FxUtil.grain(0.3)))

	AudioFX.gunshot(world, origin, randf_range(0.95, 1.05)) # Som nítido de disparo de pistola
	zone.setup(damage, 12.0, fwd * 105.0, 0.5, caster, 0.3) # Bala de arma de fogo de altíssima velocidade
	if spec != null:
		spec.marcar(zone)

# ---------- X: Espiral Negra / Kurouzu ----------
static func _kurouzu(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd := dir.normalized()
	if caster and caster is CharacterBody3D:
		caster.set_meta("custom_pose", "kurouzu")
		# Congelamento agora depende de `cast_controller`. Não forçamos lock_movement temporal.

	# Mini buraco negro (VOID_BLACK minúsculo) focado na palma da mão
	var vortex_root := Node3D.new()
	world.add_child(vortex_root)
	var palm_pos: Vector3
	if caster.has_method("get_right_hand_position"):
		palm_pos = caster.get_right_hand_position()
	else:
		palm_pos = origin + fwd * 1.2
	vortex_root.global_position = palm_pos

	# Carrega o modelo 3D do buraco negro
	var glb_scene: PackedScene = load("res://assets/models/yami_blackhole.glb")
	var r1: MeshInstance3D = null
	var r2: MeshInstance3D = null
	
	if glb_scene:
		var glb_inst = glb_scene.instantiate()
		glb_inst.scale = Vector3(0.2, 0.2, 0.2) # Escala do asset na mão
		
		# Aplica os materiais designados pelos Agentes
		var mat_void := StandardMaterial3D.new()
		mat_void.albedo_color = VOID_BLACK
		mat_void.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		var mat_disk := StandardMaterial3D.new()
		mat_disk.albedo_color = DARK_PURPLE
		mat_disk.emission_enabled = true
		mat_disk.emission = GLOW_VIOLET
		mat_disk.emission_energy_multiplier = 4.0
		mat_disk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_disk.albedo_color.a = 0.8
		mat_disk.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		var mat_aura := StandardMaterial3D.new()
		mat_aura.albedo_color = GLOW_VIOLET
		mat_aura.emission_enabled = true
		mat_aura.emission = GLOW_VIOLET
		mat_aura.emission_energy_multiplier = 1.5
		mat_aura.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_aura.albedo_color.a = 0.3
		mat_aura.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		var mat_ring := StandardMaterial3D.new()
		mat_ring.albedo_color = Color(0.8, 0.4, 1.0, 1.0)
		mat_ring.emission_enabled = true
		mat_ring.emission = Color(0.9, 0.6, 1.0, 1.0)
		mat_ring.emission_energy_multiplier = 8.0
		mat_ring.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		for child in glb_inst.get_children():
			if child is MeshInstance3D:
				if "Singularity" in child.name:
					child.material_override = mat_void
				elif "Disk" in child.name:
					child.material_override = mat_disk
				elif "Aura" in child.name:
					child.material_override = mat_aura
				elif "Ring" in child.name:
					child.material_override = mat_ring
					if "1" in child.name: r1 = child as MeshInstance3D
					if "2" in child.name: r2 = child as MeshInstance3D
		
		vortex_root.add_child(glb_inst)
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		var sphere_inst := MeshInstance3D.new()
		sphere_inst.mesh = sm
		sphere_inst.material_override = FxUtil.particle_material(VOID_BLACK, 6.0, true)
		vortex_root.add_child(sphere_inst)

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 45.0
	pm.initial_velocity_min = -4.0
	pm.initial_velocity_max = -8.0 
	pm.scale_min = 0.1
	pm.scale_max = 0.4 
	pm.color_ramp = FxUtil.gradient([GLOW_VIOLET, DARK_PURPLE, VOID_BLACK])
	vortex_root.add_child(FxUtil.particles(40, 0.4, true, pm, FxUtil.grain(0.5)))

	AudioFX.whoosh(world, palm_pos, 0.6)

	# HITBOX — a espiral tritura quem ENCOSTA nela, não só quem ela agarra.
	# Antes deste ponto o golpe não criava DamageZone nenhuma: todo o dano do
	# Kurouzu era `target.take_damage()` direto, lá no fim do KurouzuController,
	# e só saía se `_find_closest_entity` tivesse achado alguém. Sem alvo o golpe
	# era 100% enfeite, e mesmo com alvo ninguém MAIS podia ser atingido.
	# A zona é filha do vortex_root: o controlador move o vórtice para a palma da
	# mão a cada frame e a hitbox acompanha de graça.
	# Knockback baixo de propósito (6.0): este golpe PUXA. Quem arremessa é o
	# clique de release, com knockback 45.
	var vortex_zone := DamageZone.new()
	vortex_root.add_child(vortex_zone)
	vortex_zone.setup(spec.dano, 6.0, Vector3.ZERO, KUROUZU_DURATION, caster, KUROUZU_RADIUS)
	spec.marcar(vortex_zone)

	var target := _find_closest_entity(world, caster, origin, 28.0)
	if target:
		print("🌑 ESPIRAL NEGRA (Kurouzu)! ", target.name, " atraído para a mão do usuário e com poderes/ataques negados!")
		target.set_meta("in_kurouzu", true)
		StatusFX.aplicar(target, StatusFX.SUGADO, 3.2)
		target.set_meta("yami_silenced", true)
		if target.has_method("suppress_skills_temporarily"):
			target.suppress_skills_temporarily(4.0)

	var ctrl := KurouzuController.new(caster, target, fwd, damage, vortex_root, r1, r2, spec)
	world.add_child(ctrl)

# ---------- C: Black Hole ----------
static func _black_hole(world: Node, origin: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	if caster and caster is CharacterBody3D:
		caster.set_meta("custom_pose", "black_hole")
		caster.set_meta("yami_black_hole_active", true)
		if caster.has_method("lock_movement"):
			caster.lock_movement(7.0, "black_hole")

	# O BURACO NEGRO NASCE NOS PÉS DO JOGADOR (pedido do dono, 2026-08-12).
	#
	# ⚠️ O raycast que procura o chão NÃO EXCLUÍA O PRÓPRIO CASTER. Ele parte de
	# 3 m acima do CENTRO do corpo e desce — então a primeira coisa que acertava
	# era o colisor do próprio jogador (1,6 m de altura, topo em +0,8 do centro).
	# Resultado: `hit_y` virava o TOPO DA CABEÇA e o vórtice abria a ~1,78 m
	# acima dos pés, flutuando na altura do rosto.
	#
	# Com a exclusão, o raio passa direto pelo corpo e encontra o piso de fato.
	var ground_pos: Vector3 = origin
	if is_instance_valid(caster) and caster is Node3D:
		ground_pos = caster.global_position
	var hit_y: float = ground_pos.y
	if world.get_viewport() and world.get_viewport().world_3d:
		var space_state := world.get_viewport().world_3d.direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			ground_pos + Vector3(0, 3.0, 0), ground_pos - Vector3(0, 10.0, 0))
		if is_instance_valid(caster) and caster is CollisionObject3D:
			query.exclude = [(caster as CollisionObject3D).get_rid()]
		var hit := space_state.intersect_ray(query)
		if hit and hit.has("position"):
			hit_y = hit["position"].y
	# +0,18 evita o z-fighting com o chão; é rente ao piso, não flutuando.
	ground_pos.y = hit_y + 0.18

	var ctrl := BlackHoleController.new(caster, ground_pos, damage, spec)
	world.add_child(ctrl)

# ---------- V: Liberation (Ribereshon - Repelão & Destruição em Círculo) ----------
static func _liberation(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	# `dir` não é usado: o Liberation é OMNIDIRECIONAL, nasce aos pés e empurra
	# para todos os lados. A direção do olhar não muda nada aqui.
	# Posição no chão aos pés do usuário para expansão da onda no plano horizontal sem obstruir a visão!
	var spawn_center := origin
	spawn_center.y = 0.2
	if is_instance_valid(caster) and caster is Node3D:
		spawn_center = Vector3(caster.global_position.x, 0.2, caster.global_position.z)

	var absorbed: int = 0
	if caster and caster.has_meta("yami_absorbed_blocks"):
		absorbed = caster.get_meta("yami_absorbed_blocks", 0)

	# Otimização e Limites: Aplica cap estrito de blocos simultâneos
	var nominal_blocks := 15 + absorbed
	var spawn_count := clampi(nominal_blocks, 12, MAX_SPAWN_PER_CAST)
	
	# ⚠️ AQUI ESTAVA O PIOR DESEQUILÍBRIO DO JOGO.
	#
	# Cada escombro chamava `take_damage()` DIRETO, com `damage * 1.2` — fora do
	# funil, portanto sem o corte de 0,12 que todo o resto levava. Cada bloco
	# valia 72 crus, cada um com a sua própria lista `hit_targets`, e nada
	# impedia o mesmo alvo de ser atingido por todos. Com 25 blocos: 1800 de dano
	# contra uma vida de 2048. Um Liberation era 88% da vida de alguém; a
	# ultimate da Gura, na mesma medição, era 1%.
	#
	# O `damage_mult` que ficava aqui — que AUMENTAVA o dano por bloco quando o
	# número de blocos passava do limite de spawn, "para não perder poder de
	# fogo" — foi removido junto: ele empurrava na direção oposta à do teto.
	#
	# Agora os escombros valem o dano MULTI da tabela (96), passam pelo
	# `CombatResolver` e dividem o orçamento de 768 com a onda de repulsão. O
	# golpe continua ejetando de 12 a 25 blocos; os que chegam depois do teto
	# empurram e não ferem, que é o espetáculo sem a execução.
	if is_instance_valid(caster):
		caster.set_meta("yami_absorbed_blocks", 0) # Esvazia a escuridão após liberar

	print("🌊 LIBERATION! Onda repulsora ejetando ", spawn_count, " escombros de ",
		spec.dano, " (teto do golpe: ", spec.teto, ", absorvidos: ", absorbed, ")")

	# Onda de Choque Rápida no Solo (Torus 1 - Ciano Brilhante / Branco)
	var burst_root := Node3D.new()
	world.add_child(burst_root)
	burst_root.global_position = spawn_center

	var shock_inst1 := MeshInstance3D.new()
	var shock_mesh1 := TorusMesh.new()
	shock_mesh1.inner_radius = 0.8
	shock_mesh1.outer_radius = 2.0
	shock_mesh1.rings = 64
	shock_mesh1.ring_segments = 16
	shock_inst1.mesh = shock_mesh1
	var sm_mat1 := StandardMaterial3D.new()
	sm_mat1.albedo_color = FxUtil.brilho(LIB_CYAN, 8.0)
	sm_mat1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_inst1.material_override = sm_mat1
	burst_root.add_child(shock_inst1)

	# Onda de Choque Secundária (Torus 2 - Azul Elétrico)
	var shock_inst2 := MeshInstance3D.new()
	var shock_mesh2 := TorusMesh.new()
	shock_mesh2.inner_radius = 0.4
	shock_mesh2.outer_radius = 1.4
	shock_mesh2.rings = 64
	shock_mesh2.ring_segments = 16
	shock_inst2.mesh = shock_mesh2
	var sm_mat2 := StandardMaterial3D.new()
	sm_mat2.albedo_color = FxUtil.brilho(LIB_BLUE, 6.0)
	sm_mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_inst2.material_override = sm_mat2
	shock_inst2.position.y = 0.1
	burst_root.add_child(shock_inst2)

	var tw_s := world.create_tween().set_parallel(true)
	tw_s.tween_property(shock_inst1, "scale", Vector3(50.0, 0.4, 50.0), 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(sm_mat1, "albedo_color:a", 0.0, 0.6)
	tw_s.tween_property(shock_inst2, "scale", Vector3(38.0, 0.6, 38.0), 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_s.tween_property(sm_mat2, "albedo_color:a", 0.0, 0.7)

	# Partículas horizontais de expulsão (NÃO SOBEM PARA NÃO CEGAR O JOGADOR - Cor remete à energia repulsora)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 1.5
	pm.emission_ring_inner_radius = 0.5
	pm.emission_ring_height = 0.2
	pm.direction = Vector3(0, 0.05, 0) # No plano horizontal
	pm.spread = 180.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -2.0, 0) # Mantém próximo ao solo
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = FxUtil.gradient([LIB_WHITE, LIB_CYAN, LIB_BLUE, Color(0, 0, 0, 0)])
	var burst := FxUtil.particles(110, 0.65, true, pm, FxUtil.grain(0.8)) # Contagem otimizada (110)
	burst_root.add_child(burst)

	AudioFX.impact(world, spawn_center, 0.5)
	AudioFX.whoosh(world, spawn_center, 0.4)

	# Limpeza preventiva se a cena inteira estiver próxima do teto de blocos (MAX_SCENE_BLOCKS)
	if world.get_tree():
		var scene_blocks := world.get_tree().get_nodes_in_group("yami_blocks")
		if scene_blocks.size() + spawn_count > MAX_SCENE_BLOCKS:
			var excess: int = (scene_blocks.size() + spawn_count) - MAX_SCENE_BLOCKS
			for idx in range(mini(excess, scene_blocks.size())):
				var b := scene_blocks[idx]
				if is_instance_valid(b) and b.has_method("despawn"):
					b.despawn()
				elif is_instance_valid(b):
					b.queue_free()

	# REPELÃO: Escombros e blocos ejetados com recursos compartilhados (Zero micro-stutters)
	for i in range(spawn_count):
		var blk := YamiBlock.new(spec.dano, caster, spec)
		world.add_child(blk)
		var angle := randf_range(0, TAU)
		var dist := randf_range(0.8, 3.5)
		var offset_start := Vector3(cos(angle) * dist, randf_range(0.2, 1.2), sin(angle) * dist)
		blk.global_position = spawn_center + offset_start
		var throw_dir := Vector3(cos(angle), randf_range(0.15, 0.35), sin(angle)).normalized()
		blk.velocity = throw_dir * randf_range(25.0, 45.0)

	# HITBOX do Repelão — onda radial do tamanho do alcance do golpe.
	# Antes daqui o Liberation não criava DamageZone nenhuma: o repelão era uma
	# varredura manual sobre o grupo "enemy" APENAS. Numa arena PvP isso deixava
	# todos os OUTROS JOGADORES imunes ao ultimate da Yami — o golpe passava por
	# eles sem tocar. A DamageZone pega qualquer corpo com take_damage() e já
	# empurra na direção radial (centro -> alvo), que é exatamente o repelão que a
	# varredura fazia à mão. Vida curta (0.45s): é um estouro instantâneo, não uma
	# armadilha que fica no chão.
	var wave := DamageZone.new()
	world.add_child(wave)
	wave.global_position = spawn_center + Vector3.UP * 1.0
	wave.setup(spec.parte("onda", 128.0), 38.0, Vector3.ZERO, 0.45, caster, LIBERATION_RADIUS)
	# Clímax do golpe: gasta a `reserva`, então os escombros nunca a consomem.
	spec.marcar(wave, true)

	# O tween nasce no PRÓPRIO burst_root, não em `world`: é o nó que ele libera
	# (mesma correção do GomuRedHawk._spawn_explosion). A autofree é a rede de
	# segurança caso o tween seja interrompido — 2.0 > 1.8, não corta o efeito.
	var tw := burst_root.create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(burst_root.queue_free)
	FxUtil.autofree(burst_root, 2.0)

# ⚠️ NÃO USE `world.get_tree()` AQUI (corrigido em 2026-08-23). É a MESMA
# armadilha que `FxUtil.autofree` já documenta, e ela derrubava esta função em
# TODO primeiro golpe de uma vida: `world` é o `Skills_<jogador>` de
# `Player._get_skills_container()`, que entra na cena por
# `add_child.call_deferred(...)` — no primeiro cast ele ainda NÃO está na
# árvore, `get_tree()` devolve null, e a chamada morria com
# "Cannot call method 'get_nodes_in_group' on a null value".
#
# Consequência medida no X: o alvo NUNCA era encontrado na conjuração. Não saía
# `in_kurouzu`, nem o ícone SUGADO, nem os 4 s de silêncio — o golpe abria o
# vórtice na mão e ficava só bonito. O que salvava parcialmente era a revarredura
# do `KurouzuController` 150 ms depois, que roda a partir de um nó JÁ na árvore.
#
# `Engine.get_main_loop()` é o mesmo SceneTree e não depende de o nó estar
# pendurado em lugar nenhum.
static func _find_closest_entity(world: Node, ignore_caster: Node, center: Vector3, max_dist: float) -> Node3D:
	var best_target: Node3D = null
	var best_dist := max_dist
	var arv: SceneTree = world.get_tree() if world != null else null
	if arv == null:
		arv = Engine.get_main_loop() as SceneTree
	if arv == null:
		return null
	var candidates := arv.get_nodes_in_group("enemy") + arv.get_nodes_in_group("player")
	for c in candidates:
		if not (c is Node3D) or c == ignore_caster:
			continue
		var d: float = center.distance_to(c.global_position)
		if d < best_dist and d > 0.2:
			best_dist = d
			best_target = c
	return best_target

# ==================== CLASSES INTERNAS / CONTROLADORES ====================

class KurouzuController extends Node:
	var caster: Node3D
	var target: Node3D
	var fwd: Vector3
	var damage: float
	var vortex_root: Node3D
	var ring1: MeshInstance3D
	var ring2: MeshInstance3D
	var elapsed := 0.0
	const DURATION := 3.0
	
	var scan_timer := 0.0
	var cached_los := false
	var cached_blocks: Array[Node] = []
	var state := 0
	var capture_timer := 0.0

	var spec: DamageSpec = null

	func _init(c: Node3D, t: Node3D, f: Vector3, d: float, v: Node3D, r1: MeshInstance3D = null, r2: MeshInstance3D = null, s: DamageSpec = null) -> void:
		spec = s if s != null else DamageSpec.avulso(d)
		caster = c
		target = t
		fwd = f
		damage = d
		vortex_root = v
		ring1 = r1
		ring2 = r2

	func _unlock_caster() -> void:
		if is_instance_valid(caster):
			if "movement_locked_timer" in caster:
				caster.movement_locked_timer = 0.0
			elif "_movement_locked_timer" in caster:
				caster._movement_locked_timer = 0.0
			if caster.has_meta("custom_pose") and caster.get_meta("custom_pose") == "kurouzu":
				caster.set_meta("custom_pose", "")
			if caster.has_meta("is_casting"):
				caster.set_meta("is_casting", false)

	func _exit_tree() -> void:
		_unlock_caster()
		if is_instance_valid(target):
			target.set_meta("in_kurouzu", false)
			target.set_meta("yami_silenced", false)
		if is_instance_valid(vortex_root) and not vortex_root.is_queued_for_deletion():
			vortex_root.queue_free()

	func _physics_process(delta: float) -> void:
		elapsed += delta
		scan_timer -= delta
		var do_scan := false
		if scan_timer <= 0.0:
			do_scan = true
			scan_timer = 0.15 # 150ms throttle timer for scanning/raycasts

		if is_instance_valid(ring1):
			ring1.rotation.y += 14.0 * delta
			ring1.rotation.x += 4.0 * delta
		if is_instance_valid(ring2):
			ring2.rotation.y -= 16.0 * delta
			ring2.rotation.z += 6.0 * delta

		# Aborta se caster não existir, se o target não existir, ou se "yami_kurouzu_active" foi desativado no caster (hold release / dano)
		var hold_active = true
		if is_instance_valid(caster) and caster.has_meta("yami_kurouzu_active"):
			hold_active = caster.get_meta("yami_kurouzu_active", true)
		elif not is_instance_valid(caster):
			hold_active = false
		
		if not is_instance_valid(caster):
			queue_free()
			return

		var current_fwd: Vector3 = -caster.global_transform.basis.z.normalized()
		var palm_pos: Vector3
		if caster.has_method("get_right_hand_position"):
			palm_pos = caster.get_right_hand_position()
		else:
			palm_pos = caster.global_position + current_fwd * 1.4 + Vector3.UP * 1.1

		if state == 0:
			if elapsed >= 5.0 or not hold_active:
				# ⚠️ A MORTE VEM PRIMEIRO (2026-08-23). Este era o bug do "o buraco
				# negro não some da mão": `pedir_cancelar_hold` era chamado com UM
				# argumento e a assinatura pede DOIS (`slot, fruta`). O erro de
				# runtime abortava `_physics_process` inteiro — e o `queue_free()`
				# ficava DEPOIS, então nunca rodava. O controlador virava zumbi:
				# `_exit_tree` (que é quem libera o `vortex_root`) nunca disparava e
				# o orbe seguia colado na palma da mão para sempre.
				#
				# Pior: a linha `set_meta("yami_kurouzu_active", false)` continuava
				# rodando a CADA quadro. Passados os 5 s do zumbi, o X SEGUINTE era
				# desligado no primeiro quadro de vida — o golpe abria e morria sem
				# puxar ninguém, que é o outro sintoma relatado. Cada X sem captura
				# somava mais um zumbi. Medido: 2 conjurações = 2 orbes presos.
				#
				# Marcar a morte antes de tocar no caster é barato e tira a saída do
				# controlador da mão de qualquer chamada externa que possa falhar.
				queue_free()
				if is_instance_valid(caster):
					caster.set_meta("yami_kurouzu_active", false)
					if caster.has_method("pedir_cancelar_hold"):
						caster.pedir_cancelar_hold("X", "yami_yami")
				return
		else:
			capture_timer += delta
			if capture_timer >= 3.0 or not hold_active:
				_throw_target(current_fwd, palm_pos)
				queue_free()
				return
		if is_instance_valid(vortex_root):
			vortex_root.global_position = palm_pos

		# 1. Sucção de blocos Yami no ambiente (area = 28.0)
		var cnt: int = caster.get_meta("yami_absorbed_blocks", 0) if is_instance_valid(caster) else 0
		var pull_strength := 12.0 * delta
		var tree = get_tree()
		if do_scan and tree:
			cached_blocks = tree.get_nodes_in_group("yami_blocks")
			
		for blk in cached_blocks:
			if blk is Node3D and is_instance_valid(blk):
					var d_blk = blk.global_position.distance_to(palm_pos)
					if d_blk <= 28.0:
						var b_dir = (palm_pos - blk.global_position).normalized()
						if "velocity" in blk:
							blk.velocity = blk.velocity.lerp(b_dir * 25.0, pull_strength)
						else:
							blk.global_position = blk.global_position.move_toward(palm_pos, 15.0 * delta)
						
						if d_blk <= 1.5:
							if blk.has_method("despawn"): blk.despawn()
							else: blk.queue_free()
							cnt += 1
		if is_instance_valid(caster):
			caster.set_meta("yami_absorbed_blocks", cnt)

		# 2. Lógica principal do alvo (Player/Inimigo)
		if not is_instance_valid(target) and do_scan and get_tree() and get_tree().current_scene:
			target = YamiFX._find_closest_entity(get_tree().current_scene, caster, palm_pos, 28.0)
			if target:
				print("🌑 Kurouzu prendeu o alvo durante o hold: ", target.name)
				target.set_meta("in_kurouzu", true)
				StatusFX.aplicar(target, StatusFX.SUGADO, 3.2)
				target.set_meta("yami_silenced", true)
				if target.has_method("suppress_skills_temporarily"):
					target.suppress_skills_temporarily(4.0)

		if is_instance_valid(target):
			var dist = target.global_position.distance_to(palm_pos)
			
			# Oclusão / Line of Sight
			if do_scan:
				cached_los = true
				if target.is_inside_tree() and target.get_world_3d():
					var space_state = target.get_world_3d().direct_space_state
					var query = PhysicsRayQueryParameters3D.create(target.global_position + Vector3.UP * 1.0, palm_pos)
					var ex = []
					if caster is CollisionObject3D: ex.append(caster.get_rid())
					if target is CollisionObject3D: ex.append(target.get_rid())
					query.exclude = ex
					query.collision_mask = 1 # Considera apenas mapa base e props físicos da layer 1
					var result = space_state.intersect_ray(query)
					if result and not result.is_empty():
						cached_los = false

			if cached_los:
				target.set_meta("in_kurouzu", true)
				target.set_meta("yami_silenced", true)
				
				if caster.is_multiplayer_authority():
					if state == 1:
						if "velocity" in target:
							target.velocity = Vector3.ZERO
							if target.has_method("move_and_slide"):
								target.move_and_slide()
						target.global_position = target.global_position.lerp(palm_pos, 25.0 * delta)
					else:
						var pull_dir = (palm_pos - target.global_position).normalized()
						if "velocity" in target:
							target.velocity = target.velocity.lerp(pull_dir * 22.0, pull_strength)
							if target.has_method("move_and_slide"):
								target.move_and_slide()
						else:
							target.global_position = target.global_position.move_toward(palm_pos, 22.0 * delta)
				
				# Captura Automática se colidir com o buraco negro (dist < 1.4m)
				if dist < 1.4 and state == 0:
					state = 1
					print("🌑 Alvo capturado pelo Kurouzu!")
			else:
				# Bloqueado: Não é puxado
				target.set_meta("in_kurouzu", false)
				target.set_meta("yami_silenced", false)

	func _throw_target(current_fwd: Vector3, palm_pos: Vector3) -> void:
		if is_instance_valid(target):
			target.set_meta("in_kurouzu", false)
			target.set_meta("yami_silenced", false)
			
			var throw_dir: Vector3 = current_fwd
			if is_instance_valid(caster) and "_cam" in caster and is_instance_valid(caster._cam):
				throw_dir = -caster._cam.global_transform.basis.z.normalized()
			elif is_instance_valid(caster) and "rotation" in caster:
				throw_dir = -caster.global_transform.basis.z.normalized()
			
			if caster.is_multiplayer_authority():
				var mega_kb: Vector3 = throw_dir * 45.0 + Vector3.UP * 10.0
				# ⚠️ ERA `take_damage(damage * 1.5)` DIRETO — o segundo desvio da
				# Yami, e o que fazia o Kurouzu valer 56,7 quando o vórtice
				# sozinho valia 4,2. O ARREMESSO é o clímax do golpe e continua
				# valendo o triplo do vórtice, agora por `partes.arremesso` na
				# tabela; o que mudou é que ele divide o teto de 256 com ele.
				if target.has_method("take_damage"):
					CombatResolver.aplicar(target, spec.parte("arremesso", 192.0),
						spec.cast_id, spec.teto, palm_pos, mega_kb)
				elif "velocity" in target:
					target.velocity = mega_kb
			
			if get_tree() and get_tree().current_scene:
				AudioFX.impact(get_tree().current_scene, target.global_position, 0.6)
				AudioFX.whoosh(get_tree().current_scene, target.global_position, 0.7)
				var pm := ParticleProcessMaterial.new()
				pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
				pm.emission_sphere_radius = 0.8
				pm.direction = throw_dir
				pm.spread = 20.0
				pm.initial_velocity_min = 15.0
				pm.initial_velocity_max = 28.0
				pm.scale_min = 0.4
				pm.scale_max = 0.9
				pm.color_ramp = FxUtil.gradient([YamiFX.GLOW_VIOLET, YamiFX.DARK_PURPLE, YamiFX.VOID_BLACK, Color(0, 0, 0, 0)])
				var burst := FxUtil.particles(150, 0.5, true, pm, FxUtil.grain(0.7))
				var root_fx := Node3D.new()
				root_fx.position = target.global_position
				root_fx.add_child(burst)
				# ⚠️ Escapava do `clear_spawned_skills` (2026-08-22).
				FxUtil.mundo_de_skills(caster, get_tree().current_scene).add_child(root_fx)
				FxUtil.autofree(root_fx, 0.8)
		
		if is_instance_valid(caster):
			caster.set_meta("yami_kurouzu_active", false)
			if caster.has_method("pedir_cancelar_hold"):
				# Mesma correção de aridade do caminho sem captura, acima. Aqui o
				# erro não prendia o orbe (o `queue_free()` de quem chama vem
				# depois do `_throw_target`), mas cortava o `print` do release e,
				# principalmente, o AVISO DE REDE: sem este RPC os outros peers
				# ficavam com `yami_kurouzu_active` ligado no conjurador.
				caster.pedir_cancelar_hold("X", "yami_yami")
		
		print("💥 KURUOZU RELEASE: Inimigo arremessado com MEGA KNOCKBACK automático!")


class BlackHoleController extends Node:
	var caster: Node3D
	var center: Vector3
	var damage: float
	var elapsed := 0.0
	var tick := 0.0
	var pool: MeshInstance3D
	const MAX_DURATION := 7.0
	const RADIUS := 32.0

	var spec: DamageSpec = null

	func _init(c: Node3D, pos: Vector3, d: float, s: DamageSpec = null) -> void:
		spec = s if s != null else DamageSpec.avulso(d)
		caster = c
		center = pos
		damage = d

	func _ready() -> void:
		pool = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = RADIUS
		cyl.bottom_radius = RADIUS
		cyl.height = 0.12
		pool.mesh = cyl
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = FxUtil.brilho(YamiFX.VOID_BLACK, 3.0)
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p_mat.render_priority = 10 # Prioridade de render acima do chão para eliminar Z-fighting!
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pool.material_override = p_mat
		add_child(pool)
		pool.global_position = center

		# Anel de Horizonte de Eventos no solo ao redor do pântano (ligeiramente mais alto que o pool)
		var horizon := MeshInstance3D.new()
		var h_mesh := TorusMesh.new()
		h_mesh.inner_radius = RADIUS - 0.5
		h_mesh.outer_radius = RADIUS + 0.5
		h_mesh.rings = 64
		h_mesh.ring_segments = 16
		horizon.mesh = h_mesh
		var h_mat := StandardMaterial3D.new()
		h_mat.albedo_color = FxUtil.brilho(YamiFX.GLOW_VIOLET, 5.0)
		h_mat.render_priority = 15 # Renderiza acima do pântano e do piso
		h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		horizon.material_override = h_mat
		horizon.position.y = 0.08 # Elevação sobre o cilindro para evitar sobreposição de vértices
		pool.add_child(horizon)
		horizon.name = "HorizonRing"

		# Anel interno concêntrico (sucção e profundidade visual sem ocupar altura)
		var inner_ring := MeshInstance3D.new()
		var i_mesh := TorusMesh.new()
		i_mesh.inner_radius = RADIUS * 0.5 - 0.4
		i_mesh.outer_radius = RADIUS * 0.5 + 0.4
		i_mesh.rings = 48
		i_mesh.ring_segments = 16
		inner_ring.mesh = i_mesh
		var i_mat := h_mat.duplicate()
		i_mat.albedo_color = YamiFX.DARK_PURPLE
		i_mat.emission = YamiFX.GLOW_VIOLET
		i_mat.emission_energy_multiplier = 4.0
		i_mat.render_priority = 18 # Top render priority
		inner_ring.material_override = i_mat
		inner_ring.position.y = 0.12 # Elevação camada 2
		pool.add_child(inner_ring)
		inner_ring.name = "InnerRing"

		# Partículas RENTAS AO SOLO para NÃO OBSTRUIR A VISÃO do jogador
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(RADIUS - 2.0, 0.1, RADIUS - 2.0)
		pm.direction = Vector3.UP
		pm.spread = 70.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.5 # Velocidade mínima para não subir na frente da câmera!
		pm.gravity = Vector3(0, -0.1, 0) # Mantém no chão como um pântano
		pm.scale_min = 0.4
		pm.scale_max = 1.2
		pm.color_ramp = FxUtil.gradient([YamiFX.VOID_BLACK, YamiFX.DARK_PURPLE, YamiFX.GLOW_VIOLET, Color(0, 0, 0, 0)])
		var smoke := FxUtil.particles(140, 1.5, false, pm, FxUtil.grain(0.8))
		add_child(smoke)
		smoke.global_position = center + Vector3.UP * 0.1

		# HITBOX — o ENGOLIR. Uma mordida só, no momento em que o poço abre.
		#
		# O `damage` recebido no _init NUNCA era lido: o Black Hole puxava, afundava
		# e silenciava, mas não tirava um ponto de vida de ninguém — por isso o slot
		# C aparecia sem hitbox na auditoria.
		#
		# E ele NÃO vira dano contínuo, por decisão que já está escrita nas
		# entidades, não aqui: TrainingDummy.take_damage e Enemy.take_damage
		# RECUSAM dano enquanto `in_black_hole` for verdadeiro. Ou seja, o projeto
		# já declara que o prisioneiro é imune — o Black Hole é controle (puxa,
		# afunda, silencia), não moedor. Medido: um tique de esmagamento a cada
		# segundo não tirava nada do dummy. Quem quiser o poço causando dano por
		# segundo tem que mexer PRIMEIRO nessa imunidade, e isso é decisão de dono
		# de projeto — não deste efeito.
		# O que sobra e é legítimo: a mordida da entrada, aplicada antes de a
		# imunidade ligar. Medido: 6.0 de dano no dummy.
		#
		# Raio = RADIUS, o mesmo do pântano e da sucção.
		# Knockback ZERO de propósito: este golpe SUGA. Empurrar para fora mataria
		# a própria mecânica do vórtice.
		# É filha do controlador (não da cena): a varredura de anulação lá embaixo
		# só apaga DamageZone que seja filha DIRETA de current_scene, então o buraco
		# negro não engole a própria hitbox.
		var zone := DamageZone.new()
		add_child(zone)
		zone.global_position = center
		zone.setup(damage, 0.0, Vector3.ZERO, MAX_DURATION, caster, RADIUS)
		spec.marcar(zone)

		AudioFX.whoosh(get_tree().current_scene, center, 0.45)

	func _process(delta: float) -> void:
		elapsed += delta
		tick += delta
		if is_instance_valid(pool):
			var hr := pool.get_node_or_null("HorizonRing")
			if hr and is_instance_valid(hr):
				hr.rotation.y += 1.8 * delta
			var ir := pool.get_node_or_null("InnerRing")
			if ir and is_instance_valid(ir):
				ir.rotation.y -= 2.5 * delta

		var holding := true
		if is_instance_valid(caster) and caster.has_meta("yami_black_hole_active"):
			holding = caster.get_meta("yami_black_hole_active", true)
		elif not is_instance_valid(caster):
			holding = false

		if elapsed >= MAX_DURATION or not holding:
			_terminate()
			return

		# NÃO existe dano contínuo aqui, e isso é DELIBERADO — ver o comentário sobre
		# `damage` no _ready(). Quem está preso é imune por decisão das entidades.

		# A cada 0.05s (20Hz) processa sucção, afundo e bloqueio de poderes
		if tick >= 0.05 and get_tree():
			tick = 0.0
			var all_entities := get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
			for e in all_entities:
				if not (e is Node3D) or e == caster:
					continue
				if center.distance_to(e.global_position) <= RADIUS + 0.5:
					e.set_meta("in_black_hole", true)
					StatusFX.aplicar(e, StatusFX.BURACO_NEGRO, 7.0)
					e.set_meta("yami_silenced", true)
					if e.has_method("suppress_skills_temporarily"):
						e.suppress_skills_temporarily(10.0)
					# Puxa para o centro do pântano
					var pull_dir: Vector3 = (center - e.global_position)
					pull_dir.y = 0
					e.global_position += pull_dir.normalized() * minf(pull_dir.length(), 3.5 * delta)
					# Efeito AFUNDO: puxa levemente para baixo (presos e afundando no chão)
					if e.global_position.y > -0.5 and not ("is_player" in e and e.is_player):
						e.global_position.y = maxf(-0.5, e.global_position.y - 1.5 * delta)

			# Anula ataques de Akuma no Mi e DamageZones externos
			if get_tree().current_scene:
				for child in get_tree().current_scene.get_children():
					if child is DamageZone and child.global_position.distance_to(center) <= RADIUS:
						child.queue_free()
						print("🛡️ ATAQUE E DANO DE AKUMA NO MI ANULADO PELO BLACK HOLE!")

			# Absorve blocos cinza gerados pelo Liberation
			for blk in get_tree().get_nodes_in_group("yami_blocks"):
				if blk is Node3D and blk.get("landed") == true and blk.global_position.distance_to(center) <= RADIUS + 1.0:
					blk.position.y -= 3.0 * delta
					if blk.position.y < -0.5:
						blk.queue_free()
						if is_instance_valid(caster):
							var cnt: int = caster.get_meta("yami_absorbed_blocks", 0)
							var new_cnt := mini(cnt + 1, YamiFX.MAX_ABSORBED_BLOCKS)
							caster.set_meta("yami_absorbed_blocks", new_cnt)
							print("🌑 Bloco cinza absorvido no pântano! Total guardado: ", new_cnt, "/", YamiFX.MAX_ABSORBED_BLOCKS)

	func _terminate() -> void:
		if is_instance_valid(caster):
			if caster.get_meta("custom_pose", "") == "black_hole":
				caster.set_meta("custom_pose", "")
			if "movement_locked_timer" in caster:
				caster.movement_locked_timer = 0.0
			elif "_movement_locked_timer" in caster:
				caster._movement_locked_timer = 0.0
			if caster.has_meta("yami_black_hole_active"):
				caster.set_meta("yami_black_hole_active", false)

		if get_tree():
			var all_entities := get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
			for e in all_entities:
				if is_instance_valid(e) and e.has_meta("in_black_hole") and e.get_meta("in_black_hole"):
					e.set_meta("in_black_hole", false)
					if e is Node3D and e.global_position.y < 0.1:
						e.global_position.y = 0.1

		if get_tree() and get_tree().current_scene:
			AudioFX.impact(get_tree().current_scene, center, 0.6)
		queue_free()

	func _exit_tree() -> void:
		caster = null
		pool = null


class YamiBlock extends Node3D:
	var velocity := Vector3.ZERO
	var rot_spd := Vector3.ZERO
	var damage := 15.0
	var landed := false
	var caster: Node
	var hit_targets: Array[Node3D] = []
	var mesh_inst: MeshInstance3D
	var _cached_targets: Array = []

	var spec: DamageSpec = null

	func _init(d: float, c: Node, s: DamageSpec = null) -> void:
		spec = s if s != null else DamageSpec.avulso(d)
		damage = maxf(d * 0.25, 12.0)
		caster = c
		rot_spd = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))

	func _ready() -> void:
		add_to_group("yami_blocks")
		mesh_inst = MeshInstance3D.new()
		# Otimização: Reutiliza o MESMO BoxMesh e StandardMaterial3D em memória (zero alocação de malha/material)
		mesh_inst.mesh = YamiFX.get_shared_block_mesh()
		mesh_inst.material_override = YamiFX.get_shared_block_mat()
		mesh_inst.scale = Vector3(randf_range(0.5, 1.3), randf_range(0.5, 1.3), randf_range(0.5, 1.3))
		add_child(mesh_inst)
		if get_tree():
			_cached_targets = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")

	func despawn() -> void:
		if get_tree() == null or not is_inside_tree():
			queue_free()
			return
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(queue_free)

	func _exit_tree() -> void:
		hit_targets.clear()
		_cached_targets.clear()
		caster = null
		mesh_inst = null

	func _physics_process(delta: float) -> void:
		if landed:
			return
		velocity.y -= 26.0 * delta
		position += velocity * delta
		rotation += rot_spd * delta

		# Dano e knockback enquanto voa/cai.
		#
		# ⚠️ Varre "enemy" E "player". Antes era só "enemy", e numa arena PvP
		# isso significava que os escombros ATRAVESSAVAM os outros jogadores: o
		# ultimate da Yami acertava a onda de repelão e os blocos passavam
		# direto. Os inimigos estão em `disabled/` desde 2026-08-10, então na
		# prática o laço não pegava ninguém além do boneco de treino.
		if get_tree():
			for e in _cached_targets:
				if not (e is Node3D) or e in hit_targets or e == caster:
					continue
				if global_position.distance_to(e.global_position + Vector3.UP * 0.8) < 1.8:
					hit_targets.append(e)
					# ⚠️ ERA `e.take_damage(damage, ...)` DIRETO — o desvio que fazia o
					# Liberation tirar 1800 de uma vida de 2048. Passar pelo
					# `CombatResolver` põe o escombro debaixo do teto que ele
					# divide com a onda e com os outros 24 blocos.
					var kb := velocity.normalized() * 14.0 + Vector3.UP * 3.0
					CombatResolver.aplicar(e, damage, spec.cast_id, spec.teto, global_position, kb)
					if get_tree() and get_tree().current_scene:
						AudioFX.snap(get_tree().current_scene, global_position, 0.8)

		# Queda definitiva no solo
		if position.y <= 0.35:
			position.y = 0.35
			velocity = Vector3.ZERO
			rot_spd = Vector3.ZERO
			landed = true
			rotation = Vector3(0, rotation.y, 0)
			
			# OTIMIZAÇÃO CRÍTICA: Desativa processamento de física quando atinge o chão!
			set_physics_process(false)
			if get_tree():
				# Auto-despawn suave caso não seja absorvido pelo Black Hole.
				# Era 20s — tempo em que 15 escombros (30 nós) ficavam parados no
				# mapa por conjuração. A janela existe para o combo V -> C (o Black
				# Hole absorve o entulho e engorda o próximo V); DEBRIS_LIFETIME
				# ainda cobre o tempo de reagir e conjurar o C, que dura 7s.
				# GATILHO para revisitar: se o combo V -> C começar a falhar por
				# falta de tempo jogando, subir DEBRIS_LIFETIME e aceitar que o
				# test_frutas volte a acusar entulho na janela de 8s dele.
				get_tree().create_timer(YamiFX.DEBRIS_LIFETIME).timeout.connect(func(): if is_instance_valid(self): despawn())

			# Otimização de áudio e poeira: aciona efeitos de queda em apenas ~35% dos blocos para evitar sobrecarga de som/partícula
			if get_tree() and get_tree().current_scene and randf() < 0.35:
				AudioFX.impact(get_tree().current_scene, global_position, randf_range(0.95, 1.2))
				var pm := ParticleProcessMaterial.new()
				pm.direction = Vector3.UP
				pm.spread = 70.0
				pm.initial_velocity_min = 1.0
				pm.initial_velocity_max = 3.5
				pm.scale_min = 0.2
				pm.scale_max = 0.45
				pm.color = YamiFX.CONCRETE_GRY
				var dust := FxUtil.particles(6, 0.2, true, pm, FxUtil.grain(0.35))
				var d_root := Node3D.new()
				d_root.position = global_position
				d_root.add_child(dust)
				# ⚠️ Escapava do `clear_spawned_skills` (2026-08-22).
				FxUtil.mundo_de_skills(caster, get_tree().current_scene).add_child(d_root)
				# VAZAMENTO REAL: este nó NUNCA era liberado. Um por bloco que cai
				# (~35% dos 15 escombros), 2 nós cada, para sempre, a cada V.
				FxUtil.autofree(d_root, 0.6)   # poeira one_shot dura 0.2s
