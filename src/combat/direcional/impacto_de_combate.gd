class_name ImpactoDeCombate
extends RefCounted
# ============================================================================
#  IMPACTO VISUAL DO COMBATE DIRECIONAL — o que se VÊ no ponto do contato.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D9, Fase 6). Só apresentação: nasce do
#  sinal `contato` (uma vez por contato, no lado de quem bateu) e nunca decide nada.
#
#  A hierarquia é de LEITURA, não de enfeite — num combate de guarda o jogador
#  precisa distinguir num relance o que aconteceu:
#    • ACERTO ..... borrifo quente no sentido do golpe + clarão curto
#    • BLOQUEIO ... sopro frio e contido, sem clarão (defesa não comemora)
#    • APARO ...... clarão claro com anel — a deixa "agora é a sua vez"
#    • QUEBRA ..... estouro alaranjado com anel largo — a guarda caiu
#  Estética própria do boxe (poeira/suor e estalo), não a de fruta nenhuma.
#  Quantidades passam pelo `FxQuality` (orçamento por aparelho).
# ============================================================================

const COR_ACERTO := Color(1.0, 0.92, 0.76, 1.0)
const COR_BLOQUEIO := Color(0.70, 0.77, 0.86, 0.85)
const COR_APARO := Color(1.0, 0.98, 0.82, 1.0)
const COR_QUEBRA := Color(1.0, 0.62, 0.30, 1.0)
const VIDA := 0.6


## `direcao`: para onde o golpe viajava (no mundo). `pesado`: golpe pesado cresce.
static func criar(mundo: Node, pos: Vector3, direcao: Vector3, resultado: int, pesado: bool) -> void:
	if mundo == null or not is_instance_valid(mundo) or not mundo.is_inside_tree():
		return
	var palco := Node3D.new()
	palco.name = "ImpactoDeCombate"
	mundo.add_child(palco)
	palco.global_position = pos
	var dir := Vector3(direcao.x, 0.0, direcao.z).normalized()
	if dir.length_squared() < 0.5:
		dir = Vector3.FORWARD
	palco.look_at(pos + dir, Vector3.UP)   # −Z local = sentido do golpe
	var escala := 1.35 if pesado else 1.0
	match resultado:
		ResolucaoDeContato.Resultado.ACERTO:
			_borrifo(palco, COR_ACERTO, int(10 * escala), 0.24, 2.2 * escala, 5.0 * escala, 0.055 * escala, 38.0)
			_clarao(palco, COR_ACERTO, 0.09, 0.9 * escala, 0.35)
		ResolucaoDeContato.Resultado.BLOQUEIO:
			_borrifo(palco, COR_BLOQUEIO, 6, 0.18, 1.0, 2.6, 0.045, 60.0)
		ResolucaoDeContato.Resultado.APARO:
			_clarao(palco, COR_APARO, 0.12, 1.2, 0.18)
			_anel(palco, COR_APARO, 0.95, 0.18)
			_borrifo(palco, COR_APARO, 8, 0.2, 3.0, 6.0, 0.035, 80.0)
		ResolucaoDeContato.Resultado.QUEBRA_DE_GUARDA:
			_borrifo(palco, COR_QUEBRA, 14, 0.3, 1.8, 4.5, 0.06, 70.0)
			_anel(palco, COR_QUEBRA, 1.4, 0.24)
	FxUtil.autofree(palco, VIDA)


# ------------------------------------------------------------------ camadas
## Partículas num cone ao redor do sentido do golpe (−Z do palco).
static func _borrifo(palco: Node3D, cor: Color, quantidade: int, vida: float,
		v_min: float, v_max: float, tamanho: float, abertura: float) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.15, -1)
	pm.spread = abertura
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.damping_min = 6.0
	pm.damping_max = 9.0
	pm.gravity = Vector3(0, -4.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color_ramp = FxUtil.gradient([cor, Color(cor.r, cor.g, cor.b, 0.0)])
	var p := FxUtil.particles(quantidade, vida, true, pm, FxUtil.grain(tamanho), 0.95)
	p.material_override = FxUtil.particle_material(Color.WHITE, 1.4, true)
	palco.add_child(p)


## Disco achatado de frente para o golpe que cresce e some.
static func _clarao(palco: Node3D, cor: Color, duracao: float, tamanho: float, achatamento: float) -> void:
	var mi := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.12
	esfera.height = 0.24
	esfera.radial_segments = 16
	esfera.rings = 8
	mi.mesh = esfera
	var mat := FxUtil.mesh_emissive_material(cor, 6.0, true)
	mi.material_override = mat
	mi.scale = Vector3(0.4, 0.4, 0.4 * achatamento)
	palco.add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(tamanho, tamanho, tamanho * achatamento), duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao * 1.3)


## Anel perpendicular ao golpe.
static func _anel(palco: Node3D, cor: Color, tamanho: float, duracao: float) -> void:
	var mi := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.82
	toro.outer_radius = 1.0
	toro.rings = 32
	toro.ring_segments = 6
	mi.mesh = toro
	var mat := FxUtil.mesh_emissive_material(cor, 5.0, true)
	mi.material_override = mat
	mi.rotation.x = PI * 0.5   # eixo do toro (Y) vira o sentido do golpe (Z)
	mi.scale = Vector3.ONE * 0.08
	palco.add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * tamanho * 0.35, duracao) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao)
