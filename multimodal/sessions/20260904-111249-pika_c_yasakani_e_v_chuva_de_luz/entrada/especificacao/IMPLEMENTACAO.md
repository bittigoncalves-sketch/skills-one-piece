# Pika Pika — referência C/V

Fonte autoritativa: especificação enviada pelo dono em 2026-09-04. Os dois
storyboards desta pasta foram gerados a partir de `screenshot.png`, preservando
a câmera, a arena, o personagem e o estilo low-poly do jogo.

## C — Yasakani no Magatama

- No início: teleporta o jogador 7 m para cima e fixa a mira no inimigo mais
  próximo; sem alvo, preserva a direção original da câmera.
- 0,0–0,6 s: levanta os dois braços.
- 0,6–1,0 s: partículas e dois núcleos de luz acumulam nas mãos.
- 1,0–2,5 s: barragem contínua, originada no personagem, com dezenas de
  fragmentos/feixes finos simultâneos e rastros muito curtos.
- 1,2–2,7 s: impactos dourados pequenos e desencontrados.
- 2,7–3,3 s: resíduos desaparecem.
- 3,3–3,7 s: retorno à postura de combate.

O golpe é sustentado: soltar C encerra imediatamente a carga/barragem; mantendo
C pressionado ele continua até o limite coreografado de 3,7 s e se encerra
sozinho. Separação visual/gameplay: a densidade visual é maior que a quantidade de dano.
Todas as zonas compartilham um único `DamageSpec`, portanto o teto do C continua
valendo mesmo com muitos fragmentos na tela.

## V — Chuva de Luz

- 0,0–1,0 s: um braço erguido e núcleo de luz na mão.
- 1,0–2,0 s: céu dourado, partículas ascendentes e silêncio visual antes do pico.
- 2,0–12,0 s: chuva contínua de feixes quase verticais em posições aleatórias.
- 11,0–12,0 s: intensidade máxima.
- 12,0–13,0 s: os feixes param rapidamente.
- 13,0–14,0 s: partículas e marcas somem.

O campo denso da chuva usa partículas de GPU. Somente impactos destacados criam
zonas de dano, todas com o mesmo orçamento da conjuração. Isso mantém a escala de
arena sem transformar o V em centenas de aplicações independentes de dano.

## Decisões de gameplay inferidas

O prompt não define dano, hitbox ou controle do jogador. Foram adotados os
limites de balanceamento já usados pelo projeto: C com teto 384 e V com teto 768.
O C prende o jogador durante os 3,7 s coreografados; o V prende apenas nos 2 s de
ativação, deixando a chuva persistir como controle de arena.
