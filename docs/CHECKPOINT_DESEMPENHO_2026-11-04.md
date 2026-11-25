# Checkpoint — desempenho com muitos inimigos (04/11/2026)

**Objetivo:** o FPS cai com muitos inimigos spawnados / várias ações juntas. Origem: análise dos mods de desempenho do Minecraft
(EntityCulling, Gnetum, MoreCulling...) e medição no próprio jogo. Resultado: o gargalo NÃO era desenho (já cortado pelo motor e
pelo `PerfilGrafico`), era script + física de ~81 personagens do East Blue.

**Como medir:** `tools/dev_tests/medir_cronometro_carga.gd` (acampamento do East Blue, jogador imortal).
`godot --path . --resolution 960x540 --disable-vsync --fixed-fps 60 --script res://tools/dev_tests/medir_cronometro_carga.gd -- <rotulo> [sem_espalhar] [sem_parado] [sem_aquecer] [sem_fora_da_tela]`
Relatório em `user://desempenho/<rotulo>.txt`. Cronômetro: `src/utils/cronometro_de_desempenho.gd` (desligado por padrão, custo de um `if`).

## Melhorias (cada uma com chave estática, ligada por padrão, para A/B no mesmo build)
| Chave | O quê | Medido |
|---|---|---|
| `IaDoMod.espalhar_fases` | fase aleatória do relógio de ticks da IA | pico de ticks/quadro 71 → 27–32; p95 do quadro −13% |
| `PersonagemMinePiece.economia_de_parado` | parado no chão roda `move_and_slide` 1 quadro em 4 | corpo 5,0 → 2,4 ms; quadro −2,5 ms |
| `Mc.aquecimento_ligado` | `Mc.aquecer()` carrega 183 procedures na carga (lista: `tools/mine_piece/gerar_aquecimento.py`) | pico de 17,5 → 2,6 ms; **custa +1,08 s de carga** |
| `NpcDaIlha.economia_fora_da_tela` | idle de NPC fora do campo de visão não é animado | animador 1,9 → 0,57 ms; quadro −2 ms |

**Acumulado (4 desligadas × 4 ligadas, 2 pares):** quadro estável p50 20,0 → 17,8 ms; p95 28,2 → 20,0 ms; máx 33,9 → 24,7 ms.

## Pendente / gatilhos
- Despertar da ilha (A0): p95 ainda ~35 ms (estável ~20). Causa NÃO identificada; o `_ao_nascer` e a tabela do `McEvento` foram descartados.
- Regenerar `mapas/east_blue/aquecimento_de_procedures.json` (`python3 -I tools/mine_piece/gerar_aquecimento.py`) quando o tradutor regerar as procedures.
- Se os +1,08 s de carga incomodarem: aquecer só o fecho do `LivingTickEvent` (12 scripts) na carga e o resto em segundo plano.
- Sem validação VISUAL: NPC na borda da tela (idle congelado?) e personagem parado que perde o chão (até 4 quadros de atraso).
- Falhas que JÁ existiam (reproduzidas com as 4 chaves desligadas): `test_fruta_rocket_historia` (42), `test_corrida_de_caranguejos`, `test_missao_madeira_reset`.
- Instrumentação (`Cronometro`) ficou em ~11 arquivos do jogo; remover se algum dia o custo do `if` importar.
- Medidor antigo `medir_lag_inimigos.gd` ganhou imortalidade mas o ranking por ablação dele derruba o Godot (sinal 11, linha 133).

## Análise dos mods (REA + zip), 04/11/2026 — o que se traduz e o que foi medido
Jars abertos com o REA: entityculling (a fundo), servercore, gnetum. Lithium/ModernFix/FerriteCore/MoreCulling/ImmediatelyFast: só lista de pacotes/mixins.
- **ServerCore** (Simply Optimized): faixa de ativação por tipo; padrão do mob = 20 blocos, `tick-interval: 6`, `tick-new-entities: false`. Também mobcaps e `DynamicManager`.
  No jogo: dos 81 personagens do East Blue, **7 estão a < 20 m do jogador e 74 a > 80 m**, todos simulados em taxa cheia. Maior potencial. BLOQUEADO pela regra "só deixar de desenhar" (decisão do dono) — pedir decisão.
- **Lithium alloc/cache**: medido `IaDoMod.montar_args` = 0,16 ms de 3,2 ms (5%). Baixo valor; o custo é o corpo das procedures traduzidas (executar 1,44 ms + evento 1,52 ms).
- **Lithium collisions**: personagens usam layer 1 / mask 1 (colidem entre si). Não medido; mudar altera comportamento.
- **Gnetum** (HUD em 3 passes em buffer cache): HUD não aparece entre os maiores custos medidos. Baixo até haver perfil do HUD.
- **EntityCulling/MoreCulling/ImmediatelyFast**: lado render; GPU ~3 ms na RTX 3050 e `PerfilGrafico` já cobre; oclusão está desligada no projeto. Baixo agora.
- **ModernFix dynamic_resources/carga em thread**: candidato para o pico do despertar (A0 p95 ~35 ms vs ~20 estável), causa ainda não diagnosticada.

## Faixa de ativação da IA (implementada 04/11/2026; decisão do dono: "sim, conservadora")
`IaDoMod.faixa_de_ativacao` (chave estática, ligada). Além de 80 m do jogador mais próximo e fora de combate, a IA tica 1 vez em 6.
Fica ATIVO se: chefe · `cerebro.alvo` ou `_revide` · levou dano há < 8 s · jogador a < 80 m. Só `PersonagemMinePiece`.
Medido (2 pares, 81 personagens, 7 perto / 74 longe): ticks/quadro 25,7 → 8,4; `IaDoMod.fisica` 3,31 → 1,61 ms; quadro p50 18,25 → 16,35 ms, p95 20,4 → 18,0 ms.
Teste: `tools/dev_tests/test_faixa_de_ativacao.gd` (15/15). Passam também test_ia_do_mod 15/15, test_fidelidade 391/391, test_east_blue_personagens, test_goro_mine_piece.
NÃO feito: o `CerebroMinePiece` (0,35 ms) segue em taxa cheia; sem validação visual de um inimigo que "acorda" ao jogador se aproximar de 80 m.
Próximo: diagnosticar o pico do despertar (A0 p95 ~35 ms); depois decidir colisões (layer/mask 1/1) e HUD.
