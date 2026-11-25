shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_add;

// CHAMA — corpo de fogo desenhado em MALHA, não em partícula.
//
// A régua é o `ope_room.gdshader`: geometria própria, sem textura, `presence` e
// `age` dirigidos de fora. Aqui o gradiente corre ao longo do EIXO LOCAL Y da
// malha (0 na base, 1 na ponta), então a mesma casca serve para língua de fogo,
// anel e esfera — basta orientar a malha.

uniform vec4 core_color : source_color = vec4(1.0, 0.93, 0.62, 1.0);
uniform vec4 mid_color  : source_color = vec4(1.0, 0.46, 0.06, 1.0);
uniform vec4 edge_color : source_color = vec4(0.72, 0.06, 0.01, 1.0);
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float age = 0.0;
uniform float turbulence : hint_range(0.0, 4.0) = 1.6;
uniform float scroll : hint_range(0.0, 6.0) = 2.4;
uniform float span = 1.0;      // altura da malha, para normalizar o gradiente
uniform float erosion : hint_range(0.0, 1.0) = 0.55;

varying vec3 local_pos;

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03) * 0.30 + vnoise(p * 4.11) * 0.15;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// 0 na base da malha, 1 na ponta.
	float h = clamp(local_pos.y / max(span, 0.001), 0.0, 1.0);

	// O fogo SOBE: a amostra desce enquanto o tempo passa.
	vec3 sample_p = vec3(local_pos.x, local_pos.y - age * scroll, local_pos.z) * turbulence;
	float n = fbm(sample_p);

	// A chama afina para a ponta, e o ruído decide onde ela se rompe.
	float taper = 1.0 - h;
	float body = clamp(taper * 1.35 + n * 0.5 - h * erosion, 0.0, 1.0);

	// Núcleo claro embaixo, borda escura em cima — a leitura de temperatura.
	float heat = clamp(body * 1.25 - h * 0.35, 0.0, 1.0);
	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.10, 0.55, heat));
	col = mix(col, core_color.rgb, smoothstep(0.62, 0.95, heat));

	// Borda de silhueta, como o rim do ROOM — dá volume sem luz dinâmica.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 3.0);

	ALBEDO = col * (1.35 + rim * 0.85);
	ALPHA = clamp(body * (0.42 + rim * 0.5) * presence, 0.0, 1.0);
}
