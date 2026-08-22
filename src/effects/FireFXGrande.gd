class_name FireFXGrande
extends RefCounted
# ============================================================================
#  MERA MERA — OS GOLPES GRANDES (Hibashira legado, Inferno e a explosão).
#
#  Saiu do `FireFX.gd` em 2026-08-11 porque ele tinha 916 linhas e o limite do
#  projeto é 900 (regra do dono). O corte foi por TAMANHO de bloco, não por
#  capricho: estes três eram 533 das 916 linhas, e são os únicos que não
#  participam do dia a dia da fruta — Z e X são o combate normal, estes são os
#  espetáculos.
#
#  Os ajudantes comuns (materiais, partículas, brasas) continuam no `FireFX` e
#  são chamados de lá — duplicá-los aqui criaria duas fontes de verdade para a
#  paleta do fogo, que é justamente o que mantém a fruta coerente.
# ============================================================================

# ---------- C Legado: Hibashira ----------
# ⚠️ CÓDIGO LEGADO E INALCANÇÁVEL: nada chama esta função desde que o C da Mera
# virou o Entei carregável. Foi passada pelo funil junto com o resto para não
# ficar sendo a única fonte de dano cru do arquivo caso alguém a ressuscite.
static func _hibashira_legado(world: Node, pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var ground := Vector3(pos.x, 0.0, pos.z)
	var space = world.get_world_3d().direct_space_state if (world is Node3D and world.is_inside_tree() and world.get_world_3d() != null) else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 40.0, pos + Vector3.DOWN * 80.0)
		q.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty(): ground = hit["position"]
		
	# 1. Ativação da Pose de Entrada Imune (Soca o chão e abre as pernas, imune por toda a duração)
	if is_instance_valid(caster):
		caster.set_meta("damage_immune", true)
		caster.set_meta("custom_pose", "hibashira")
		if caster.has_method("lock_movement"):
			caster.lock_movement(3.5, "C")
		print("🔥 [Mera Mera C - Hibashira] Ativado! Usuário na pose de combate e IMUNE A DANOS por 3.5s!")
		
	var zone := Node3D.new()
	world.add_child(zone)
	zone.global_position = ground
	
	# 2. Luz Térmica Dinâmica e Efeitos de Impacto Inicial (ScreenFX & Shake)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.05)
	light.light_energy = 16.0
	light.omni_range = 30.0
	light.position = Vector3(0, 5.0, 0)
	zone.add_child(light)
	
	var sfx := world.get_node_or_null("/root/ScreenFX") if is_instance_valid(world) else null
	if sfx and sfx.has_method("flash"):
		sfx.flash(Color(1.0, 0.45, 0.1), 0.5)
		
	if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
		caster.add_camera_shake(0.5)
		
	# 3. Onda de Choque de Fogo no Solo (Anel emissivo se expandindo na terra)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.1
	tm.outer_radius = 1.6
	ring.mesh = tm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.4, 0.05)
	ring_mat.emission_energy_multiplier = 4.0
	ring.material_override = ring_mat
	ring.scale = Vector3(0.2, 0.2, 0.2)
	zone.add_child(ring)
	ring.position = Vector3(0, 0.15, 0)
	
	var tw_ring := zone.create_tween()
	tw_ring.set_parallel(true)
	tw_ring.tween_property(ring, "scale", Vector3(8.5, 0.1, 8.5), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ring.tween_property(ring_mat, "albedo_color:a", 0.0, 0.45)
	tw_ring.tween_callback(ring.queue_free).set_delay(0.46)
	
	# 4. Vórtex Duplo de Chamas: Núcleo de Plasma Branco-Quente e Hélice de Magma Externa
	var pivot_core := Node3D.new()
	var pivot_vortex := Node3D.new()
	zone.add_child(pivot_core)
	zone.add_child(pivot_vortex)
	
	var core_blocks := []
	var bs_core := 0.65
	for y in range(0, 24):
		var ang := y * 0.5
		var r := 0.4 + (y * 0.02)
		core_blocks.append(Vector3(cos(ang)*r, y * 0.75, sin(ang)*r))
		core_blocks.append(Vector3(cos(ang + PI)*r, y * 0.75, sin(ang + PI)*r))
		
	var mmi_core := MultiMeshInstance3D.new()
	var mm_core := MultiMesh.new()
	mm_core.transform_format = MultiMesh.TRANSFORM_3D
	mm_core.instance_count = core_blocks.size()
	var box_core := BoxMesh.new(); box_core.size = Vector3.ONE * bs_core
	mm_core.mesh = box_core
	mmi_core.multimesh = mm_core
	mmi_core.material_override = FireFX._plasma_material()
	for i in range(core_blocks.size()):
		mm_core.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf()*TAU), core_blocks[i]))
	pivot_core.add_child(mmi_core)
	
	var vortex_blocks := []
	var bs_vortex := 0.95
	for y in range(0, 20):
		var ang := -y * 0.6
		var r := 1.6 + (y * 0.05)
		vortex_blocks.append(Vector3(cos(ang)*r, y * 0.85, sin(ang)*r))
		vortex_blocks.append(Vector3(cos(ang + PI*0.66)*r, y * 0.85, sin(ang + PI*0.66)*r))
		vortex_blocks.append(Vector3(cos(ang + PI*1.33)*r, y * 0.85, sin(ang + PI*1.33)*r))
		
	var mmi_vortex := MultiMeshInstance3D.new()
	var mm_vortex := MultiMesh.new()
	mm_vortex.transform_format = MultiMesh.TRANSFORM_3D
	mm_vortex.instance_count = vortex_blocks.size()
	var box_vortex := BoxMesh.new(); box_vortex.size = Vector3.ONE * bs_vortex
	mm_vortex.mesh = box_vortex
	mmi_vortex.multimesh = mm_vortex
	mmi_vortex.material_override = FireFX._magma_material()
	for i in range(vortex_blocks.size()):
		mm_vortex.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf()*TAU), vortex_blocks[i]))
	pivot_vortex.add_child(mmi_vortex)
	
	pivot_core.position.y = -24.0
	pivot_vortex.position.y = -26.0
	var tw_erup := zone.create_tween()
	tw_erup.set_parallel(true)
	tw_erup.tween_property(pivot_core, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_erup.tween_property(pivot_vortex, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Rotação Contínua do Furacão de Fogo durante os 3.5 segundos da técnica
	var tw_rot := zone.create_tween()
	tw_rot.set_parallel(true)
	tw_rot.tween_property(pivot_core, "rotation:y", TAU * 7.0, 3.5)
	tw_rot.tween_property(pivot_vortex, "rotation:y", -TAU * 5.5, 3.5)
	
	var pm := FireFX._flame_proc(Vector3.UP, 8.0, 18.0, 30.0, Vector3(0, 8.0, 0), 2.0, 6.0, 3.5)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.8, 0.5, 2.8)
	zone.add_child(FxUtil.particles(600, 1.6, false, pm, FxUtil.grain(1.0)))
	zone.add_child(FireFX._embers())
	
	if is_instance_valid(world):
		AudioFX.impact(world, ground, 0.9)
		AudioFX.whoosh(world, ground + Vector3.UP * 2.0, 1.35)
		
	# 5. Área do Furacão Gravitacional: suspende inimigos no ar girando sem que consigam se mover ou atacar
	var area := Area3D.new()
	zone.add_child(area)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 8.5
	cyl.height = 22.0
	col.shape = cyl
	col.position = Vector3(0, 11.0, 0)
	area.add_child(col)
	
	var trapped_victims: Dictionary = {}
	var vortex_active := true
	var burn_acc := 0.0
	
	var vortex_timer := Timer.new()
	vortex_timer.wait_time = 0.05   # 20 Hz (controle contínuo de posição, rotação e CC no ar)
	vortex_timer.autostart = true
	zone.add_child(vortex_timer)
	
	vortex_timer.timeout.connect(func():
		if not vortex_active or not is_instance_valid(area):
			return
		burn_acc += 0.05
		var do_burn := (burn_acc >= 0.45)
		if do_burn: burn_acc = 0.0
		
		for body in area.get_overlapping_bodies():
			if body == caster or not is_instance_valid(body):
				continue
			if not body.has_method("take_damage"):
				continue
				
			# Marca a vítima no dicionário e aplica CC (imobiliza e impede ataques)
			trapped_victims[body] = true
			body.set_meta("in_vortex", true)
			StatusFX.aplicar(body, StatusFX.SUGADO, 3.0)
			body.set_meta("is_suppressed", true)
			if body.has_method("suppress_skills_temporarily"):
				body.suppress_skills_temporarily(0.25)
				
			# "Fica voando no furacão": suspender no ar e girar ao redor do pilar flamejante
			if body is CharacterBody3D:
				var rel := (body as CharacterBody3D).global_position - ground
				var flat_rel := Vector3(rel.x, 0.0, rel.z)
				if flat_rel.length() < 0.3:
					flat_rel = Vector3(2.5, 0.0, 0.0)
				var target_y: float = ground.y + 4.2 + sin(rel.x * 2.0 + rel.z) * 0.8
				var vy: float = (target_y - (body as CharacterBody3D).global_position.y) * 6.0
				var pull_dir := -flat_rel.normalized()
				var swirl_dir := Vector3.UP.cross(flat_rel).normalized()
				(body as CharacterBody3D).velocity = swirl_dir * 16.0 + pull_dir * (flat_rel.length() - 2.5) * 5.0 + Vector3.UP * vy
				(body as CharacterBody3D).move_and_slide()
				
			if do_burn:
				# Queimadura contínua, sem knockback de saída.
				CombatResolver.aplicar(body, spec.dano, spec.cast_id, spec.teto, ground)
	)
	
	# 6. Encerramento com Explosão Massiva: liberta e espalha qualquer vítima do ataque
	var end_timer := Timer.new()
	end_timer.wait_time = 3.5
	end_timer.one_shot = true
	end_timer.autostart = true
	zone.add_child(end_timer)
	
	end_timer.timeout.connect(func():
		vortex_active = false
		vortex_timer.stop()
		
		# Fim do ataque: usuário sai da pose de entrada e perde a imunidade
		if is_instance_valid(caster):
			caster.set_meta("damage_immune", false)
			caster.set_meta("custom_pose", "")
			print("⚡ [Mera Mera C - Hibashira] Encerrado! Fim da pose e da imunidade ao dano do usuário.")
			
		var final_targets := trapped_victims.duplicate()
		if is_instance_valid(area):
			for b in area.get_overlapping_bodies():
				if b != caster and is_instance_valid(b) and b.has_method("take_damage"):
					final_targets[b] = true
					
		print("💥 [Mera Mera C - Hibashira] EXPLOSÃO FINAL! Espalhando vítimas do furacão!")
		for body in final_targets.keys():
			if not is_instance_valid(body) or not (body is Node3D):
				continue
			body.set_meta("in_vortex", false)
			body.set_meta("is_suppressed", false)
			
			# Vetor explosivo para fora e para cima (scatter total)
			var dir_out: Vector3 = ((body as Node3D).global_position - ground)
			dir_out.y = 0.0
			if dir_out.length_squared() < 0.01:
				dir_out = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			else:
				dir_out = dir_out.normalized()
				
			var scatter_kb: Vector3 = dir_out * 48.0 + Vector3.UP * 24.0
			CombatResolver.aplicar(body, spec.parte("final", spec.dano * 2.0),
				spec.cast_id, spec.teto, ground, scatter_kb)
				
		# Efeitos da Supernova / Explosão final de encerramento
		if is_instance_valid(world):
			var exp_sfx := world.get_node_or_null("/root/ScreenFX")
			if exp_sfx and exp_sfx.has_method("flash"):
				exp_sfx.flash(Color(1.0, 0.6, 0.15), 0.7)
			AudioFX.impact(world, ground + Vector3.UP * 2.0, 1.25)
			AudioFX.snap(world, ground + Vector3.UP * 2.0, 1.5)
			
		var exp_mesh := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.6; sm.height = 1.2
		exp_mesh.mesh = sm
		exp_mesh.material_override = FireFX._plasma_material()
		exp_mesh.position = Vector3(0, 3.5, 0)
		zone.add_child(exp_mesh)
		var tw_exp := zone.create_tween()
		tw_exp.set_parallel(true)
		tw_exp.tween_property(exp_mesh, "scale", Vector3(25.0, 25.0, 25.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_exp.tween_property(exp_mesh, "transparency", 1.0, 0.45)
		tw_exp.tween_property(light, "light_energy", 0.0, 0.5)
		tw_exp.tween_callback(zone.queue_free).set_delay(0.6)
	)

# Utilizado pelo Hiken ao final de sua trajetória
static func _explosion(world: Node, pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = pos + Vector3.UP * 1.0
	var pm := FireFX._flame_proc(Vector3.UP, 90.0, 6.0, 14.0, Vector3(0, 1.0, 0), 2.0, 5.0, 4.0, 1.5)
	var fire := FxUtil.particles(700, 1.4, true, pm, FxUtil.grain(1.2), 0.85)
	fire.material_override = FxUtil.particle_material(Color(1, 0.4, 0.1), 4.0, true)
	zone.add_child(fire)
	zone.add_child(FireFX._embers())
	zone.setup(damage, 35.0, Vector3.ZERO, 1.6, caster, 6.0)
	if spec != null:
		spec.marcar(zone)
	AudioFX.impact(world, pos, 0.9)

# ==================== CONTROLADOR DO SOL (DAI ENKAI: ENTEI) ====================
class EnteiSunController extends Node3D:
	var caster: Node
	var dir: Vector3
	var damage: float
	var elapsed := 0.0
	var fired := false
	var sun: Node3D
	var light: OmniLight3D
	var zone: DamageZone

	var _spec: DamageSpec = null
	# Carga do instante do DISPARO. Guardada porque a explosão acontece segundos
	# depois e precisa valer o que o jogador carregou — ver `_explode`.
	var _carga := 0.0

	func _init(c: Node, orig: Vector3, d: Vector3, dmg: float, spec: DamageSpec = null) -> void:
		_spec = spec if spec != null else DamageSpec.avulso(dmg)
		caster = c
		global_position = orig
		dir = d.normalized()
		damage = dmg

	func _ready() -> void:
		if dir.length_squared() < 0.01:
			dir = Vector3(0, 0, -1)
		sun = FireFX._build_sun_model()
		add_child(sun)
		sun.scale = Vector3(0.1, 0.1, 0.1)

		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.1)
		light.light_energy = 0.0
		light.omni_range = 45.0
		add_child(light)

		var pm := FireFX._flame_proc(Vector3.UP, 180.0, 2.0, 8.0, Vector3(0, 4.0, 0), 0.5, 2.0, 1.0)
		var p_flames := FxUtil.particles(300, 0.8, false, pm, FxUtil.grain(0.8))
		add_child(p_flames)

		if get_tree() and get_tree().current_scene:
			AudioFX.whoosh(get_tree().current_scene, global_position, 0.4)
			var sfx := get_tree().current_scene.get_node_or_null("/root/ScreenFX")
			if sfx and sfx.has_method("flash"):
				sfx.flash(Color(1.0, 0.5, 0.1), 0.5)

	func setup_charge() -> void:
		# Posição alvo inicial acima do caster
		var target_pos := global_position + Vector3.UP * 7.5 + dir * 1.5
		if is_instance_valid(caster) and caster is Node3D:
			target_pos = caster.global_position + Vector3.UP * 7.5 + dir * 1.5
			
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "global_position", target_pos, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	func update_charge(charge_time: float) -> void:
		# Cresce de acordo com o charge_time.
		#
		# ⚠️ O SOL NUNCA CHEGAVA AO TAMANHO CHEIO (corrigido em 2026-08-21).
		# A conta era `clampf((charge_time * 0.5) / 3.0, 0, 1)`: com o tempo de
		# carga real de 3,5 s ela parava em 0,58, então a bola travava em 58% da
		# escala máxima e a carga completa lia igual a uma carga de 2 s. Eram dois
		# números pressupondo cargas diferentes — o `/ 3.0` vinha de quando a carga
		# durava 3 s, e o `* 0.5` ("velocidade reduzida pela metade") nunca foi
		# recalculado depois.
		#
		# Agora o divisor é o tempo de carga DA TABELA (`Balance`), que é o mesmo
		# que manda no dano — visual e dano passam a falar da mesma carga.
		if not is_instance_valid(sun) or fired: return
		var max_s = 3.5   # escala máxima da malha (não é tempo)
		var t_max: float = _spec.tempo_de_carga if _spec != null and _spec.tempo_de_carga > 0.0 else 3.5
		var ratio = clampf(charge_time / t_max, 0.0, 1.0)
		var s = lerpf(0.1, max_s, ratio)
		sun.scale = Vector3(s, s, s)
		
		if is_instance_valid(light):
			light.light_energy = lerpf(0.0, 40.0, ratio)
		
		if is_instance_valid(caster) and caster is Node3D:
			global_position = caster.global_position + Vector3.UP * (7.5 + s) + dir * 1.5
			caster.add_camera_shake(0.45)

	func _process(delta: float) -> void:
		elapsed += delta
		if is_instance_valid(sun):
			sun.rotation.y += 4.5 * delta
			sun.rotation.z += 1.8 * delta
		
		# Não atira mais automaticamente no elapsed >= 1.0
		# Só atira quando o MeraChargeNode chamar shoot()

		if fired:
			# ⚠️ O SOL E A HITBOX ANDAVAM EM RELÓGIOS DIFERENTES (2026-08-22).
			#
			# Aqui o controlador avançava `global_position += dir * 28 * delta` no
			# quadro OCIOSO, enquanto a `DamageZone` avança sozinha (`vel`) no quadro
			# de FÍSICA. Dois integradores com o mesmo número e passos diferentes
			# ficam juntos no papel e derivam na prática — e a 28 m/s por 3,5 s a
			# separação é visível: a explosão nascia onde estava o DESENHO, e o dano
			# tinha ficado para trás (ou à frente) do que o jogador viu.
			#
			# Agora a HITBOX é a fonte da verdade e o desenho a segue. Isso preserva
			# o conserto do commit `91f0929`: quem anda é a zona, então o
			# `_varrer_caminho` dela continua valendo e o sol não atravessa ninguém.
			if is_instance_valid(zone):
				global_position = zone.global_position
			else:
				global_position += dir * 28.0 * delta
			if elapsed >= 4.5 or _check_impact():
				_explode()

	func shoot(aim: Vector3, charge_time: float) -> void:
		fired = true
		_carga = charge_time
		elapsed = 0.0 # Reseta o tempo para a viagem
		print("🚀 [Dai Enkai: Entei] DISPARANDO O SOL com carga: ", charge_time)
		dir = aim.normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3(0, 0, -1)
		
		zone = DamageZone.new()
		if get_tree() and get_tree().current_scene:
			# ⚠️ Ia para `current_scene` e escapava do `clear_spawned_skills` (2026-08-22).
			FxUtil.mundo_de_skills(caster, get_tree().current_scene).add_child(zone)
			zone.global_position = global_position
			AudioFX.impact(get_tree().current_scene, global_position, 0.75)
			AudioFX.whoosh(get_tree().current_scene, global_position, 0.85)
		
		# ⚠️ ERA `damage * (1.0 + carga/3.0)` — a terceira curva de carregamento
		# diferente do jogo. Agora é a mesma interpolação das outras duas
		# (`DamageSpec.valor_do_hit`), com mínimo e máximo vindos da tabela.
		# O `area` continua crescendo com a carga: carga longa = knockback maior.
		var area = 7.5 + (charge_time * 2.0)
		zone.setup(_spec.valor_do_hit(charge_time), area, dir * 28.0, 3.5, caster, 3.5)
		zone.collided_with_any.connect(_on_zone_collided)
		_spec.marcar(zone)

	func _check_impact() -> bool:
		if elapsed < 1.15: return false
		if global_position.y <= 0.9: return true
		return false

	func _on_zone_collided(body: Node) -> void:
		if not is_instance_valid(self): return
		if body == caster: return
		if not is_processing(): return # Já explodiu
		_explode()

	func _explode() -> void:
		set_process(false)
		if is_instance_valid(zone):
			zone.queue_free()
		print("💥 [Dai Enkai: Entei] EXPLOSÃO SOLAR APOCALÍPTICA!")
		var world := get_tree().current_scene if get_tree() else null
		if is_instance_valid(world):
			AudioFX.impact(world, global_position, 0.5)
			AudioFX.snap(world, global_position, 0.7)
			var exp_sfx := world.get_node_or_null("/root/ScreenFX")
			if exp_sfx and exp_sfx.has_method("flash"):
				exp_sfx.flash(Color(1.0, 0.7, 0.2), 0.9)
			if is_instance_valid(caster) and caster.has_method("add_camera_shake"):
				caster.add_camera_shake(0.9)

			# Super Damage Zone da explosão final (raio 15 m).
			# ⚠️ O comentário dizia "raio de 18 metros" (corrigido em 2026-08-21):
			# 18 é o KNOCKBACK — o 2º argumento de `setup` —, e o raio é o 6º, 15,0.
			# ⚠️ Ia para `world` (a cena) e escapava do `clear_spawned_skills`
			# (2026-08-22) — golpe que continuava no mapa depois de trocar de fruta.
			var mundo_skills := FxUtil.mundo_de_skills(caster, world)
			var exp_zone := DamageZone.new()
			mundo_skills.add_child(exp_zone)
			exp_zone.global_position = global_position
			# A explosão fecha o golpe com o valor cheio da carga. Ela e o sol em voo
			# dividem o mesmo orçamento, então acertar com os dois não dobra.
			# ⚠️ O número escrito aqui era 384 (corrigido em 2026-08-21): o Entei
			# MUDOU do slot C para o V, e o teto do V é 768.
			# ⚠️ ERA `valor_do_hit(3.5)` — o MÁXIMO FIXO (corrigido em 2026-08-22).
			# A explosão valia carga cheia mesmo num toque de tecla, e como ela
			# sozinha já bate no teto do slot, CARREGAR NÃO MUDAVA NADA no dano. O
			# jogador segurava 3,5 s por espetáculo, não por poder. Agora vale a
			# carga que ele realmente segurou.
			exp_zone.setup(_spec.valor_do_hit(_carga), 18.0, Vector3.ZERO, 0.4, caster, 15.0)
			_spec.marcar(exp_zone)

			# Visual da explosão solar (Esfera de plasma de fogo expandindo)
			var exp_mesh := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0
			exp_mesh.mesh = sm
			exp_mesh.material_override = FxUtil.particle_material(Color(1.0, 0.65, 0.1), 8.0, false)
			mundo_skills.add_child(exp_mesh)
			exp_mesh.global_position = global_position
			var tw_exp := world.create_tween().set_parallel(true)
			tw_exp.tween_property(exp_mesh, "scale", Vector3(30.0, 30.0, 30.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_exp.tween_property(exp_mesh, "transparency", 1.0, 0.55)
			tw_exp.tween_callback(exp_mesh.queue_free).set_delay(0.6)

		queue_free()   # o `zone` já foi liberado no topo de `_explode`

