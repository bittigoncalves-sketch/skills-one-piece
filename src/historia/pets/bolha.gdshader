shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
void fragment() {
	float borda = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
	vec3 perola = vec3(0.48, 0.75, 0.83) + 0.14 * sin(vec3(0.0, 2.1, 4.2) + NORMAL.y * 7.0);
	ALBEDO = perola;
	ROUGHNESS = 0.09;
	METALLIC = 0.12;
	ALPHA = 0.07 + 0.66 * borda;
}
