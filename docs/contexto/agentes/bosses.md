# Contexto (agentes) — Chefes e IA

> 21/09/2026 · versão para pessoas: [`../pessoas/bosses.md`](../pessoas/bosses.md) · arquivos e ★:
> [`INDICE.md#bosses`](../INDICE.md#bosses) · donos do detalhe: [`PLANO_BOSS_IA.md`](../../PLANO_BOSS_IA.md)
> (ondas e metas), [`BOSS_BUGGY_PROGRESS.md`](../../BOSS_BUGGY_PROGRESS.md) (histórico),
> [`BOSS_BUGGY_COMBAT_DESIGN.md`](../../BOSS_BUGGY_COMBAT_DESIGN.md), [`BOSS_BUGGY_DETACHED.md`](../../BOSS_BUGGY_DETACHED.md)

## Escopo

O Boss (Buggy) na arena: controle, cérebro, combo, mobilidade, recepção do M1, golpes à
distância, punho destacado, telegrafia e visual. Tudo em `src/bosses/`, com autoridade do
servidor. **Não** é daqui: IA dos bonecos de treino (`nucleo`/`historia`) e o combate direcional.

## Arquivos

| arquivo | papel |
|---|---|
| `src/bosses/BossController.gd` | ciclo do Boss; hoje decide em ordem fixa (a onda 3 troca por ação pontuada) |
| `src/bosses/BossBrain.gd` | leitura do alvo (velocidade de fuga suavizada); a onda 2 move isso para `BossPerception` |
| `src/bosses/BossCombat.gd` | combo = sequência de golpes da definição (ability + followups) |
| `src/bosses/BossMobility.gd` | dash de esquiva e pulo duplo |
| `src/bosses/BossHitReaction.gd` + `BossReactionPose.gd` | recepção do M1 do jogador (tranco, voo) |
| `src/bosses/BossSlashAbility.gd`, `BossDetachedAbility.gd`, `BossDetachedAttack.gd` | corte contra quem foge; punho destacado como finalizador (só a ida fere) |
| `src/bosses/BossTelegraph.gd` | marca no chão com o alcance do soco em curso (todo golpe avisa) |
| `src/bosses/BossDefinition.gd`, `BossEncounter.gd`, `BodyPartDefinition.gd` | dados: definição, registro (identidade nunca por peer_id/nome), partes |

## Contratos

- **Servidor decide, cliente vê.** Comportamento novo do Boss é decidido só no servidor e
  replicado; entrada tardia tem que ver o estado certo (agente `boss-rede`).
- **Todo golpe tem aviso** (telegrafia); letalidade se ajusta por número, não tirando aviso.
- Dados imutáveis em `BossAbility`/definições; relógio, orçamento e cooldown vivem no `BossCombat`.
- Nenhuma malha do Buggy no código comum (bindings em `BodyPartDefinition`/`BossHandBinding`).

## Plano de IA (agentes `boss-*`, em `~/.claude/agents/`)

Onda 1 `boss-auditor-linha-base` (feita, 13/09: linha de base em
`art_src/validation/boss_ia/LINHA_DE_BASE.md`) → 2 `boss-percepcao` → 3 `boss-tatica` →
4 `boss-skills` (uma skill por execução) → 5 `boss-fases` → 6 `boss-letalidade`. Depois de cada
onda: `boss-regressao` (sem alterar código) e `boss-rede` (3 processos). Métrica: cinco bots de
jogador (parado, strafe, recuo, kite, círculo). A lista de falhas conhecidas citada nos agentes
pode estar mais velha que a do `PROJECT_CONTEXT.md` §8 — confira.

## Jogar e validar

`./jogar_buggy.sh` (exporta `SOP_TEST_CHARACTER_VISUAL` com o visual do Buggy; o atalho da área de
trabalho abre o jogo normal desde 16/09). Testes: `test_buggy`, `test_boss_lifecycle`, `test_boss_corte`,
`test_boss_detached`, `test_boss_mobilidade`, `test_boss_recepcao`, `test_boss_arremesso_jogador`,
`test_boss_buggy_visual`, `test_boss_network` (+ `.py`); medida `medir_boss_ia`; capturas
`capture_boss_*`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "boss combo followup" --area bosses
python3 tools/contexto/indice.py buscar "fuga alvo corte distancia"
python3 tools/contexto/indice.py buscar "onda metas bots" --docs
```
