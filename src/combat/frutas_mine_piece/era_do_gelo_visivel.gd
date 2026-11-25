extends Node3D
## Ice Age (V da Hie Mine Piece) — a parte VISÍVEL. O dano continua em `hie.gd` (`_ataque_gelo`); aqui só se desenha.
##
## Por que existe (15/11/2026): a técnica funcionava mas quase não se via — a expansão dura ~8 ticks (0,4 s) e o único
## desenho era uma placa translúcida (alfa 0,42) no chão. Agora o raio que o dano cobre a cada tick vira, na tela:
##   • um DISCO de geada (textura de rachaduras do `EraDoGelo`) que cresce junto com o dano e fica ~3 s;
##   • CRISTAIS de gelo que nascem onde a frente de gelo passa e SOBEM do chão (mais altos na borda);
##   • um ANEL de choque a cada tick de expansão e NÉVOA fria subindo;
##   • uma luz ciano que estoura e apaga.
## Tudo some em fade no fim. Quem chama: `set_raio(metros)` a cada tick e `encerrar()` quando a técnica acaba.

const MUNDO_MASCARA := 1
const CRISTAIS := 110
const DURACAO_APOS_FIM := 3.2     # s que o gelo fica depois que o dano para de crescer
const FADE := 1.1                 # s de desbotar no fim
const COR_CRISTAL := Color(0.62, 0.86, 1.0, 0.9)
const EMISSAO_DISCO := 0.65       # era 1,4: o centro virava uma mancha branca
const PROFUNDO := Color(0.30, 0.58, 0.92, 1.0)   # cada cristal sorteia um tom entre este azul fundo e o claro: menos "azul chapado"

var _raio := 0.0                  # raio do dano agora (m)
var _raio_final := 10.0          # raio que o dano alcança no último tick (m): é nele que os cristais são distribuídos
var _idade := 0.0
var _fim_em := -1.0               # idade em que `encerrar()` foi chamado
var _disco: MeshInstance3D
var _mat_disco: StandardMaterial3D
var _cristais: MultiMeshInstance3D
var _mm: MultiMesh
var _mat_cristal: StandardMaterial3D
var _luz: OmniLight3D
var _nevoa: GPUParticles3D
## Cada cristal: posição polar no disco unitário (ângulo, distância 0–1), altura-alvo (m), inclinação, e o momento em que a frente o alcançou.
var _dados: Array[Dictionary] = []
var _solo_y := 0.0


static func criar(pai: Node, centro: Vector3, ator: Node, raio_final: float) -> Node3D:
	var n: Node3D = load("res://src/combat/frutas_mine_piece/era_do_gelo_visivel.gd").new()
	pai.add_child(n)
	n.global_position = centro
	n._raio_final = raio_final
	n._montar(ator)
	return n


func _montar(ator: Node) -> void:
	# O pé do jogador pode estar numa encosta: o disco assenta no chão sob o centro.
	_solo_y = _chao_em(global_position, ator)
	EraDoGelo.preparar()
	_mat_disco = StandardMaterial3D.new()
	_mat_disco.albedo_texture = EraDoGelo._albedo
	_mat_disco.albedo_color = Color(0.86, 0.95, 1.05, 1.0)   # 1,12/1,18/1,25 estourava em branco no centro (revisão do Codex, 24/11/2026)
	_mat_disco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_disco.roughness = 0.25
	_mat_disco.emission_enabled = true
	_mat_disco.emission_texture = EraDoGelo._emissao
	_mat_disco.emission_energy_multiplier = EMISSAO_DISCO
	_mat_disco.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * 2.0
	_disco = MeshInstance3D.new()
	_disco.mesh = plano
	_disco.material_override = _mat_disco
	_disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disco.scale = Vector3.ONE * 0.01
	add_child(_disco)
	_disco.global_position = Vector3(global_position.x, _solo_y + 0.05, global_position.z)

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	_mat_cristal = StandardMaterial3D.new()
	_mat_cristal.albedo_color = COR_CRISTAL
	_mat_cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cristal.roughness = 0.08
	_mat_cristal.vertex_color_use_as_albedo = true
	_mat_cristal.metallic_specular = 0.8
	_mat_cristal.emission_enabled = true
	_mat_cristal.emission = Color(0.35, 0.75, 1.0)
	_mat_cristal.emission_energy_multiplier = 0.9
	_mat_cristal.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = cone
	_mm.instance_count = CRISTAIS
	_mm.visible_instance_count = 0
	_cristais = MultiMeshInstance3D.new()
	_cristais.multimesh = _mm
	_cristais.material_override = _mat_cristal
	_cristais.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cristais)
	_cristais.global_transform = Transform3D(Basis.IDENTITY, Vector3(global_position.x, _solo_y, global_position.z))

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in CRISTAIS:
		# Mais cristais perto da borda (raiz quadrada espalha por área; o expoente 0,6 puxa para fora).
		var d := pow(rng.randf(), 0.6)
		_dados.append({"ang": rng.randf() * TAU, "d": d, "alt": rng.randf_range(0.9, 2.6) * (0.6 + 0.9 * d),
			"larg": rng.randf_range(0.28, 0.6), "incl": rng.randf_range(-0.28, 0.28), "incl2": rng.randf_range(-0.28, 0.28),
			"nasceu": -1.0})
		_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		_mm.set_instance_color(i, PROFUNDO.lerp(Color(0.85, 0.95, 1.0, 1.0), rng.randf()))

	_luz = OmniLight3D.new()
	_luz.light_color = Color(0.55, 0.85, 1.0)
	_luz.light_energy = 0.0
	_luz.omni_range = 10.0
	_luz.shadow_enabled = false
	add_child(_luz)
	_luz.global_position = global_position + Vector3.UP * 1.5

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, 0.15, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 1.0
	pm.emission_ring_inner_radius = 0.0
	pm.emission_ring_height = 0.2
	pm.emission_ring_axis = Vector3.UP
	pm.scale_min = 1.0
	pm.scale_max = 2.2
	pm.color_ramp = FxUtil.gradient([Color(0.8, 0.93, 1.0, 0.0), Color(0.82, 0.94, 1.0, 0.42), Color(0.8, 0.92, 1.0, 0.0)])
	# A névoa usava `FxUtil.grain` SEM textura: cada partícula era um quadrado pálido de ~3 m (os "planos retangulares" que o Codex apontou, 24/11/2026,
	# confirmados desligando a névoa numa captura). Com um degradê radial a borda some e ela volta a ser fumaça.
	var nevoa_malha := FxUtil.grain(1.5)
	var macio := GradientTexture2D.new()
	macio.fill = GradientTexture2D.FILL_RADIAL
	macio.fill_from = Vector2(0.5, 0.5)
	macio.fill_to = Vector2(1.0, 0.5)
	macio.width = 64
	macio.height = 64
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_offset(0, 0.0)
	degrade.set_color(1, Color(1, 1, 1, 0))
	degrade.set_offset(1, 1.0)
	degrade.add_point(0.5, Color(1, 1, 1, 0.45))
	macio.gradient = degrade
	(nevoa_malha.material as StandardMaterial3D).albedo_texture = macio
	_nevoa = FxUtil.particles(70, 2.6, false, pm, nevoa_malha, 0.0, "padrao")
	_nevoa.emitting = false
	add_child(_nevoa)
	_nevoa.global_position = Vector3(global_position.x, _solo_y + 0.15, global_position.z)


func _chao_em(p: Vector3, ator: Node) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 12.0, MundoMinePiece.MASCARA_MUNDO)
	if ator is CollisionObject3D:
		q.exclude = [(ator as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else p.y - 1.0


## O raio (m) que o dano cobre agora. Chamado a cada tick da técnica.
func set_raio(metros: float) -> void:
	if metros <= _raio:
		return
	_raio = metros
	_raio_final = maxf(_raio_final, metros)
	if _nevoa != null:
		_nevoa.emitting = true
		var pm := _nevoa.process_material as ParticleProcessMaterial
		pm.emission_ring_radius = maxf(_raio * 0.9, 1.0)
		pm.emission_ring_inner_radius = _raio * 0.3
	_luz.light_energy = 3.0
	_luz.omni_range = maxf(_raio * 1.4, 6.0)
	# Anel de choque a cada passo da frente.
	VfxFrutaMinePiece.onda_de_choque(self, Vector3(global_position.x, _solo_y + 0.1, global_position.z), _raio, Color(0.6, 0.88, 1.0), 0.5)
	# Os cristais que a frente acabou de alcançar passam a nascer (com um pequeno atraso aleatório, para não brotarem em bloco).
	for dado in _dados:
		if float(dado.nasceu) < 0.0 and float(dado.d) * _raio_final <= _raio:
			dado.nasceu = _idade + randf() * 0.2


func encerrar() -> void:
	if _fim_em < 0.0:
		_fim_em = _idade


func _process(delta: float) -> void:
	_idade += delta
	var vida_fim := (_fim_em if _fim_em >= 0.0 else 1.0e9) + DURACAO_APOS_FIM
	if _idade >= vida_fim + FADE:
		queue_free()
		return
	var fade := 1.0 - clampf((_idade - vida_fim) / FADE, 0.0, 1.0)
	_disco.scale = Vector3(_raio, 1.0, _raio)
	_mat_disco.albedo_color.a = fade
	_mat_disco.emission_energy_multiplier = EMISSAO_DISCO * fade
	_mat_cristal.albedo_color.a = COR_CRISTAL.a * fade
	_luz.light_energy = maxf(_luz.light_energy - delta * 6.0, 0.0)
	if fade < 1.0 and _nevoa != null:
		_nevoa.emitting = false
	var visiveis := 0
	for i in _dados.size():
		var dado: Dictionary = _dados[i]
		if float(dado.nasceu) < 0.0:
			continue
		var t := clampf((_idade - float(dado.nasceu)) / 0.35, 0.0, 1.0)
		var sobe := 1.0 - pow(1.0 - t, 3.0)                       # brota rápido e assenta (ease-out)
		var altura := float(dado.alt) * sobe * fade
		var largura := float(dado.larg) * (0.4 + 0.6 * sobe) * (0.5 + 0.5 * fade)
		var raio_c := float(dado.d) * _raio_final
		var pos := Vector3(cos(float(dado.ang)) * raio_c, altura * 0.5, sin(float(dado.ang)) * raio_c)
		var base := Basis.from_euler(Vector3(float(dado.incl), float(dado.ang), float(dado.incl2)))
		base = base.scaled(Vector3(largura * 2.0, altura, largura * 2.0))
		_mm.set_instance_transform(i, Transform3D(base, pos))
		visiveis = i + 1
	_mm.visible_instance_count = maxi(visiveis, 0)
