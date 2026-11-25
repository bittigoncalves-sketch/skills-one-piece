extends Node3D
# ============================================================================
#  VISÃO SUBMERSA (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E7).
#
#  Decisão do dono (14/10): a superfície continua OPACA; o investimento é a visão de
#  dentro d'água. Com a câmera submersa liga:
#   - cáusticas no fundo (`agua_causticas.gdshader`, soma de luz, prioridade 95);
#   - névoa da água + raios de luz (`agua_nevoa.gdshader`, prioridade 100 — depois do
#     `Contorno` (90), então as linhas do contorno somem na água junto com o resto);
#   - "neve marinha": partículas em suspensão em volta da câmera (sensação de volume);
#  e desliga a tinta chapada da `AguaHud` (ela lê o grupo "visao_submersa").
#
#  DESEMPENHO: tudo que SÓ existe debaixo d'água fica no grupo `SO_SUBMERSO` e é escondido
#  com a câmera fora d'água (a superfície opaca esconderia de qualquer jeito, mas a GPU
#  ainda processaria os vértices): blocos fundos do relevo, cascos e decoração dos
#  naufrágios. A troca acontece só quando o estado muda.
# ============================================================================

const CAUSTICAS := preload("res://src/historia/mar/agua_causticas.gdshader")
const NEVOA := preload("res://src/historia/mar/agua_nevoa.gdshader")
const SO_SUBMERSO := "so_submerso"
## Folga para dentro d'água: a câmera rente às ondas não pisca entre os dois mundos.
const FOLGA := 0.08

var relevo: RelevoMarinho
var submerso := false
var _causticas: MeshInstance3D
var _nevoa: MeshInstance3D
var _neve: GPUParticles3D
var _ciclo: Node
var _primeira := true


func ligar(campo: RelevoMarinho) -> void:
	relevo = campo
	add_to_group("visao_submersa")
	_causticas = _quadro("Causticas", CAUSTICAS, 95)
	_nevoa = _quadro("NevoaDaAgua", NEVOA, 100)
	_neve = _neve_marinha()
	_aplicar(false)


func _quadro(nome: String, shader: Shader, prioridade: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = prioridade
	mi.material_override = m
	# O vértice manda o quadro para a tela inteira: a caixa não pode ser cortada.
	mi.custom_aabb = AABB(Vector3(-100000, -100000, -100000), Vector3(200000, 200000, 200000))
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _neve_marinha() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "NeveMarinha"
	p.amount = 260
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20, -12, -20), Vector3(40, 24, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 9, 16)
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 4.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.95, 0.9, 0.55)
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _process(_delta: float) -> void:
	if relevo == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var sup := AguaDoMundo.superficie_em(c.x, c.z)
	var agora := not is_nan(sup) and c.y < sup - FOLGA
	if agora != submerso or _primeira:
		_primeira = false
		_aplicar(agora)
	if not submerso:
		return
	_neve.global_position = c
	var luz := 1.0
	var rumo := Vector3(0.3, 0.9, 0.2)
	if _ciclo == null or not is_instance_valid(_ciclo):
		_ciclo = _achar_ciclo()
	if _ciclo != null:
		var p: Dictionary = _ciclo.paleta()
		var sol := float(p.get("sol_energia", 1.75))
		var lua := float(p.get("lua_energia", 0.0))
		luz = clampf(0.3 + 0.7 * maxf(sol, lua * 0.9) / 1.75, 0.3, 1.0)
		var astro: Node3D = _ciclo.get("_sol") if sol >= lua else _ciclo.get("_lua")
		if astro != null:
			rumo = astro.global_basis.z.normalized()
	var mn := _nevoa.material_override as ShaderMaterial
	mn.set_shader_parameter("profundidade_camera", maxf(0.0, sup - c.y))
	mn.set_shader_parameter("luz", luz)
	mn.set_shader_parameter("rumo_sol", rumo)
	var mc := _causticas.material_override as ShaderMaterial
	mc.set_shader_parameter("nivel", sup)
	mc.set_shader_parameter("luz", luz)
	var oceano := get_tree().current_scene.get_node_or_null("Oceano") if get_tree().current_scene != null else null
	if oceano != null and oceano.get("material") != null:
		(oceano.get("material") as ShaderMaterial).set_shader_parameter("luz_submersa", luz)


func _aplicar(dentro: bool) -> void:
	submerso = dentro
	_causticas.visible = dentro
	_nevoa.visible = dentro
	_neve.visible = dentro
	_neve.emitting = dentro
	for n in get_tree().get_nodes_in_group(SO_SUBMERSO):
		(n as Node3D).visible = dentro


func _achar_ciclo() -> Node:
	var cena := get_tree().current_scene
	if cena == null:
		return null
	for n in cena.get_children():
		if n is CicloDiaNoite:
			return n
	return null
