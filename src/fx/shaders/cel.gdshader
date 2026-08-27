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

// ---------------------------------------------------------------- A GRADE
//  ⚠️ FASE 4, e ela é FUNCIONAL antes de ser bonita.
//
//  O mapa É uma grade de células de 10 m com buracos quadrados do tamanho de
//  uma célula (`MapBuilder.CELL`). Até aqui o chão era um plano claro e liso —
//  a maior superfície da tela sem carregar informação nenhuma, e sem dar ao
//  jogador NENHUMA referência de escala ou de onde os buracos podem estar.
//
//  Desenhar a grade de verdade resolve as duas coisas de uma vez: dá escala e
//  mostra a estrutura do mapa, num jogo em que cair é a principal forma de
//  morrer. Sem asset nenhum.
//
//  ⚠️ EM ESPAÇO DE MUNDO, não em UV. A plataforma é um `MultiMesh` de lajes de
//  tamanhos diferentes (o `_merge_runs` funde células em faixas), então UV não
//  tem relação com a grade real — a linha cairia em lugar errado e mentiria
//  sobre onde a célula acaba.
//
//  A largura usa `fwidth`: a linha tem a mesma grossura APARENTE perto e longe,
//  em vez de virar moiré no horizonte. É o mesmo princípio da espessura em
//  pixels do contorno.
uniform bool usar_grade = false;
uniform float grade_celula = 10.0;
uniform float grade_forca : hint_range(0.0, 1.0) = 0.16;
uniform float grade_largura : hint_range(0.5, 4.0) = 1.5;
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
	if (usar_grade) {
		// posição no MUNDO — ver a nota da grade
		vec3 mundo = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 c = mundo.xz / grade_celula;
		// distância até a linha de célula mais próxima, em pixels
		vec2 d = abs(fract(c - 0.5) - 0.5) / max(fwidth(c), vec2(0.00001));
		float linha = 1.0 - min(min(d.x, d.y) / grade_largura, 1.0);
		base *= 1.0 - linha * grade_forca;
	}
	ALBEDO = base;
	// ⚠️ NÃO ESCREVER `ALPHA` AQUI. Medido em 2026-08-27.
	//
	// No Godot 4 a transparência é decidida em tempo de COMPILAÇÃO: basta o
	// shader ESCREVER em `ALPHA` — mesmo que o valor seja sempre 1,0 — para o
	// material inteiro ir para o pipeline de transparência. Ali ele deixa de
	// participar do prepass de profundidade e passa a ser iluminado por um
	// caminho diferente, e o resultado é um escurecimento em FAIXA no chão que
	// muda conforme a câmera gira.
	//
	// Medido no mesmo quadro, mesma câmera, mesma luz, chão 100% plano
	// (a linha de leitura foi validada por raio: 560 de 560 pixels acertam a
	// Plataforma, zero blocos, zero céu):
	//     com `ALPHA = cor.a;`   metade esquerda 29,8% escurecida
	//     sem a linha            metade esquerda  0,0%
	// Uma linha, uma medição, tudo o mais idêntico.
	//
	// Foi o que sobrou depois de derrubar, medindo: cascata de sombra, grade do
	// chão, quantização do cel, contorno de tela, SSAO, névoa, o `light()`
	// inteiro (removê-lo não muda nada) e o `render_mode`.
	//
	// Se algum dia este shader precisar de superfície TRANSLÚCIDA, faça uma
	// VARIANTE separada que escreva `ALPHA` e use-a só onde for preciso — não
	// devolva a linha aqui, porque ela custa o chão inteiro.
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
