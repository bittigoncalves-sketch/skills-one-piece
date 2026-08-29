class_name ChamaLunar
extends RefCounted
# ============================================================================
#  A CHAMA DAS COSTAS DO LUNARIANO.
#
#  Pedido do dono (2026-08-29): "chama realista nas costas, literalmente uma
#  chama com animação". Caixa não serve — é a única característica de raça do
#  jogo que precisa se MEXER, e uma peça estática lia como uma placa laranja
#  colada nas costas.
#
#  ------------------------------------------------------- POR QUE NÃO O FireFX
#  O `FireFX` do jogo é para GOLPE: a entrada dele é `cast(world, origem,
#  direção, variante, dano, caster…)`, cria hitbox e morre sozinho. Esta chama é
#  passiva, permanente e não fere ninguém. O que se aproveita dele é a PALETA —
#  se a chama do Lunariano tivesse outras cores, ela leria como fogo de outro
#  jogo ao lado de um Hiken.
#
#  ⚠️ `local_coords = true`: as partículas acompanham o corpo. Em coordenadas de
#  mundo a chama ficaria para trás a cada passo e o rastro apareceria pendurado
#  no ar — bonito num lança-chamas, errado numa chama que É do personagem.
# ============================================================================

## A paleta do fogo do jogo (`FireFX.FLAME`), do núcleo quente à fumaça.
const NUCLEO := Color(1.00, 0.95, 0.50, 0.95)
const LARANJA := Color(1.00, 0.55, 0.10, 0.80)
const VERMELHO := Color(0.90, 0.15, 0.05, 0.40)
const SOME := Color(0.20, 0.05, 0.00, 0.00)


static func criar() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 0.9
	p.preprocess = 0.9          # já nasce acesa, em vez de "acender" ao aparecer
	p.local_coords = true
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 1.1
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.4, 0)          # fogo SOBE: gravidade invertida
	pm.scale_min = 0.10
	pm.scale_max = 0.26
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.34, 0.10, 0.06)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.55
	pm.turbulence_noise_scale = 2.2

	# A cor ao longo da vida: amarelo -> laranja -> vermelho -> some. É a rampa
	# que faz a chama parecer quente na base e esfriar na ponta.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
	grad.colors = PackedColorArray([NUCLEO, LARANJA, VERMELHO, SOME])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt

	# E encolher no fim, senão a chama termina em quadrados grandes e chapados.
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.35))
	curva.add_point(Vector2(0.30, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct

	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 1)
	quad.material = mat
	p.draw_pass_1 = quad
	return p
