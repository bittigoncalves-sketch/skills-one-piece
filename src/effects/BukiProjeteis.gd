class_name BukiProjeteis
extends RefCounted
# ============================================================================
#  A MUNIÇÃO DA BUKI BUKI — um modelo de bala por arma.
#
#  POR QUE ESTE ARQUIVO EXISTE (2026-08-11)
#
#  Até aqui o projétil era genérico: `BukiFX._projetil` escolhia entre CÁPSULA
#  DE LATÃO e BOLA DE FERRO olhando só o `raio` (`raio > 0.4` = canhão). Ou seja,
#  pistola, sniper e minigun cuspiam exatamente a mesma cápsula. A bala é a
#  única parte da arma que o adversário vê de perto — quatro armas com a mesma
#  munição achatam a fruta inteira num "cano que solta pontinho amarelo".
#
#  Agora cada slot tem munição com cara própria, e a cara sai da TABELA
#  (`BukiFX.ARSENAL`), não de números soltos:
#
#    • `raio` (calibre)  -> comprimento e grossura da bala;
#    • `vel`             -> vida do rastro (bala rápida com rastro longo vira
#                           parede de fumaça; bala lenta com rastro curto some).
#
#  CONVENÇÃO DE EIXO: tudo é modelado apontando pra **−Z** (a mesma dos .glb das
#  armas). Quem alinha a bala com o rumo do tiro é o `BukiFX._projetil`, que
#  gira a DamageZone com `look_at` antes de pendurar o modelo. Antes disso a
#  cápsula deitava sempre no Z do MUNDO: só ficava certa quando o jogador
#  atirava pro norte.
#
#  Tudo aqui nasce como FILHO da DamageZone — morre com ela. É o que mantém a
#  auditoria (`tools/dev_tests/test_frutas.gd`) em zero vazamento de nó.
# ============================================================================

const LATAO := Color(0.86, 0.68, 0.28)
const LATAO_FOSCO := Color(0.66, 0.50, 0.20)
const FERRO := Color(0.13, 0.13, 0.15)
const COBRE := Color(0.78, 0.44, 0.20)
const BRASA := Color(1.0, 0.72, 0.30)
const TRACANTE := Color(1.0, 0.55, 0.12)

# Rastro quente (mesma família do FAISCA do BukiFX: o tiro tem que ler como uma
# coisa só, do fogacho ao impacto).
const RASTRO_QUENTE := [
	Color(1.0, 0.95, 0.70, 1.0),
	Color(1.0, 0.70, 0.25, 0.9),
	Color(0.70, 0.35, 0.10, 0.4),
	Color(0.30, 0.30, 0.30, 0.0),
]
const RASTRO_FUMACA := [
	Color(0.60, 0.58, 0.56, 0.65),
	Color(0.45, 0.44, 0.44, 0.35),
	Color(0.38, 0.38, 0.38, 0.0),
]

# --------------------------------------------------------------------- API
# Devolve o modelo da bala do slot, já com rastro. `raio` e `vel` vêm da
# ARSENAL — quem chama não inventa número.
static func montar(slot: String, raio: float, vel: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Bala_" + slot
	match slot:
		"X": _obus(n, raio, vel)
		"C": _dardo(n, raio, vel)
		"V": _tracante(n, raio, vel)
		_: _bala_curta(n, raio, vel)
	return n

# ------------------------------------------------------------------ MODELOS
# Z — PISTOLA (raio 0.18, vel 42). Bala CURTA de latão: ogiva + corpo, na
# proporção 1:2. É o formato que o olho já conhece de "bala"; serve de régua
# para as outras três lerem como exceção (mais pesada, mais longa, mais rápida).
static func _bala_curta(raiz: Node3D, r: float, vel: float) -> void:
	var latao := _mat(LATAO, 1.0, 0.22, BRASA, 1.3)
	raiz.add_child(_cone(r * 0.30, r * 0.60, -r * 1.15, latao))       # ogiva
	raiz.add_child(_cilindro(r * 0.30, r * 1.20, -r * 0.25, latao))   # corpo
	raiz.add_child(_cilindro(r * 0.33, r * 0.12, r * 0.36, _mat(LATAO_FOSCO, 0.9, 0.4)))  # culote
	_rastro(raiz, 10, _vida_do_rastro(vel, 0.30), r * 1.6, RASTRO_QUENTE, 0.9)

# X — CANHÃO (raio 0.55, vel 22). OBUS: ferro fosco, ogiva longa e uma cinta de
# cobre na base (a peça que grita "artilharia" e não "bola de canhão de pirata").
# Vai devagar de propósito — 22 m/s é meio segundo de voo aos 11 m, tempo de
# ver o volume passar. Por isso é a única que ganha fumaça em vez de fagulha.
static func _obus(raiz: Node3D, r: float, vel: float) -> void:
	var ferro := _mat(FERRO, 0.9, 0.55)
	var cobre := _mat(COBRE, 1.0, 0.30, BRASA, 0.8)
	raiz.add_child(_cone(r * 0.46, r * 0.95, -r * 1.05, ferro))        # ogiva longa
	raiz.add_child(_cilindro(r * 0.46, r * 1.10, -r * 0.03, ferro))    # corpo
	raiz.add_child(_cilindro(r * 0.52, r * 0.16, r * 0.42, cobre))     # cinta de cobre
	raiz.add_child(_cilindro(r * 0.40, r * 0.10, r * 0.56, _mat(BRASA, 0.2, 0.6, BRASA, 3.0)))  # rabo quente
	_rastro(raiz, 26, _vida_do_rastro(vel, 0.95), r * 1.5, RASTRO_FUMACA, 0.35, 0.55)
	_rastro(raiz, 12, _vida_do_rastro(vel, 0.45), r * 0.9, RASTRO_QUENTE, 0.8)

# C — SNIPER (raio 0.16, vel 95). DARDO: fino e MUITO longo (5,4 calibres), com
# um risco fino de traçante colado atrás. A 95 m/s a bala atravessa o alcance de
# mira (60 m) em 0,63 s — sem o risco o jogador não vê NADA sair do cano, e o
# tiro de precisão vira um som sem imagem. O risco é geometria (não partícula)
# justamente porque partícula a 95 m/s sai espaçada demais e vira tracejado.
static func _dardo(raiz: Node3D, r: float, vel: float) -> void:
	var aco := _mat(Color(0.80, 0.82, 0.86), 1.0, 0.18, BRASA, 0.9)
	raiz.add_child(_cone(r * 0.22, r * 1.30, -r * 2.05, aco))          # ponta afilada
	raiz.add_child(_cilindro(r * 0.22, r * 2.80, -r * 0.02, aco))      # corpo
	# Risco: cilindro fino e aditivo, 11 calibres atrás da bala.
	var risco := _cilindro(r * 0.07, r * 11.0, r * 5.6,
		_mat_luz(Color(1.0, 0.80, 0.45, 0.55)))
	raiz.add_child(risco)
	_rastro(raiz, 8, _vida_do_rastro(vel, 0.35), r * 0.8, RASTRO_QUENTE, 0.5)

# V — MINIGUN (raio 0.14, vel 46). TRAÇANTE: quase não tem corpo — é um ponto
# de luz com um risquinho. Com cadência de 0,06 s há ~17 balas no ar ao mesmo
# tempo; qualquer bala "de verdade" aqui vira sopa visual. O que precisa ler é a
# LINHA de fogo, não a bala.
static func _tracante(raiz: Node3D, r: float, vel: float) -> void:
	raiz.add_child(_cilindro(r * 0.26, r * 0.85, -r * 0.10,
		_mat(LATAO, 1.0, 0.25, TRACANTE, 2.6)))
	var brilho := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = r * 0.55
	e.height = r * 1.10
	e.radial_segments = 8
	e.rings = 4
	brilho.mesh = e
	brilho.material_override = _mat_luz(Color(1.0, 0.62, 0.20, 0.75))
	raiz.add_child(brilho)
	raiz.add_child(_cilindro(r * 0.10, r * 4.5, r * 2.3,
		_mat_luz(Color(1.0, 0.55, 0.15, 0.40))))
	_rastro(raiz, 5, _vida_do_rastro(vel, 0.16), r * 0.7, RASTRO_QUENTE, 0.6)

# ------------------------------------------------------------------ RASTRO
# Rastro fica no espaço do MUNDO (local_coords = false, padrão): a partícula
# nasce e FICA, a bala vai embora — é isso que desenha o traço. Se virasse
# local_coords a nuvem viajaria junto e o tiro pareceria uma bola de fumaça.
static func _rastro(raiz: Node3D, qtd: int, vida: float, escala: float,
		cores: Array, veloc: float, gravidade: float = -1.2) -> void:
	var p := GPUParticles3D.new()
	p.amount = qtd
	p.lifetime = vida
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)          # pra TRÁS da bala (ela olha pra −Z)
	pm.spread = 12.0
	pm.initial_velocity_min = veloc * 0.3
	pm.initial_velocity_max = veloc
	pm.gravity = Vector3(0, gravidade, 0)
	pm.scale_min = escala * 0.45
	pm.scale_max = escala
	pm.color_ramp = FxUtil.gradient(cores)
	p.process_material = pm
	p.draw_pass_1 = FxUtil.grain(0.28)
	raiz.add_child(p)

# Bala rápida precisa de rastro CURTO: a 95 m/s, 0,9 s de vida deixa 85 m de
# fumaça pendurada no ar. Normalizado em 42 m/s, que é a pistola (a régua).
static func _vida_do_rastro(vel: float, base: float) -> float:
	return clampf(base * (42.0 / maxf(vel, 1.0)), 0.10, 1.2)

# ---------------------------------------------------------------- GEOMETRIA
# Todas as peças nascem no eixo +Y do CylinderMesh e giram −90° em X, o que leva
# +Y em −Z: o topo do cilindro vira a PONTA da bala.
static func _cilindro(raio: float, alt: float, z: float, mat: Material) -> MeshInstance3D:
	return _tronco(raio, raio, alt, z, mat)

static func _cone(raio: float, alt: float, z: float, mat: Material) -> MeshInstance3D:
	return _tronco(0.0, raio, alt, z, mat)

static func _tronco(r_topo: float, r_base: float, alt: float, z: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_topo
	c.bottom_radius = r_base
	c.height = alt
	c.radial_segments = 8          # facetado, como o resto do jogo
	c.rings = 1
	mi.mesh = c
	mi.rotation_degrees.x = -90.0
	mi.position = Vector3(0, 0, z)
	mi.material_override = mat
	return mi

static func _mat(cor: Color, metal: float, aspereza: float,
		emissao: Color = Color(0, 0, 0), energia: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = aspereza
	if energia > 0.0:
		m.emission_enabled = true
		m.emission = emissao
		m.emission_energy_multiplier = energia
	return m

# Material de LUZ pura (risco do traçante): sem sombra, sem iluminação, aditivo.
static func _mat_luz(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.emission_enabled = true
	m.emission = Color(cor.r, cor.g, cor.b)
	m.emission_energy_multiplier = 2.0
	return m
