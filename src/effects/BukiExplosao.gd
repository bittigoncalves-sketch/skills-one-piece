class_name BukiExplosao
extends RefCounted
# ============================================================================
#  EXPLOSÕES DA BUKI BUKI (22/11/2026)
#
#  Pedido do dono: bala que bate em algo explode PEQUENO; o tiro do canhão explode
#  GRANDE. Este arquivo só desenha (clarão, bola de fogo, fagulhas, fumaça, anel
#  de choque) e, no grande, aplica o dano em área — quem DECIDE explodir é a
#  `BalaDaBuki`, que roda em todos os peers (a explosão é visual em todos; o dano
#  em área só nasce no servidor).
#
#  Tudo nasce como filho do mundo e some sozinho (`autofree`): a auditoria de
#  vazamento de nós de `tools/dev_tests/test_frutas.gd` continua em zero.
# ============================================================================

const RAIO_PEQUENA := 0.9
const RAIO_GRANDE := 5.0
# Dano em área do canhão = fração do dano do tiro. Sem teto de conjuração (a área
# não divide o orçamento do pente: o pente do canhão tem 3 tiros e dividir o teto
# em 6 zonas tiraria dano do tiro direto). Por isso é só uma fração.
const FRACAO_DANO_AREA := 0.5
const KB_AREA := 22.0

const FOGO := [
	Color(1.0, 0.95, 0.75, 1.0),
	Color(1.0, 0.62, 0.18, 0.95),
	Color(0.75, 0.25, 0.06, 0.55),
	Color(0.18, 0.16, 0.15, 0.0),
]
const FUMACA := [
	Color(0.35, 0.33, 0.32, 0.55),
	Color(0.22, 0.21, 0.21, 0.30),
	Color(0.15, 0.15, 0.15, 0.0),
]


## Explosão visual. `grande` = canhão. `normal` aponta para fora da superfície.
static func visual(world: Node, pos: Vector3, grande: bool, normal: Vector3 = Vector3.UP) -> void:
	if world == null or not world.is_inside_tree():
		return
	var k := 1.0 if grande else 0.22
	_bola_de_fogo(world, pos, k, grande)
	_fagulhas(world, pos, k, normal, grande)
	if grande:
		_fumaca(world, pos, k)
		_anel(world, pos, RAIO_GRANDE * 0.9, 0.38)
	else:
		_anel(world, pos, RAIO_PEQUENA * 1.3, 0.16)
	_luz(world, pos, 3.5 if grande else 1.2, 0.30 if grande else 0.10, 10.0 if grande else 2.5)
	if grande:
		AudioFX.impact(world, pos, 0.55)
		AudioFX.cannon(world, pos, 0.7)
	else:
		AudioFX.impact(world, pos, randf_range(1.2, 1.5))


## Dano em área do canhão (SÓ no servidor). `ja_acertado` é o corpo que já levou o
## tiro direto: não leva de novo. Devolve a zona (ou null) para os testes.
static func area(world: Node, pos: Vector3, dano_do_tiro: float, caster: Node,
		ja_acertado: Node = null) -> DamageZone:
	if world == null or not world.is_inside_tree():
		return null
	var zona := DamageZone.new()
	world.add_child(zona)
	zona.global_position = pos
	zona.setup(dano_do_tiro * FRACAO_DANO_AREA, KB_AREA, Vector3.ZERO, 0.12, caster, RAIO_GRANDE)
	zona.exige_linha_de_visao = true
	zona.origem_linha_de_visao = pos + Vector3.UP * 0.2
	if ja_acertado != null:
		zona._hit[ja_acertado] = true
	DestruicaoDeEstruturas.golpe(world.get_tree(), pos, RAIO_GRANDE * 0.6)   # o canhão derruba construções
	return zona


# ------------------------------------------------------------------ peças
static func _bola_de_fogo(world: Node, pos: Vector3, k: float, grande: bool) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.5 * (1.0 + 3.0 * k)
	pm.initial_velocity_max = 4.0 * (1.0 + 3.0 * k)
	pm.gravity = Vector3(0, 1.2, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6 * k + 0.12
	pm.scale_max = 1.8 * k + 0.25
	pm.color_ramp = FxUtil.gradient(FOGO)
	var p := FxUtil.particles(34 if grande else 8,
		0.55 if grande else 0.22, true, pm, FxUtil.grain(1.0), 0.9, "essencial")
	p.material_override = FxUtil.particle_material(Color(1.0, 0.5, 0.12), 4.0, true)
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	FxUtil.autofree(p, p.lifetime + 0.5)


static func _fagulhas(world: Node, pos: Vector3, k: float, normal: Vector3, grande: bool) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = normal.normalized() if normal.length() > 0.1 else Vector3.UP
	pm.spread = 70.0 if not grande else 120.0
	pm.initial_velocity_min = 3.0 + 6.0 * k
	pm.initial_velocity_max = 7.0 + 14.0 * k
	pm.gravity = Vector3(0, -12.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color_ramp = FxUtil.gradient(FOGO)
	var p := FxUtil.particles(36 if grande else 9,
		0.7 if grande else 0.4, true, pm, FxUtil.grain(0.09), 0.95, "essencial")
	p.material_override = FxUtil.particle_material(Color(1.0, 0.75, 0.3), 3.0, true)
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	FxUtil.autofree(p, p.lifetime + 0.5)


static func _fumaca(world: Node, pos: Vector3, k: float) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 1.0 * k + 0.4
	pm.scale_max = 2.4 * k + 0.6
	pm.color_ramp = FxUtil.gradient(FUMACA)
	var p := FxUtil.particles(16, 1.4, true, pm, FxUtil.grain(1.0), 0.8)
	world.add_child(p)
	p.global_position = pos + Vector3.UP * 0.6
	p.emitting = true
	FxUtil.autofree(p, p.lifetime + 0.5)


# Onda de choque: disco aditivo (billboard, gradiente radial) que cresce e some. Era uma esfera: o contorno do jogo a desenhava como bolhas azuis.
static func _anel(world: Node, pos: Vector3, raio: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mi.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.8, 0.45, 0.0), Color(1.0, 0.7, 0.3, 0.55), Color(1.0, 0.5, 0.15, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = Color(1, 1, 1, 1)
	mi.material_override = m
	mi.scale = Vector3.ONE * 0.2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * raio, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)


static func _luz(world: Node, pos: Vector3, raio: float, dur: float, energia: float) -> void:
	if not FxQuality.permite_luz("essencial"):
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = energia
	l.omni_range = raio * 3.0
	world.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)
