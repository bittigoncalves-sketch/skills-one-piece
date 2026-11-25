shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// NUVEM DE TEMPESTADE da Goro Goro. Antes cada "puff" era uma esfera de cor
// chapada (StandardMaterial unshaded): de longe a nuvem virava uma mancha plana,
// e o clarao de relampago era so uma luz EXTERNA piscando ao lado dela.
//
// A REGRA DE OURO DA PALETA CONTINUA VALENDO (docs/frutas/goro_goro.md): a nuvem
// e ESCURA e NAO usa blend aditivo. O relampago daqui acende POR DENTRO e some;
// ele nunca clareia a nuvem inteira, senao o raio amarelo perde onde aparecer.

uniform vec4 cloud_color : source_color = vec4(0.05, 0.09, 0.22, 1.0);
uniform vec4 bolt_color : source_color = vec4(0.62, 0.78, 1.0, 1.0);
// `presence` substitui o antigo tween de `albedo_color:a` — e como ele multiplica
// TUDO no fim, dissipar a nuvem continua sendo animar um numero de 1 para 0.
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float age = 0.0;
// Quanto a bola ja carregou (0..1). Quanto mais carregada, mais o interior da
// nuvem pisca: o aviso de que a coisa esta prestes a cair.
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.86;

varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}

// Ruido barato e estavel por hash — sem textura, para o efeito nao depender de
// asset importado.
float hash11(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));

    // VOLUME: denso de frente, ralo de perfil. E o INVERSO do rim da `ope_room`
    // (la o campo e uma casca de vidro; aqui e massa). Sem isto cada puff se
    // revela como a esfera que e.
    float corpo = pow(facing, 1.45);

    // Duas bandas de altura tiram a lisura da esfera: relevo sem textura.
    float veio = 0.5 + 0.5 * sin(local_pos.y * 15.0 + age * 0.7);
    float corpo_final = corpo * mix(0.82, 1.0, veio);

    // RELAMPAGO INTERNO. Um flash curto por janela de tempo, em instante
    // pseudo-aleatorio: piscar em cadencia regular denuncia o truque na hora.
    float janela = 0.45 - 0.22 * charge;              // carregada = pisca mais
    float slot = floor(age / janela);
    float inicio = hash11(slot) * 0.55;
    float dt = fract(age / janela) - inicio;
    float flash = dt < 0.0 ? 0.0 : exp(-dt * 26.0);
    // O flash mora FUNDO no puff (onde `facing` e alto) e some na borda.
    float brilho = flash * pow(facing, 3.0) * (0.30 + 0.70 * charge);

    ALBEDO = cloud_color.rgb + bolt_color.rgb * brilho * 1.7;
    ALPHA = clamp(corpo_final * density * cloud_color.a + brilho * 0.25, 0.0, 1.0) * presence;
}
