// ============================================================================
//  BLOCO ESTILO MINECRAFT (12/11/2026) — textura 16×16 do vanilla, filtro mais próximo, sem contorno.
//
//  A malha da `GradeVoxel` junta faces vizinhas em retângulos grandes (guloso), então o UV sai em UNIDADES DE BLOCO
//  (1.0 = um bloco) e o sampler repete: a textura se repete sozinha dentro do retângulo, como se cada bloco fosse um quadro.
//  UV2.x = camada da `Texture2DArray` (−1 = sem textura: usa a cor do vértice, que é a cor do tipo).
//
//  `textureGrad` com o UV SEM repetir: é o que impede o filtro de mipmap de pegar a costura do retângulo grande
//  (o gradiente seria enorme no pixel onde a fração dá a volta) e pintar uma linha entre blocos.
//
//  Translúcido (gelo, vidro, água): compilado com `TRANSLUCIDO` — o alfa vem da textura.
// ============================================================================
shader_type spatial;
#ifdef TRANSLUCIDO
render_mode specular_disabled, diffuse_lambert, cull_disabled, depth_draw_opaque;
#else
render_mode specular_disabled, diffuse_lambert;
#endif

uniform sampler2DArray blocos : source_color, filter_nearest_mipmap, repeat_enable;
// Só o topo da grama usa a arte autoral; o restante mantém o atlas pixelado.
uniform sampler2D grama_personalizada : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float camada_grama = -2.0;
// Uma imagem cobre 4 blocos (3,52 m), mantendo pequenas folhas legíveis na câmera do jogo.
uniform float grama_blocos_por_repeticao = 4.0;
varying float camada;

void vertex() {
	camada = UV2.x;
}

void fragment() {
	vec3 cor = COLOR.rgb;
	float alfa = COLOR.a;
	if (camada >= -0.5) {
		vec4 t = textureGrad(blocos, vec3(UV, camada), dFdx(UV), dFdy(UV));
		cor = t.rgb;
		alfa = t.a;
		if (abs(camada - camada_grama) < 0.25) {
			vec2 uv_grama = UV / grama_blocos_por_repeticao;
			cor = textureGrad(grama_personalizada, uv_grama, dFdx(uv_grama), dFdy(uv_grama)).rgb;
		}
	}
	ALBEDO = cor;
	ROUGHNESS = 1.0;
#ifdef TRANSLUCIDO
	ALPHA = alfa;
#else
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = alfa;
#endif
}
