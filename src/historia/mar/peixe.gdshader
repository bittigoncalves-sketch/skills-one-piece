// ============================================================================
//  PEIXE — nado no vértice (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E6).
//
//  A malha vem NORMALIZADA (`cardumes.gd`): comprimento 1, cabeça em −Z, cauda em +Z.
//  O rabo ondula (onda que corre da cabeça para a cauda, mais forte atrás) e cada peixe
//  oscila dentro do cardume. A CPU só move o cardume inteiro; o resto é aqui.
//  `agitacao` (por cardume, 0–1): fugindo do jogador, bate o rabo mais rápido e espalha.
//  INSTANCE_CUSTOM: x = fase, y = ritmo, z = desvio lateral, w = desvio vertical.
// ============================================================================
shader_type spatial;
render_mode specular_disabled, diffuse_lambert, cull_disabled;
#include "res://src/fx/shaders/luz_cel.gdshaderinc"

uniform vec4 cor : source_color = vec4(1.0);
instance uniform float agitacao = 0.0;

void vertex() {
	float fase = INSTANCE_CUSTOM.x * 6.2831;
	float ritmo = 0.8 + INSTANCE_CUSTOM.y * 0.4;
	float t = TIME * (7.0 + agitacao * 9.0) * ritmo + fase;
	float atras = clamp(VERTEX.z + 0.15, 0.0, 1.0);
	VERTEX.x += sin(t - VERTEX.z * 6.0) * (0.07 + agitacao * 0.05) * atras * atras * 2.0;
	// Oscilação no cardume (em comprimentos de peixe): devagar, cada um no seu tempo.
	float lento = TIME * 0.6 * ritmo + fase * 2.0;
	vec3 deriva = vec3(sin(lento) * INSTANCE_CUSTOM.z, sin(lento * 1.3 + 1.0) * INSTANCE_CUSTOM.w,
		cos(lento * 0.8) * 0.4) * (1.0 + agitacao * 1.5);
	VERTEX += deriva;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// As cores dos modelos da loja são escuras para um peixe de meio metro cercado de
	// contorno (viravam silhueta — foto da E6): clareia e satura, no tom do recife vibrante.
	vec3 c = cor.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 1.45) * 1.55 + 0.03;
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
