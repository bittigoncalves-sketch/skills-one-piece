// ============================================================================
//  NAUFRÁGIO — madeira afundada (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E3).
//
//  A cor do vértice é a COR da peça (madeira, metal, lona: tools/blender/naufragios.py).
//  Por cima, o tempo no fundo: ALGA nas faces que olham para CIMA no mundo (o casco
//  tomba em qualquer ângulo e a alga continua por cima), CRACAS em pintas claras e a
//  madeira mais escura e verde perto do chão. Luz em faixas com o piso alto de água.
// ============================================================================
shader_type spatial;
render_mode specular_disabled, diffuse_lambert, cull_disabled;
#include "res://src/fx/shaders/luz_cel.gdshaderinc"

uniform vec4 alga : source_color = vec4(0.30, 0.47, 0.25, 1.0);
uniform vec4 alga_clara : source_color = vec4(0.52, 0.66, 0.32, 1.0);
uniform vec4 craca : source_color = vec4(0.86, 0.84, 0.76, 1.0);
uniform float chao_y = -15.0;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

float ruido(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(c + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float cc = fract(sin(dot(c + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(c + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(cc, d, f.x), f.y);
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(normal_mundo);
	if (!FRONT_FACING) {
		n = -n;
		NORMAL = -NORMAL;
	}
	vec3 c = COLOR.rgb;
	// Mais escura e esverdeada perto do chão (lodo).
	float baixo = 1.0 - smoothstep(0.0, 2.5, pos_mundo.y - chao_y);
	c = mix(c, c * vec3(0.55, 0.7, 0.6), baixo * 0.6);
	// Alga por cima: manchas pelo ruído, mais densas quanto mais a face olha para cima.
	vec2 q = pos_mundo.xz * 0.55 + pos_mundo.y * 0.3;
	float mancha = ruido(q) * 0.65 + ruido(q * 3.1) * 0.35;
	float cima = smoothstep(0.35, 0.85, n.y);
	float a = smoothstep(0.45, 0.62, mancha * (0.55 + cima * 0.6));
	c = mix(c, mix(alga.rgb, alga_clara.rgb, ruido(q * 7.0)), a * 0.85);
	// Cracas: pintas claras nos costados.
	float pinta = step(0.86, ruido(pos_mundo.xy * 6.0 + pos_mundo.zz * 3.0)) * (1.0 - cima);
	c = mix(c, craca.rgb, pinta * 0.7);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
