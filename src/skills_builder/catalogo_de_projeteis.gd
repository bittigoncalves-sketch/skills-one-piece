class_name CatalogoDeProjeteis
extends RefCounted
## LOJA DE PROJÉTEIS do Skills Builder (06/10/2026).
##
## Pedido do dono: "adicionar uma loja de projéteis na aba de projéteis a serem disparados
## no editor". Decisão dele: catálogo PRONTO (forma + rastro + valores padrão) E qualquer
## modelo .glb da loja do editor como projétil.
##
## Fonte ÚNICA do desenho: a prévia do Builder (`arena_preview.gd`) e o executor do jogo
## (`executor_de_skill.gd`) chamam `criar` e `animar`. O acerto continua sendo a esfera
## de `raio` — a forma é só o que se vê. Frente do projétil = −Z: `animar` vira o nó
## para o rumo a cada quadro e gira só o filho "Corpo" (o rastro não gira).

const Visual = preload("res://src/skills_builder/visual_de_skill.gd")
const AuraDeLentidao = preload("res://src/skills_builder/aura_de_lentidao.gd")

const MODELO := "Modelo da loja"
const PADRAO := "Energia"
const FORMAS: Array[String] = ["Energia", "Bala de canhão", "Bomba", "Flecha", "Kunai", "Shuriken",
	"Pedra", "Bola de fogo", "Bolha", "Estaca de gelo", "Pata", "Rajada", MODELO]
const RASTROS: Array[String] = ["Nenhum", "Brilho", "Fumaça", "Fogo", "Faísca", "Vento", "Gelo"]

## Os prontos da loja. O clique grava `valores` (+ forma) na seção Projéteis, ou no bloco
## aberto. Números pela física de cada um: flecha rápida com pouca queda, bomba em arco,
## bolha lenta que sobe (gravidade negativa).
const PRONTOS := {
	"Energia": {"texto": "Esfera de luz na cor da skill.",
		"valores": {"velocidade": 14.0, "raio": 0.4, "gravidade": 0.0, "vida": 2.0, "giro": 0.0, "rastro": "Brilho"}},
	"Bala de canhão": {"texto": "Ferro pesado e rápido; cai um pouco.",
		"valores": {"velocidade": 28.0, "raio": 0.35, "gravidade": 6.0, "vida": 3.0, "giro": 0.0, "rastro": "Fumaça"}},
	"Bomba": {"texto": "Lançada em arco, com o pavio aceso.",
		"valores": {"velocidade": 13.0, "raio": 0.4, "gravidade": 16.0, "vida": 3.0, "giro": 240.0, "rastro": "Faísca"}},
	"Flecha": {"texto": "Rápida e fina; aponta para onde vai.",
		"valores": {"velocidade": 36.0, "raio": 0.15, "gravidade": 5.0, "vida": 2.5, "giro": 0.0, "rastro": "Vento"}},
	"Kunai": {"texto": "Lâmina curta de arremesso.",
		"valores": {"velocidade": 30.0, "raio": 0.16, "gravidade": 2.0, "vida": 1.5, "giro": 0.0, "rastro": "Vento"}},
	"Shuriken": {"texto": "Estrela de aço girando deitada.",
		"valores": {"velocidade": 26.0, "raio": 0.26, "gravidade": 0.0, "vida": 1.5, "giro": 1440.0, "rastro": "Vento"}},
	"Pedra": {"texto": "Pedra bruta rolando no ar.",
		"valores": {"velocidade": 18.0, "raio": 0.45, "gravidade": 12.0, "vida": 2.5, "giro": 300.0, "rastro": "Nenhum"}},
	"Bola de fogo": {"texto": "Núcleo quente com chamas atrás.",
		"valores": {"velocidade": 16.0, "raio": 0.5, "gravidade": 0.0, "vida": 2.0, "giro": 0.0, "rastro": "Fogo"}},
	"Bolha": {"texto": "Lenta; sobe flutuando.",
		"valores": {"velocidade": 6.0, "raio": 0.55, "gravidade": -1.5, "vida": 4.0, "giro": 0.0, "rastro": "Nenhum"}},
	"Pata": {"texto": "Pata de gato de pelúcia (Nikyu Nikyu); largura = 2 x raio.",
		"valores": {"velocidade": 22.0, "raio": 0.5, "gravidade": 0.0, "vida": 2.0, "giro": 0.0, "rastro": "Brilho"}},
	"Rajada": {"texto": "Meias-luas de vento empilhadas (Estilo de Combate Base); largura = 2 x raio.",
		"valores": {"velocidade": 30.0, "raio": 1.0, "gravidade": 0.0, "vida": 1.0, "giro": 0.0, "rastro": "Vento"}},
	"Estaca de gelo": {"texto": "Cristal pontudo e frio.",
		"valores": {"velocidade": 24.0, "raio": 0.25, "gravidade": 0.0, "vida": 2.0, "giro": 0.0, "rastro": "Gelo"}},
}

static var _textura_suave: Texture2D = null
static var _shader_bolha: Shader = null


## O que o clique num pronto grava na skill.
static func valores_do_pronto(forma: String) -> Dictionary:
	var v: Dictionary = (PRONTOS.get(forma, PRONTOS[PADRAO]) as Dictionary).valores.duplicate(true)
	v.visual = forma if PRONTOS.has(forma) else PADRAO
	v.modelo = ""
	return v


## O que o clique num modelo da loja grava: a forma vira o modelo; velocidade, raio e o
## resto ficam como estavam.
static func valores_do_modelo(id: String) -> Dictionary:
	return {"visual": MODELO, "modelo": id}


## O nó do projétil (corpo + rastro), ainda fora da árvore. `bib` = loja dos modelos
## (padrão: a do jogo). Modelo que não existe mais desenha a Energia.
static func criar(p: Dictionary, cor: Color, bib: BibliotecaDeModelos = null) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Projetil"
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	raiz.add_child(corpo)
	var r := maxf(float(p.get("raio", 0.4)), 0.05)
	var forma := str(p.get("visual", PADRAO))
	if forma == MODELO and not _modelo(corpo, str(p.get("modelo", "")), r, bib):
		forma = PADRAO
	match forma:
		"Bala de canhão": _bala(corpo, r)
		"Bomba": _bomba(corpo, r)
		"Flecha": _flecha(corpo, cor, r)
		"Kunai": _kunai(corpo, cor, r)
		"Shuriken": _shuriken(corpo, cor, r)
		"Pedra": _pedra(corpo, r)
		"Bola de fogo": _bola_de_fogo(corpo, r)
		"Bolha": _bolha(corpo, cor, r)
		"Estaca de gelo": _estaca(corpo, r)
		"Pata": _pata(corpo, cor, r)
		"Rajada": _rajada(corpo, cor, r)
		"Modelo da loja": pass
		_:
			forma = PADRAO
			_energia(corpo, cor, r)
	raiz.set_meta("forma", forma)
	raiz.set_meta("giro", deg_to_rad(float(p.get("giro", 0.0))))
	raiz.set_meta("eixo", Vector3.UP if forma == "Shuriken" else Vector3.RIGHT)
	var rastro := str(p.get("rastro", "Nenhum"))
	if rastro != "Nenhum" and rastro in RASTROS:
		raiz.add_child(_rastro(rastro, cor, r))
	return raiz


## A cada quadro: vira para o rumo, gira o corpo e mexe o que tem vida própria (chama,
## bolha). Só desenho; quem move é o dono do projétil.
static func animar(no: Node3D, vel: Vector3, dt: float) -> void:
	if not is_instance_valid(no) or not no.is_inside_tree():
		return
	if vel.length_squared() > 0.0001:
		var dir := vel.normalized()
		no.global_basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK)
	var corpo := no.get_node_or_null("Corpo") as Node3D
	if corpo == null:
		return
	var giro := float(no.get_meta("giro", 0.0))
	if giro != 0.0:
		corpo.rotate_object_local(no.get_meta("eixo", Vector3.RIGHT), giro * dt)
	var t := Time.get_ticks_msec() / 1000.0
	match str(no.get_meta("forma", "")):
		"Bola de fogo", "Energia":
			var halo := corpo.get_node_or_null("Halo") as Node3D
			if halo != null:
				halo.scale = Vector3.ONE * (1.0 + 0.09 * sin(t * 27.0) + 0.05 * sin(t * 41.0))
		"Bolha":
			corpo.scale = Vector3(1.0 + 0.05 * sin(t * 7.0), 1.0 - 0.05 * sin(t * 7.0), 1.0 + 0.03 * sin(t * 5.0))


# ------------------------------------------------------------------ formas

static func _mat(cor: Color, metal := 0.0, aspereza := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = aspereza
	if cor.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _peca(pai: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, nome := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not nome.is_empty():
		mi.name = nome
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	pai.add_child(mi)
	return mi


static func _esfera(r: float, segmentos := 20) -> SphereMesh:
	var e := SphereMesh.new()
	e.radius = r
	e.height = r * 2.0
	e.radial_segments = segmentos
	e.rings = maxi(segmentos / 2, 4)
	return e


static func _cilindro(r_cima: float, r_baixo: float, altura: float, lados := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_cima
	c.bottom_radius = r_baixo
	c.height = altura
	c.radial_segments = lados
	c.rings = 1
	return c


## Energia: miolo quase branco dentro de um halo na cor da skill. Tudo brilho aditivo:
## miolo opaco ganhava um aro duro (o contorno toon do jogo desenha a borda dele).
static func _energia(corpo: Node3D, cor: Color, r: float) -> void:
	corpo.add_child(Visual.esfera_de_brilho("Miolo", cor.lerp(Color.WHITE, 0.7), r * 0.55, 0.6))
	corpo.add_child(Visual.esfera_de_brilho("Halo", cor, r, 2.2))


## Pata de pelúcia (tools/blender/pata_nikyu.py): a pelagem na cor da skill e as
## almofadas num tom mais escuro e quente. Largura do modelo = 1 m -> escala 2 x raio.
const PATA_GLB := "res://assets/models/nikyu/pata.glb"

static func _pata(corpo: Node3D, cor: Color, r: float) -> void:
	var cena := load(PATA_GLB) as PackedScene if ResourceLoader.exists(PATA_GLB) else null
	if cena == null:
		_energia(corpo, cor, r)
		return
	var modelo := cena.instantiate() as Node3D
	modelo.scale = Vector3.ONE * r * 2.0
	corpo.add_child(modelo)
	var pelo := _mat(cor, 0.0, 0.85)
	var almofada := _mat(cor.darkened(0.3).lerp(Color(1.0, 0.5, 0.65), 0.45), 0.0, 0.6)
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = almofada if "almofada" in mi.name.to_lower() else pelo


## Rajada (14/10/2026, Estilo de Combate Base): três meias-luas finas + fios de ar, feitas no
## Blender (`tools/blender/rajada_vento.py`). Vento é translucido e sem sombreamento: brilho
## aditivo na cor da skill, para não virar uma peça de plástico no ar.
const RAJADA_GLB := "res://assets/models/vento/rajada.glb"


static func _rajada(corpo: Node3D, cor: Color, r: float) -> void:
	var cena := load(RAJADA_GLB) as PackedScene if ResourceLoader.exists(RAJADA_GLB) else null
	if cena == null:
		_energia(corpo, cor, r)
		return
	var modelo := cena.instantiate() as Node3D
	modelo.scale = Vector3.ONE * r * 2.0
	corpo.add_child(modelo)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(cor.lerp(Color.WHITE, 0.55), 0.75)
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _bala(corpo: Node3D, r: float) -> void:
	_peca(corpo, _esfera(r), _mat(Color(0.17, 0.17, 0.19), 0.75, 0.38))


static func _bomba(corpo: Node3D, r: float) -> void:
	_peca(corpo, _esfera(r), _mat(Color(0.07, 0.08, 0.11), 0.3, 0.45))
	var latao := _mat(Color(0.62, 0.48, 0.2), 0.8, 0.35)
	_peca(corpo, _cilindro(r * 0.3, r * 0.34, r * 0.32), latao, Vector3(0, r * 0.98, 0))
	_peca(corpo, _cilindro(r * 0.05, r * 0.05, r * 0.55, 6), _mat(Color(0.55, 0.45, 0.3)), Vector3(r * 0.1, r * 1.32, 0), Vector3(0, 0, -0.35))
	var faisca := Visual.esfera_de_brilho("Faisca", Color(1.0, 0.75, 0.3), r * 0.22, 1.4)
	faisca.position = Vector3(r * 0.2, r * 1.58, 0)
	corpo.add_child(faisca)


## Flecha: haste de madeira, ponta de aço, três penas na cor da skill.
static func _flecha(corpo: Node3D, cor: Color, r: float) -> void:
	var L := r * 7.0
	_peca(corpo, _cilindro(r * 0.12, r * 0.12, L * 0.82, 8), _mat(Color(0.55, 0.38, 0.2), 0.0, 0.9), Vector3(0, 0, L * 0.06), Vector3(PI / 2, 0, 0))
	_peca(corpo, _cilindro(0.0, r * 0.4, L * 0.16, 4), _mat(Color(0.7, 0.72, 0.76), 0.9, 0.3), Vector3(0, 0, -L * 0.43), Vector3(-PI / 2, 0, 0))
	var pena := BoxMesh.new()
	pena.size = Vector3(r * 0.03, r * 0.75, L * 0.17)
	var m := _mat(cor, 0.0, 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 3:
		var a := float(k) * TAU / 3.0
		_peca(corpo, pena, m, Vector3(sin(a), cos(a), 0) * r * 0.42 + Vector3(0, 0, L * 0.36), Vector3(0, 0, -a))


## Kunai: lâmina losango achatada, cabo escuro com duas faixas na cor da skill e a argola.
static func _kunai(corpo: Node3D, cor: Color, r: float) -> void:
	var L := r * 6.0
	var aco := _mat(Color(0.6, 0.63, 0.68), 0.6, 0.3)
	var lamina := _peca(corpo, _cilindro(0.0, r * 0.5, L * 0.5, 4), aco, Vector3(0, 0, -L * 0.25), Vector3(-PI / 2, 0, 0))
	lamina.scale = Vector3(0.28, 1.0, 1.0)      # achatada de lado: a lâmina fica em pé (lê de perfil)
	_peca(corpo, _cilindro(r * 0.11, r * 0.11, L * 0.34, 8), _mat(Color(0.12, 0.11, 0.12)), Vector3(0, 0, L * 0.17), Vector3(PI / 2, 0, 0))
	for z in [L * 0.08, L * 0.24]:
		_peca(corpo, _cilindro(r * 0.125, r * 0.125, L * 0.04, 8), _mat(cor), Vector3(0, 0, z), Vector3(PI / 2, 0, 0))
	var argola := TorusMesh.new()
	argola.inner_radius = r * 0.14
	argola.outer_radius = r * 0.22
	_peca(corpo, argola, aco, Vector3(0, 0, L * 0.34 + r * 0.2), Vector3(0, 0, PI / 2))


## Shuriken: estrela de quatro pontas de aço, com o miolo na cor da skill. Gira deitada.
static func _shuriken(corpo: Node3D, cor: Color, r: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t := r * 0.08
	var pontas: Array[Vector3] = []
	for k in 8:
		var a := float(k) * TAU / 8.0
		var rr := r if k % 2 == 0 else r * 0.32
		pontas.append(Vector3(cos(a) * rr, 0, sin(a) * rr))
	for k in 8:
		var a := pontas[k]
		var b := pontas[(k + 1) % 8]
		_tri(st, Vector3(0, t, 0), a, b)
		_tri(st, Vector3(0, -t, 0), b, a)
	# Metal de menos reflete menos o fundo: aço muito espelhado ficava preto contra céu escuro.
	var m := _mat(Color(0.62, 0.65, 0.7), 0.6, 0.3)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_peca(corpo, st.commit(), m)
	_peca(corpo, _cilindro(r * 0.13, r * 0.13, t * 2.6, 12), _mat(cor, 0.2, 0.5))


## Triângulo com normal explícita apontando para fora do centro (a ordem dos vértices
## não decide o lado iluminado).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + b + c) / 3.0) < 0.0:
		n = -n
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


## Pedra: esfera de poucos lados com os vértices puxados por um ruído fixo (a mesma pedra
## sempre) e faces chapadas.
static func _pedra(corpo: Node3D, r: float) -> void:
	var arrays := _esfera(r, 9).get_mesh_arrays()
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vs.size():
		var v := vs[i]
		var chave := v.snapped(Vector3.ONE * 0.001)        # costura da esfera: mesmo lugar, mesmo ruído
		var ruido := fposmod(sin(chave.dot(Vector3(12.9898, 78.233, 37.719)) / maxf(r, 0.01)) * 43758.5453, 1.0)
		vs[i] = Vector3(v.x, v.y * 0.82, v.z) * (0.86 + 0.28 * ruido)
	arrays[Mesh.ARRAY_VERTEX] = vs
	var bruta := ArrayMesh.new()
	bruta.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(bruta, 0)
	st.deindex()
	st.generate_normals()
	_peca(corpo, st.commit(), _mat(Color(0.46, 0.43, 0.39), 0.0, 1.0))


static func _bola_de_fogo(corpo: Node3D, r: float) -> void:
	corpo.add_child(Visual.esfera_de_brilho("Miolo", Color(1.0, 0.92, 0.65), r * 0.45, 0.6))
	corpo.add_child(Visual.esfera_de_brilho("Meio", Color(1.0, 0.58, 0.14), r * 0.8, 1.5))
	corpo.add_child(Visual.esfera_de_brilho("Halo", Color(1.0, 0.27, 0.05), r * 1.2, 2.6))


## Bolha: película quase transparente com aro iridescente e um brilho de reflexo.
static func _bolha(corpo: Node3D, cor: Color, r: float) -> void:
	if _shader_bolha == null:
		_shader_bolha = Shader.new()
		_shader_bolha.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec4 tinta : source_color = vec4(0.6, 0.85, 1.0, 1.0);
void fragment() {
	float f = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 iris = 0.5 + 0.5 * cos(6.2831 * (f * 1.4 + vec3(0.0, 0.33, 0.67)));
	ALBEDO = mix(tinta.rgb, iris, 0.55) + vec3(pow(f, 6.0));
	ALPHA = clamp(0.08 + pow(f, 2.2) * 0.85, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader_bolha
	m.set_shader_parameter("tinta", cor.lerp(Color(0.6, 0.85, 1.0), 0.5))
	_peca(corpo, _esfera(r, 24), m)
	var reflexo := Visual.esfera_de_brilho("Reflexo", Color.WHITE, r * 0.14, 0.5)
	reflexo.position = Vector3(-r * 0.38, r * 0.42, -r * 0.4)
	corpo.add_child(reflexo)


## Estaca de gelo: cristal sextavado pontudo, translúcido, com três lascas atrás.
static func _estaca(corpo: Node3D, r: float) -> void:
	var m := _mat(Color(0.72, 0.92, 1.0, 0.82), 0.2, 0.08)
	m.emission_enabled = true
	m.emission = Color(0.35, 0.7, 1.0)
	m.emission_energy_multiplier = 0.6
	_peca(corpo, _cilindro(0.0, r * 0.55, r * 4.2, 6), m, Vector3(0, 0, -r * 1.6), Vector3(-PI / 2, 0, 0))
	_peca(corpo, _cilindro(0.0, r * 0.55, r * 1.0, 6), m, Vector3(0, 0, r * 0.95), Vector3(PI / 2, 0, 0))
	for k in 3:
		var a := float(k) * TAU / 3.0 + 0.4
		var lasca := _peca(corpo, _cilindro(0.0, r * 0.22, r * 1.6, 5), m,
			Vector3(sin(a), cos(a), 0) * r * 0.55 + Vector3(0, 0, r * 0.6))
		# A ponta (+Y do cilindro) para trás e para fora.
		var d := (Vector3(sin(a), cos(a), 0) * 0.5 + Vector3.BACK).normalized()
		lasca.basis = Basis(Quaternion(Vector3.UP, d))


## Modelo da loja do editor, cabendo no diâmetro do projétil (maior medida = 2 × raio).
static func _modelo(corpo: Node3D, id: String, r: float, bib: BibliotecaDeModelos) -> bool:
	if id.is_empty():
		return false
	var b := bib if bib != null else MapaMontador.biblioteca_em_uso()
	if b == null or not b.tem(id):
		return false
	var no := b.instanciar(id)
	if no == null:
		return false
	var e := b.info(id)
	var tam: Vector3 = e["tamanho"]
	var s := 2.0 * r / maxf(maxf(tam.x, tam.y), maxf(tam.z, 0.001))
	no.scale = Vector3.ONE * s
	no.position = -(e["centro"] as Vector3) * s
	no.name = "Modelo"
	corpo.add_child(no)
	return true


# ------------------------------------------------------------------ rastro

static func _suave() -> Texture2D:
	if _textura_suave == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_textura_suave = t
	return _textura_suave


## Partículas no MUNDO (`local_coords` falso): ficam para trás do projétil e formam a
## trilha. Some junto com ele.
static func _rastro(estilo: String, cor: Color, r: float) -> CPUParticles3D:
	var pt := CPUParticles3D.new()
	pt.name = "Rastro"
	pt.local_coords = false
	pt.amount = 36
	pt.lifetime = 0.32
	pt.gravity = Vector3.ZERO
	pt.direction = Vector3(0, 0, 1)
	pt.spread = 15.0
	pt.initial_velocity_min = 0.2
	pt.initial_velocity_max = 0.8
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _suave()
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var tamanho := 1.6
	var cores := PackedColorArray([cor, Color(cor, 0.0)])
	var escala := Vector2(1.0, 0.2)
	match estilo:
		"Fumaça":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			cores = PackedColorArray([Color(0.78, 0.77, 0.75, 0.55), Color(0.55, 0.55, 0.55, 0.0)])
			escala = Vector2(0.5, 1.8)
			pt.lifetime = 0.6
			pt.gravity = Vector3(0, 0.6, 0)
			tamanho = 1.8
		"Fogo":
			# Aditivo empilha: com alfa cheio a trilha estourava num borrão branco (foto).
			cores = PackedColorArray([Color(1.0, 0.82, 0.4, 0.55), Color(1.0, 0.38, 0.06, 0.4), Color(0.4, 0.08, 0.03, 0.0)])
			escala = Vector2(0.9, 0.2)
			pt.amount = 22
			tamanho = 1.2
		"Faísca":
			cores = PackedColorArray([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.45, 0.1, 0.0)])
			escala = Vector2(0.35, 0.05)
			pt.lifetime = 0.25
			pt.spread = 180.0
			pt.initial_velocity_min = 1.5
			pt.initial_velocity_max = 3.0
			pt.gravity = Vector3(0, -6, 0)
			tamanho = 0.6
		"Vento":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			cores = PackedColorArray([Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
			escala = Vector2(0.7, 0.15)
			pt.lifetime = 0.22
			tamanho = 1.2
		"Gelo":
			m.albedo_texture = AuraDeLentidao.textura_de_cintila()
			cores = PackedColorArray([Color(0.9, 0.98, 1.0, 1.0), Color(0.5, 0.8, 1.0, 0.0)])
			escala = Vector2(0.8, 0.2)
			pt.lifetime = 0.4
			pt.spread = 40.0
			pt.initial_velocity_min = 0.3
			pt.initial_velocity_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * r * tamanho
	quad.material = m
	pt.mesh = quad
	var rampa := Gradient.new()
	var offs := PackedFloat32Array()
	for i in cores.size():
		offs.append(float(i) / float(cores.size() - 1))
	rampa.offsets = offs
	rampa.colors = cores
	pt.color_ramp = rampa
	var curva := Curve.new()
	curva.max_value = 3.0
	curva.add_point(Vector2(0.0, escala.x))
	curva.add_point(Vector2(1.0, escala.y))
	pt.scale_amount_curve = curva
	return pt
