// ============================================================================
//  CÉU COM NUVEM CHAPADA — §7.1a de docs/PLANO_VISUAL.md
//
//  Substitui o `ProceduralSkyMaterial`, que entregava um degradê azul e mais
//  nada. One Piece É céu: cúmulo enorme, branco, de BORDA DURA, sobre azul
//  saturado. Isto muda todo quadro do jogo, inclusive os que não têm ação —
//  é o motivo de o plano chamar este item de maior ganho de identidade dele.
//
//  ------------------------------------------------ POR QUE UM SHADER DE CÉU
//  Duas alternativas foram descartadas antes desta:
//
//    GEOMETRIA (quads/partículas de nuvem)  custo de desenho, ordenação e
//      transparência para reproduzir uma coisa que é FORMA CHAPADA, não
//      volume. Em cel-shading a nuvem não tem profundidade para vender.
//    VOLUMÉTRICA  cara, e `GameFlow.device` inclui "celular" (§7.4 do plano
//      já barra névoa volumétrica pela mesma razão).
//
//  Um `shader_type sky` é zero geometria, zero material novo, zero draw call:
//  o céu já era desenhado, só passa a ser desenhado por esta conta.
//
//  ------------------------------------------------- A MESMA MATEMÁTICA DO CEL
//  A borda dura da nuvem e a faixa de luz de `cel.gdshader` são o MESMO
//  problema: transformar um valor contínuo em degraus com borda estreita. A
//  função `degrau()` aqui embaixo é a de `light()` de lá, palavra por palavra
//  — de propósito, para o céu e os objetos bandarem com o mesmo passo. Se um
//  dia a faixa do cel mudar de forma, esta tem que mudar junto.
//
//  ==========================================================================
//  ⚠️ O QUE NÃO PODE MUDAR — regras herdadas, não gosto
//  ==========================================================================
//
//  1. O "CHÃO" DO CÉU CONTINUA ESCURO. `cor_chao_fundo` é (0.03,0.04,0.07) e
//     nasceu de um bug de JOGABILIDADE registrado em docs/erros.md: ele já foi
//     verde (0.15,0.32,0.22) e, olhando por um buraco do mapa, o poço lia como
//     GRAMA LÁ EMBAIXO — num jogo em que cair (`Scoreboard.VOID_Y`) é a
//     principal forma de morrer. Um abismo que parece chão convida o erro que
//     mata. NENHUMA nuvem, halo de sol ou clareamento entra abaixo do
//     horizonte: a função `sky()` decide isso num `if` antes de qualquer coisa,
//     e não por multiplicação — máscara que "quase zera" ainda clareia.
//
//  2. A NUVEM RESPEITA O HORIZONTE. O `Environment` mistura a cor da névoa no
//     céu (`fog_sky_affect = 0.22`, `fog_aerial_perspective = 0.42`). O motor
//     faz isso sozinho com a saída deste shader, mas só isso não bastaria:
//     uma nuvem branca colada no horizonte ficaria mais clara que o ar em volta
//     dela. Por isso ela também se dissolve na `cor_horizonte` daqui — ver
//     `nuvem_perto` e `nuvem_longe`.
//
//  3. O SOL CONTINUA EXISTINDO. O `ProceduralSkyMaterial` desenhava disco e
//     halo de graça a partir da luz direcional; um shader próprio não desenha.
//     Esquecer isso apaga o sol da cena e ninguém liga o sumiço ao céu.
//
//  ------------------------------------------------- DE ONDE VEM O SOL, E POR QUÊ
//  ⚠️ A direção do sol chega por UNIFORME (`dir_sol`), não por `LIGHT0_DIRECTION`.
//  O built-in existe, mas o SINAL dele (aponta para o sol ou para onde a luz
//  vai?) é fácil de errar e o sintoma — sol no lado errado do céu — parece
//  problema de rotação da luz, não de shader. `WorldEnv` já cria o
//  `DirectionalLight3D` e escreve aqui a coluna Z da base dele, que é a direção
//  PARA o sol. Uma fonte só, e ela é a mesma que ilumina a cena.
// ============================================================================
shader_type sky;

// ------------------------------------------------------------------ PALETA
// Os quatro valores em vigor no `ProceduralSkyMaterial` que este shader
// substitui, para a troca não mexer no ar já calibrado da Fase 1.
uniform vec3 cor_topo : source_color = vec3(0.13, 0.45, 0.90);
uniform vec3 cor_horizonte : source_color = vec3(0.66, 0.86, 0.99);
uniform vec3 cor_chao_horizonte : source_color = vec3(0.20, 0.28, 0.38);
uniform vec3 cor_chao_fundo : source_color = vec3(0.03, 0.04, 0.07);
// Chuva de Luz (Pika V): tinge o céu real, sem cúpula ou disco geométrico.
// Zero mantém exatamente a direção de arte normal; um produz a atmosfera
// dourada temporária controlada pelo efeito.
uniform float pika_v_dourado : hint_range(0.0, 1.0) = 0.0;
// Curva pequena = transição CURTA E DURA (o expoente é 1/curva). O chão em
// 0.04 vira expoente 25: cinco graus abaixo do horizonte já é quase o fundo
// escuro — que é exatamente a regra 1 lá de cima.
uniform float curva_ceu : hint_range(0.05, 1.0) = 0.15;
uniform float curva_chao : hint_range(0.01, 1.0) = 0.04;

// --------------------------------------------------------------------- SOL
uniform vec3 dir_sol = vec3(-0.472, 0.788, -0.396);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.97, 0.86);
// Raio do disco em GRAUS. O `ProceduralSkyMaterial` desenhava um sol enorme e
// difuso; aqui o disco é menor e o que dá o tamanho aparente é o halo.
uniform float raio_sol : hint_range(0.5, 12.0) = 2.6;
uniform float raio_halo : hint_range(2.0, 40.0) = 13.0;
uniform float forca_halo : hint_range(0.0, 1.5) = 0.55;

// ------------------------------------------------------------------- NUVEM
uniform vec3 cor_nuvem_luz : source_color = vec3(1.0, 0.99, 0.95);
uniform vec3 cor_nuvem_sombra : source_color = vec3(0.60, 0.69, 0.85);
// Fração do céu tomada por nuvem. É o botão mais forte daqui: subir isto clareia
// o quadro inteiro, e as capturas de `captura_visual.gd` cobram por isso.
uniform float cobertura : hint_range(0.0, 1.0) = 0.44;
// Tamanho aparente do cúmulo. Menor = nuvem maior.
uniform float escala : hint_range(0.5, 12.0) = 3.2;
// ⚠️ OITAVAS É A ALAVANCA DE DISPOSITIVO. Cada oitava é uma amostra de ruído a
// mais POR PIXEL, e ela paga duas vezes (silhueta + relevo). `WorldEnv` escreve
// 3 no celular, 4 no tablet, 5 no pc. Abaixo de 3 a nuvem perde a renda da
// borda e vira mancha.
uniform int oitavas : hint_range(1, 6) = 5;
// Degraus de tom DENTRO da nuvem — o mesmo `faixas` do cel. Três é o que o
// desenho de anime usa: claro do sol, meio-tom, sombra de baixo.
uniform float faixas : hint_range(2.0, 5.0) = 3.0;
// Largura da borda entre um degrau e o outro. Zero serrilha (a transição cai em
// menos de um pixel), largo vira degradê — que é o que este shader existe para
// não ter.
uniform float suavidade : hint_range(0.005, 0.3) = 0.06;
// Quanto a massa precisa AFINAR na direção do sol para o tom subir uma faixa.
uniform float ganho_relevo : hint_range(0.5, 12.0) = 4.5;
uniform float passo_luz : hint_range(0.01, 0.5) = 0.09;
uniform float vento : hint_range(0.0, 0.2) = 0.006;
// Onde a faixa de nuvem começa e termina de aparecer, em seno de elevação.
// ⚠️ NÃO É ECONOMIA, É ANTI-SERRILHADO. A projeção no plano da nuvem divide por
// `EYEDIR.y`: rente ao horizonte um pixel cobre centenas de metros de nuvem e o
// ruído vira chuvisco. Aqui ela se dissolve no ar antes disso, que é também o
// que a perspectiva aérea faria.
uniform float nuvem_perto : hint_range(0.0, 0.5) = 0.045;
uniform float nuvem_longe : hint_range(0.02, 0.8) = 0.20;

const float PI_MEIO = 1.5707963;
// Giro entre oitavas. Sem ele o ruído empilha nos mesmos eixos e a nuvem sai
// quadriculada — visível justo nas bordas duras, que é o que se olha aqui.
const mat2 GIRO = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));


// ⚠️ HASH SEM `sin()`. O `fract(sin(dot(...)) * 43758.5)` de sempre depende da
// precisão do `sin` para argumentos gigantes, e é justamente ele que varia entre
// GPU de desktop e de celular — o mesmo céu sairia com outro desenho no
// telefone. Esta versão (Dave Hoskins) só usa fract/dot e é estável.
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Ruído somado em oitavas, normalizado para 0..1. O `break` por uniforme é o
// jeito de o número de oitavas ser configurável sem recompilar o shader.
float massa(vec2 p, int n) {
	float soma = 0.0;
	float amp = 0.5;
	float norma = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		soma += amp * ruido(p);
		norma += amp;
		p = GIRO * p * 2.02;
		amp *= 0.5;
	}
	return soma / max(norma, 0.0001);
}

// A MESMA conta de `cel.gdshader::light()`: arredonda para `n` degraus com uma
// borda estreita entre um e outro. Ver a nota do cabeçalho.
float degrau(float v, float n, float suave) {
	float passo = 1.0 / n;
	float idx = floor(v / passo);
	float f = fract(v / passo);
	return clamp((idx + smoothstep(0.5 - suave, 0.5 + suave, f)) * passo, 0.0, 1.0);
}

// Rampa do `ProceduralSkyMaterial`: `curva` pequena encurta e endurece a
// transição. Mantida idêntica para o horizonte não mudar de lugar na troca.
float rampa(float x, float curva) {
	return clamp(1.0 - pow(max(1.0 - x, 0.0), 1.0 / max(curva, 0.001)), 0.0, 1.0);
}


void sky() {
	// Elevação normalizada: +1 no zênite, 0 no horizonte, −1 no nadir. Pelo
	// ÂNGULO e não pelo seno, que é como o material substituído fazia — trocar
	// por `EYEDIR.y` mexeria a altura de toda a faixa clara do horizonte.
	float elev = 1.0 - acos(clamp(EYEDIR.y, -1.0, 1.0)) / PI_MEIO;

	// ---------------------------------------------------------------- ABAIXO
	// Regra 1 do cabeçalho: aqui não entra nuvem, nem sol, nem halo.
	//
	// ⚠️ ISTO ERA UM `return` ANTECIPADO E O GODOT NÃO ACEITA:
	//     "Using 'return' in the 'sky' processor function is incorrect"
	// O shader inteiro deixa de compilar, e o motor cai para um céu de reserva
	// escuro — sem erro na tela, só um céu chapado sem nuvem nenhuma. Foi
	// exatamente o sintoma. A intenção continua a mesma: `else`, e não
	// multiplicação por máscara, porque máscara que "quase zera" ainda clareia.
	if (elev <= 0.0) {
		COLOR = mix(cor_chao_horizonte, cor_chao_fundo, rampa(-elev, curva_chao));
	} else {
	// ----------------------------------------------------------------- ACIMA
		vec3 fundo = mix(cor_horizonte, cor_topo, rampa(elev, curva_ceu));

		// Sol: disco de borda dura (é cel-shading, o sol também é uma FORMA) mais um
		// halo largo que dá o tamanho aparente. `cos` do ângulo evita um `acos` por
		// pixel só para comparar com um limiar.
		vec3 dsol = normalize(dir_sol);
		float cs = dot(EYEDIR, dsol);
		float cos_disco = cos(radians(raio_sol));
		float disco = smoothstep(cos_disco, mix(cos_disco, 1.0, 0.35), cs);
		// Expoente que faz o halo cair pela metade no raio pedido.
		float exp_halo = log(0.5) / log(max(cos(radians(raio_halo)), 0.0001));
		float halo = pow(max(cs, 0.0), exp_halo) * forca_halo;
		fundo += cor_sol * (halo + disco * 1.35);

		// ---------------------------------------------------------------- NUVEM
		// Projeção no PLANO DA NUVEM: `EYEDIR.xz / EYEDIR.y` é onde a linha de visão
		// fura um plano horizontal. É o que dá perspectiva de verdade — o cúmulo
		// encolhe e se achata em direção ao horizonte, como cúmulo faz — em vez de
		// uma textura colada na cúpula, que lê como papel de parede.
		// O `+ 0.12` é o que impede a divisão por ~zero rente ao horizonte.
		float subida = max(EYEDIR.y, 0.0);
		vec2 uvp = EYEDIR.xz / (subida + 0.12) * escala + vec2(TIME * vento, TIME * vento * 0.42);

		int oit = oitavas;
		// ⚠️ O CÉU TAMBÉM É DESENHADO PARA O MAPA DE RADIÂNCIA (o cubemap que
		// alimenta reflexo). Ali ninguém enxerga renda de borda: duas oitavas
		// bastam, e isso corta o custo do passe que roda fora do quadro.
		if (AT_CUBEMAP_PASS) {
			oit = min(oit, 2);
		}

		float d = massa(uvp, oit);

		// Borda dura, mas ANTISSERRILHADA: a largura da transição acompanha o quanto
		// o ruído muda de um pixel para o vizinho (`fwidth`), do mesmo jeito que a
		// grade do chão em `cel.gdshader` mantém a linha com a mesma grossura perto e
		// longe. Largura fixa daria escada nas nuvens de cima e chuvisco nas de longe.
		float limiar = 1.0 - cobertura;
		float aa = clamp(fwidth(d) * 1.1, 0.003, 0.25);
		float silhueta = smoothstep(limiar - aa, limiar + aa, d);

		// Relevo: uma segunda amostra deslocada NA DIREÇÃO DO SOL. Se lá também há
		// massa, este ponto está atrás de nuvem e recebe a faixa escura; se a massa
		// afina para aquele lado, ele é a borda que pega sol. É sombreamento de duas
		// dimensões fingindo três — e num desenho chapado é tudo o que se pede.
		vec2 dir_plano = normalize(dsol.xz + vec2(0.0001, 0.0));
		float d_sol = massa(uvp + dir_plano * passo_luz, oit);
		float relevo = clamp((d - d_sol) * ganho_relevo + 0.5, 0.0, 1.0);
		vec3 nuvem = mix(cor_nuvem_sombra, cor_nuvem_luz, degrau(relevo, faixas, suavidade));

		// Regra 2: a nuvem morre no ar do horizonte em vez de ficar branca em cima de
		// um horizonte lavado pela névoa.
		float perto = smoothstep(nuvem_perto, nuvem_longe, EYEDIR.y);
		nuvem = mix(cor_horizonte, nuvem, perto);

		COLOR = mix(fundo, nuvem, silhueta * perto);

		// O dourado conserva a massa e o relevo das nuvens: muda a iluminação do
		// céu, não cola uma cor chapada na tela. Mais luminoso no horizonte e
		// âmbar profundo no zênite, como a progressão da referência do Pika V.
		vec3 ouro_topo = vec3(0.52, 0.29, 0.055);
		vec3 ouro_horizonte = vec3(1.10, 0.72, 0.20);
		vec3 fundo_ouro = mix(ouro_horizonte, ouro_topo, rampa(elev, curva_ceu));
		vec3 nuvem_ouro = mix(vec3(0.72, 0.40, 0.08),
			vec3(1.28, 0.96, 0.46), degrau(relevo, faixas, suavidade));
		vec3 cena_ouro = mix(fundo_ouro, nuvem_ouro, silhueta * perto);
		cena_ouro += vec3(1.0, 0.72, 0.24) * (halo + disco * 1.20);
		COLOR = mix(COLOR, cena_ouro, pika_v_dourado);
	}
}
