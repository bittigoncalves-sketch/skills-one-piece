shader_type spatial;
render_mode blend_mix, cull_disabled;
uniform vec4 cor : source_color = vec4(0.10, 0.53, 0.85, 0.72);
uniform float fluxo = 1.0;
void fragment() {
	float borda = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float veios = pow(0.5 + 0.5 * sin(UV.y * 110.0 - TIME * 32.0 * fluxo + sin(UV.x * 25.0)), 8.0);
	ALBEDO = mix(cor.rgb, vec3(0.78, 0.94, 1.0), veios * 0.65 + borda * 0.25);
	ROUGHNESS = 0.12;
	METALLIC = 0.10;
	EMISSION = ALBEDO * (0.18 + veios * 0.35);
	ALPHA = cor.a * (0.55 + borda * 0.35 + veios * 0.1);
}
