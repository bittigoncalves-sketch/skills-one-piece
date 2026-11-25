# Pesquisa — Fujitora e a Zushi Zushi no Mi (12/11/2026)

Pedido do dono: pesquisar os poderes e o modo de uso do Fujitora (Issho) e acrescentar 2 poderes à Zushi Zushi importada do Mine Piece.
Fontes: busca na web e o artigo da CBR "One Piece: Fujitora's Devil Fruit abilities explained" (o wiki do Fandom devolveu HTTP 402 — não usado).

## O que o anime mostra
| Poder | Como é usado | No mod? |
|---|---|---|
| Gravito / Gravity Blade | balança a espada: onda gravitacional numa direção (cima, baixo ou lado), abre cratera | sim (22) |
| Moko ("Tigre Furioso") | força gravitacional enorme ao redor, empurra tudo para fora, destrói prédios e árvores | sim (25) |
| Puxar meteoros | traz meteoros do céu e os joga no alvo | sim (23 pequenos, 28 grande) |
| Levantar escombros / navio | ergue destroços e até um navio de guerra e os arremessa | sim (27 Rubble) |
| **Jigoku Tabi** ("Viagem ao Inferno") | embainha a espada: força muito forte para baixo numa área grande, cria uma cratera enorme | **não** |
| **Abare Himatsuri** ("Festival Furioso") | levanta a rocha em que pisa e voa pelo campo com uma chuva de meteoros atrás | **não** |

Fraqueza: golpe direto no corpo interrompe (Zoro em Dressrosa); alvos muito fortes resistem mais.

## Escolha — os 2 poderes que o mod não tem
- **K — Jigoku Tabi**: 450 de energia, recarga 14 s, só no chão. Preparo de 0,7 s (corpo parado), depois tudo num raio de 14 m leva 260 (escala do mod) e é achatado (impulso para baixo, atordoamento 1 s) + anel de poeira.
- **L — Abare Himatsuri**: 700 de energia, recarga 24 s. 4 s voando 13 m/s para onde a câmera olha, sobre uma pedra; um meteoro a cada 0,2 s atrás do jogador (0,55 s de queda, raio de impacto 3,5 m, 60 de dano, teto 480 por alvo).

## Decisões e limites
- Código em `src/combat/zushi/zushi_fujitora.gd`, no mesmo padrão da Flor de Buda (extensão autoral; o gerado do mod não é editado). Números 1002/1003 ficam fora da faixa 21–30 do mod. Dano em `Balance.FRUTAS["zushi_zushi"]`.
- Teclas K e L (as 6 teclas Z–N já estão todas ocupadas pelas técnicas do mod; K/L estavam livres). Entram em `HistoriaHud.TECLAS_DE_FRUTA`.
- Recarga por técnica (`controlador.iniciar_recarga`), igual às do mod.
- **Limites**: a cratera é só visual (anel) — não escava o terreno voxel (gatilho: quando a grade de blocos expuser uma API de explosão estável); sem som/modelo próprios; teclas K/L ainda sem botão no controle de toque; rede só validada pela regra "decide no servidor", sem teste de 3 processos.
- Teste: `tools/dev_tests/test_zushi_fujitora.gd` (17/0).

## C e V da Zushi Zushi (12/11/2026, queixa do dono: "C e V quando clicados não fazem nada")
Causa 1 — o mod só oferece Moko (C, 400) e Rubble (V, 600) depois das grades de recompensa de 300 M / 500 M (`ChangeTechniqueTest`); num save novo só Z e X existiam, então C e V não tinham técnica. Correção: `src/minecraft/otimizadas/ChangeTechniqueTestProcedure.gd` (envoltório do gerado) libera até 600 de custo SÓ na Zushi Zushi; o Meteor (B, 1250) segue pedindo a grade.
Causa 2 — o Rubble do mod traduzido faz as pedras nascerem e seguirem o alvo, mas nenhuma causa dano (medido: 0 de dano mesmo com as pedras forçadas sobre o alvo; as pedras do mod dependem da física da entidade `rubble`, que o jogo não tem). O V agora é a versão própria `ZushiFujitora.iniciar_rubble`: 1,6 s de chuva de rochas (a cada 0,08 s, raio 6 m) sobre o inimigo mais perto da linha da mira (ou o chão a 18 m), 600 de energia, recarga 12 s, dano em `Balance.FRUTAS["zushi_zushi"]["V"]`. A Moko (C) é a do mod e causa dano (verificado). Teste: `test_zushi_fujitora` 23/0.
