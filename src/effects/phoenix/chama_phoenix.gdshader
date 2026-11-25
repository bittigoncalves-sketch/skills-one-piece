shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, shadows_disabled;
uniform vec4 azul : source_color = vec4(0.02,0.68,1.0,1.0);
uniform vec4 ouro : source_color = vec4(0.38,0.98,0.95,1.0);
varying vec3 local;
void vertex() {
	local = VERTEX;
	float ponta = UV.y*UV.y;
	VERTEX.x += sin(TIME*5.8+VERTEX.y*4.0+VERTEX.z*3.0)*0.12*ponta;
	VERTEX.y += sin(TIME*4.2+VERTEX.z*5.0+VERTEX.x*3.0)*0.08*ponta;
}
void fragment() {
	float veio = abs(UV.x-0.5)*2.0;
	float fogo = sin(local.y*6.0+local.z*4.0-TIME*6.0)*0.12;
	vec3 cor = mix(ouro.rgb,azul.rgb,smoothstep(0.4+fogo,0.95,veio));
	ALBEDO = cor;
	EMISSION = cor*0.7;
	ALPHA = 1.0;
}
