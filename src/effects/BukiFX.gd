class_name BukiFX
extends RefCounted
# ============================================================================
#  BUKI FX — Buki Buki no Mi (fruta da Baby 5). Paramecia: o corpo vira arma.
#
#  REGRA DA FRUTA (definida pelo usuário): a transformação é INSTANTÂNEA NO
#  GOLPE — o membro vira arma, dispara, e volta ao normal. Nada fica ativo
#  entre golpes. Isso encaixa na tríade do Gomu Pistol (padrão-ouro do projeto):
#  a arma nasce no wind-up, cospe no release, e some no recovery.
#
#  SKILLS:
#   Z: Metralhadora — antebraço vira cano, rajada curta pra frente.
#   X: Lâmina — antebraço vira foice, golpe em arco corpo-a-corpo.
#   C: Canhão de Perna — joelho vira canhão; tiro pesado + RECUO que empurra
#      o conjurador pra trás (vira mobilidade).
#   V: Arsenal Completo — canhão primeiro, metralhadora depois, e TODOS os
#      disparos são TELEGUIADOS no inimigo mais próximo da mira. Dano e
#      knockback maiores. É isso que separa o V dos outros slots.
# ============================================================================

const ACO := Color(0.74, 0.78, 0.84)
const ACO_QUENTE := Color(1.0, 0.72, 0.30)
const FAISCA := [
	Color(1.0, 0.95, 0.7, 1.0),
	Color(1.0, 0.7, 0.25, 0.9),
	Color(0.7, 0.35, 0.1, 0.4),
	Color(0.3, 0.3, 0.3, 0.0),
]

const ALCANCE_MIRA := 60.0     # alcance da busca de alvo teleguiado
const CONE_MIRA := 0.82        # cos do cone de aquisição (~35°)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float, caster: Node) -> void:
	match variant:
		0: _metralhadora(world, origin, dir, damage, caster)
		1: _lamina(world, origin, dir, damage, caster)
		2: _canhao_de_perna(world, origin, dir, damage, caster)
		_: _arsenal_completo(world, origin, dir, damage, caster)

# ----------------------------------------------------------------- MATERIAIS
static func _mat_aco(emissivo: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = ACO
	m.metallic = 0.95
	m.roughness = 0.28
	if emissivo:
		m.emission_enabled = true
		m.emission = ACO_QUENTE
		m.emission_energy_multiplier = 2.2
	return m

# ------------------------------------------------------- ANEXO NO MEMBRO
# Acha o membro no rig e pendura a arma nele. Funciona nos dois tipos de
# personagem: no voxel os papéis são nós; no skinnado o BodyScanner criou
# proxies com os mesmos nomes (ver src/anim/SkeletonDriver.gd).
static func _membro(caster: Node, papel: String) -> Node3D:
	if caster == null:
		return null
	var m = caster.get("_char_model")
	if m is Node3D:
		var n = (m as Node3D).find_child(papel, true, false)
		if n is Node3D:
			return n
	# Fallback: procura o papel em qualquer lugar sob o conjurador. Cobre quem
	# guarda o modelo com outro nome e o caso do rig skinnado (proxies).
	var d = caster.find_child(papel, true, false)
	return d as Node3D if d is Node3D else null

# Cria a arma no membro, deixa viva por `dur` e some (transformação instantânea).
static func _transformar(caster: Node, papel: String, arma: Node3D, dur: float) -> void:
	var membro := _membro(caster, papel)
	var alvo: Node = membro if membro else (caster.get_tree().current_scene if caster else null)
	if alvo == null:
		return
	alvo.add_child(arma)
	# Brilho de metal esquentando na saída e no retorno.
	var tw := arma.create_tween()
	tw.tween_property(arma, "scale", Vector3.ONE, 0.06).from(Vector3(0.15, 0.15, 0.15))
	tw.tween_interval(maxf(dur - 0.16, 0.0))
	tw.tween_property(arma, "scale", Vector3(0.1, 0.1, 0.1), 0.10)
	tw.tween_callback(arma.queue_free)

# ------------------------------------------------------------ ALVO TELEGUIADO
# Inimigo mais próximo da MIRA (não o mais próximo do corpo) — o V trava nele.
static func alvo_da_mira(caster: Node, origin: Vector3, dir: Vector3) -> Node3D:
	if caster == null or not caster.is_inside_tree():
		return null
	var fwd := dir.normalized()
	var best: Node3D = null
	var best_align := CONE_MIRA
	for e in caster.get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or e == caster:
			continue
		var to: Vector3 = (e.global_position + Vector3.UP * 0.6) - origin
		var d := to.length()
		if d > ALCANCE_MIRA or d < 0.5:
			continue
		var align := fwd.dot(to / d)
		if align > best_align:
			best_align = align
			best = e
	return best

# ------------------------------------------------------------------ PROJÉTIL
# `alvo` != null -> teleguiado: corrige o rumo por frame até acertar.
static func _projetil(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, raio: float, velocidade: float, kb: float, alvo: Node3D) -> void:
	var fwd := dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	zone.setup(damage, kb, fwd * velocidade, 3.0, caster, raio)

	var corpo := MeshInstance3D.new()
	var malha := CapsuleMesh.new()
	malha.radius = raio * 0.6
	malha.height = raio * 3.0
	corpo.mesh = malha
	corpo.rotation_degrees.x = 90.0   # capsula deitada no rumo do tiro
	corpo.material_override = _mat_aco(true)
	zone.add_child(corpo)

	var rastro := GPUParticles3D.new()
	rastro.amount = 18
	rastro.lifetime = 0.35
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.ZERO
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.7
	pm.color_ramp = FxUtil.gradient(FAISCA)
	rastro.process_material = pm
	rastro.draw_pass_1 = SphereMesh.new()
	zone.add_child(rastro)

	if alvo != null and is_instance_valid(alvo):
		_perseguir(zone, alvo, velocidade)

# Correção de rumo por frame. Fica na própria zona (morre junto com ela).
static func _perseguir(zone: Node3D, alvo: Node3D, velocidade: float) -> void:
	var t := Timer.new()
	t.wait_time = 0.02
	t.autostart = true
	zone.add_child(t)
	t.timeout.connect(func():
		if not is_instance_valid(alvo) or not is_instance_valid(zone):
			return
		var para: Vector3 = (alvo.global_position + Vector3.UP * 0.6) - zone.global_position
		if para.length() < 0.05:
			return
		# vira devagar pro alvo: teleguiado, não instantâneo (dá pra desviar)
		var novo: Vector3 = zone.vel.normalized().slerp(para.normalized(), 0.25)
		zone.vel = novo * velocidade
		zone.look_at(zone.global_position + novo, Vector3.UP)
	)

# ------------------------------------------------------------------- Z: METRA
static func _metralhadora(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var cano := _construir_metralhadora()
	_transformar(caster, "ForeArm_R", cano, 0.9)
	_rajada(world, origin, dir, damage, caster, 6, 0.07, 22.0, 5.0, null)
	AudioFX.whoosh(world, origin)

# Dispara `n` tiros espaçados no tempo, com dispersão.
static func _rajada(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, n: int, intervalo: float, velocidade: float, kb: float,
		alvo: Node3D) -> void:
	if not (world is Node) or not world.is_inside_tree():
		return
	for i in n:
		var atraso := i * intervalo
		world.get_tree().create_timer(atraso).timeout.connect(func():
			if not is_instance_valid(caster) or not is_instance_valid(world):
				return
			var o: Vector3 = caster.global_position + Vector3.UP * 1.0 if caster is Node3D else origin
			# dispersão pequena; teleguiado corrige depois
			var d := dir.normalized()
			d += Vector3(randf_range(-0.05, 0.05), randf_range(-0.04, 0.04), randf_range(-0.05, 0.05))
			_projetil(world, o, d, damage, caster, 0.22, velocidade, kb, alvo)
		)

# ------------------------------------------------------------------- X: LÂMINA
static func _lamina(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var foice := _construir_lamina()
	_transformar(caster, "ForeArm_R", foice, 0.5)

	# Golpe em ARCO: zona curta que varre à frente do conjurador.
	var fwd := dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin + fwd * 1.4
	zone.setup(damage, 9.0, fwd * 3.0, 0.28, caster, 1.9)

	# Rastro do corte: um leque fino que abre e some.
	var corte := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(3.4, 1.5)
	corte.mesh = plano
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.97, 1.0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.8, 0.9, 1.0)
	m.emission_energy_multiplier = 3.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	corte.material_override = m
	corte.rotation_degrees = Vector3(90, 0, 25)
	zone.add_child(corte)
	var tw := corte.create_tween()
	tw.tween_property(corte, "rotation_degrees:z", -35.0, 0.22)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.26)
	AudioFX.whoosh(world, origin)

# --------------------------------------------------------- C: CANHÃO DE PERNA
static func _canhao_de_perna(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var canhao := _construir_canhao()
	_transformar(caster, "Shin_R", canhao, 0.8)
	_tiro_de_canhao(world, origin, dir, damage, caster, 12.0, null)

	# RECUO: o tranco empurra o conjurador pra trás — o tiro vira mobilidade.
	if caster is CharacterBody3D:
		var recuo: Vector3 = -dir.normalized() * 11.0 + Vector3.UP * 3.5
		(caster as CharacterBody3D).velocity += recuo
	if caster and caster.has_method("add_camera_shake"):
		caster.add_camera_shake(0.55)

static func _tiro_de_canhao(world: Node, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, kb: float, alvo: Node3D) -> void:
	_projetil(world, origin, dir, damage, caster, 0.55, 16.0, kb, alvo)
	# fogacho na boca do cano
	var flash := GPUParticles3D.new()
	flash.amount = 40
	flash.lifetime = 0.4
	flash.one_shot = true
	flash.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir.normalized()
	pm.spread = 28.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 11.0
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	pm.color_ramp = FxUtil.gradient(FAISCA)
	flash.process_material = pm
	flash.draw_pass_1 = SphereMesh.new()
	world.add_child(flash)
	(flash as Node3D).global_position = origin + dir.normalized() * 0.8
	world.get_tree().create_timer(1.2).timeout.connect(flash.queue_free)
	AudioFX.impact(world, origin)

# ------------------------------------------------------- V: ARSENAL COMPLETO
# Canhão -> metralhadora, TUDO teleguiado no inimigo mais próximo da mira.
# O que diferencia dos outros slots é exatamente isto: mira automática, dano e
# knockback maiores.
static func _arsenal_completo(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var alvo := alvo_da_mira(caster, origin, dir)

	# 1) canhão pesado
	var canhao := _construir_canhao()
	canhao.scale = Vector3(1.35, 1.35, 1.35)
	_transformar(caster, "Shin_R", canhao, 0.7)
	_tiro_de_canhao(world, origin, dir, damage * 1.6, caster, 20.0, alvo)
	if caster is CharacterBody3D:
		(caster as CharacterBody3D).velocity += -dir.normalized() * 8.0 + Vector3.UP * 2.5
	if caster and caster.has_method("add_camera_shake"):
		caster.add_camera_shake(0.9)

	# 2) metralhadora logo depois, nas DUAS mãos
	if not world.is_inside_tree():
		return
	world.get_tree().create_timer(0.55).timeout.connect(func():
		if not is_instance_valid(caster) or not is_instance_valid(world):
			return
		for lado in ["ForeArm_L", "ForeArm_R"]:
			var cano := _construir_metralhadora()
			cano.scale = Vector3(1.2, 1.2, 1.2)
			_transformar(caster, lado, cano, 1.4)
		var o: Vector3 = caster.global_position + Vector3.UP * 1.0 if caster is Node3D else origin
		_rajada(world, o, dir, damage * 0.55, caster, 14, 0.08, 26.0, 7.0, alvo)
	)

# --------------------------------------------------------------- CONSTRUTORES
# Armas em estilo voxel, no mesmo idioma dos modelos do jogo.
static func _caixa(tam: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	return mi

static func _construir_metralhadora() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiMetralhadora"
	var aco := _mat_aco()
	var quente := _mat_aco(true)
	# a arma cresce a partir da PONTA do antebraço, apontando pra frente (-Z)
	r.add_child(_caixa(Vector3(0.16, 0.16, 0.62), Vector3(0, -0.34, -0.30), aco))
	r.add_child(_caixa(Vector3(0.09, 0.09, 0.22), Vector3(0, -0.34, -0.68), quente))
	r.add_child(_caixa(Vector3(0.22, 0.10, 0.20), Vector3(0, -0.28, -0.10), aco))
	return r

static func _construir_lamina() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiLamina"
	var aco := _mat_aco()
	var gume := _mat_aco(true)
	r.add_child(_caixa(Vector3(0.07, 0.95, 0.16), Vector3(0, -0.72, -0.10), aco))
	r.add_child(_caixa(Vector3(0.03, 0.95, 0.05), Vector3(0, -0.72, -0.19), gume))
	r.add_child(_caixa(Vector3(0.16, 0.12, 0.22), Vector3(0, -0.30, -0.04), aco))
	return r

static func _construir_canhao() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiCanhao"
	var aco := _mat_aco()
	var boca := _mat_aco(true)
	r.add_child(_caixa(Vector3(0.30, 0.30, 0.70), Vector3(0, -0.30, -0.34), aco))
	r.add_child(_caixa(Vector3(0.38, 0.38, 0.14), Vector3(0, -0.30, -0.70), boca))
	r.add_child(_caixa(Vector3(0.34, 0.34, 0.16), Vector3(0, -0.30, -0.02), aco))
	return r
