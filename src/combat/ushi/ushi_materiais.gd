class_name UshiMateriais
extends RefCounted
## Materiais e malhas COMPARTILHADOS da Ushi Ushi (21/11/2026): um de cada, criados uma vez — nenhum golpe ou forma aloca material novo
## (a rajada de cortes e o quadrúpede reutilizam estes; é parte de "não lagar").
## A pele reproduz o padrão da girafa do mod (amarelo 247,228,124 com manchas 148,82,47 da textura `ushi_ushi_giraffe_humanbeast`):
## manchas de Voronoi com linhas claras entre elas, tileável, projetada em triplanar (a malha procedural não tem UV).

const CLARO := Color(0.97, 0.89, 0.49)
const MANCHA := Color(0.58, 0.32, 0.18)
const OSSO := Color(0.30, 0.18, 0.10)
const COR_DO_CORTE := Color(1.0, 0.95, 0.72)           # núcleo quase branco; o halo é dourado (referência do Codex)
const TAM := 128
const SEMENTES := 14

static var _pele: StandardMaterial3D
static var _corte: StandardMaterial3D
static var _halo: StandardMaterial3D
static var _escuro: StandardMaterial3D
static var _malha_do_corte: ArrayMesh


static func pele() -> StandardMaterial3D:
	if _pele == null:
		_pele = StandardMaterial3D.new()
		_pele.albedo_texture = _textura_da_pele()
		_pele.uv1_triplanar = true
		_pele.uv1_scale = Vector3.ONE * 1.1
		_pele.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_pele.roughness = 1.0
	return _pele


static func escuro() -> StandardMaterial3D:
	if _escuro == null:
		_escuro = StandardMaterial3D.new()
		_escuro.albedo_color = OSSO
		_escuro.roughness = 1.0
	return _escuro


static func _textura_da_pele() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21112026
	var pontos: Array[Vector2] = []
	for i in SEMENTES:
		pontos.append(Vector2(rng.randf(), rng.randf()) * TAM)
	var img := Image.create(TAM, TAM, false, Image.FORMAT_RGB8)
	for y in TAM:
		for x in TAM:
			var d1 := 1e9
			var d2 := 1e9
			for p in pontos:
				# Distância com dobra (tileável): a menor entre o ponto e suas cópias vizinhas.
				var dx := absf(float(x) - p.x)
				var dy := absf(float(y) - p.y)
				dx = minf(dx, TAM - dx)
				dy = minf(dy, TAM - dy)
				var d := sqrt(dx * dx + dy * dy)
				if d < d1:
					d2 = d1
					d1 = d
				elif d < d2:
					d2 = d
			img.set_pixel(x, y, MANCHA if d2 - d1 > 5.0 else CLARO)
	return ImageTexture.create_from_image(img)


## Lâmina do corte: material emissivo sem sombra, dos dois lados, mistura aditiva (barato e legível contra qualquer cenário).
static func corte() -> StandardMaterial3D:
	if _corte == null:
		_corte = _brilho(COR_DO_CORTE, 1.0, 3.2)
	return _corte


static func halo() -> StandardMaterial3D:
	if _halo == null:
		_halo = _brilho(Color(1.0, 0.62, 0.18), 0.42, 1.6)
	return _halo


static func _brilho(cor: Color, alfa: float, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = energia
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


## Crescente de largura 1 (−0,5..+0,5 no eixo X): uma FOLHA curva (não uma fita plana) — vista de TRÁS (a câmera do jogo) é um arco largo, de lado é um
## fio curvo com as pontas RECUADAS (−Z é a frente do voo), como a foice do Rankyaku. Y local = "altura" da lâmina (perpendicular à direção e ao eixo).
## UMA malha com 2 superfícies (núcleo claro + halo dourado, maior e deslocado para trás): 1 MeshInstance3D por corte, materiais compartilhados.
static func malha_do_corte() -> ArrayMesh:
	if _malha_do_corte != null:
		return _malha_do_corte
	_malha_do_corte = ArrayMesh.new()
	_superficie(_malha_do_corte, 1.0, 0.30, 0.10, 0.0, corte())
	_superficie(_malha_do_corte, 1.12, 0.40, 0.03, 0.18, halo())
	return _malha_do_corte


## Faixa de 20 segmentos entre a borda de cima (`alto`) e a de baixo (`baixo`), ambas ∝ sin(t·π): forma de lua. `recuo` desloca para trás (+Z).
static func _superficie(malha: ArrayMesh, larg: float, alto: float, baixo: float, recuo: float, mat: Material) -> void:
	var seg := 20
	var vs := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var t := float(i) / seg
		var x := (t - 0.5) * larg
		var z := -pow(2.0 * (t - 0.5), 2.0) * 0.34 + recuo       # as pontas recuam 0,34
		var env := sin(t * PI)
		vs.append(Vector3(x, env * alto + 0.004, z))
		vs.append(Vector3(x, env * baixo, z))
	for i in seg:
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_INDEX] = idx
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	malha.surface_set_material(malha.get_surface_count() - 1, mat)
