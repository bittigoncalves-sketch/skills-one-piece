shader_type spatial;
render_mode cull_disabled;

uniform vec4 cor_rasa : source_color = vec4(0.19, 0.69, 0.88, 1.0);
uniform vec4 cor_funda : source_color = vec4(0.018, 0.12, 0.31, 1.0);
uniform vec4 cor_espuma : source_color = vec4(0.83, 0.96, 1.0, 1.0);
uniform vec4 bases[64]; // centro XZ, semitamanho XZ
uniform vec2 giros[64]; // cos/sin do giro Y
uniform int quantidade_bases = 0;
uniform float largura_raso : hint_range(10.0, 250.0) = 85.0;
uniform float altura_ondas : hint_range(0.0, 3.0) = 0.65;
uniform float velocidade : hint_range(0.0, 3.0) = 1.0;
// Capturas comparáveis sem depender do tempo de importação/carregamento.
uniform float tempo_fixo = -1.0;
// Mesmo relógio usado pela física dos barcos; também respeita pausa da cena.
uniform float tempo_simulado = 0.0;
// Vista de BAIXO (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E7): luz do dia que atravessa
// a superfície (1 = meio-dia), posta pela `VisaoSubmersa`.
uniform float luz_submersa = 1.0;
varying vec3 pos_mundo;
varying float altura;

float costa(vec2 p) {
	float d = 1000000.0;
	for (int i = 0; i < quantidade_bases; i++) {
		vec2 q = p - bases[i].xy;
		q = vec2(giros[i].x*q.x - giros[i].y*q.y, giros[i].y*q.x + giros[i].x*q.y);
		q = abs(q) - bases[i].zw;
		d = min(d, length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0));
	}
	return d;
}

float tempo() { return (tempo_fixo >= 0.0 ? tempo_fixo : tempo_simulado) * velocidade; }

float ondulacao(vec2 p, float d, float t) {
	float mar = sin(dot(p, vec2(0.105, 0.046)) - t*1.05);
	mar += 0.48*sin(dot(p, vec2(-0.066, 0.16)) - t*1.38 + 1.7);
	mar += 0.22*sin(dot(p, vec2(0.28, 0.19)) - t*1.85);
	float perto = 1.0 - smoothstep(8.0, 65.0, d);
	// +t na distância à costa faz a arrebentação vir do mar para a ilha.
	float rebentacao = sin(d*0.72 + t*1.65 + sin(p.x*0.10 + p.y*0.07)*0.35);
	return altura_ondas * (mar*0.55*mix(0.22, 1.0, 1.0-perto) + rebentacao*0.19*perto);
}

void vertex() {
	vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = costa(mundo.xz);
	// Malha densa perto da câmera, horizonte progressivo sem costura entre planos.
	float detalhe = 1.0-smoothstep(65.0, 94.0, max(abs(VERTEX.x), abs(VERTEX.z)));
	altura = ondulacao(mundo.xz, d, tempo());
	VERTEX.y += altura*detalhe;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pos_mundo.xz;
	float d = costa(p);
	float t = tempo();
	float profundo = smoothstep(5.0, largura_raso, max(d, 0.0));
	float variacao = sin(dot(p, vec2(0.042, -0.059)) + t*0.19) * sin(dot(p, vec2(0.029, 0.031)) - t*0.14);
	vec3 agua = mix(cor_rasa.rgb, cor_funda.rgb, profundo);
	agua *= 1.0 + variacao*0.10;
	// Normais de ondas longas + ondulação curta animada: superfície tem volume
	// também na distância onde não vale deslocar geometria.
	float h = ondulacao(p, d, t);
	float hx = ondulacao(p + vec2(0.35, 0.0), costa(p + vec2(0.35, 0.0)), t);
	float hz = ondulacao(p + vec2(0.0, 0.35), costa(p + vec2(0.0, 0.35)), t);
	vec2 miudo = vec2(0.91, 0.41)*cos(dot(p, vec2(0.91, 0.41))*1.7 - t*2.1 + variacao)*0.018;
	miudo += vec2(-0.35, 0.94)*cos(dot(p, vec2(-0.35, 0.94))*2.3 - t*1.7)*0.009;
	vec3 normal_mundo = normalize(vec3((h-hx)/0.35 + miudo.x, 1.0, (h-hz)/0.35 + miudo.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);
	float fase = d*0.72 + t*1.65 + sin(p.x*0.10 + p.y*0.07)*0.35;
	float quebra = smoothstep(0.82, 0.98, sin(fase));
	float recorte = smoothstep(-0.55, 0.4, sin(p.x*0.55+p.y*0.73-t*0.38) + sin(p.y*1.15-p.x*0.21)*0.4);
	float espuma = quebra * recorte * (1.0-smoothstep(2.0, 18.0, d)) * smoothstep(-0.4, 0.8, d);
	// Cristas esparsas em mar aberto, sem transformar toda a água em ruído branco.
	espuma += smoothstep(0.79, 0.96, h/max(altura_ondas, 0.001)) * 0.16 * profundo;
	if (FRONT_FACING) {
		ALBEDO = mix(agua, cor_espuma.rgb, clamp(espuma, 0.0, 0.9));
		ROUGHNESS = mix(0.38, 0.72, espuma);
		SPECULAR = 0.45;
		METALLIC = 0.08;
	} else {
		// De baixo: a "janela de Snell" — olhando para cima a luz do céu atravessa (claro);
		// em ângulo rasante a superfície espelha o fundo (escuro). As ondulações tremem a
		// luz. Brilho por EMISSÃO: a face de trás não recebe o sol. A névoa da água (E7)
		// apaga o que está longe.
		vec3 v = normalize(pos_mundo - CAMERA_POSITION_WORLD);
		float janela = smoothstep(0.45, 0.88, v.y);
		float tremor = 0.8 + 0.4 * smoothstep(-0.6, 0.9, (h - hx) * 6.0 + (miudo.x + miudo.y) * 20.0);
		vec3 claro = vec3(0.78, 0.95, 1.0);
		vec3 espelho = vec3(0.05, 0.26, 0.34);
		NORMAL = -NORMAL;
		ALBEDO = vec3(0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		EMISSION = mix(espelho, claro, janela) * tremor * (0.35 + 0.65 * luz_submersa) + cor_espuma.rgb * espuma * 0.3;
	}
}
