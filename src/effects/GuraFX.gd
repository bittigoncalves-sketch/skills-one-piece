class_name GuraFX
extends RefCounted
## Gura Gura no Mi (Tremor) — o foco é KNOCKBACK massivo (jogar pra fora do mapa).
## Visual: ondas de choque (anéis que expandem), "bolha" de ar rachado branco-azulada,
## destroços e poeira. Reaproveita FxUtil/DamageZone/AudioFX. Knockback altíssimo.

const QUAKE := Color(0.85, 0.94, 1.0)   # branco-azulado (o ar rachando)
const DEBRIS := Color(0.55, 0.5, 0.45)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, charge: float = 0.0, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _punch(world, origin, dir.normalized(), damage, caster, charge, spec)
		1: _shockwave(world, dir, damage, caster, charge, spec) # `dir` agora carrega a posição absoluta do alvo (captura sísmica)
		2: _eruption(world, _ground(caster, dir, 5.0), damage, caster, charge, spec)
		_: _seaquake(world, _self_pos(caster), damage, caster, charge, spec)

# ---------- helpers ----------
static func _self_pos(caster: Node) -> Vector3:
	return (caster as Node3D).global_position + Vector3.UP * 1.0 if caster is Node3D else Vector3.ZERO

# Escreve a `custom_pose` do golpe e a apaga sozinha no fim.
#
# É o CONTRATO do projeto (`docs/frutas/gura_gura.md`): o efeito não toca
# animação, ele NOMEIA uma pose e o `ProceduralAnimator` desenha. Foi o que
# substituiu, em 2026-08-15, os três `play_baked` de clipes do Mixamo — e a troca
# não é de gosto: `_apply_baked` escreve a rotação de TODOS os papéis todo
# quadro e sai cedo da `update`, então durante o clipe a locomoção, o parkour, a
# mira e a recepção de dano simplesmente não existiam.
#
# `atraso` existe porque o estrago de alguns golpes é AGENDADO (tween de 0,25 ×
# mult no Z, 0,4 s no C): a pose precisa começar antes para o punho chegar junto
# com a onda. Ver `GuraPoses.Z_IMPACTO_EM`.
static func _pose(caster: Node, nome: String, duracao: float, atraso: float = 0.0) -> void:
	if not is_instance_valid(caster):
		return
	var arv := (caster as Node).get_tree()
	if arv == null:
		return
	var por := func() -> void:
		if not is_instance_valid(caster):
			return
		caster.set_meta("custom_pose", nome)
		arv.create_timer(duracao).timeout.connect(func() -> void:
			# ⚠️ SÓ limpa se a pose ainda for A NOSSA. O jogador encadeia golpes
			# (Z e depois C), e apagar a meta de quem entrou depois largaria o
			# corpo na pose errada — no limite, tiraria o T do V no meio da
			# ultimate. É a mesma guarda que o `YamiFX` usa no Kurouzu.
			if is_instance_valid(caster) and caster.get_meta("custom_pose", "") == nome:
				caster.remove_meta("custom_pose"))
	if atraso <= 0.0:
		por.call()
	else:
		arv.create_timer(atraso).timeout.connect(por)

static func _ground(caster: Node, dir: Vector3, dist: float) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = Vector3.FORWARD if flat.length_squared() < 0.001 else flat.normalized()
	var s: Vector3 = (caster as Node3D).global_position if caster is Node3D else Vector3.ZERO
	return s + flat * dist

# Anel de choque (torus deitado no chão) que expande e some.
static func _ring(parent: Node, start_r: float, end_r: float, color: Color, life: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = FxUtil.brilho(Color(color.r, color.g, color.b, 0.6), 2.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.scale = Vector3(start_r, 1.0, start_r)
	parent.add_child(mi)
	var tw := (parent as Node).create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(end_r, 1.0, end_r), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)

# Bolha de "ar rachado" (esfera translúcida que incha e some).
static func _bubble(parent: Node, radius: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = FxUtil.brilho(Color(QUAKE.r, QUAKE.g, QUAKE.b, 0.22), 1.2)
	mi.material_override = mat
	mi.scale = Vector3.ONE * 0.2
	parent.add_child(mi)
	var tw := (parent as Node).create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, life).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)

static func _debris(parent: Node, up_bias: float, amount: int) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, up_bias, 0)
	pm.spread = 65.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0, -22.0, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	pm.color_ramp = FxUtil.gradient([DEBRIS, QUAKE, Color(1, 1, 1, 0)])
	var p := FxUtil.particles(amount, 0.9, true, pm, FxUtil.grain(0.5), 1.0)
	parent.add_child(p)

# ---------- Z: Gura Punch — soco do tremor (onda pra frente) ----------
static func _punch(world: Node, origin: Vector3, fwd: Vector3, damage: float, caster: Node,
		charge: float = 0.0, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	# ⚠️ O `mult` MANDA NO ESPETÁCULO, NÃO NO DANO (mudou em 2026-08-21).
	# O Z da Gura não é carregável: ele é disparado pela investida (`Player.
	# _process_gura_rush`) sempre com `charge = 1.0`, o que fazia o `mult` valer
	# fixos 1,667 e multiplicar o dano por um número que ninguém escolheu. Raio da
	# onda, detritos e tremor de tela continuam escalando com ele.
	var mult: float = 1.0 + clampf(charge / 1.5, 0.0, 3.0)
	
	var delay: float = 0.25 * mult
	# O SOCO AUTORAL (`GuraPoses._z_soco`) no lugar do `right_upper_hook_from_guard`
	# do Mixamo. Começa ANTES do estrago, para o punho chegar junto com a onda.
	_pose(caster, "gura_z_soco", GuraPoses.Z_DURACAO, delay - GuraPoses.Z_IMPACTO_EM)
	var tw := world.create_tween()
	tw.tween_interval(delay)
	
	tw.tween_callback(func():
		if not is_instance_valid(world): return
		var atq_pos = origin if not is_instance_valid(caster) else (caster as Node3D).global_position + Vector3.UP * 1.0 + fwd * 1.5
		var zone := DamageZone.new()
		world.add_child(zone)
		zone.global_position = atq_pos
		_bubble(zone, 2.2 * mult, 0.4)
		_ring(zone, 0.6, 6.0 * mult, QUAKE, 0.5)
		_debris(zone, 0.4, int(40 * mult))
		GuraShatterMesh.spawn(zone, zone.global_position, 1.2 * mult)
		if Engine.has_singleton("ScreenShatterFX"):
			Engine.get_singleton("ScreenShatterFX").shatter(0.3 * mult, 0.5 * mult)
		elif world.get_node_or_null("/root/ScreenShatterFX"):
			world.get_node("/root/ScreenShatterFX").shatter(0.3 * mult, 0.5 * mult)
		AudioFX.impact(world, atq_pos, 0.7 * mult)
		
		# PASSO 5: Efeitos de Câmera (Leve zoom in no impacto, Desfoque Radial)
		var cam = world.get_viewport().get_camera_3d()
		if cam:
			pass
			# var orig_fov = cam.fov
			# cam.fov -= 12.0 # Leve zoom in
			# var tw_cam = cam.create_tween()
			# tw_cam.tween_property(cam, "fov", orig_fov, 0.4).set_trans(Tween.TRANS_EXPO)
			
		var sfx := world.get_node_or_null("/root/ScreenFX")
		if sfx and sfx.has_method("chromatic_pulse"):
			sfx.chromatic_pulse(1.5 * mult)
		if sfx and sfx.has_method("set_borrao"):
			sfx.set_borrao(0.8 * mult)
			var tw_fx = sfx.create_tween()
			tw_fx.tween_method(sfx.set_borrao, 0.8 * mult, 0.0, 0.4)
			
		zone.override_kb_dir = fwd
		zone.setup(spec.dano, 30.0 * mult, fwd * 22.0, 0.5, caster, 1.8 * mult)   # viaja + knockback ALTO
		spec.marcar(zone)
	)

# ---------- X: Esfera Sísmica (Projétil que explode no impacto) ----------
static func _shockwave(world: Node, target_pos: Vector3, damage: float, caster: Node,
		charge: float = 0.0, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	# O ARREMESSO AUTORAL no lugar do `punching.res` do Mixamo. A esfera nasce no
	# mesmo quadro do cast, então a pose começa já no arremesso (sem antecipação):
	# a puxada por cima do ombro é a CARGA, e ela já aconteceu no `gura_x_charge`.
	_pose(caster, "gura_x_arremesso", GuraPoses.X_DURACAO, 0.0)

	var mult: float = 1.0 + clampf(charge / 1.5, 0.0, 3.0)
	var fwd := Vector3.FORWARD
	var origin_pos := Vector3.ZERO
	if caster is Node3D:
		origin_pos = caster.global_position + Vector3.UP * 1.5
		fwd = (target_pos - origin_pos).normalized()
	
	# Cria a zona de dano atuando como projétil
	var proj := DamageZone.new()
	proj.is_projectile = true
	world.add_child(proj)
	var spawn_pos := origin_pos + fwd * 1.5
	proj.global_position = spawn_pos
	if fwd != Vector3.ZERO:
		proj.look_at(spawn_pos + fwd, Vector3.UP)
		
	# Spawn shatter effect vertically at the player's arm during launch
	GuraShatterMesh.spawn(world, spawn_pos, 1.5 * mult, fwd)
		
	# Adiciona o visual da esfera
	var orb = load("res://src/effects/SeismicOrb.gd").new()
	orb.charge = charge
	proj.add_child(orb)
	
	# Configura a hitbox móvel
	proj.setup(0.0, 0.0, fwd * 25.0, 4.0, caster, 3.2) # Raio do projétil dobrado (dano 0: quem fere é a explosão)
	
	# Intercepta colisões conectando ao sinal nativo `body_entered` para explodir
	proj.body_entered.connect(func(body: Node3D):
		if body == caster: return
		if not is_instance_valid(proj) or proj.vel == Vector3.ZERO: return
		
		# Parar o projétil
		proj.vel = Vector3.ZERO
		
		# Treme a esfera antes de explodir
		var tw = proj.create_tween()
		var s_mat = orb._orb_mesh.material_override as StandardMaterial3D
		if s_mat: tw.tween_property(s_mat, "albedo_color:a", 0.9, 0.15)
		tw.tween_interval(0.15)
		tw.tween_callback(func():
			if not is_instance_valid(world): return
			var pos = proj.global_position
			proj.queue_free() # Destroi o projétil
			
			var zone := DamageZone.new()
			world.add_child(zone)
			zone.global_position = pos
			
			var sfx := world.get_node_or_null("/root/ScreenFX")
			if sfx and sfx.has_method("chromatic_pulse"):
				sfx.chromatic_pulse(1.2 * mult)
				
			_ring(zone, 0.8 * mult, 9.0 * mult, QUAKE, 0.55)
			_ring(zone, 0.4 * mult, 6.0 * mult, Color(1, 1, 1), 0.4)
			_debris(zone, 0.6, int(60 * mult)) # Detritos massivos da explosão
			
			if Engine.has_singleton("ScreenShatterFX"):
				Engine.get_singleton("ScreenShatterFX").shatter(0.5 * mult, 0.6)
			elif world.get_node_or_null("/root/ScreenShatterFX"):
				world.get_node("/root/ScreenShatterFX").shatter(0.5 * mult, 0.6)
				
			AudioFX.impact(world, pos, 0.85 * mult)
			
			# O dano e knockback real da explosão
			# O dano vem da CURVA de carregamento da tabela (192 -> 256), a mesma
			# fórmula das outras duas skills carregáveis do jogo. `mult` continua
			# escalando só o tamanho da explosão.
			zone.setup(spec.valor_do_hit(charge), 34.0 * mult, Vector3.ZERO, 0.4, caster, 6.0 * mult)
			spec.marcar(zone)
		)
	)

# ---------- C: Eruption — o chão racha e ergue os inimigos ----------
static func _eruption(world: Node, pos: Vector3, damage: float, caster: Node,
		charge: float = 0.0, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var delay: float = 0.4
	# KABUTSUCHI AUTORAL. O clipe antigo era o `left_uppercut_from_guard` — um
	# gancho de BAIXO PARA CIMA enquanto o chão rachava, ou seja, a animação
	# contava a história ao contrário. Agora os braços descem sobre a cratera.
	_pose(caster, "gura_c_kabutsuchi", GuraPoses.C_DURACAO, delay - GuraPoses.C_IMPACTO_EM)
	var tw := world.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		if not is_instance_valid(world): return
		var zone := DamageZone.new()
		world.add_child(zone)
		zone.global_position = Vector3(pos.x, 0.2, pos.z)
		_bubble(zone, 3.0, 0.5)
		_ring(zone, 0.6, 7.0, QUAKE, 0.5)
		_debris(zone, 1.2, 90)                                    # muitos destroços PRA CIMA
		GuraShatterMesh.spawn(zone, zone.global_position, 1.8)
		if Engine.has_singleton("ScreenShatterFX"):
			Engine.get_singleton("ScreenShatterFX").shatter(0.6, 0.7)
		elif world.get_node_or_null("/root/ScreenShatterFX"):
			world.get_node("/root/ScreenShatterFX").shatter(0.6, 0.7)
		AudioFX.impact(world, zone.global_position, 0.9)
		zone.setup(spec.dano, 30.0, Vector3.ZERO, 0.5, caster, 5.0) # Erupção radial
		spec.marcar(zone)
	)

# ---------- V: Seaquake / Tsunamis Duplos (ultimate) ----------
static func _seaquake(world: Node, pos: Vector3, damage: float, caster: Node,
		charge: float = 0.0, spec: DamageSpec = null) -> void:
	var v_node = load("res://src/effects/GuraVNode.gd").new(caster, damage, spec)
	world.add_child(v_node)
	v_node.global_position = pos

# Removido: _exagerar_soco (Euler * escalar causava inversão de eixos (gimbal) e afetava o braço esquerdo acidentalmente)
