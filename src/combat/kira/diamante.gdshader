shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

// Pequenas faces de cristal sobre a malha articulada e a aparência existente.
float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * vec2(9.0, 12.0);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float facet = step(f.x + f.y, 1.0);
	float brilho = hash_cell(cell) * 0.30 + facet * 0.20;
	float borda = 1.0 - smoothstep(0.015, 0.06, min(min(f.x, f.y), min(1.0 - f.x, 1.0 - f.y)));
	vec3 azul = mix(vec3(0.14, 0.46, 0.68), vec3(0.69, 0.91, 1.0), clamp(brilho + 0.35, 0.0, 1.0));
	ALBEDO = mix(azul, vec3(0.85, 0.97, 1.0), borda * 0.38);
	METALLIC = 0.25;
	ROUGHNESS = 0.24;
	SPECULAR = 0.8;
	ALPHA = 0.87;
}
