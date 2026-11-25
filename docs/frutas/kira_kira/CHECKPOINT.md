# Kira Kira — Z e transformação

Objetivo: manter o jogador em diamante durante uma investida longa, imune a dano, que termina no primeiro inimigo ou obstáculo e explode em estilhaços que causam dano.

Decisões: a onda inicial causa dano em área e empurra para fora. Os 32 fragmentos radiais têm trajetórias e colisões reais; até 48 inimigos detectados em 9 m recebem fragmentos adicionais, priorizando os mais próximos com linha de visão. Os estilhaços causam 40% do dano-base do Z, no máximo uma vez por alvo, além da onda inicial, e continuam em voo após o fim da investida. A forma anterior é restaurada no fim; cancelamento não explode. A imunidade própria do Z não altera outras imunidades.

Arquivos principais: `src/combat/kira/`, `src/combat/frutas_do_mod/controlador.gd`, `src/minecraft/forma_zoan.gd` e `Player.gd`. Teste e captura: `tools/dev_tests/test_kira_kira.gd`, `tools/dev_tests/captura_kira_kira.gd` e `art_src/validation/kira_kira_codex/explosao_z.png`.

Validação em 22/11/2026: 39/39 verificações headless no Modo História, incluindo dano após o voo em várias direções, aliados, alvo distante, parede e inimigo encostado atrás dela, além dos testes anteriores. Captura: `art_src/validation/kira_kira_codex/particulas_360.png`, em OpenGL de compatibilidade. O teste registrou erros de animação `idle` e recursos ainda em uso ao sair.

Próximos passos: playtest de sensação e revisão visual em Forward+; validar a sincronização em uma partida com dois clientes.

## Remaster 22/11/2026 — Z (impacto + arremesso) e X/C (pedras cúbicas)

**Z (Brilliant Punk).** Transformação, imunidade, recarga 5 s, custo 200 e estilhaços intactos. Mudou: (1) mira assistida em `kira_investida.gd::_direcao_assistida` — cone de ~45°, 26 m, com linha de visão e previsão linear do alvo; a direção é fixada no início (é a que a rede replica); (2) raio de contato 1,15→1,7; (3) o alvo do impacto leva 1,5× o dano e é arremessado (22 m/s + 9 vertical, ≈17 m num inimigo do East Blue, medido; 30 m/s dava 32 m e jogava o alvo fora da ilha); quem só pega a onda segue com o empurrão radial de antes; (4) visual em `kira_vfx.gd`: trilha de cacos e brilhos durante a investida (`controlador._aplicar_forma_kira`, vale em todos os peers) e impacto de cristal (anel, rachadura no chão, cacos, luz, tremor) maior quando acerta alguém.

**X/C (Stone Throwing / Giant Rock).** O `rock_fragment` redondo do mod sai de cena para a Kira: `kira_pedras.gd` (habilidade) + `kira_pedra.gd` (cubo). X = 6 pedras de 0,8 m a cada 0,13 s, surgem num arco à frente e partem para o ponto do retículo (alvo quase na mira vira o ponto). C = 1 pedra de 3,2 m que sobe do chão (0,9 s), voa reta e explode (raio 5,5, vizinhos 60 % do dano). Mod: X 150/3,75 s, C 500/12,5 s — mantidos. **Hitbox = o cubo**: caixa só com yaw, testada contra o Hurtbox do alvo (`cubo_toca_alvo`: cápsula por pontos no eixo, esfera, caixa) e contra o cenário por `intersect_shape` com o cubo inteiro. Texturas do Codex em `assets/textures/kira_kira/` (fonte em `art_src/kira_kira/`); sem o PNG o `kira_vfx.gd` gera uma equivalente.

**Validação.** `test_kira_kira` 42/42 (inclui mira assistida e arremesso em personagem real) e `test_kira_pedras` 25/25 (hitbox do cubo, X, C, parede, recarga, limpeza), headless. Capturas Weston em `tools/dev_tests/captura_kira_z_x.gd`. `test_frutas_na_historia` passa; `test_frutas_acertam_npcs` só diverge em buki_buki/Z→boneco (não é Kira).

**Limites.** Sem aprovação visual/playtest humano; sem teste com dois clientes (pedras replicadas por RPC como visual; o servidor decide o acerto, mas o cliente continua desenhando a pedra até a parede/alcance se ela quebrou em alguém); C sem carga por segurar (o mod amplificava com `cnt6`). Gatilho: se um playtest em rede mostrar pedra atravessando inimigo no cliente, replicar o evento de quebra.
