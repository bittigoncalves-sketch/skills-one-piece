// ============================================================================
//  FUNDO DO MAR — material (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E1).
//
//  Cor pela PROFUNDIDADE (areia clara no raso → verde-água → azul petróleo no mar
//  aberto), rocha pelas máscaras do relevo e pela inclinação, e ondulação miúda de
//  areia (marcas da corrente) só no desenho — o relevo de 4 m não carrega detalhe de
//  1 m. Luz em faixas, a mesma do resto do mundo (`luz_cel.gdshaderinc`).
//
//  COR do vértice = máscaras do `RelevoMarinho`: r = rocha, g = recife (substrato
//  claro onde os corais crescem, E2), b = dunas (crista clara).
//  Na costa (acima de `nivel − 1,5 m`) a cor é a areia do relevo da ilha
//  (`COR_RASA` = #d8c8a0), para a emenda com a praia não aparecer fora d'água.
// ============================================================================
shader_type spatial;
render_mode specular_disabled, diffuse_lambert;
#include "res://src/fx/shaders/luz_cel.gdshaderinc"

uniform float nivel = -0.65;
uniform vec4 areia_praia : source_color = vec4(0.847, 0.784, 0.627, 1.0);
uniform vec4 areia_rasa : source_color = vec4(0.80, 0.74, 0.58, 1.0);
uniform vec4 areia_meia : source_color = vec4(0.47, 0.60, 0.55, 1.0);
uniform vec4 fundo_aberto : source_color = vec4(0.16, 0.30, 0.36, 1.0);
uniform vec4 fundo_fossa : source_color = vec4(0.07, 0.14, 0.22, 1.0);
uniform vec4 rocha_clara : source_color = vec4(0.46, 0.47, 0.42, 1.0);
uniform vec4 rocha_escura : source_color = vec4(0.22, 0.27, 0.27, 1.0);
uniform vec4 substrato_recife : source_color = vec4(0.88, 0.82, 0.70, 1.0);
uniform float ondulacao_forca : hint_range(0.0, 1.0) = 0.35;

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
	float prof = nivel - pos_mundo.y;
	vec3 n = normalize(normal_mundo);
	// Areia pela profundidade.
	vec3 cor = mix(areia_rasa.rgb, areia_meia.rgb, smoothstep(2.0, 18.0, prof));
	cor = mix(cor, fundo_aberto.rgb, smoothstep(20.0, 58.0, prof));
	cor = mix(cor, fundo_fossa.rgb, smoothstep(66.0, 78.0, prof));
	// Substrato claro do recife e crista das dunas.
	cor = mix(cor, substrato_recife.rgb * mix(1.0, 0.75, smoothstep(6.0, 18.0, prof)), COLOR.g * 0.55);
	cor *= 1.0 + COLOR.b * 0.06;
	// Rocha: máscara do relevo OU encosta íngreme. Manchas pelo ruído (pedra gasta).
	float ingreme = 1.0 - smoothstep(0.72, 0.9, n.y);
	float rocha = clamp(max(COLOR.r, ingreme), 0.0, 1.0);
	vec2 gp = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * pos_mundo.xz;
	vec3 pedra = mix(rocha_escura.rgb, rocha_clara.rgb, ruido(gp * 0.35) * 0.6 + ruido(gp * 1.7) * 0.4);
	pedra = mix(pedra, fundo_aberto.rgb, smoothstep(25.0, 70.0, prof) * 0.6);
	cor = mix(cor, pedra, smoothstep(0.25, 0.6, rocha));
	// Fora d'água, na costa: a areia do relevo da ilha, sem emenda.
	cor = mix(cor, areia_praia.rgb, smoothstep(nivel - 1.5, nivel + 0.2, pos_mundo.y));
	// Marcas de corrente na areia: perturba a normal (só na areia, some ao longe).
	// Direção FIXA com o domínio entortado por ruído: ondas paralelas e sinuosas.
	// (Rumo variando com a posição dentro de dot(pos, rumo) fazia ANÉIS concêntricos:
	// a fase cresce com a distância à origem — foto da E1, 14/10.)
	float longe = 1.0 - smoothstep(14.0, 40.0, length(pos_mundo - CAMERA_POSITION_WORLD));
	float areia = (1.0 - smoothstep(0.25, 0.6, rocha)) * smoothstep(0.5, 2.0, prof) * longe;
	areia *= smoothstep(0.25, 0.7, ruido(pos_mundo.xz * 0.06));
	vec2 rumo = vec2(0.83, 0.56);
	float entorta = ruido(pos_mundo.xz * 0.045) * 6.0 + ruido(pos_mundo.xz * 0.14) * 1.6;
	float fase = dot(pos_mundo.xz, rumo) * 2.4 + entorta;
	vec2 inclina = rumo * cos(fase) * ondulacao_forca * areia;
	vec3 nm = normalize(n + vec3(inclina.x, 0.0, inclina.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nm, 0.0)).xyz);
	// Grão: variação leve, como o `variacao_chao` do relevo. Domínio girado: alinhado aos
	// eixos, o ruído de valor deixava uma grade de quadrados visível (foto E1, 14/10).
	vec2 girado = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * pos_mundo.xz;
	cor *= 0.96 + ruido(girado * 0.9) * 0.04 + ruido(girado * 0.23) * 0.04;
	ALBEDO = cor;
	ROUGHNESS = 1.0;
}
