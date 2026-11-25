extends RefCounted
## Geometria de fogo própria da Mera Mera. Malha e shader — sem partícula e sem
## luz dinâmica, do mesmo jeito que `OpeGeometry` resolve o visual da Ope.
##
## POR QUE MALHA, E NÃO PARTÍCULA: partícula é uma nuvem de quadrados virados
## para a câmera. Ela não tem silhueta — de longe vira mancha, e no quadro
## congelado não dá para dizer que golpe é. A régua da casa é ler o golpe pela
## sombra (`docs/AGENTES.md`), e isso pede volume. As chamas daqui são cascas
## afiladas com o gradiente de calor no shader, então a língua de fogo tem
## silhueta em qualquer distância.
##
## ⚠️ O gradiente do `mera_flame` corre no EIXO LOCAL +Y da malha (0 na base,
## 1 na ponta) e usa o uniform `span` para normalizar. Toda malha construída
## aqui nasce com a base na origem e cresce para +Y; orientar é trabalho de quem
## chama, girando o nó.

const FLAME_SHADER := preload("res://src/fx/shaders/mera_flame.gdshader")
const EMBER_SHADER := preload("res://src/fx/shaders/mera_ember.gdshader")
const SCORCH_SHADER := preload("res://src/fx/shaders/mera_scorch.gdshader")

const CORE := Color(1.0, 0.93, 0.62)     # branco-amarelo do centro
const MID := Color(1.0, 0.46, 0.06)      # laranja do corpo
const EDGE := Color(0.72, 0.06, 0.01)    # vermelho escuro da borda
const EMBER := Color(1.0, 0.38, 0.05)
## Amplitude da codificação de posição em `INSTANCE_CUSTOM`. Tem que ser igual
## ao `CUSTOM_RANGE` do `mera_ember.gdshader`.
const CUSTOM_RANGE := 4.0


# ----------------------------------------------------------------- materiais

static func flame_material(span: float, turbulence: float = 1.6,
		scroll: float = 2.4, erosion: float = 0.55) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("span", maxf(span, 0.001))
	material.set_shader_parameter("turbulence", turbulence)
	material.set_shader_parameter("scroll", scroll)
	material.set_shader_parameter("erosion", erosion)
	material.set_shader_parameter("core_color", CORE)
	material.set_shader_parameter("mid_color", MID)
	material.set_shader_parameter("edge_color", EDGE)
	return material


static func ember_material(heat: float = 1.0, variant: float = 0.0,
		displacement: float = 0.11, feature_scale: float = 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = EMBER_SHADER
	material.set_shader_parameter("heat", heat)
	material.set_shader_parameter("variant", variant)
	material.set_shader_parameter("displacement", displacement)
	# O tamanho do corpo normaliza o ruído das fendas. Um sol de raio 7 com a
	# frequência de um punho de raio 1 vira chuvisco.
	material.set_shader_parameter("feature_scale", maxf(feature_scale, 0.001))
	return material


static func scorch_material(radius: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SCORCH_SHADER
	material.set_shader_parameter("radius", maxf(radius, 0.001))
	return material


## Material simples e sem sombreamento, para brasas e rastros pequenos onde um
## shader inteiro seria desperdício. Mesmo papel do `OpeGeometry.luminous`.
static func luminous(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, color.a)
	return material


static func instance(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual


# ------------------------------------------------------------------ primitiva

## A LÍNGUA DE FOGO. Base na origem, ponta em +Y.
##
## O afilamento é `(1-t)^0.62` em vez de linear: fogo é gordo embaixo e some
## rápido em cima. A torção e o ruído por anel são determinísticos a partir de
## `seed` — duas línguas do mesmo plume nunca ficam iguais, e o mesmo `seed`
## sempre reconstrói a mesma malha (importa para quem compara quadro a quadro).
static func tongue(parent: Node3D, length: float, width: float, material: Material,
		seed_value: float = 0.0, rings: int = 11, sides: int = 7) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var anel: Array[PackedVector3Array] = []
	for i: int in range(rings + 1):
		var t := float(i) / float(rings)
		var raio := width * pow(1.0 - t, 0.62)
		# Bojo logo acima da base: a chama incha antes de afinar.
		raio *= 1.0 + 0.28 * sin(t * PI) * (1.0 - t * 0.5)
		var torcao := t * (1.9 + sin(seed_value * 2.3) * 0.8)
		var pontos := PackedVector3Array()
		for k: int in range(sides):
			var ang := TAU * float(k) / float(sides) + torcao
			# Ruído por vértice: a seção deixa de ser círculo.
			var ondulacao := 1.0 + 0.20 * sin(ang * 3.0 + seed_value * 5.1 + t * 4.0)
			pontos.append(Vector3(cos(ang) * raio * ondulacao, t * length,
				sin(ang) * raio * ondulacao))
		anel.append(pontos)

	for i: int in range(rings):
		var baixo := anel[i]
		var cima := anel[i + 1]
		for k: int in range(sides):
			var k2 := (k + 1) % sides
			surface.add_vertex(baixo[k])
			surface.add_vertex(cima[k])
			surface.add_vertex(baixo[k2])
			surface.add_vertex(baixo[k2])
			surface.add_vertex(cima[k])
			surface.add_vertex(cima[k2])

	surface.generate_normals()
	return instance(parent, surface.commit(), material)


## Um punhado de línguas em coroa, tudo crescendo para +Y. É o que veste um
## corpo sólido (punho, sol) de fogo sem custar partícula.
static func plume(parent: Node3D, count: int, radius: float, length: float,
		width: float, material: Material) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for i: int in range(count):
		var ang := TAU * float(i) / float(count)
		var pivot := Node3D.new()
		parent.add_child(pivot)
		pivot.position = Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		# Inclina para fora: a coroa abre em vez de subir em coluna.
		pivot.rotation = Vector3(sin(ang) * 0.42, -ang, -cos(ang) * 0.42)
		# ⚠️ NUNCA passar de 1,0. O `mera_flame` normaliza o gradiente por `span`,
		# e quem chama passa `span = length`. Uma língua mais comprida que isso
		# tem a ponta com h=1, onde a erosão apaga tudo — o fogo sai mais curto
		# do que foi pedido, sem erro nenhum no log. Variar só para baixo mantém
		# a irregularidade sem mentir sobre a altura.
		var escala := 0.72 + 0.28 * absf(sin(float(i) * 2.399))
		out.append(tongue(pivot, length * escala, width, material, float(i) * 1.618))
	return out


static func ring(parent: Node3D, radius: float, width: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - width)
	mesh.outer_radius = radius + width
	mesh.rings = 48
	mesh.ring_segments = 6
	return instance(parent, mesh, material)


static func mote(parent: Node3D, size: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	return instance(parent, mesh, material)


static func shell(parent: Node3D, radius: float, material: Material,
		segments: int = 32) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	return instance(parent, mesh, material)


## A marca no chão. Fica DEITADA (plano XZ) e é recortada em círculo pelo shader.
static func scorch(parent: Node3D, radius: float) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 2.0
	var visual := instance(parent, mesh, scorch_material(radius))
	visual.position.y = 0.02   # sem z-fighting com o chão
	return visual


## O PUNHO em blocos, com a mesma disposição autorada em `FireFX._hiken`: palma,
## quatro dedos dobrados e polegar na lateral. Um `MultiMesh` — um desenho só
## para ~60 blocos.
##
## ⚠️ A SILHUETA É O NOME DO GOLPE. "Hiken" é **Punho** de Fogo; trocar o punho
## por uma esfera foi medido na captura `03_hiken_punho.png` de 2026-09-08 e lia
## como meteoro. O que muda em relação ao original não é a forma, é a
## SUPERFÍCIE: era laranja chapado, virou crosta de brasa com fenda acesa.
##
## ⚠️ `INSTANCE_CUSTOM` guarda a POSIÇÃO do bloco, não uma semente aleatória. O
## shader soma isso ao vértice para amostrar o ruído na posição real dentro do
## punho — é o que faz a rachadura ATRAVESSAR os blocos em vez de se repetir em
## cada um. Com semente aleatória o punho lia como parede de tijolos.
## A codificação é `pos / CUSTOM_RANGE + 0.5` porque `Color` guarda 0..1; o
## `CUSTOM_RANGE` do shader tem que casar com o daqui.
static func fist_blocks(parent: Node3D, block: float, material: Material) -> MultiMeshInstance3D:
	var blocos: Array[Vector3] = []
	for x: int in range(-2, 3):          # palma e dorso
		for y: int in range(-1, 2):
			for z: int in range(0, 3):
				blocos.append(Vector3(x, y, z) * block)
	for x: int in range(-2, 2):          # os quatro dedos dobrados, à frente (-Z)
		blocos.append(Vector3(x, 1, -1) * block)
		blocos.append(Vector3(x, 1, -2) * block)
		blocos.append(Vector3(x, 0, -2) * block)
		blocos.append(Vector3(x, -1, -2) * block)
		blocos.append(Vector3(x, -1, -1) * block)
	for ponto in [Vector3(2, 0, -1), Vector3(3, 0, -1),
			Vector3(2, -1, -1), Vector3(1, -1, -1)]:   # polegar
		blocos.append(ponto * block)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var caixa := BoxMesh.new()
	# 0,99 e não 0,95: com folga entre os cubos a luz passa pelas frestas e o
	# punho lê como blocos empilhados em vez de uma peça só.
	caixa.size = Vector3.ONE * (block * 0.99)
	mm.mesh = caixa
	mm.instance_count = blocos.size()
	for i: int in range(blocos.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), blocos[i]))
		var p := blocos[i] / CUSTOM_RANGE + Vector3(0.5, 0.5, 0.5)
		mm.set_instance_custom_data(i, Color(p.x, p.y, p.z, 0.0))

	var visual := MultiMeshInstance3D.new()
	visual.multimesh = mm
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual


# -------------------------------------------------------------------- tempo

## Empurra `age` (e opcionalmente `presence`) num punhado de materiais.
## Toda casca de fogo precisa disso todo quadro; centralizar evita que cada
## efeito invente o seu.
static func advance(materials: Array, age: float, presence: float = -1.0) -> void:
	for material in materials:
		if material is ShaderMaterial:
			material.set_shader_parameter("age", age)
			if presence >= 0.0:
				material.set_shader_parameter("presence", presence)


static func fade(material: StandardMaterial3D, alpha: float) -> void:
	var color := material.albedo_color
	color.a = clampf(alpha, 0.0, 1.0)
	material.albedo_color = color
