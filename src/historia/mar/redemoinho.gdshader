// ============================================================================
//  REDEMOINHO — aviso de besta surgindo (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E5).
//  Disco na superfície: braços de espuma em espiral girando, olho escuro no meio,
//  borda que some. `forca` (0–1) é a vida do aviso: cresce, gira mais rápido, apaga.
// ============================================================================
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 espuma : source_color = vec4(0.88, 0.97, 1.0, 1.0);
uniform vec4 olho : source_color = vec4(0.02, 0.10, 0.20, 1.0);
uniform float forca = 0.0;
uniform float giro = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = atan(p.y, p.x);
	// 4 braços em espiral logarítmica: o ângulo cresce para dentro.
	float bracos = fract((a / 6.2831) * 4.0 + log(r + 0.04) * 1.6 + giro);
	float faixa = smoothstep(0.0, 0.08, bracos) * (1.0 - smoothstep(0.45, 0.62, bracos));
	float borda = 1.0 - smoothstep(0.7, 1.0, r);
	float miolo = 1.0 - smoothstep(0.0, 0.22, r);
	float alfa = faixa * borda * smoothstep(0.08, 0.3, r);
	vec3 c = espuma.rgb;
	alfa = max(alfa, miolo * 0.8);
	c = mix(c, olho.rgb, miolo);
	ALBEDO = c;
	ALPHA = alfa * forca;
}
