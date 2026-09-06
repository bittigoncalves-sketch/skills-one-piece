shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float age = 0.0;
uniform float radius = 18.0;
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float clip_circle = 1.0 - smoothstep(0.988, 1.0, r);
    vec2 world_p = p * radius;
    vec2 cell = abs(fract(world_p / 3.0 + 0.5) - 0.5);
    float grid = 1.0 - smoothstep(0.007, 0.02, min(cell.x, cell.y));
    float edge = 1.0 - smoothstep(0.0015, 0.0045, abs(r - 0.985));
    float inner = 1.0 - smoothstep(0.001, 0.003, abs(r - 0.95));
    float angle = atan(p.y, p.x);
    float ticks = (1.0 - smoothstep(0.01, 0.04, abs(sin(angle * 48.0)))) * step(0.927, r);
    float scan = exp(-abs(r - fract(age * 0.23)) * 95.0) * 0.07;
    float alpha = grid * 0.032 + edge * 0.62 + inner * 0.18 + ticks * 0.38 + scan;
    ALBEDO = vec3(0.09, 1.18, 1.52);
    ALPHA = alpha * clip_circle * presence;
}
