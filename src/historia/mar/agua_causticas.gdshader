// ============================================================================
//  CÁUSTICAS — luz ondulando no fundo, vista de dentro d'água
//  (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E7). Decisão do dono: a superfície é opaca e
//  o investimento é a VISÃO SUBMERSA.
//
//  Quadro de tela cheia (como o `Contorno`): lê a profundidade, reconstrói o ponto no
//  mundo e SOMA a rede de luz das cáusticas nas superfícies que olham para cima, forte no
//  raso e sumindo com a profundidade e a distância. Só existe com a câmera submersa
//  (`visao_submersa.gd` liga/desliga). Desenha depois da cena e antes da névoa.
// ============================================================================
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D prof_tex : hint_depth_texture, filter_nearest;
uniform sampler2D norm_tex : hint_normal_roughness_texture, filter_nearest;
uniform float nivel = -0.65;
uniform float forca = 2.8;   // HDR: a areia ao sol passa de 2,0 em linear antes do tonemap
uniform float luz = 1.0;
uniform vec4 cor : source_color = vec4(0.78, 0.97, 1.0, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

// Rede de cáusticas (turbulência de água clássica, 4 iterações; azulejável no plano).
float causticas(vec2 p, float t) {
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 4; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return pow(abs(c), 8.0);
}

void fragment() {
	float cru = texture(prof_tex, SCREEN_UV).x;
	vec4 vista = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, cru, 1.0);
	vista /= vista.w;
	float dist = length(vista.xyz);
	vec3 mundo = (INV_VIEW_MATRIX * vec4(vista.xyz, 1.0)).xyz;
	vec3 n = normalize(texture(norm_tex, SCREEN_UV).rgb * 2.0 - 1.0);
	vec3 n_mundo = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float abaixo = nivel - mundo.y;
	float cima = smoothstep(0.1, 0.7, n_mundo.y);
	float raso = exp(-max(abaixo, 0.0) / 20.0) * step(0.2, abaixo);
	float perto = 1.0 - smoothstep(18.0, 48.0, dist);
	// Duas escalas misturadas: rede fina e ondas largas.
	// 0,9/m: células de 1–2 m (com 0,32/m cada célula tinha 3–6 m e a rede virava
	// claridade larga — medido fora do jogo: mediana 0,055, p90 0,21, p99 0,58).
	vec2 p = mundo.xz * 0.9;
	// Domínio canônico da função: mod(p, 2π) − 250 (com outro deslocamento a rede vira
	// claridade uniforme — a areia estourou na primeira captura).
	float c = causticas(mod(p, 6.2831) - 250.0, TIME * 0.45);
	c = c * 0.8 + causticas(mod(p * 0.47 + 1.7, 6.2831) - 250.0, TIME * 0.31) * 0.45;
	c = smoothstep(0.12, 0.6, c);              // realça as linhas, apaga o fundo da rede
	ALBEDO = cor.rgb * c * forca * raso * cima * perto * luz;
	ALPHA = 1.0;
}
