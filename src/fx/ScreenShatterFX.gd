extends CanvasLayer
## Efeito visual de quebra de tela (Screen Shatter) para os impactos da Gura Gura no Mi.

const SHADER_CODE := """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0; // 0 = normal, 1 = tela totalmente estilhaçada
uniform vec4 crack_color : source_color = vec4(0.85, 0.94, 1.0, 1.0);

// Random hash function
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    vec2 center = vec2(0.5, 0.5);
    vec2 offset = uv - center;
    float dist = length(offset);
    float angle = atan(offset.y, offset.x);

    // Cria rachaduras agudas estilo vidro estilhaçado
    float num_shards = 7.0;
    float base_angle = angle * num_shards / 6.28318;
    float line_pattern = abs(fract(base_angle + sin(dist * 8.0) * 0.4) - 0.5);
    float cracks = smoothstep(0.08, 0.0, line_pattern);
    
    // Distorce o UV onde existem rachaduras
    float shatter = cracks * intensity;
    vec2 shattered_uv = SCREEN_UV + (offset * shatter * 0.15);
    
    // Coleta a cor da tela distorcida
    vec4 screen_color = texture(SCREEN_TEXTURE, shattered_uv);
    
    // Adiciona o brilho das rachaduras (cyan/branco da Gura Gura)
    float crack_glow = cracks * intensity;
    
    COLOR = mix(screen_color, crack_color, crack_glow * 1.5);
}
"""

var _mat: ShaderMaterial
var _intensity := 0.0

func _ready() -> void:
	layer = 110 # Fica acima de quase tudo
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)
	
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	rect.material = _mat
	add_child(rect)

func shatter(strength: float = 1.0, duration: float = 0.5) -> void:
	_intensity = clampf(strength, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_method(_set_intensity, _intensity, 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_intensity(val: float) -> void:
	_intensity = val
	_mat.set_shader_parameter("intensity", _intensity)
