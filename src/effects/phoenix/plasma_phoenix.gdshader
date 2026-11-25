shader_type spatial;
render_mode cull_disabled, unshaded;
uniform vec4 fundo : source_color = vec4(0.0, 0.30, 0.76, 1.0);
uniform vec4 meio : source_color = vec4(0.0, 0.72, 1.0, 1.0);
uniform vec4 nucleo : source_color = vec4(0.30, 1.0, 1.0, 1.0);
uniform float energia = 0.75;
uniform float movimento = 0.035;
uniform float relogio = -1.0;
varying float fase;
void vertex() {
	fase = COLOR.g * 6.28318;
	float t = relogio < 0.0 ? TIME : relogio;
	float livre = COLOR.r * COLOR.r;
	// A seção inteira acompanha a onda. Deslocar pela normal invertia a
	// espessura das mechas finas e causava cintilação nas interseções.
	VERTEX.x += sin(t*4.5 + UV.y*10.0 + fase) * movimento * livre;
	VERTEX.y += cos(t*3.7 + UV.y*8.0 + fase) * movimento * 0.5 * livre;
}
void fragment() {
	float t = relogio < 0.0 ? TIME : relogio;
	float veio = abs(UV.x-.5)*2.0;
	float curva = sin(UV.y*12.0-t*2.4+fase)*.11 + sin(UV.y*25.0-t*3.1+fase)*.04;
	float faixa = smoothstep(.26,.33,veio+curva);
	vec3 cor = mix(nucleo.rgb, meio.rgb, faixa);
	cor = mix(cor, fundo.rgb, smoothstep(.91,.97,veio+curva*.45));
	ALBEDO = cor * (1.0 + energia);
	EMISSION = cor*energia;
}
