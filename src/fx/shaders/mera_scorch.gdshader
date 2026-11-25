shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// CHÃO QUEIMADO — a marca que o fogo deixa onde bateu.
//
// Mesmo papel do `ope_floor.gdshader`: um plano recortado em círculo que carrega
// a borda do efeito quando a câmera está por perto. Lá é grade cirúrgica com
// varredura radial; aqui é chão rachado com a brasa esfriando de fora para
// dentro. `presence` some com o efeito, `cooling` apaga as fendas.

uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float cooling : hint_range(0.0, 1.0) = 0.0;   // 0 = recém-queimado, 1 = frio
uniform float age = 0.0;
uniform float radius = 3.0;
uniform vec4 char_color  : source_color = vec4(0.045, 0.032, 0.030, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.38, 0.05, 1.0);

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
	           mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);

	// A queimadura não é um disco perfeito: o ruído come a borda.
	vec2 world_p = p * radius;
	float edge_noise = vnoise(world_p * 1.9) * 0.16 + vnoise(world_p * 5.3) * 0.06;
	float burn = 1.0 - smoothstep(0.62 - edge_noise, 1.0 - edge_noise, r);

	// As RACHADURAS, mais largas no centro (onde bateu mais quente).
	float n = vnoise(world_p * 2.6) + vnoise(world_p * 6.1) * 0.45;
	float crack = 1.0 - smoothstep(0.020, 0.085, abs(fract(n * 2.2) - 0.5));
	crack *= smoothstep(0.98, 0.30, r);

	// A brasa esfria de FORA para dentro — a borda apaga primeiro.
	float cool_front = clamp(cooling * 1.35 - (1.0 - r) * 0.35, 0.0, 1.0);
	float ember = crack * (1.0 - cool_front);

	// Respiro lento, para o chão não ficar estático enquanto ainda queima.
	ember *= 0.72 + 0.28 * sin(age * 2.3 + n * 6.0);

	vec3 col = mix(char_color.rgb, ember_color.rgb, clamp(ember * 1.6, 0.0, 1.0));
	float alpha = burn * (0.55 + ember * 0.45) * presence;

	ALBEDO = col * (1.0 + ember * 2.8);
	ALPHA = clamp(alpha, 0.0, 0.92);
}
