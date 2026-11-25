// ============================================================================
//  NÉVOA DA ÁGUA — absorção e raios de luz vistos de dentro d'água
//  (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E7).
//
//  Quadro de tela cheia DEPOIS do `Contorno` (prioridade 100 > 90): a água engole o que
//  está longe — e as linhas do contorno junto (as cristas do fundo viravam aramado preto,
//  pendência da E1). Cor da água pela profundidade da CÂMERA (turquesa no raso, azul
//  petróleo no fundo) e pela luz do dia (`luz`). Raios de luz descendo da superfície na
//  direção do sol, mais fortes olhando para cima. Substitui a tinta chapada da HUD.
// ============================================================================
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D prof_tex : hint_depth_texture, filter_nearest;
uniform vec4 agua_rasa : source_color = vec4(0.10, 0.46, 0.56, 1.0);
uniform vec4 agua_funda : source_color = vec4(0.02, 0.12, 0.24, 1.0);
uniform vec4 cor_raios : source_color = vec4(0.62, 0.9, 0.95, 1.0);
uniform float profundidade_camera = 0.0;
uniform float densidade = 0.042;
uniform float tinta_minima = 0.1;
uniform float luz = 1.0;
uniform vec3 rumo_sol = vec3(0.3, 0.9, 0.2);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

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

void fragment() {
	float cru = texture(prof_tex, SCREEN_UV).x;
	vec4 vista = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, cru, 1.0);
	vista /= vista.w;
	float dist = min(length(vista.xyz), 400.0);
	vec3 olhar = normalize((INV_VIEW_MATRIX * vec4(vista.xyz, 0.0)).xyz);
	float fundo = smoothstep(2.0, 50.0, profundidade_camera);
	vec3 agua = mix(agua_rasa.rgb, agua_funda.rgb, fundo) * luz;
	// Olhando para cima a água clareia (a luz vem de lá); para baixo, escurece.
	agua *= mix(0.7, 1.35, smoothstep(-0.6, 0.8, olhar.y));
	// Raios: faixas que descem inclinadas pelo rumo do sol, tremendo devagar.
	vec3 s = normalize(rumo_sol);
	float para_sol = pow(max(dot(olhar, s), 0.0), 3.0);
	vec2 faixa = vec2(dot(olhar.xz, normalize(vec2(-s.z, s.x) + 1e-4)) * 9.0, TIME * 0.12);
	float listras = smoothstep(0.55, 0.95, ruido(faixa) * 0.7 + ruido(faixa * 2.3 + 3.1) * 0.3);
	float raios = listras * (0.35 + para_sol * 0.9) * smoothstep(-0.1, 0.6, olhar.y) * (1.0 - fundo * 0.8) * luz;
	vec3 cor = agua + cor_raios.rgb * raios * 0.45;
	float f = 1.0 - exp(-dist * densidade * mix(1.0, 1.35, fundo));
	ALBEDO = cor;
	ALPHA = clamp(tinta_minima + f * (1.0 - tinta_minima) + raios * 0.25, 0.0, 1.0);
}
