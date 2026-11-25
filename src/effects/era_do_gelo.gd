class_name EraDoGelo
extends Node3D
# ============================================================================
#  ERA DO GELO NO MODO HISTÓRIA — o V da Hie que CONGELA O LUGAR (10/10/2026).
#
#  Pedido do dono: "habilidade V fazer com que transforme o terreno ao redor em gelo,
#  trocando a cor do relevo, casas, árvores em branco azulado; ela não irá mais se
#  expandir, nascerá com limite definido". Na arena o V segue o de antes (placa que
#  cresce por 22 s até o mapa todo) — `IceFX._ice_age`.
#
#  COMO SE LÊ "VIROU GELO":
#    • DECAL de geada projetado de cima para baixo num cilindro de `RAIO`: pinta de
#      branco-azulado tudo o que é CENÁRIO dentro dele — relevo, casas, árvores, pedras —
#      inclusive paredes (fica em listras verticais, que leem como gelo escorrido). Brilho
#      de gelo (rugosidade baixa) e rachaduras com leve brilho ciano. Só pinta a camada
#      `MapaMontador.CAMADA_CENARIO`: jogador, inimigos, bichos, NPCs e o mar ficam com as
#      cores deles.
#    • NASCIMENTO: o gelo corre do centro até a borda em `NASCER` s (um lampejo, não o
#      crescimento de antes) com um ANEL de choque — outro decal, que acompanha a encosta.
#      Depois disso o tamanho é FIXO até o fim.
#    • Borda marcada por cristais mais densos; cristais espalhados no chão (raio para
#      baixo, assentados no que estiver ali: chão, telhado, pedra); névoa fria subindo.
#    • Fim: tudo desbota em `DESBOTAR` s e some.
#  JOGO (o mesmo de antes, no tamanho fixo): erupção de 5 m no começo; quem PISA no gelo
#  (corpo no chão dentro do cilindro) leva o tique do campo e congela; dura `DURACAO`.
# ============================================================================

const RAIO := 20.0                 # m — o limite do gelo (decisão minha, ajustável)
const DURACAO := 50.0              # s — o mesmo campo de antes
const NASCER := 0.35               # s — o gelo corre do centro até a borda
const DESBOTAR := 1.5              # s — no fim
const ACIMA := 26.0                # m acima do centro que o gelo cobre (telhados, copas)
const ABAIXO := 14.0               # m abaixo (encosta descendo)
const TAMANHO_TEXTURA := 256
const TIQUE := 0.2                 # s entre verificações do campo

static var _albedo: ImageTexture
static var _orm: ImageTexture
static var _emissao: ImageTexture
static var _anel: GradientTexture2D

var caster: Node
var spec: DamageSpec
var _decal: Decal
var _choque: Decal
var _cristais: Array[Node3D] = []
var _nevoa: GPUParticles3D
var _luz: OmniLight3D
var _area: Area3D
var _idade := 0.0
var _tique := 0.0
var _desbotando := false


## Cria o V da história em `centro` (pés do conjurador). Quem chama: `IceFX._ice_age`.
static func lancar(world: Node, centro: Vector3, quem: Node, dano: DamageSpec) -> EraDoGelo:
	var e := EraDoGelo.new()
	e.name = "EraDoGelo"
	e.caster = quem
	e.spec = dano
	world.add_child(e)
	e.global_position = centro
	# Montado DEPOIS de posto no lugar: os cristais são assentados por raios no mundo
	# (no `_ready` o nó ainda estaria na origem — medido: cristais nasciam longe).
	e._montar()
	return e


## Gera as texturas uma vez (≈ dezenas de ms). O Modo História chama no carregamento
## para o primeiro V não engasgar.
static func preparar() -> void:
	if _albedo != null:
		return
	var n := TAMANHO_TEXTURA
	var manchas := FastNoiseLite.new()
	manchas.seed = 7
	manchas.frequency = 0.012
	manchas.fractal_octaves = 3
	var celulas := FastNoiseLite.new()
	celulas.seed = 11
	celulas.noise_type = FastNoiseLite.TYPE_CELLULAR
	celulas.frequency = 0.035
	celulas.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var borda := FastNoiseLite.new()
	borda.seed = 23
	borda.frequency = 4.0
	var img_m := manchas.get_image(n, n, false, false, true)
	var img_c := celulas.get_image(n, n, false, false, true)
	var a_bytes := PackedByteArray()
	a_bytes.resize(n * n * 4)
	var o_bytes := PackedByteArray()
	o_bytes.resize(n * n * 3)
	var e_bytes := PackedByteArray()
	e_bytes.resize(n * n * 3)
	var m_dados := img_m.get_data()
	var c_dados := img_c.get_data()
	# Branco-azulado com corpo: claro demais estoura no sol + brilho da tela (medido:
	# luz média 0,86 na 1ª versão, chão sem desenho nenhum).
	var claro := Color(0.78, 0.88, 0.96)
	var azul := Color(0.6, 0.76, 0.92)
	var veio := Color(0.36, 0.58, 0.85)
	var meio := (n - 1) * 0.5
	for y in n:
		for x in n:
			var i := y * n + x
			var m := m_dados[i] / 255.0
			var c := c_dados[i] / 255.0                     # 0 na rachadura
			var racha := 1.0 - smoothstep(0.0, 0.12, c)
			var cor := claro.lerp(azul, smoothstep(0.35, 0.75, m)).lerp(veio, racha * 0.7)
			var dx := (x - meio) / meio
			var dy := (y - meio) / meio
			var d := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var limite := 0.9 + 0.06 * borda.get_noise_1d(ang * 3.0) + 0.03 * sin(ang * 13.0)
			var alfa := 1.0 - smoothstep(limite - 0.05, limite + 0.01, d)
			a_bytes[i * 4] = int(cor.r * 255.0)
			a_bytes[i * 4 + 1] = int(cor.g * 255.0)
			a_bytes[i * 4 + 2] = int(cor.b * 255.0)
			a_bytes[i * 4 + 3] = int(alfa * 255.0)
			o_bytes[i * 3] = 255                                          # oclusão: nenhuma
			o_bytes[i * 3 + 1] = int(clampf(0.3 + 0.25 * m + 0.2 * racha, 0.0, 1.0) * 255.0)   # liso, sem espelhar o sol
			o_bytes[i * 3 + 2] = 0                                        # não metálico
			var brilho := racha * 0.9 * alfa
			e_bytes[i * 3] = int(0.35 * brilho * 255.0)
			e_bytes[i * 3 + 1] = int(0.75 * brilho * 255.0)
			e_bytes[i * 3 + 2] = int(1.0 * brilho * 255.0)
	var img_a := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, a_bytes)
	img_a.generate_mipmaps()
	_albedo = ImageTexture.create_from_image(img_a)
	var img_o := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, o_bytes)
	img_o.generate_mipmaps()
	_orm = ImageTexture.create_from_image(img_o)
	var img_e := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, e_bytes)
	img_e.generate_mipmaps()
	_emissao = ImageTexture.create_from_image(img_e)
	# Anel de choque do nascimento: aro claro só na borda do disco.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.78, 0.93, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.75, 0.92, 1.0, 0), Color(0.9, 0.98, 1.0, 1), Color(1, 1, 1, 0)])
	_anel = GradientTexture2D.new()
	_anel.gradient = g
	_anel.fill = GradientTexture2D.FILL_RADIAL
	_anel.fill_from = Vector2(0.5, 0.5)
	_anel.fill_to = Vector2(1.0, 0.5)
	_anel.width = 256
	_anel.height = 256


func _montar() -> void:
	preparar()
	_montar_decais()
	_montar_cristais()
	_montar_nevoa()
	_montar_luz()
	_montar_campo()
	_tocar_som()


func _montar_decais() -> void:
	_decal = Decal.new()
	_decal.name = "Geada"
	_decal.texture_albedo = _albedo
	_decal.texture_orm = _orm
	_decal.texture_emission = _emissao
	_decal.emission_energy = 0.35
	_decal.albedo_mix = 0.88
	_decal.normal_fade = 0.0             # paredes também
	_decal.upper_fade = 0.05
	_decal.lower_fade = 0.05
	_decal.cull_mask = MapaMontador.CAMADA_CENARIO
	_decal.size = Vector3(0.1, ACIMA + ABAIXO, 0.1)
	_decal.position = Vector3.UP * (ACIMA - ABAIXO) * 0.5
	add_child(_decal)
	_choque = Decal.new()
	_choque.name = "Choque"
	_choque.texture_albedo = _anel
	_choque.texture_emission = _anel
	_choque.emission_energy = 3.0
	_choque.albedo_mix = 1.0
	_choque.normal_fade = 0.3
	_choque.cull_mask = MapaMontador.CAMADA_CENARIO
	_choque.size = _decal.size
	_choque.position = _decal.position
	add_child(_choque)


## Cristais: um anel denso na borda e um punhado espalhado; cada um assentado no que
## houver embaixo (raio para baixo no cenário) e aparece quando a onda passa por ele.
func _montar_cristais() -> void:
	var espaco := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position.snapped(Vector3.ONE * 0.5))
	var pontos: Array[Vector2] = []
	for i in 30:                                   # a borda
		var a := TAU * i / 30.0 + rng.randf_range(-0.08, 0.08)
		pontos.append(Vector2(cos(a), sin(a)) * RAIO * rng.randf_range(0.86, 0.97))
	for i in 26:                                   # dentro
		var a := rng.randf() * TAU
		pontos.append(Vector2(cos(a), sin(a)) * RAIO * sqrt(rng.randf()) * 0.8)
	for p in pontos:
		var de := global_position + Vector3(p.x, ACIMA, p.y)
		var q := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * (ACIMA + ABAIXO), 1)
		var excluir: Array[RID] = []
		for n in get_tree().get_nodes_in_group("player"):
			if n is CollisionObject3D:
				excluir.append((n as CollisionObject3D).get_rid())
		q.exclude = excluir
		var hit := espaco.intersect_ray(q)
		if hit.is_empty():
			continue
		var borda := p.length() > RAIO * 0.84
		var cr := _estalactite(rng.randf_range(2.2, 4.2) if borda else rng.randf_range(1.0, 2.6),
			rng.randf_range(0.5, 1.1), rng)
		cr.name = "Cristal"
		cr.top_level = true
		add_child(cr)
		var normal: Vector3 = hit["normal"]
		var cima := Vector3.UP.lerp(normal, 0.5).normalized()
		var lado := cima.cross(Vector3.FORWARD if absf(cima.z) < 0.9 else Vector3.RIGHT).normalized()
		cr.global_transform = Transform3D(Basis(lado, cima, lado.cross(cima)).rotated(cima, rng.randf() * TAU),
			(hit["position"] as Vector3) - cima * 0.1)
		cr.scale = Vector3.ONE * 0.05
		cr.set_meta("atraso", NASCER * p.length() / RAIO)
		_cristais.append(cr)
		var tw := cr.create_tween()
		tw.tween_interval(float(cr.get_meta("atraso")))
		tw.tween_property(cr, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Espinho em forma de estalactite azul: cone facetado e afilado (base larga, ponta
## fina levemente torta), origem na BASE, com duas lascas menores ao redor.
## Cor por vértice: azul profundo na base, gelo claro na ponta.
static var _mat_estalactite: StandardMaterial3D

static func _estalactite(altura: float, largura: float, rng: RandomNumberGenerator) -> Node3D:
	var raiz := Node3D.new()
	raiz.add_child(_espinho(altura, largura * 0.5, rng, Vector3.ZERO))
	for i in 2:
		var a := rng.randf() * TAU
		var lasca := _espinho(altura * rng.randf_range(0.35, 0.6), largura * 0.3, rng,
			Vector3(cos(a), 0.0, sin(a)) * largura * 0.45)
		lasca.rotation = Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5)) * rng.randf_range(0.15, 0.35)
		raiz.add_child(lasca)
	return raiz


static func _espinho(altura: float, raio: float, rng: RandomNumberGenerator, pos: Vector3) -> MeshInstance3D:
	const LADOS := 7
	var base_cor := Color(0.08, 0.28, 0.95, 0.88)
	var ponta_cor := Color(0.72, 0.92, 1.0, 0.7)
	var anel_base: Array[Vector3] = []
	var anel_meio: Array[Vector3] = []
	for i in LADOS:
		var a := TAU * i / LADOS
		var r := raio * rng.randf_range(0.8, 1.15)
		anel_base.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		anel_meio.append(Vector3(cos(a) * r * 0.45, altura * 0.5, sin(a) * r * 0.45))
	var ponta := Vector3(rng.randf_range(-0.12, 0.12) * altura * 0.3, altura, rng.randf_range(-0.12, 0.12) * altura * 0.3)
	var meio_cor := base_cor.lerp(ponta_cor, 0.55)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in LADOS:
		var j := (i + 1) % LADOS
		# Faces planas (facetas de cristal): quad base→meio e triângulo meio→ponta.
		for tri in [[anel_base[i], base_cor, anel_meio[j], meio_cor, anel_base[j], base_cor],
				[anel_base[i], base_cor, anel_meio[i], meio_cor, anel_meio[j], meio_cor],
				[anel_meio[i], meio_cor, ponta, ponta_cor, anel_meio[j], meio_cor]]:
			for k in 3:
				st.set_color(tri[k * 2 + 1])
				st.add_vertex(tri[k * 2])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if _mat_estalactite == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.06
		m.metallic = 0.2
		m.rim_enabled = true
		m.rim = 0.8
		m.emission_enabled = true
		m.emission = Color(0.1, 0.4, 1.0)
		m.emission_energy_multiplier = 1.8
		_mat_estalactite = m
	mi.material_override = _mat_estalactite
	mi.position = pos
	return mi


func _montar_nevoa() -> void:
	var proc := IceFX._frost_proc(RAIO * 0.85, 1.4)
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proc.emission_ring_axis = Vector3.UP
	proc.emission_ring_height = 2.0
	proc.emission_ring_radius = RAIO * 0.9
	proc.emission_ring_inner_radius = 0.0
	proc.scale_min = 0.6
	proc.scale_max = 1.4
	_nevoa = FxUtil.particles(240, 2.6, false, proc, _floco(), 0.0, "hero")
	_nevoa.name = "Nevoa"
	_nevoa.visibility_aabb = AABB(Vector3(-RAIO, -ABAIXO, -RAIO), Vector3(RAIO * 2.0, ACIMA + ABAIXO, RAIO * 2.0))
	add_child(_nevoa)


## Floco de névoa: quad redondo e macio (o grão quadrado do V da arena lia como
## quadradinhos espalhados na tela).
static var _floco_malha: QuadMesh

static func _floco() -> QuadMesh:
	if _floco_malha != null:
		return _floco_malha
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = t
	m.disable_receive_shadows = true
	_floco_malha = QuadMesh.new()
	_floco_malha.size = Vector2(0.45, 0.45)
	_floco_malha.material = m
	return _floco_malha


func _montar_luz() -> void:
	_luz = OmniLight3D.new()
	_luz.name = "Lampejo"
	_luz.light_color = Color(0.6, 0.85, 1.0)
	_luz.omni_range = RAIO * 1.2
	_luz.light_energy = 4.0
	_luz.shadow_enabled = false
	_luz.position = Vector3.UP * 3.0
	add_child(_luz)


## O campo de antes, no tamanho fixo: erupção de 5 m e o tique em quem pisa no gelo.
func _montar_campo() -> void:
	if spec == null:
		spec = DamageSpec.avulso(0.0)
	var burst := DamageZone.new()
	get_parent().add_child(burst)
	burst.global_position = global_position + Vector3.UP
	burst.setup(spec.parte("impacto", 256.0), 8.0, Vector3.ZERO, 1.0, caster, 5.0)
	spec.marcar(burst)
	_area = Area3D.new()
	_area.name = "Campo"
	_area.collision_layer = 0
	_area.collision_mask = 1 | HurtboxDeCombate.CAMADA
	var col := CollisionShape3D.new()
	var forma := CylinderShape3D.new()
	forma.radius = RAIO
	forma.height = ACIMA + ABAIXO
	col.shape = forma
	col.position = Vector3.UP * (ACIMA - ABAIXO) * 0.5
	_area.add_child(col)
	add_child(_area)


## Sopro grave e o estalo do gelo fechando (os sons de gelo do jogo, mais graves).
func _tocar_som() -> void:
	AudioFX.whoosh(self, global_position, 0.55)
	AudioFX.snap(self, global_position, 0.7)
	get_tree().create_timer(NASCER).timeout.connect(func():
		if is_inside_tree(): AudioFX.snap(self, global_position, 0.55))


func _process(delta: float) -> void:
	if _decal == null:
		return
	_idade += delta
	var nasce := clampf(_idade / NASCER, 0.0, 1.0)
	var curva := 1.0 - pow(1.0 - nasce, 3.0)                 # sai rápido, assenta na borda
	var lado := maxf(RAIO * 2.0 * curva, 0.1)
	_decal.size = Vector3(lado, ACIMA + ABAIXO, lado)
	# Anel: corre junto com a frente do gelo e some logo depois.
	var anel := clampf(_idade / (NASCER * 1.6), 0.0, 1.0)
	_choque.size = Vector3(maxf(RAIO * 2.2 * anel, 0.1), ACIMA + ABAIXO, maxf(RAIO * 2.2 * anel, 0.1))
	_choque.modulate.a = 1.0 - smoothstep(0.55, 1.0, anel)
	_choque.visible = anel < 1.0
	_luz.light_energy = 4.0 * (1.0 - smoothstep(0.0, 0.6, _idade))
	_luz.visible = _luz.light_energy > 0.01
	if not _desbotando and _idade >= DURACAO - DESBOTAR:
		_desbotar()


func _desbotar() -> void:
	_desbotando = true
	_nevoa.emitting = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_decal, "albedo_mix", 0.0, DESBOTAR)
	tw.tween_property(_decal, "emission_energy", 0.0, DESBOTAR)
	tw.tween_property(_decal, "modulate:a", 0.0, DESBOTAR)
	for cr in _cristais:
		if is_instance_valid(cr):
			tw.tween_property(cr, "scale", Vector3.ONE * 0.01, DESBOTAR * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _desbotando or _area == null:
		return
	_tique -= delta
	if _tique > 0.0:
		return
	_tique = TIQUE
	var vistos := {}
	for corpo in _area.get_overlapping_bodies():
		var dono := HurtboxDeCombate.dono_de(corpo) as Node
		if dono == null or dono == caster or vistos.has(dono.get_instance_id()) or not dono.has_method("take_damage"):
			continue
		vistos[dono.get_instance_id()] = true
		if not pisando(dono):
			continue
		CombatResolver.aplicar(dono, spec.dano, spec.cast_id, spec.teto, global_position)
		if IceFX._decide(self):
			IceFX.congelar(dono)


## Quem conta como "pisando no gelo": dentro do raio (no plano), corpo no chão — ou
## corpo que não pula (estático/inimigo do mapa) — e não muito acima do centro.
func pisando(dono: Node) -> bool:
	if not dono is Node3D:
		return false
	var p := (dono as Node3D).global_position
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	if d > RAIO:
		return false
	if dono is CharacterBody3D:
		return (dono as CharacterBody3D).is_on_floor()
	return true
