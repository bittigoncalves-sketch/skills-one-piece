shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform float variant = 0.0;
uniform float held : hint_range(0.0, 1.0) = 1.0;
varying vec3 object_pos;

float stone_noise(vec3 p) {
    return sin(p.x * 4.7 + p.y * 2.1 + variant) * sin(p.z * 5.2 - p.y * 3.2)
        + 0.45 * sin(p.x * 11.3 + p.z * 4.0) * sin(p.y * 9.7 + variant);
}
void vertex() {
    VERTEX *= 0.9 + stone_noise(VERTEX) * 0.105;
    object_pos = VERTEX;
}
void fragment() {
    float strata = stone_noise(object_pos * 1.7);
    float band = smoothstep(-0.35, -0.28, strata) * 0.25 + smoothstep(0.35, 0.42, strata) * 0.22;
    vec3 stone = mix(vec3(0.055, 0.085, 0.11), vec3(0.24, 0.32, 0.36), band + 0.22);
    float vein = 1.0 - smoothstep(0.015, 0.045, abs(sin(object_pos.y * 15.0 + strata * 0.5)));
    ALBEDO = stone;
    ROUGHNESS = 0.98;
    EMISSION = vec3(0.02, 0.85, 1.0) * vein * (0.75 + held * 0.5);
}
