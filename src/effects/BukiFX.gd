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
	_onda_de_aco(alvo)
	# Brilho de metal esquentando na saída e no retorno.
	var tw := arma.create_tween()
	tw.tween_property(arma, "scale", Vector3.ONE, 0.06).from(Vector3(0.15, 0.15, 0.15))
	tw.tween_interval(maxf(dur - 0.16, 0.0))
	tw.tween_property(arma, "scale", Vector3(0.1, 0.1, 0.1), 0.10)
	tw.tween_callback(arma.queue_free)

# O AÇO SE ESPALHANDO PELA PELE — é isto que faz a fruta ler como "o corpo virou
# arma" em vez de "apareceu uma arma na mão". Um anel incandescente desce pelo
# membro no instante da transformação, com fagulhas atrás.
#
# Fica preso ao MEMBRO (não ao mundo), então acompanha o braço no meio do golpe.
static func _onda_de_aco(membro: Node) -> void:
	if not (membro is Node3D):
		return
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.10
	toro.outer_radius = 0.19
	toro.rings = 12
	anel.mesh = toro
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.35, 0.9)
	m.emission_enabled = true
	m.emission = ACO_QUENTE
	m.emission_energy_multiplier = 5.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anel.material_override = m
	anel.rotation_degrees.x = 90.0        # o anel abraça o membro (eixo do braço)
	membro.add_child(anel)

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.ZERO
	pm.spread = 180.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.30
	pm.color_ramp = FxUtil.gradient(FAISCA)
	anel.add_child(FxUtil.particles(24, 0.30, true, pm, FxUtil.grain(0.05), 0.85))

	# Desce do ombro/quadril até a ponta e some.
	var tw := anel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anel, "position:y", -0.75, 0.18).from(0.05)
	tw.tween_property(anel, "scale", Vector3(1.5, 1.5, 1.5), 0.18).from(Vector3(0.4, 0.4, 0.4))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.20)
	tw.chain().tween_callback(anel.queue_free)

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

	# PROJÉTIL: bala de latão (metralhadora) ou bola de ferro (canhão). O raio
	# decide qual — o canhão usa 0.55, a metralhadora 0.22.
	var bola := raio > 0.4
	var corpo := MeshInstance3D.new()
	if bola:
		var esf := SphereMesh.new()
		esf.radius = raio * 0.62
		esf.height = raio * 1.24
		esf.radial_segments = 10
		esf.rings = 6
		corpo.mesh = esf
		var mf := StandardMaterial3D.new()
		mf.albedo_color = Color(0.13, 0.13, 0.15)     # ferro fosco
		mf.metallic = 0.9
		mf.roughness = 0.55
		corpo.material_override = mf
	else:
		var cap := CapsuleMesh.new()
		cap.radius = raio * 0.42
		cap.height = raio * 2.6
		cap.radial_segments = 8
		corpo.mesh = cap
		corpo.rotation_degrees.x = 90.0               # deitada no rumo do tiro
		var ml := StandardMaterial3D.new()
		ml.albedo_color = Color(0.86, 0.68, 0.28)     # latão
		ml.metallic = 1.0
		ml.roughness = 0.25
		ml.emission_enabled = true
		ml.emission = Color(1.0, 0.72, 0.30)
		ml.emission_energy_multiplier = 1.4
		corpo.material_override = ml
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
	var cano := _arma("metralhadora")
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
			# Tiro a tiro, com o pitch variando um pouco: rajada com pitch fixo
			# vira um zumbido só, e o ouvido para de contar os disparos.
			AudioFX.gunshot(world, o, randf_range(0.92, 1.12))
			_fogacho(world, o, d, 0.35)
			_capsulas(world, o, d)
		)

# ------------------------------------------------------------------- X: LÂMINA
static func _lamina(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var foice := _arma("lamina")
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
	var canhao := _arma("canhao")
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
	_fogacho(world, origin, dir, 1.0)
	AudioFX.cannon(world, origin, randf_range(0.94, 1.04))

# Fogacho na boca do cano. `escala` 1.0 = canhão, 0.35 = metralhadora.
static func _fogacho(world: Node, origin: Vector3, dir: Vector3, escala: float) -> void:
	if world == null or not world.is_inside_tree():
		return
	var fwd := dir.normalized()
	var flash := GPUParticles3D.new()
	flash.amount = int(40 * escala) + 8
	flash.lifetime = 0.18 + 0.22 * escala
	flash.one_shot = true
	flash.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 28.0
	pm.initial_velocity_min = 4.0 * escala
	pm.initial_velocity_max = 11.0 * escala
	pm.scale_min = 0.4 * escala
	pm.scale_max = 1.3 * escala
	pm.color_ramp = FxUtil.gradient(FAISCA)
	flash.process_material = pm
	flash.draw_pass_1 = SphereMesh.new()
	world.add_child(flash)
	(flash as Node3D).global_position = origin + fwd * 0.8
	world.get_tree().create_timer(1.2).timeout.connect(flash.queue_free)

	# LUZ DO DISPARO. É o que mais rende no fogacho: sem ela o clarão não toca no
	# personagem nem no chão, e o tiro parece um adesivo colado na tela. Vive
	# 0,07 s — arma de fogo pisca, não ilumina.
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.80, 0.45)
	luz.light_energy = 7.0 * escala + 1.5
	luz.omni_range = 5.0 + 7.0 * escala
	luz.shadow_enabled = false          # 6 tiros x sombra = tranco de frame
	world.add_child(luz)
	(luz as Node3D).global_position = origin + fwd * 0.7
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.07)
	tw.tween_callback(luz.queue_free)

	# FUMAÇA — cinza, lenta, subindo. Fica DEPOIS do clarão, senão some junto.
	var fumaca := GPUParticles3D.new()
	fumaca.amount = int(10 * escala) + 4
	fumaca.lifetime = 0.9 + 0.6 * escala
	fumaca.one_shot = true
	fumaca.emitting = true
	var fp := ParticleProcessMaterial.new()
	fp.direction = fwd + Vector3.UP * 0.5
	fp.spread = 40.0
	fp.initial_velocity_min = 0.6 * escala
	fp.initial_velocity_max = 2.2 * escala
	fp.gravity = Vector3(0, 0.7, 0)      # fumaça SOBE
	fp.scale_min = 0.5 * escala
	fp.scale_max = 1.8 * escala
	fp.color_ramp = FxUtil.gradient([
		Color(0.55, 0.55, 0.58, 0.55),
		Color(0.45, 0.45, 0.48, 0.30),
		Color(0.40, 0.40, 0.42, 0.0),
	])
	fumaca.process_material = fp
	fumaca.draw_pass_1 = FxUtil.grain(0.5)
	world.add_child(fumaca)
	(fumaca as Node3D).global_position = origin + fwd * 0.85
	world.get_tree().create_timer(2.5).timeout.connect(fumaca.queue_free)

# CÁPSULAS EJETADAS — só na metralhadora. Latão saltando pra direita e caindo.
# Detalhe pequeno, mas é o que dá CADÊNCIA visível à rajada: sem ele os 6 tiros
# viram um borrão só.
static func _capsulas(world: Node, origin: Vector3, dir: Vector3) -> void:
	if world == null or not world.is_inside_tree():
		return
	var lado := dir.normalized().cross(Vector3.UP).normalized()
	var p := GPUParticles3D.new()
	p.amount = 2
	p.lifetime = 1.1
	p.one_shot = true
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = lado + Vector3.UP * 0.9
	pm.spread = 18.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 3.6
	pm.gravity = Vector3(0, -9.0, 0)
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.scale_min = 0.5
	pm.scale_max = 0.7
	pm.color_ramp = FxUtil.gradient([
		Color(0.86, 0.68, 0.28, 1.0),
		Color(0.80, 0.62, 0.24, 1.0),
		Color(0.70, 0.55, 0.20, 0.0),
	])
	p.process_material = pm
	var casq := BoxMesh.new()
	casq.size = Vector3(0.035, 0.10, 0.035)
	p.draw_pass_1 = casq
	world.add_child(p)
	(p as Node3D).global_position = origin
	world.get_tree().create_timer(2.0).timeout.connect(p.queue_free)

# ------------------------------------------------------- V: ARSENAL COMPLETO
# Canhão -> metralhadora, TUDO teleguiado no inimigo mais próximo da mira.
# O que diferencia dos outros slots é exatamente isto: mira automática, dano e
# knockback maiores.
static func _arsenal_completo(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var alvo := alvo_da_mira(caster, origin, dir)

	# 1) canhão pesado
	var canhao := _arma("canhao")
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
			var cano := _arma("metralhadora")
			cano.scale = Vector3(1.2, 1.2, 1.2)
			_transformar(caster, lado, cano, 1.4)
		var o: Vector3 = caster.global_position + Vector3.UP * 1.0 if caster is Node3D else origin
		_rajada(world, o, dir, damage * 0.55, caster, 14, 0.08, 26.0, 7.0, alvo)
	)

# ============================================================================
#  ARMAS — agora são ASSETS (.glb), não geometria montada em código.
#
#  Modeladas em tools/blender/buki_weapons.py (Blender headless) e exportadas
#  pra assets/models/weapons/. Mexer na arte deixou de ser mexer em GDScript:
#  edita o script do Blender, roda, e o jogo pega o arquivo novo.
#
#  Os construtores voxel antigos continuam logo abaixo como PLANO B — se o .glb
#  sumir (clone sem os assets, import ainda não rodou), a fruta continua
#  jogável em vez de disparar arma invisível.
# ============================================================================
const ARMAS := {
	"metralhadora": "res://assets/models/weapons/buki_metralhadora.glb",
	"lamina": "res://assets/models/weapons/buki_lamina.glb",
	"canhao": "res://assets/models/weapons/buki_canhao.glb",
}

static var _cache_armas: Dictionary = {}

static func _arma(nome: String) -> Node3D:
	if not _cache_armas.has(nome):
		var caminho: String = ARMAS.get(nome, "")
		_cache_armas[nome] = load(caminho) if ResourceLoader.exists(caminho) else null
	var cena = _cache_armas[nome]
	if cena is PackedScene:
		var n := (cena as PackedScene).instantiate() as Node3D
		n.name = "Buki_" + nome
		return n
	# Plano B: a versão voxel montada em código.
	match nome:
		"metralhadora": return _voxel_metralhadora()
		"lamina": return _voxel_lamina()
		_: return _voxel_canhao()

# --------------------------------------------------------------- CONSTRUTORES
# PLANO B — armas em estilo voxel montadas em código (ver bloco acima).
static func _caixa(tam: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	return mi

static func _cil(raio: float, alt: float, pos: Vector3, mat: StandardMaterial3D,
		eixo := "z") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = alt
	c.radial_segments = 10          # facetado: combina com o resto do jogo
	mi.mesh = c
	mi.position = pos
	# CylinderMesh nasce ao longo de +Y; deitar em Z é o eixo de tiro (frente = −Z)
	if eixo == "z":
		mi.rotation_degrees.x = 90.0
	mi.material_override = mat
	return mi

# METRALHADORA — cano, camisa de refrigeração, tambor de munição e alça de mira.
# O tambor e as ranhuras da camisa são o que fazem ler como "metralhadora" em vez
# de "cano genérico"; sem eles vira um tubo.
static func _voxel_metralhadora() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiMetralhadora"
	var aco := _mat_aco()
	var escuro := _mat_escuro()
	var quente := _mat_aco(true)
	var y := -0.34                       # ponta do antebraço

	r.add_child(_caixa(Vector3(0.20, 0.17, 0.30), Vector3(0, y + 0.02, -0.08), escuro))  # culatra
	r.add_child(_cil(0.075, 0.60, Vector3(0, y, -0.42), aco))                            # cano
	for i in 5:                                                                          # camisa
		r.add_child(_cil(0.105, 0.028, Vector3(0, y, -0.22 - i * 0.085), escuro))
	r.add_child(_cil(0.055, 0.10, Vector3(0, y, -0.76), quente))                          # boca
	r.add_child(_cil(0.13, 0.10, Vector3(0, y - 0.13, -0.10), escuro, "y"))               # tambor
	r.add_child(_caixa(Vector3(0.02, 0.07, 0.02), Vector3(0, y + 0.13, -0.20), escuro))   # alça
	r.add_child(_caixa(Vector3(0.02, 0.05, 0.02), Vector3(0, y + 0.12, -0.62), escuro))   # massa
	return r

# LÂMINA — gume assimétrico (fio de um lado só), guarda e ricasso.
static func _voxel_lamina() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiLamina"
	var aco := _mat_aco()
	var gume := _mat_aco(true)
	var escuro := _mat_escuro()

	var corpo := _caixa(Vector3(0.055, 0.98, 0.17), Vector3(0, -0.78, -0.06), aco)
	corpo.rotation_degrees.x = -6.0          # leve curvatura de sabre
	r.add_child(corpo)
	var fio := _caixa(Vector3(0.018, 0.96, 0.05), Vector3(0, -0.78, -0.155), gume)
	fio.rotation_degrees.x = -6.0
	r.add_child(fio)
	r.add_child(_caixa(Vector3(0.10, 0.16, 0.10), Vector3(0, -0.30, -0.02), escuro))   # ricasso
	r.add_child(_caixa(Vector3(0.24, 0.035, 0.10), Vector3(0, -0.37, -0.04), escuro))  # guarda
	r.add_child(_caixa(Vector3(0.06, 0.16, 0.09), Vector3(0, -1.24, -0.12), gume))     # ponta
	return r

# CANHÃO — boca alargada, aros de reforço e câmara. É a peça mais pesada da
# fruta, então a silhueta tem que ler como grossa mesmo de longe.
static func _voxel_canhao() -> Node3D:
	var r := Node3D.new()
	r.name = "BukiCanhao"
	var aco := _mat_aco()
	var escuro := _mat_escuro()
	var boca := _mat_aco(true)
	var y := -0.30

	r.add_child(_cil(0.19, 0.30, Vector3(0, y, -0.06), escuro))        # câmara (traseira)
	r.add_child(_cil(0.155, 0.56, Vector3(0, y, -0.44), aco))          # corpo do cano
	for i in 3:                                                        # aros de reforço
		r.add_child(_cil(0.185, 0.05, Vector3(0, y, -0.26 - i * 0.20), escuro))
	r.add_child(_cil(0.215, 0.14, Vector3(0, y, -0.78), aco))          # boca alargada
	r.add_child(_cil(0.145, 0.06, Vector3(0, y, -0.83), boca))         # interior quente
	r.add_child(_caixa(Vector3(0.10, 0.16, 0.10), Vector3(0, y - 0.17, -0.14), escuro))  # punho
	return r

static func _mat_escuro() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.20, 0.21, 0.24)
	m.metallic = 0.85
	m.roughness = 0.45
	return m
