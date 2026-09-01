shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// ============================================================================
//  A CHAMA DAS COSTAS DO LUNARIANO — 2D, num plano só.
//
//  Pedido do dono (2026-08-29): "faz como se fosse um fogo em 2D nas costas".
//  A primeira versão era GPUParticles: fogo volumétrico, com partículas
//  soltando em profundidade. Bonito e ERRADO para o que ele quer — na folha de
//  referência a chama é uma silhueta chapada subindo pelas costas, do mesmo
//  jeito que o resto do jogo é chapado.
//
//  ⚠️ SEM TEXTURA. O ruído é gerado aqui: uma chama em flipbook exigiria um
//  atlas de quadros que alguém teria de desenhar e manter, e ficaria presa ao
//  número de quadros. Assim ela é contínua e o arquivo é só este.
//
//  A FORMA sai de três coisas multiplicadas:
//    1. o ruído, que rola para CIMA com o tempo (as línguas de fogo);
//    2. uma máscara que estreita no topo (a chama afina);
//    3. um recorte por altura, que faz a ponta se desfazer em vez de cortar.
// ============================================================================

uniform vec3 cor_nucleo : source_color = vec3(1.00, 0.95, 0.55);
uniform vec3 cor_meio : source_color = vec3(1.00, 0.52, 0.10);
uniform vec3 cor_ponta : source_color = vec3(0.78, 0.12, 0.04);
uniform float velocidade = 1.35;
// ⚠️ BAIXA DE PROPÓSITO. Com 1,5 e `blend_add` a chama saturava em branco e
// virava um RETÂNGULO luminoso — a forma sumia dentro do próprio brilho. O que
// faz ler como fogo é o recorte deixar línguas SEPARADAS, não o brilho.
uniform float intensidade = 1.42;

// BILLBOARD EM TORNO DO Y. A chama roda para encarar a câmera, mas continua em
// pé: billboard cheio a deitaria junto com a câmera quando o jogador olhasse de
// cima, e fogo deitado não lê como fogo. A escala do nó é preservada pelo
// comprimento das colunas do MODEL_MATRIX — sem isso a chama do Gigante sairia
// do tamanho da de um humano.
void vertex() {
	vec3 escala = vec3(length(MODEL_MATRIX[0].xyz),
	                   length(MODEL_MATRIX[1].xyz),
	                   length(MODEL_MATRIX[2].xyz));
	vec3 para_camera = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	para_camera.y = 0.0;
	if (length(para_camera) < 0.0001) {
		para_camera = vec3(0.0, 0.0, 1.0);
	}
	vec3 z = normalize(para_camera);
	vec3 y = vec3(0.0, 1.0, 0.0);
	vec3 x = normalize(cross(y, z));
	mat4 m = mat4(vec4(x * escala.x, 0.0),
	              vec4(y * escala.y, 0.0),
	              vec4(z * escala.z, 0.0),
	              MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Valor-ruído com interpolação suave: é o degrau entre células que dá a
// aparência de língua de fogo, e não de mancha.
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Três oitavas bastam: com uma a chama fica lisa demais, com cinco o custo sobe
// e a diferença some no tamanho em que ela aparece na tela.
float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * ruido(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// ⚠️ O UV DO QuadMesh TEM O Y INVERTIDO: 0 é o TOPO do plano, não a base.
	// Sem esta linha a máscara de altura desenhava o fogo forte em cima e fraco
	// embaixo — o oposto do pretendido. Medido: a chama cobria as costas
	// inteiras (y de 1,73 a 2,98, com a cabeça em 2,70) e só aparecia acima da
	// cabeça, o que fez parecer que ela estava mal POSICIONADA quando o defeito
	// era de DESENHO.
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME * velocidade;

	// O ruído SOBE (uv.y - t): é isso, e só isso, que faz o fogo parecer subir.
	float n = fbm(vec2(uv.x * 3.2, uv.y * 2.4 - t));
	n += 0.5 * fbm(vec2(uv.x * 6.5 + 3.0, uv.y * 5.0 - t * 1.7));

	// afina no topo e nas beiradas
	float largura = 1.0 - smoothstep(0.0, 1.0, uv.y) * 0.78;
	float lateral = 1.0 - smoothstep(0.0, largura, abs(uv.x - 0.5) * 2.0);
	float altura = 1.0 - smoothstep(0.15, 1.0, uv.y);

	float chama = clamp(n * lateral * altura * intensidade, 0.0, 1.0);
	// o corte alto é o que desfaz a ponta em línguas soltas em vez de aparar
	// Corte alto e estreito: é ele que separa as línguas. Faixa larga borra tudo
	// numa mancha só.
	chama = smoothstep(0.30, 0.90, chama);

	// A cor segue a INTENSIDADE, não a altura: assim o núcleo claro acompanha as
	// línguas quando elas sobem, em vez de ficar preso na base.
	vec3 cor = mix(cor_ponta, cor_meio, smoothstep(0.15, 0.55, chama));
	cor = mix(cor, cor_nucleo, smoothstep(0.60, 0.95, chama));

	ALBEDO = cor;
	ALPHA = chama;
}
