extends RefCounted
# ============================================================================
#  CORES DOS CARANGUEJOS RIVAIS (06/10/2026).
#
#  Pedido do dono: "dar várias cores aos caranguejos, deixando a cor dos adversários do
#  jogador aleatória". Decisões dele: só os RIVAIS (o caranguejo do jogador fica como
#  está), sorteados a cada corrida, em qualquer cor, VIVAS e DISTINTAS entre si.
#
#  Pintar: a cor do caranguejo vem dos VÉRTICES (albedo branco × cor de vértice); tingir
#  o albedo só escurecia o marrom. Aqui cada superfície ganha um shader que troca o
#  MATIZ e a saturação e conserva o brilho relativo de cada ponto — as manchas e o
#  desenho do casco continuam lá, em outra cor.
# ============================================================================

## Folga mínima de matiz entre dois rivais da mesma largada (fração do círculo).
const MATIZ_MINIMO := 0.14
const SATURACAO := Vector2(0.75, 0.95)
const VALOR := Vector2(0.85, 1.0)
## O caranguejo original é marrom escuro: o brilho de cada ponto sobe este tanto para a
## cor ficar viva (sem estourar o branco).
const GANHO_DE_BRILHO := 1.9

static var _shader: Shader = null


## `n` cores vivas e distintas: o círculo dividido em `n` fatias a partir de um ponto
## sorteado, com um tremor em cada uma, embaralhadas.
static func sortear(n: int, rng: RandomNumberGenerator) -> Array[Color]:
	var cores: Array[Color] = []
	var inicio := rng.randf()
	var fatia := 1.0 / maxf(float(n), 1.0)
	var tremor := maxf(0.0, (fatia - MATIZ_MINIMO) * 0.5)
	for i in n:
		var h := fposmod(inicio + i * fatia + rng.randf_range(-tremor, tremor), 1.0)
		cores.append(Color.from_hsv(h, rng.randf_range(SATURACAO.x, SATURACAO.y), rng.randf_range(VALOR.x, VALOR.y)))
	for i in range(cores.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := cores[i]
		cores[i] = cores[j]
		cores[j] = t
	return cores


## Menor distância de matiz (0..0,5) entre duas cores, no círculo.
static func distancia_de_matiz(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h)
	return minf(d, 1.0 - d)


## Pinta todas as malhas debaixo de `raiz` com o matiz de `cor`. Materiais repetidos
## (as oito patas) dividem o mesmo material novo.
static func pintar(raiz: Node, cor: Color) -> void:
	var feitos := {}
	for no in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var original := mi.get_active_material(s)
			if not original is StandardMaterial3D:
				continue
			if not feitos.has(original):
				feitos[original] = _material(original as StandardMaterial3D, cor)
			mi.set_surface_override_material(s, feitos[original])


static func _material(o: StandardMaterial3D, cor: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform vec4 base : source_color = vec4(1.0);
uniform bool usa_vertice = true;
uniform vec4 tinta : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float ganho = 1.9;
uniform float aspereza = 0.7;
uniform float metal = 0.0;

vec3 rgb_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 original = base.rgb * (usa_vertice ? COLOR.rgb : vec3(1.0));
	vec3 o = rgb_hsv(original);
	vec3 t = rgb_hsv(tinta.rgb);
	// Matiz da tinta; saturação perto da dela; brilho de cada ponto (o desenho fica).
	float v = clamp(o.z * ganho * t.z, 0.0, 1.0);
	ALBEDO = hsv_rgb(vec3(t.x, mix(o.y, t.y, 0.85), v));
	ROUGHNESS = aspereza;
	METALLIC = metal;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("base", o.albedo_color)
	m.set_shader_parameter("usa_vertice", o.vertex_color_use_as_albedo)
	m.set_shader_parameter("tinta", cor)
	m.set_shader_parameter("ganho", GANHO_DE_BRILHO)
	m.set_shader_parameter("aspereza", o.roughness)
	m.set_shader_parameter("metal", o.metallic)
	return m
