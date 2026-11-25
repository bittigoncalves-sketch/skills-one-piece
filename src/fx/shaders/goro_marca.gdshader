shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, blend_add;

// MARCA DE AVISO no chao do V da Goro Goro (remodelacao de 2026-09-12).
//
// O papel dela e CONTRA-JOGO, nao decoracao: o Mamaragan cai de cima, e quem
// esta embaixo precisa ver onde e com quanto tempo. Por isso o desenho responde
// a `charge` — o anel pulsa mais rapido conforme a bola enche, e a urgencia se
// le sem olhar o HUD de quem conjurou.
//
// Antes era um TorusMesh com `volt_material` (aditivo, brilho fixo): marcava o
// lugar, mas nao dizia NADA sobre o tempo.

uniform vec4 mark_color : source_color = vec4(0.65, 0.95, 1.0, 1.0);
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform float age = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float dentro = 1.0 - smoothstep(0.985, 1.0, r);

    // Aro externo: a fronteira da area. E a linha mais forte do desenho.
    float aro = 1.0 - smoothstep(0.006, 0.020, abs(r - 0.94));

    // Marcas radiais, como a mira de uma artilharia. Somem perto do centro para
    // nao virar uma estrela cheia.
    float ang = atan(p.y, p.x);
    float raias = (1.0 - smoothstep(0.03, 0.10, abs(sin(ang * 12.0)))) * smoothstep(0.35, 0.92, r);

    // PULSO QUE CORRE PARA DENTRO e acelera com a carga: o relogio do golpe.
    float velocidade = 0.30 + 0.85 * charge;
    float onda = fract(age * velocidade);
    float pulso = exp(-abs(r - (1.0 - onda)) * 26.0);

    // Perto de encher, o centro esquenta: o ultimo aviso antes da queda.
    float nucleo = (1.0 - smoothstep(0.0, 0.55, r)) * pow(charge, 3.0) * 0.30;

    float alpha = aro * 0.75 + raias * 0.16 + pulso * (0.18 + 0.30 * charge) + nucleo;
    ALBEDO = mark_color.rgb * (1.0 + 0.9 * charge);
    ALPHA = clamp(alpha, 0.0, 1.0) * dentro * presence;
}
