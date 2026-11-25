shader_type spatial;
// ÁGUA DO RIO — superfície das células molhadas dos blocos de terreno (30/09/2026).
//
// Translúcida de propósito: o rio é raso e o leito escavado aparece por baixo. A cor
// sai da PROFUNDIDADE REAL (o que está atrás da água no buffer de profundidade):
// clara e quase transparente na beira, azul mais fundo no meio, espuma onde encosta
// no barranco. Paleta irmã da do oceano (`oceano_historia.gdshader`), um tom acima —
// água doce, mais clara.
//
// A correnteza corre em coordenada de MUNDO, de norte para sul (+Z), como o rio da
// Ilha Inicial; blocos vizinhos emendam sem costura porque ninguém usa UV.
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec4 cor_rasa : source_color = vec4(0.31, 0.70, 0.81, 1.0);
uniform vec4 cor_funda : source_color = vec4(0.11, 0.43, 0.60, 1.0);
uniform vec4 cor_espuma : source_color = vec4(0.90, 0.97, 1.0, 1.0);
uniform float profundidade_cheia : hint_range(0.2, 5.0) = 1.1;
uniform vec2 correnteza = vec2(0.05, 0.55);   // m/s no plano XZ do mundo
uniform float altura_ondulacao : hint_range(0.0, 0.2) = 0.025;
// Captura determinística (validador): >= 0 congela o tempo neste valor.
uniform float tempo_fixo = -1.0;
uniform sampler2D tela_profundidade : hint_depth_texture, filter_linear_mipmap;

varying vec3 mundo;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(c), hash(c + vec2(1.0, 0.0)), f.x),
		mix(hash(c + vec2(0.0, 1.0)), hash(c + vec2(1.0, 1.0)), f.x), f.y);
}

float tempo() {
	return tempo_fixo >= 0.0 ? tempo_fixo : TIME;
}

// Duas camadas de ondinha arrastadas pela correnteza, em velocidades diferentes:
// é o que dá a leitura de "água andando" sem textura nenhuma.
float ondinhas(vec2 p, float t) {
	return ruido((p - correnteza * t) * 0.9) + 0.5 * ruido((p - correnteza * t * 1.6) * 2.3 + 17.0);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = tempo();
	VERTEX.y += (sin(mundo.x * 0.9 + t * 1.7) + sin(mundo.z * 1.3 - t * 2.1)) * altura_ondulacao;
}

void fragment() {
	float t = tempo();
	vec2 p = mundo.xz;
	float e = 0.12;
	float h = ondinhas(p, t);
	float hx = ondinhas(p + vec2(e, 0.0), t);
	float hz = ondinhas(p + vec2(0.0, e), t);
	// Inclinação da normal contida (0,6): mais que isso cada ondinha refletia o sol
	// e o rio virava purpurina (capturas de 30/09/2026).
	vec3 n_mundo = normalize(vec3((h - hx) * 0.6, 1.0, (h - hz) * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_mundo, 0.0)).xyz);

	// Profundidade da água ao longo do olhar: chão atrás menos a superfície.
	float d = texture(tela_profundidade, SCREEN_UV).r;
	vec4 chao = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	chao.xyz /= chao.w;
	float prof = max(VERTEX.z - chao.z, 0.0);
	float f = clamp(prof / profundidade_cheia, 0.0, 1.0);

	vec3 cor = mix(cor_rasa.rgb, cor_funda.rgb, f);
	// Espuma: faixa fina onde a água encosta na margem, picotada pelas ondinhas.
	float beira = 1.0 - smoothstep(0.0, 0.22, prof);
	float picote = smoothstep(0.45, 0.75, ruido((p - correnteza * t) * 2.6));
	cor = mix(cor, cor_espuma.rgb, clamp(beira * (0.55 + 0.45 * picote), 0.0, 1.0));

	ALBEDO = cor;
	ALPHA = mix(0.62, 0.93, f) + beira * 0.2;
	// Rugosidade não muito baixa: com 0,12 o sol virava purpurina branca no rio
	// inteiro e a água lia cinza-leitosa (captura de 30/09/2026).
	ROUGHNESS = 0.32;
	SPECULAR = 0.3;
}
