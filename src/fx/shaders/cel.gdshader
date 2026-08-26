// ============================================================================
//  BANDA DE LUZ — Fase 3 de docs/PLANO_VISUAL.md
//
//  A sombra vira DEGRAUS CHAPADOS em vez de degradê. É a outra metade da
//  leitura de anime (a primeira é o contorno, Fase 2).
//
//  ------------------------------------------------- POR QUE SUBSTITUI light()
//  Um shader `spatial` pode redefinir `light()` e decidir sozinho como a luz
//  vira cor. É o único jeito de a banda cair sobre a LUZ e não sobre a imagem
//  final: quantizar a tela inteira bandaria o céu e os efeitos junto, e leria
//  como filtro de foto (a opção (b) que o §2 do plano descartou).
//
//  ---------------------------------------------------------- O QUE ELE FAZ
//  `NdotL` (o quanto a superfície olha para a luz) é contínuo de 0 a 1. Aqui
//  ele é arredondado para `faixas` degraus, com uma borda estreita entre um e
//  outro — borda ZERO produz serrilhado, porque a transição cai em menos de um
//  pixel nas superfícies quase paralelas à luz.
//
//  `sombra_min` é o piso: a faixa mais escura ainda recebe parte da luz. Sem
//  ele o lado escuro vira preto puro e o personagem some quando gira.
//
//  ⚠️ ESPECULAR DESLIGADO. Brilho especular é gradiente por natureza e briga
//  com faixa chapada — é a mesma razão pela qual o SSAO foi apertado e o
//  tonemap deixou de ser filmic na Fase 1.
// ============================================================================
shader_type spatial;
render_mode specular_disabled, diffuse_lambert;

uniform vec4 cor : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D textura : source_color, hint_default_white, filter_nearest_mipmap;
uniform bool usar_textura = false;

// ⚠️ DUAS FAIXAS, e a razão é a geometria DESTE jogo. Banda de luz só aparece
// onde a normal VARIA ao longo da superfície — numa esfera, num cilindro, na
// copa da árvore. O mapa é feito de CAIXAS e de um plano: cada face tem normal
// constante, logo um tom só, com ou sem banda. Três faixas não desenhariam
// nada a mais nas caixas e ainda achatariam a árvore.
//
// O que a Fase 3 entrega neste mundo não é a banda em si — é a SOMBRA DE BORDA
// DURA e o fim do gradiente especular. Está dito assim no plano para ninguém
// procurar um efeito que a geometria não permite.
uniform int faixas : hint_range(2, 5) = 2;
uniform float suavidade : hint_range(0.005, 0.2) = 0.035;
// ⚠️ PISO BAIXO. A primeira tentativa usou 0,42 e a cena ficou CHAPADA: a face
// que não olha para o sol recebia quase metade da luz, e a diferença entre lado
// claro e lado escuro — que no cel É o desenho — quase sumiu. Medido em
// captura, o contraste entre as faces de um bloco caiu abaixo do que o Lambert
// padrão já dava.
uniform float sombra_min : hint_range(0.0, 0.9) = 0.16;

void fragment() {
	vec3 base = cor.rgb;
	if (usar_textura) {
		base *= texture(textura, UV).rgb;
	}
	ALBEDO = base;
	ALPHA = cor.a;
	ROUGHNESS = 1.0;
}

void light() {
	float ndl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);

	// Quantiza em `faixas` degraus. `smoothstep` na fração dá a borda estreita
	// — ver a nota do cabeçalho sobre serrilhado.
	float passo = 1.0 / float(faixas);
	float idx = floor(ndl / passo);
	float f = fract(ndl / passo);
	float degrau = (idx + smoothstep(0.5 - suavidade, 0.5 + suavidade, f)) * passo;

	// Piso: o lado escuro continua existindo.
	float luz = mix(sombra_min, 1.0, clamp(degrau, 0.0, 1.0));

	// ⚠️ A SOMBRA PROJETADA TAMBÉM É BANDA. `ATTENUATION` chega contínua (a
	// borda macia do mapa de sombra); passá-la direto devolveria o degradê que
	// esta função existe para eliminar, justo na sombra, que é a forma mais
	// visível da cena.
	//
	// ⚠️ E ENTRA COMO TETO (`min`), NÃO COMO FATOR. Multiplicar aplicava o piso
	// DUAS vezes — uma pelo ângulo, outra pela sombra — e uma superfície de
	// frente para o sol mas dentro de uma sombra ficava mais escura que o lado
	// de trás dela, o que não faz sentido nenhum. Como teto, a regra fica
	// simples: sombra não deixa a superfície passar da faixa escura.
	float som = smoothstep(0.35, 0.65, ATTENUATION);
	luz = min(luz, mix(sombra_min, 1.0, som));

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * luz;
}
