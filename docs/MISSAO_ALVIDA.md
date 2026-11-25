# Missão 5 — o barril da Alvida (22/11/2026)

**Divisão:** Codex = planejamento, referências, partitura, falas (`art_src/references/missao_alvida/PLANO.md`, `data/dialogos/vendedor_barcos_barril.json` e `alvida.json`, `art_src/audio/buggy_cutscene/PARTITURA_VIOLINO.*`). Claude = código.

## Pedido do dono → onde está
| Pedido | Código |
|---|---|
| Música nova, calma, notas de violino (a antiga ficou estranha) | `tools/audio/sintetizar_violino.py` (síntese própria; lê a partitura do Codex) → `buggy_chegada.ogg`, `buggy_copos_loop.ogg` |
| Todos os navios a 100 mil moedas | `LojaDeBarcos.PRECO` |
| 5ª missão, bússola → vendedor de navios | `Missoes.TABELA["alvida_no_navio"]` (depois do baú), `MissaoDaAlvida.ponto_da_bussola` |
| Diálogo cinematográfico focado no rosto, boca trocando textura | `CenaCinematografica` + `PalcoDaAlvida.close_do_rosto` + `BocaFalante` (3 visemas, 8 Hz) |
| Quem venceu o Buggy ganha o barril | `RegrasDaAlvida.situacao` exige `desafio_buggy.fase == copos_certo` |
| Barril no mar (visão de dentro), pescado pelo navio, aberto, "invasor" | `MissaoDaAlvida._planos_do_barril`, `PalcoDaAlvida.colocar_barril/abrir_tampa` |
| Duelo pedra-papel-tesoura 7×7, empate = desvio | `DueloPpt`, `HudDoDuelo`, `MissaoDaAlvida._rodada` |
| Derrota: Ilha dos Macacos sem itens (só permanentes) | `RegrasDaAlvida.perder_itens` |
| Vitória: cena de saída, 1000 moedas + 8000 XP | `MissaoDaAlvida._desfecho` + tabela `Missoes` (fonte única do prêmio) |
| NPCs compatíveis com o tamanho do jogador | `test_moradores_quadrados` (+ `test_npcs_tamanho_do_jogador`) |

## Decisões (do dono, 22/11) e minhas
- Dono: "vencer o Buggy" = acertar os copos; depois do baú; música por síntese própria.
- Minha: quem ERROU os copos fala com o vendedor (`sem_vitoria`) e a loja abre normal — **sem barril**. Consequência: esse jogador não consegue concluir a 5ª missão enquanto a luta N7 do Buggy (fatia J) não existir. **Gatilho:** implementar a luta N7 → ela também libera o barril.
- Minha: PERMANENTE x ITEM — a derrota apaga mochila/hotbar/armadura/grade/cursor, peixes, madeira e equipamentos; mantém nível, XP, moedas, fruta e frutas guardadas, estilo de luta, skills, habilidades, missões, barcos, pets, tripulantes. **Gatilho:** o dono querer perder moedas também.
- Minha: interrupção no meio da cena/duelo recomeça pela conversa; prêmio/penalidade só no fim do duelo e idempotentes.
- Palco no mar a leste do cais (`ANCORA_DO_MAR`), arena no meio do convés (zona sem obstáculos medida no GLB), piso nosso (caixa) na altura do convés.

## Limites (não validado)
- **Nada foi visto nem ouvido por pessoa**: a música só foi medida (pico, emenda do loop); cenas, boca, barril e duelo só passam testes headless (sem render). Precisa de playtest.
- Modelos `mp_alvida`/`mpe_ship_alvida`/`barrel_2` são provisórios; a boca é pixel-art por código (o Codex pode trocar por `assets/textures/bocas_falantes/boca_*.png`).
- Animações do jogador no duelo reutilizam clipes existentes (`punching`, `falling_to_roll`, `hard_landing`, `walking`, `dying`); sem clipes dedicados.
- Sem som de mar/barril abafado (não há asset): gatilho = o Codex/dono fornecer.
