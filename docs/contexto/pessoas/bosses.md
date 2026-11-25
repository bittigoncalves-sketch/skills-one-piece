# Chefes e IA — para quem chega

> Versão para agentes: [`../agentes/bosses.md`](../agentes/bosses.md) · arquivos: [`../INDICE.md#bosses`](../INDICE.md#bosses)

## O que é

O primeiro chefe do jogo é o **Buggy**, que luta na arena. Ele tem combo de socos, esquiva, pulo
duplo, um corte à distância contra quem foge, o punho que se solta do corpo como finalizador e
reações quando apanha. Todo golpe dele mostra antes uma marca vermelha no chão com a área de
alcance, para o jogador poder reagir.

Tudo mora em `src/bosses/`, dividido em peças: quem decide (`BossController`, `BossBrain`), quem
executa os golpes (`BossCombat`), quem se move (`BossMobility`), quem reage (`BossHitReaction`) e
quem avisa (`BossTelegraph`).

## Como está evoluindo

Existe um plano para deixar o Buggy mais esperto e perigoso, feito em **ondas** por agentes de IA
especializados, cada um com uma tarefa fechada:

1. medir como ele luta hoje contra cinco "jogadores robô" (parado, andando de lado, recuando,
   atacando de longe, circulando) — **feito em 13/09**;
2. ele passar a "perceber" o jogador (velocidade, fuga, momento de ataque);
3. escolher a melhor ação em vez de seguir uma ordem fixa;
4. golpes novos, um por vez;
5. fases conforme a vida cai;
6. ajuste final dos números, sempre mantendo o aviso de cada golpe.

## Como ver

`./jogar_buggy.sh` abre o jogo com o visual do Buggy. Os testes dele começam com `test_boss_` e
`test_buggy` em `tools/dev_tests/`.

## Cuidado com

- **Quem decide o que o chefe faz é o servidor.** Se algo só funciona na tela de quem hospeda, está
  errado.
- **Todo golpe precisa de aviso.** Deixar o chefe mais perigoso é ajustar números, não esconder
  ataques.

## Para saber mais

- [`../../PLANO_BOSS_IA.md`](../../PLANO_BOSS_IA.md) — o plano das ondas e as metas
- [`../../BOSS_BUGGY_PROGRESS.md`](../../BOSS_BUGGY_PROGRESS.md) — o histórico do que foi feito
- [`../../BOSS_BUGGY_COMBAT_DESIGN.md`](../../BOSS_BUGGY_COMBAT_DESIGN.md) — o desenho do combate dele
