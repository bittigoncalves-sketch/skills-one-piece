shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 field_color : source_color = vec4(0.06, 0.80, 0.94, 1.0);
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float age = 0.0;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float rim = pow(1.0 - facing, 8.0);
    float latitude = abs(fract(local_pos.y * 8.0 + 0.5) - 0.5);
    float wire = 1.0 - smoothstep(0.008, 0.025, latitude);
    float scan_y = mod(age * 0.13, 2.4) - 1.2;
    float scan = exp(-abs(local_pos.y - scan_y) * 80.0);
    ALBEDO = field_color.rgb * (1.8 + scan * 0.45);
    ALPHA = clamp((0.002 + rim * 0.48 + wire * 0.014 + scan * 0.055) * presence, 0.0, 0.55);
}
