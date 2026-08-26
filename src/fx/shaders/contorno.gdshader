// ============================================================================
//  CONTORNO — Fase 2 de docs/PLANO_VISUAL.md
//
//  Desenha a linha escura da SILHUETA, que é metade da leitura de anime.
//
//  ------------------------------------------------ POR QUE É UM SHADER SPATIAL
//  O `ScreenFX` do jogo é um `CanvasLayer` com shader `canvas_item`, e shader de
//  canvas NÃO ENXERGA O BUFFER DE PROFUNDIDADE. Contorno de qualidade precisa de
//  profundidade e normal (`hint_depth_texture`, `hint_normal_roughness_texture`),
//  e as duas só existem em shader `spatial`, no Forward+.
//
//  Isso também separa o que é ESTILO DE RENDER (aqui) do que é GAME FEEL
//  (vinheta, flash, speed lines — lá no ScreenFX).
//
//  ------------------------------------------------------ TELA CHEIA SEM CÂMERA
//  O `vertex()` sobrescreve `POSITION` com coordenadas de recorte, então este
//  quad cobre a tela inteira independentemente de onde o nó está no mundo.
//  É por isso que ele não precisa ser filho da câmera — o que importa, já que a
//  câmera do jogo nasce dentro do `CameraRig` de cada jogador.
//
//  ------------------------------------ ⚠️ SILHUETA, NÃO ARESTA (risco 1 do plano)
//  O personagem é VOXEL: ele é só quina. Um contorno que dispare em toda
//  descontinuidade de normal desenharia cada aresta de cada cubo, do corpo e dos
//  blocos do mapa, e o resultado é RUÍDO, não desenho.
//
//  Por isso o peso está na PROFUNDIDADE (que só quebra na silhueta, onde um
//  objeto termina e o fundo começa) e a normal entra com limiar alto e força
//  separada — `peso_normal` nasce baixo de propósito. Subir isso é uma decisão
//  de arte, não um ajuste técnico.
//
//  ⚠️ E O LIMIAR DE PROFUNDIDADE ESCALA COM A DISTÂNCIA. Um limiar fixo em
//  metros desenha tudo de perto e nada de longe: a 60 m, dois objetos separados
//  por 30 cm têm quase a mesma profundidade. Aqui o limiar é relativo à
//  distância do pixel, então a linha continua existindo no fundo da arena.
//
//  ==========================================================================
//  ⚠️⚠️ DEGRAU x INCLINAÇÃO — a correção de 2026-08-25, e o porquê dela
//  ==========================================================================
//  A primeira versão comparava a profundidade do pixel com a dos vizinhos
//  (diferença PRIMEIRA). Isso confunde duas coisas que precisam ser separadas:
//
//    • DEGRAU     — o objeto termina e o fundo começa. É contorno.
//    • INCLINAÇÃO — a mesma superfície continua, só que de raspão. NÃO é.
//
//  O chão da arena visto quase de perfil tem gradiente de profundidade enorme
//  sem nenhuma descontinuidade. Medido em captura: o horizonte virou uma BARRA
//  PRETA de dezenas de pixels de altura, não uma linha.
//
//  E o remédio óbvio — subir o limiar até a barra sumir — criou o segundo
//  defeito: o contorno do personagem **deixava de fechar embaixo**. Onde o pé
//  encosta no chão o degrau é pequeno (pé e chão estão quase à mesma
//  distância), e ele morria junto com a barra. Cabeça e tronco tinham linha;
//  perna e pé, não.
//
//  A correção é olhar a diferença SEGUNDA (a curvatura), não a primeira:
//
//      d(+x) + d(−x) − 2·d(0)
//
//  Numa superfície de inclinação constante isso dá ZERO, por mais inclinada que
//  ela esteja — a barra do horizonte some por construção. Num degrau, dá um
//  valor grande, mesmo que o degrau seja pequeno — o pé volta a ter contorno.
//  Uma conta resolve os dois, e é por isso que ela veio no lugar de dois
//  ajustes de limiar puxando para lados opostos.
// ============================================================================
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D prof_tex : hint_depth_texture, filter_nearest;
uniform sampler2D norm_tex : hint_normal_roughness_texture, filter_nearest;

uniform vec4 cor : source_color = vec4(0.04, 0.05, 0.09, 1.0);
// Espessura em PIXELS, não em unidades de mundo: linha de anime tem a mesma
// grossura perto e longe. Em unidades de mundo ela engrossaria de perto.
uniform float espessura : hint_range(0.5, 4.0) = 1.3;
// Quanto a profundidade precisa saltar, em FRAÇÃO da distância do pixel.
// ⚠️ ESTE LIMIAR É DE CURVATURA, não de diferença simples — a escala é OUTRA.
// Trocar a conta sem recalibrar o número deixaria contorno em tudo.
uniform float limiar_prof : hint_range(0.0005, 0.05) = 0.0022;
uniform float peso_normal : hint_range(0.0, 1.0) = 0.18;
uniform float limiar_normal : hint_range(0.1, 1.0) = 0.72;
// ⚠️ ALCANCE CURTO, E ISSO É DECISÃO DE ESTILO, NÃO ECONOMIA.
//
// A arena tem 200 m de lado e a grade é cheia de buracos. Vista de raspão do
// nível do chão, cada borda de buraco distante ocupa 1-2 pixels de altura — e
// dezenas delas empilhadas viram uma BARRA PRETA no horizonte. Cada linha ali é
// "correta"; o problema é que juntas não desenham nada, borram.
//
// Anime também não contorna o fundo distante: a linha é do que está perto o
// bastante para o olho separar. 70 m cobre a arena jogável em volta do jogador
// e deixa o horizonte respirar.
uniform float alcance : hint_range(20.0, 400.0) = 70.0;

varying mat4 inv_proj;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
	inv_proj = INV_PROJECTION_MATRIX;
}

// Profundidade em METROS, a partir do valor cru do buffer.
float metros(vec2 uv, mat4 ip) {
	float cru = texture(prof_tex, uv).x;
	vec4 vista = ip * vec4(uv * 2.0 - 1.0, cru, 1.0);
	return -(vista.z / vista.w);
}

vec3 normal_em(vec2 uv) {
	return normalize(texture(norm_tex, uv).rgb * 2.0 - 1.0);
}

void fragment() {
	vec2 px = espessura / VIEWPORT_SIZE;
	float d0 = metros(SCREEN_UV, inv_proj);

	// Céu: o buffer devolve distância enorme. Sem isto o horizonte inteiro
	// ganharia uma linha, porque o salto céu-para-chão é o maior de todos.
	if (d0 > alcance) {
		ALPHA = 0.0;
	} else {
		// Cruz de quatro amostras. Diagonal daria linha mais macia e custa o
		// dobro; num contorno de 1,3 px a diferença não aparece.
		vec2 o[4] = {vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y)};

		// Pares OPOSTOS, para a diferença segunda: ver a nota "degrau x
		// inclinação" no cabeçalho.
		float dl = metros(SCREEN_UV + o[1], inv_proj);
		float dr = metros(SCREEN_UV + o[0], inv_proj);
		float dd = metros(SCREEN_UV + o[3], inv_proj);
		float du = metros(SCREEN_UV + o[2], inv_proj);

		float cx = abs(dl + dr - 2.0 * d0);
		float cy = abs(du + dd - 2.0 * d0);
		float salto = max(cx, cy) / max(d0, 1.0);

		vec3 n0 = normal_em(SCREEN_UV);
		float dobra = 0.0;
		for (int i = 0; i < 4; i++) {
			dobra = max(dobra, 1.0 - dot(n0, normal_em(SCREEN_UV + o[i])));
		}

		float f_prof = smoothstep(limiar_prof, limiar_prof * 2.2, salto);
		float f_norm = smoothstep(limiar_normal, limiar_normal * 1.35, dobra) * peso_normal;
		// Some suavemente perto do alcance, em vez de cortar numa linha reta.
		float esmaece = 1.0 - smoothstep(alcance * 0.45, alcance, d0);
		ALPHA = clamp(max(f_prof, f_norm), 0.0, 1.0) * cor.a * esmaece;
	}
	ALBEDO = cor.rgb;
}
