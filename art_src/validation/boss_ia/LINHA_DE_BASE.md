# Linha de base do Boss (Buggy) — onda 1 do `docs/PLANO_BOSS_IA.md`

Medido em 13/09/2026 por `boss-auditor-linha-base`, na árvore de trabalho atual
(sem worktree, sem checkout). Godot 4.6.3-stable, headless, física a 60 Hz,
tempo real 1,0x, porta `SOP_PORTA=25000`. Arena normal, Boss no ponto de spawn
(0; 1,1; -18), bonecos desligados, `SOP_BOSS_ENABLED=1`.

`src/bosses/*.gd`: último mtime 11:56 no início (12:33) e no fim (19:15) da
medição; `buggy_definition.tres` 11:39; `Player.gd` 11:32. Nada mudou durante
as rodadas. Régua congelada: `md5 039e1c2c57c18b3b09cb4fe15d74531b`
(`tools/dev_tests/medir_boss_ia.gd`) em todas as rodadas A–D.

## Como reproduzir

```bash
cd /home/gabriel-bitti/dev/skills-one-piece
# rodada inteira (5 bots em série): rodar_regua.sh <rodada> <semente> <porta> <hitstop> [bots]
art_src/validation/boss_ia/rodar_regua.sh A 1 25000 1     # jogo como é
art_src/validation/boss_ia/rodar_regua.sh C 1 25000 0     # sem GameFlow.hit_stop (determinístico)
# um bot, à mão:
SOP_PORTA=25000 /home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64 --headless --path . \
  --script tools/dev_tests/medir_boss_ia.gd -- --bot=strafe --semente=1 --rodada=A --hitstop=1
```

| Rodada | Comando | Semente | hitstop | Bots |
|---|---|---:|---:|---|
| A | `rodar_regua.sh A 1 25000 1` | 1 | 1 | os 5 |
| B | `rodar_regua.sh B 1 25000 1` | 1 | 1 | os 5 |
| C | `rodar_regua.sh C 1 25000 0` | 1 | 0 | os 5 |
| D | `rodar_regua.sh D 1 25000 0` (circulo completado depois com `rodar_regua.sh D 1 25000 0 circulo`, a sessão caiu no meio dele) | 1 | 0 | os 5 |

A semente fixa o RNG global (`seed()`); o caminho do Boss não sorteia nada.
Cada linha de cada tabela abaixo sai do `resumo_<bot>.json` da rodada da coluna;
o log de decisão bruto é `rodada_<X>/decisao_<bot>.csv` (colunas: `t, quadro,
bot_fase, estado, acao, combo, reacao, alvo, dist, flee_rate, vel_boss,
hp_jogador, cd_combo, cd_corte, cd_punho, parte, evento`; uma linha por mudança
de estado/ação/fase/alvo, por evento e a cada 0,1 s).

## Os bots (roteiros exatos)

Todos: o jogador real começa 6 m ao sul da origem do Boss, mira sempre no Boss
(`_yaw`), anda pelo `MoveFrame` trocado por um `BotFrame` (resto da locomoção é
o do jogo, 4,2 m/s), não entra em buraco (0 desvios em todas as rodadas).

| Bot | Roteiro |
|---|---|
| `parado` | não se move |
| `strafe` | lateral a 4,2 m/s em relação ao Boss, troca de sentido a cada 1,2 s |
| `recuo` | anda até 4 m do Boss; recua em linha reta (direção fixada no início do recuo) até o Boss perder o alvo (> 0,5 s) ou 20 m; repete |
| `kite` | anda até 2 m; 2 M1 pelo `MeleeController.pedir` real (espera a trava); recua 5 m em linha reta; repete |
| `circulo` | tangente + correção radial `clamp(d - 3, -1, 1)` em torno do Boss |

**Regra comum de reengajar** (todos menos `recuo`, que já a tem no ciclo): se o
cérebro do Boss fica sem alvo por mais de 30 quadros, o bot anda até o Boss até
ser reconhecido e retoma o roteiro. Ver o achado A1 — sem ela, `parado` e
`strafe` passavam a maior parte da medição sem luta.

## Definição das grandezas

- **Tempo**: quadros de física / 60. Com hitstop=1, `Engine.time_scale` cai a 0,06
  por 0,05 s de relógio a cada acerto; o "tempo simulado" fica ~2% menor que a
  duração. As durações abaixo são a do jogador (quadros).
- **Dano**: queda da `health` da cópia autoritativa (host) a cada quadro. A vida é
  2048 com a regeneração natural do jogo (1 HP/s em combate, 10 HP/s fora); nada
  foi escrito na vida. Subestima em até 0,17 HP por golpe (a regen do quadro).
- **Tempo p/ 2048**: instante em que o dano SOMADO chega a 2048 (a rodada acaba
  ali). Sem isso até 120 s, mostra a extrapolação `2048 / DPS`.
- **Acerto por golpe**: `acertou/lançado`. Lançado = novo `action_sequence` com
  aquele `action_id`. Acerto = queda de vida atribuída pelo valor (jab 72, corte
  90, punho 112; 0 danos sem atribuição em todas as rodadas) ao cast mais recente
  daquele id. O JSON tem também `chegaram_ao_contato` (preparação completa).
- **Parado sem agir**: Boss com alvo, não ocupado (`combat.busy`, reação,
  controle), velocidade horizontal < 0,05 m/s. Separado em pausa pós-combo
  (`cooldown_remaining > 0`, projetada) e o resto; "≥ 2 quadros" descarta o quadro
  único em que o golpe termina dentro de `BossCombat.tick`, depois do controlador
  (ordem de observação, não trava).
- **Perseguindo a ≤ 2 m sem atacar**: estado `chase`, andando, alvo a ≤ 2 m
  (`combo_break_distance`). É o "travado de fato" que a definição do plano não
  pega (ver meta 1).
- **Distância**: horizontal entre centros.

## Tabelas por bot

`var.` = (máx − mín) / 2 / média entre as duas rodadas do par. `0` = idêntico.

### `parado`

| Grandeza | A (hitstop=1) | B (hitstop=1) | C (hitstop=0) | D (hitstop=0) | var. A-B | var. C-D |
|---|---:|---:|---:|---:|---|---|
| Duração medida (s) | 55.017 | 55.017 | 53.783 | 53.783 | 0 | 0 |
| Tempo p/ 2048 de dano (s) | 55.017 | 55.017 | 53.783 | 53.783 | 0 | 0 |
| Dano total | 2070.8 | 2070.8 | 2070.8 | 2070.8 | 0 | 0 |
| DPS (duração inteira) | 37.64 | 37.64 | 38.5 | 38.5 | 0 | 0 |
| DPS nos primeiros 40 s | 39.98 | 39.98 | 39.98 | 39.98 | 0 | 0 |
| jab (acertou/lançado) | 6/6 (100%) | 6/6 (100%) | 6/6 (100%) | 6/6 (100%) |  |  |
| jab_right | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) |  |  |
| jab_left | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) |  |  |
| jab_finish | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) |  |  |
| punho destacado (acertou/usos) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) | 5/5 (100%) |  |  |
| corte: lançados / com frente / acertaram | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |  |  |
| Arremessos no jogador | 5 | 5 | 5 | 5 | 0 | 0 |
| Parado sem agir c/ alvo, total (s) | 0.017 | 0.017 | 0.017 | 0.017 | 0 | 0 |
|   pausa pós-combo (s) | 0.017 | 0.017 | 0.017 | 0.017 | 0 | 0 |
|   fora da pausa (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
|   fora da pausa, >= 2 quadros seguidos (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Perseguindo c/ alvo a <= 2 m sem atacar (s) | 1.3 | 1.3 | 1.333 | 1.333 | 0 | 0 |
| Alvo fugindo elegível, corte em recarga (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Tempo com alvo (s) | 36.55 | 36.55 | 35.317 | 35.317 | 0 | 0 |
| Bot reaproximando (s) | 16.383 | 16.383 | 16.383 | 16.383 | 0 | 0 |
| Distância média com alvo (m) | 4.135 | 4.135 | 4.221 | 4.221 | 0 | 0 |
| Distância média total (m) | 7.524 | 7.524 | 7.64 | 7.64 | 0 | 0 |
| Dano do jogador no Boss | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |

### `strafe`

| Grandeza | A (hitstop=1) | B (hitstop=1) | C (hitstop=0) | D (hitstop=0) | var. A-B | var. C-D |
|---|---:|---:|---:|---:|---|---|
| Duração medida (s) | 74.483 | 69.017 | 77.917 | 77.917 | ±3.8% | 0 |
| Tempo p/ 2048 de dano (s) | 74.483 | 69.017 | 77.917 | 77.917 | ±3.8% | 0 |
| Dano total | 2094.9 | 2055.2 | 2102.8 | 2102.8 | ±1.0% | 0 |
| DPS (duração inteira) | 28.13 | 29.78 | 26.99 | 26.99 | ±2.8% | 0 |
| DPS nos primeiros 40 s | 29.79 | 29.79 | 33.39 | 33.39 | 0 | 0 |
| jab (acertou/lançado) | 3/14 (21%) | 4/15 (27%) | 4/13 (31%) | 4/13 (31%) |  |  |
| jab_right | 8/14 (57%) | 5/15 (33%) | 8/13 (62%) | 8/13 (62%) |  |  |
| jab_left | 12/14 (86%) | 14/15 (93%) | 7/13 (54%) | 7/13 (54%) |  |  |
| jab_finish | 3/13 (23%) | 4/14 (29%) | 4/13 (31%) | 4/13 (31%) |  |  |
| punho destacado (acertou/usos) | 2/8 (25%) | 1/8 (12%) | 4/8 (50%) | 4/8 (50%) |  |  |
| corte: lançados / com frente / acertaram | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |  |  |
| Arremessos no jogador | 4 | 3 | 5 | 5 | ±14.3% | 0 |
| Parado sem agir c/ alvo, total (s) | 6.733 | 8.166 | 5.134 | 5.134 | ±9.6% | 0 |
|   pausa pós-combo (s) | 6.583 | 7.983 | 5.017 | 5.017 | ±9.6% | 0 |
|   fora da pausa (s) | 0.15 | 0.183 | 0.117 | 0.117 | ±9.9% | 0 |
|   fora da pausa, >= 2 quadros seguidos (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Perseguindo c/ alvo a <= 2 m sem atacar (s) | 1.483 | 1.367 | 1.6 | 1.6 | ±4.1% | 0 |
| Alvo fugindo elegível, corte em recarga (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Tempo com alvo (s) | 66.15 | 66.267 | 62.65 | 62.65 | ±0.1% | 0 |
| Bot reaproximando (s) | 7.283 | 1.7 | 13.7 | 13.7 | ±62.2% | 0 |
| Distância média com alvo (m) | 2.714 | 2.343 | 2.979 | 2.979 | ±7.3% | 0 |
| Distância média total (m) | 3.991 | 2.61 | 5.093 | 5.093 | ±20.9% | 0 |
| Dano do jogador no Boss | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |

### `recuo`

| Grandeza | A (hitstop=1) | B (hitstop=1) | C (hitstop=0) | D (hitstop=0) | var. A-B | var. C-D |
|---|---:|---:|---:|---:|---|---|
| Duração medida (s) | 120.0 | 120.0 | 120.0 | 120.0 | 0 | 0 |
| Tempo p/ 2048 de dano (s) | > 120 (extrap. 136.8) | > 120 (extrap. 136.8) | > 120 (extrap. 136.8) | > 120 (extrap. 136.8) |  |  |
| Dano total | 1796.8 | 1796.8 | 1796.8 | 1796.8 | 0 | 0 |
| DPS (duração inteira) | 14.97 | 14.97 | 14.97 | 14.97 | 0 | 0 |
| DPS nos primeiros 40 s | 15.72 | 15.72 | 15.72 | 15.72 | 0 | 0 |
| jab (acertou/lançado) | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| jab_right | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| jab_left | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| jab_finish | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| punho destacado (acertou/usos) | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| corte: lançados / com frente / acertaram | 21 / 20 / 20 | 21 / 20 / 20 | 21 / 20 / 20 | 21 / 20 / 20 |  |  |
| Arremessos no jogador | 0 | 0 | 0 | 0 | 0 | 0 |
| Parado sem agir c/ alvo, total (s) | 0.333 | 0.333 | 0.333 | 0.333 | 0 | 0 |
|   pausa pós-combo (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
|   fora da pausa (s) | 0.333 | 0.333 | 0.333 | 0.333 | 0 | 0 |
|   fora da pausa, >= 2 quadros seguidos (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Perseguindo c/ alvo a <= 2 m sem atacar (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Alvo fugindo elegível, corte em recarga (s) | 11.633 | 11.6 | 11.6 | 11.633 | ±0.1% | ±0.1% |
| Tempo com alvo (s) | 64.083 | 64.167 | 64.167 | 64.083 | ±0.1% | ±0.1% |
| Bot reaproximando (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Distância média com alvo (m) | 8.663 | 8.658 | 8.658 | 8.662 | ±0.0% | ±0.0% |
| Distância média total (m) | 11.705 | 11.702 | 11.701 | 11.705 | ±0.0% | ±0.0% |
| Dano do jogador no Boss | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |

### `kite`

| Grandeza | A (hitstop=1) | B (hitstop=1) | C (hitstop=0) | D (hitstop=0) | var. A-B | var. C-D |
|---|---:|---:|---:|---:|---|---|
| Duração medida (s) | 120.0 | 120.0 | 120.0 | 120.0 | 0 | 0 |
| Tempo p/ 2048 de dano (s) | > 120 (extrap. 210.4) | > 120 (extrap. 195.4) | > 120 (extrap. 195.4) | > 120 (extrap. 210.4) |  |  |
| Dano total | 1168.0 | 1257.8 | 1257.8 | 1168.0 | ±3.7% | ±3.7% |
| DPS (duração inteira) | 9.73 | 10.48 | 10.48 | 9.73 | ±3.7% | ±3.7% |
| DPS nos primeiros 40 s | 11.23 | 11.23 | 11.23 | 11.23 | 0 | 0 |
| jab (acertou/lançado) | 0/25 (0%) | 0/28 (0%) | 0/30 (0%) | 0/29 (0%) |  |  |
| jab_right | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| jab_left | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| jab_finish | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| punho destacado (acertou/usos) | 0/0 | 0/0 | 0/0 | 0/0 |  |  |
| corte: lançados / com frente / acertaram | 13 / 13 / 13 | 14 / 14 / 14 | 14 / 14 / 14 | 13 / 13 / 13 |  |  |
| Arremessos no jogador | 0 | 0 | 0 | 0 | 0 | 0 |
| Parado sem agir c/ alvo, total (s) | 0.05 | 0.05 | 0.05 | 0.05 | 0 | 0 |
|   pausa pós-combo (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
|   fora da pausa (s) | 0.05 | 0.05 | 0.05 | 0.05 | 0 | 0 |
|   fora da pausa, >= 2 quadros seguidos (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Perseguindo c/ alvo a <= 2 m sem atacar (s) | 6.8 | 6.45 | 6.7 | 6.967 | ±2.6% | ±2.0% |
| Alvo fugindo elegível, corte em recarga (s) | 1.667 | 1.633 | 1.833 | 1.867 | ±1.0% | ±0.9% |
| Tempo com alvo (s) | 80.633 | 79.033 | 77.667 | 79.267 | ±1.0% | ±1.0% |
| Bot reaproximando (s) | 23.333 | 24.417 | 28.367 | 25.217 | ±2.3% | ±5.9% |
| Distância média com alvo (m) | 2.916 | 2.941 | 2.929 | 2.956 | ±0.4% | ±0.5% |
| Distância média total (m) | 4.112 | 4.187 | 4.191 | 4.177 | ±0.9% | ±0.2% |
| Dano do jogador no Boss | 3264.0 | 3162.0 | 3264.0 | 3312.0 | ±1.6% | ±0.7% |

### `circulo`

| Grandeza | A (hitstop=1) | B (hitstop=1) | C (hitstop=0) | D (hitstop=0) | var. A-B | var. C-D |
|---|---:|---:|---:|---:|---|---|
| Duração medida (s) | 75.517 | 76.167 | 74.933 | 74.933 | ±0.4% | 0 |
| Tempo p/ 2048 de dano (s) | 75.517 | 76.167 | 74.933 | 74.933 | ±0.4% | 0 |
| Dano total | 2086.1 | 2086.1 | 2086.1 | 2086.1 | 0 | 0 |
| DPS (duração inteira) | 27.62 | 27.39 | 27.84 | 27.84 | ±0.4% | 0 |
| DPS nos primeiros 40 s | 26.98 | 26.98 | 26.98 | 26.98 | 0 | 0 |
| jab (acertou/lançado) | 10/10 (100%) | 10/10 (100%) | 10/10 (100%) | 10/10 (100%) |  |  |
| jab_right | 10/10 (100%) | 10/10 (100%) | 10/10 (100%) | 10/10 (100%) |  |  |
| jab_left | 9/9 (100%) | 9/9 (100%) | 9/9 (100%) | 9/9 (100%) |  |  |
| jab_finish | 0/9 (0%) | 0/9 (0%) | 0/9 (0%) | 0/9 (0%) |  |  |
| punho destacado (acertou/usos) | 0/9 (0%) | 0/9 (0%) | 0/9 (0%) | 0/9 (0%) |  |  |
| corte: lançados / com frente / acertaram | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |  |  |
| Arremessos no jogador | 0 | 0 | 0 | 0 | 0 | 0 |
| Parado sem agir c/ alvo, total (s) | 0.15 | 0.15 | 0.15 | 0.15 | 0 | 0 |
|   pausa pós-combo (s) | 0.15 | 0.15 | 0.15 | 0.15 | 0 | 0 |
|   fora da pausa (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
|   fora da pausa, >= 2 quadros seguidos (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Perseguindo c/ alvo a <= 2 m sem atacar (s) | 25.867 | 26.483 | 26.483 | 26.483 | ±1.2% | 0 |
| Alvo fugindo elegível, corte em recarga (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Tempo com alvo (s) | 75.5 | 76.15 | 74.917 | 74.917 | ±0.4% | 0 |
| Bot reaproximando (s) | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |
| Distância média com alvo (m) | 2.048 | 2.043 | 2.056 | 2.056 | ±0.1% | 0 |
| Distância média total (m) | 2.049 | 2.044 | 2.057 | 2.057 | ±0.1% | 0 |
| Dano do jogador no Boss | 0.0 | 0.0 | 0.0 | 0.0 | 0 | 0 |

Cortes com lateral: em TODAS as rodadas, os 20 cortes do `recuo` e os 13–14 do
`kite` passaram pelo jogador com desvio lateral 0,00 m (campo
`lateral_na_passagem`), jogador a 7,9 m (recuo) e 3,6 m (kite) da origem da
frente. O 21º corte do `recuo` aparece como "cancelado" só porque a medição
acabou aos 120 s durante a preparação dele: taxa real 20/20.

## Tolerância entre rodadas (critério de repetição)

| Par | Condição | Resultado |
|---|---|---|
| A × B | hitstop=1 (jogo como é) | `parado` e `recuo`: grandezas idênticas. `circulo`: ±0,4% no TTK, dano idêntico. `kite`: dano ±3,7% (13 × 14 cortes: um corte de 90). **`strafe`: TTK ±3,8%, arremessos ±14%, pausa pós-combo ±9,6%, reaproximação ±62%, acerto do jab_right 57% × 33%.** |
| C × D | hitstop=0 | `parado`, `strafe`: **CSV idêntico byte a byte**. `circulo`: todas as grandezas idênticas; o CSV difere só na coluna `hp_jogador` a partir de 41,6 s (≤ 0,2 HP, regeneração por relógio de parede) — *corrigido no complemento: a 1ª versão deste relatório dizia byte a byte também para o `circulo`*. `recuo`: todas as grandezas iguais (±0,1% em tempos), CSV difere só na coluna de vida (regen) e 1–2 quadros. `kite`: dano ±3,7% (de novo 14 × 13 cortes). |

**Tolerância declarada para comparar ondas: ±5% em DPS/TTK/dano e ±1 golpe por
contagem, com `--hitstop=0`.** Com hitstop=1 o `strafe` não cabe em ±5% nas
contagens (achado A6). Números absolutos "do jogo como é" = rodadas A/B.

## Achados (com número; nada foi consertado)

**A1 — O leash desliga a luta depois de 2 arremessos.** Rodada sem a regra de
reengajar (`achado_leash_sem_reengajar/`, mesma régua antes da regra, semente 1,
hitstop=1, 120 s): `parado` teve alvo por só **12,6 s de 120 s**, dano 799,7,
DPS 6,66, distância média 25,8 m; o alvo é descartado aos 12,60 s, 0,53 s depois
do 2º arremesso do punho destacado (12,07 s). `strafe`: alvo por 31,4 s, dano
1047,6, descarte aos 31,42 s logo após um arremesso do punho. Causa provável
(código, não sonda): `BossBrain.tick` descarta o alvo a > 22 m da origem; o
combo começa a ~5 m da origem e cada arremesso voa ~11,6 m no sentido de fora,
então o 2º põe o jogador além de 22 m, e o Boss volta para casa. Aggro é 11 m:
quem fica parado onde caiu nunca é perseguido de novo. Um Boss "mortal" que
abandona o jogador atordoado depois de 2 combos é um defeito de tática.

**A2 — Contra `circulo`, o combo nunca termina.** `jab_finish` 0/9 e punho
destacado **0/9** nas quatro rodadas, enquanto os três primeiros jabs acertam
29/29. `jab_finish` começa a 1,35 m; o punho emenda com o alvo a 2,74 m, mira
travada no início de 0,55 s de preparação contra um alvo a 4,2 m/s lateral. Zero
arremessos: o jogador que orbita nunca é derrubado.

**A3 — Contra `circulo`, 35% do tempo é perseguição sem ataque.** 25,9–26,5 s de
75 s em `chase` com o alvo a ≤ 2 m (1,25 m de `attack_distance` não é alcançado:
Boss 3,2 m/s contra componente radial do alvo de até ~3 m/s). No `kite`: 6,5–7,0 s.

**A4 — Contra `kite`, o Boss não conclui nenhum soco.** `jab` 0/25–30 lançados,
**0 chegaram ao contato**: o M1 do jogador (startup menor que os 0,24 s de
preparação) paralisa o Boss em todos (31–32 `stagger`). O jogador tira
3162–3312 de 4096 do Boss em 120 s e toma 1168–1258, só de cortes. Defesa do
Boss está fora do escopo por decisão do dono; o dano contra `kite` só pode vir
do corte/investida/fases.

**A5 — O corte não é gargalo de mira, é de gatilho e recarga.** Contra `recuo` e
`kite` o corte acerta **100%** (20/20; 13/13–14/14) sem previsão, porque os dois
bots se afastam na linha Boss→alvo. Contra `strafe` e `circulo` sai **0 corte**:
`flee_rate` só mede o afastamento radial (≥ 2 m/s) e a distância mínima é 4 m.
Intervalo entre cortes no `recuo`: 6,0–7,0 s para uma recarga de 4 s; 11,6 s de
"alvo fugindo elegível com o corte em recarga" em 120 s.

**A6 — `GameFlow.hit_stop` torna a medição não determinística.** Ele muda
`Engine.time_scale` para 0,06 por 0,05 s medidos em relógio de parede
(`create_timer(..., ignore_time_scale=true)`), a cada acerto. Em headless isso
desloca a simulação em ±1 quadro por golpe (primeira divergência do `parado`:
fim do `jab_finish` no quadro 190 × 191) e o `strafe` diverge (±3,8% TTK, ±14%
arremessos). Desligado (`--hitstop=0`, que marca `GameFlow.is_dedicated` só
depois do spawn do jogador — o flag só é lido no spawn e no hit-stop/slow-mo), 2
dos 5 bots dão CSV idêntico e o `circulo` só difere na vida (≤ 0,2 HP). Resíduo no `kite` (±3,7%, um corte) e no `recuo`
(vida): relógios de parede restantes — `HealthController.em_combate`
(`Time.get_ticks_msec`) e a hitbox do M1 por `create_timer` (`Melee.gd:660`).

**A7 — Pausa pós-combo é o único "parado" real.** Parado fora da pausa, em
sequências ≥ 2 quadros: **0,000 s em todos os bots e rodadas**. O resto
(0,05–0,33 s) é o quadro único de ordem de observação. Pausa pós-combo: `strafe`
5,0–8,0 s; `parado` 0,017 s; `circulo` 0,15 s.

**A8 — Vida nunca zera no fim da medição.** Nos bots que chegam a 2048 de dano
somado, a regeneração natural deixa o jogador vivo (`morreu=false` em todos):
o "tempo para matar" é o de dano somado, como pedido.

## As metas do plano, com o valor de hoje

| Meta proposta | Hoje (hitstop=1, rodadas A/B; C/D entre parênteses quando difere) | Parecer |
|---|---|---|
| **Nunca travar**: parado sem agir com alvo em alcance = 0 s | Pela definição do plano (chase com vel. 0 ou guard sem ataque): **0,000 s** em sequências ≥ 2 quadros, todos os bots. Com a pausa pós-combo: strafe 6,7–8,2 s (5,1). Mas perseguindo a ≤ 2 m sem atacar: circulo **25,9–26,5 s** (35% do tempo), kite 6,5–7,0 s, strafe 1,4–1,6 s, parado 1,3 s. | **Rever.** Como está escrita, já é cumprida hoje e não mede o problema. Proposta: "perseguindo a ≤ 2 m sem atacar ≤ X s por minuto" + "pausa pós-combo conta à parte". Sugestão de X para o dono: ≤ 3 s/min no `circulo` (hoje ~21 s/min). |
| **Punir quem foge**: ≥ 50% dos cortes acertam contra `recuo` e `kite` | `recuo` **20/20 (100%)**, `kite` **13/13–14/14 (100%)**, desvio lateral 0,00 m, sem previsão. | **Rever.** Já é 100% sem mira adiantada: os bots não têm componente lateral, então não medem a previsão. Proposta: um bot novo de fuga em diagonal (ex.: 45° da linha Boss→alvo) para a meta de ≥ 50%, e/ou meta de cadência (cortes por minuto contra quem foge; hoje recuo 10,5/min, kite 6,5–7/min, strafe/circulo 0). Mudar o conjunto de bots muda a régua: decisão do dono. |
| **Mortal**: tempo para matar cai ≥ 40% em `strafe`, `kite`, `circulo` | `strafe` 69,0–74,5 s (77,9) → meta ≤ ~43 s. `circulo` 75,5–76,2 s (74,9) → ≤ ~45 s. `kite` > 120 s, extrapolado 195–210 s → ≤ ~120 s (DPS 9,7–10,5 → ≥ 17). | **Realista para `strafe` e `circulo`** se A2/A3 forem resolvidos (finalizador e punho que hoje erram 100% contra circulo) mais as fases. **Duvidosa para `kite`** sem defesa do Boss (fora de escopo): todo dano hoje é corte (100% de acerto já), então −40% depende da investida (S2) e da recarga do corte; e o TTK do kite precisa de `--max` ≥ 220 s para ser medido em vez de extrapolado. Também depende de A1: com o leash atual, `parado`/`strafe` só lutam por causa da regra de reengajar da régua. |
| **Punitivo com aviso**: todo golpe com aviso ≥ 0,15 s | Não é medida da régua (dado estático, `buggy_definition.tres`): marca desde o início da preparação; jabs 2–4 **0,16 s**, jab 0,24, punho 0,55, corte: linha 0,55 s. | **Realista hoje, mas conflita com a F2**: "preparações 20% mais curtas" leva os jabs 2–4 a **0,128 s < 0,15 s**. Ou a F2 poupa os jabs, ou o dono aprova explicitamente. |
| **Justiça mínima**: sem acerto em jogador morto/em respawn, sem dano infinito, "prende" com janela de saída | Não coberto: a régua para a rodada ao somar 2048 e ninguém morreu (A8). | **Manter**, mas precisa de teste próprio (`boss-regressao`), não desta régua. |

## Arquivos

- `tools/dev_tests/medir_boss_ia.gd` — a régua (não é teste; o `validar.sh` não roda).
- `art_src/validation/boss_ia/rodar_regua.sh` — roda uma rodada.
- `rodada_{A,B,C,D}/` — `resumo_<bot>.json`, `decisao_<bot>.csv`, `stdout_<bot>.log`.
- `achado_leash_sem_reengajar/` — evidência de A1 (parado, strafe, recuo, sem a regra de reengajar).

---

## Complemento 13/09 — bot `zigzag`, `kite` longo e metas revisadas

Pedido do coordenador (19:21): 6º bot `zigzag` aprovado pelo dono, `kite` com
`--max` ≥ 220 s, metas revisadas em `docs/PLANO_BOSS_IA.md`. Mesma árvore:
`src/bosses/*.gd` último mtime 11:56 às 19:21 e às 19:40. Nada do jogo editado.

### A régua mudou: md5 novo

| Versão | md5 de `tools/dev_tests/medir_boss_ia.gd` | Rodadas |
|---|---|---|
| onda 1 | `039e1c2c57c18b3b09cb4fe15d74531b` | A, B, C, D |
| complemento | `77a72550f3861546a5f27687b3e54fe1` | V, E, F, K, L |

O que mudou: o bot `zigzag` (constantes `ZIGZAG_*` e um ramo novo em `_roteiro`),
a regra de reengajar agora exclui `recuo` **e** `zigzag` (os dois têm a volta no
próprio ciclo), e dois campos novos no resumo: `fuga_s` e
`fuga_com_flee_rate_no_gatilho_frac`. O runner ganhou `MAX=<s>` (padrão 120).
Os outros 5 roteiros não foram tocados.

**Os outros bots continuam iguais** (rodada V, régua nova, `--hitstop=0`, semente 1,
`rodar_regua.sh V 1 25000 0 parado strafe circulo`):

| Bot | V × C | V × D |
|---|---|---|
| `parado` | CSV idêntico byte a byte | idêntico |
| `strafe` | CSV idêntico byte a byte | idêntico |
| `circulo` | todas as grandezas idênticas (TTK 74,933 s, dano 2086,1, DPS 27,84, punho 0/9, perseguindo a ≤ 2 m 26,483 s); o CSV só difere em `hp_jogador` (≤ 0,2 HP), 0 linhas diferentes fora dessa coluna | idem |

### Bot `zigzag`

Roteiro (cabeçalho do bot na régua): ciclo igual ao `recuo` (anda até 4 m do Boss;
foge até o Boss perder o alvo por > 0,5 s ou 20 m; volta). Na fuga, a direção é a
de afastamento do Boss (recalculada a cada quadro) girada **±35°**, trocando de
lado a cada **1,5 s** (período **3,0 s**). Radial 4,2·cos35° = **3,44 m/s**,
lateral 4,2·sen35° = **2,41 m/s**, **3,6 m de pico a pico** por meia volta
(amplitude ±1,8 m em torno da linha média).

Por que esses números: a 1ª versão (45°, troca a cada 0,8 s), sonda de 30 s na
pasta temporária, deu radial 2,97 m/s < 3,2 m/s do Boss, e a distância nunca
passava dos 4 m do corte: 2 cortes em 30 s. A meia volta de 0,8 s ≈ tempo entre a
mira travar e a frente passar (~0,8 s) anulava o desvio (lateral na passagem
0,02 e 0,19 m, os dois acertaram). Não mediria a mira.

**Gatilho de fuga verificado:** `flee_rate` ≥ 2 m/s em **93,4%** dos quadros de
fuga (92,98 s de fuga com alvo e sem estar arremessado).

Comando (E e F): `art_src/validation/boss_ia/rodar_regua.sh E 1 25000 0 zigzag` e
o mesmo com `F`. Semente 1, `--hitstop=0`, `--max=120`.

| Grandeza | E | F |
|---|---:|---:|
| Duração (s) | 120,0 | 120,0 |
| **Cortes: lançados / com frente / acertaram** | **22 / 21 / 5** | **22 / 21 / 5** |
| **Taxa sobre cortes com frente** | **23,8%** | **23,8%** |
| Dano total | 449,7 | 449,7 |
| DPS (inteira / 40 s) | 3,75 / 4,50 | 3,75 / 4,50 |
| Tempo p/ 2048 | > 120 s (extrap. 546,5 s) | idem |
| Distância média com alvo / total (m) | 5,545 / 5,709 | idem |
| Tempo com alvo (s) | 110,4 | 110,4 |
| Alvo fugindo elegível, corte em recarga (s) | 54,7 | 54,7 |
| Parado fora da pausa, ≥ 2 quadros (s) | 0,0 | 0,0 |
| Quadros com desvio de buraco do bot | 97 (1,6 s) | 97 |

**Repetição E × F: CSV idêntico byte a byte** (tolerância 0).

Lateral do jogador quando a frente passa por ele (m), corte a corte, rodada E:
`2,39 e · 2,39 e · 0,83 A · 1,21 A · 2,39 e · 2,45 e · (sumiu a 6,0 m) e · 2,38 e ·
0,76 A · 0,25 A · 1,73 e · 2,28 e · 2,39 e · 2,44 e · 2,39 e · 2,39 e · 0,16 A ·
(sumiu a 6,4 m) e · 2,45 e · 1,90 e · 2,39 e`; o 22º foi cortado pelo fim da
medição em 120 s. A = acertou, e = errou. Todos os acertos com lateral ≤ 1,21 m,
todos os erros ≥ 1,73 m: coerente com meia largura da frente 0,75 + meia caixa
do jogador 0,5 = 1,25 m. Em 2 cortes a frente sumiu antes de alcançar o jogador
(a 6,0 e 6,4 m da origem); a régua não diz por quê (parede ou pilar é a hipótese).

### `kite` com 240 s

Comando: `MAX=240 art_src/validation/boss_ia/rodar_regua.sh K 1 25000 0 kite` e o
mesmo com `L`. Semente 1, `--hitstop=0`.

**Achado A9 — o `kite` mata o Boss antes de o Boss matar o jogador.** Nas duas
rodadas o Boss morre em **t = 151,033 s** (4096 de dano, 40 paralisias). Até ali o
Boss tirou **1440** do jogador (16 cortes, 16 acertos; jabs 0 de 35–36 lançados,
0 no contato), e a vida do jogador estava em **1384**. DPS do Boss no jogador até
morrer: **9,53** → tempo para matar 2048 extrapolado **~215 s**. DPS do jogador no
Boss: **27,1**. O tempo para matar real **não existe hoje**: o jogador vence.

| Grandeza | K | L |
|---|---:|---:|
| Boss morre em (s) | 151,033 | 151,033 |
| Dano no jogador até o Boss morrer | 1440 | 1440 |
| Cortes (lançados / acertaram), 240 s | 16 / 16 | 16 / 16 |
| jab (acertou / contato / lançado), 240 s | 0 / 0 / 36 | 0 / 0 / 35 |
| Distância média com alvo, 240 s (m) | 3,336 | 3,337 |
| Resumo JSON: duração / dano / DPS | 240 s / 1437,4 / 5,99 | igual |

⚠️ **Limite da régua:** ela não termina a rodada quando o Boss morre. Os campos
"de 240 s" do JSON do `kite` incluem ~89 s com o Boss morto; use os números até
151 s. **Gatilho:** na próxima mudança da régua (ou antes da onda 6, se algum bot
matar o Boss), encerrar a rodada quando `boss.dead`, e declarar o md5 novo.
Repetição K × L: grandezas idênticas até a morte do Boss; o CSV difere em 1 jab
lançado a mais (36 × 35) e na vida.

### Metas revisadas (dono, 13/09) contra os números de hoje

| Meta revisada | Hoje | Leitura |
|---|---|---|
| **Nunca travar** = 0 s em todos os bots (mantida) | 0,000 s parado fora da pausa (≥ 2 quadros) nos 6 bots, incluindo `zigzag` (E/F) e `kite` 240 s. Perseguindo a ≤ 2 m sem atacar: `circulo` 26,5 s em 75 s (não é meta) | Cumprida hoje; vira guarda de regressão |
| **Punir quem foge**: ≥ 50% dos cortes acertam contra `zigzag` | **23,8% (5/21 com frente; 5/22 lançados)**, sem mira adiantada | Faz sentido: a lateral na passagem separa bem os casos (acertos ≤ 1,21 m; erros ≥ 1,73 m), então previsão de posição tem margem para mover a taxa. Atenção ao recurso escasso: 54,7 s de 120 s com o alvo fugindo elegível e o corte em recarga (cooldown 4 s) |
| **Mortal**: TTK −40% em `strafe` e `circulo` | Com hitstop=1 (A/B): `strafe` 69,0–74,5 s → ≤ ~41–45 s; `circulo` 75,5–76,2 s → ≤ ~45 s. Com hitstop=0 (C/D/V): `strafe` 77,9 s → ≤ 46,8 s; `circulo` 74,9 s → ≤ 45,0 s | Comparar sempre com `--hitstop=0` (C/D), por causa do A6 |
| **Mortal**: `kite` TTK ≤ 120 s | Não mensurável hoje: o Boss morre em 151 s com o jogador em 1384 HP; DPS do Boss 9,53 → ~215 s extrapolado | A meta exige quase dobrar o DPS contra o `kite` (≥ 17,1) **e** que ele saia antes de 151 s, ou seja, o Boss precisa matar antes de morrer. Para medir, a régua precisa encerrar na morte do Boss (gatilho acima) |
| **Aviso**: piso 0,15 s na F1; até 0,12 s nos jabs em F2/F3 | jabs 2–4 0,16 s; jab 0,24; punho 0,55; linha do corte 0,55 (dado do `.tres`) | F2 com −20% dá 0,128 s ≥ 0,12: cabe na liberação do dono. A régua não mede aviso |
| **Justiça mínima** | Não coberta pela régua | Precisa de teste próprio |
| **Não abandonar a luta** (A1) | Sem reengajar: `parado` com alvo 12,6 s de 120 s, descarte 0,53 s depois do 2º arremesso do punho; `strafe` 31,4 s de 120 s | Para medir o conserto: rodar `parado` com a regra de reengajar desligada. Hoje a régua não tem essa opção (a evidência veio da versão anterior). **Gatilho:** quando `boss-tatica` tratar o A1, acrescentar `--reengajar=0` à régua e registrar o md5 |

### Arquivos do complemento

- `rodada_V/` — verificação de `parado`, `strafe`, `circulo` com a régua nova.
- `rodada_E/`, `rodada_F/` — `zigzag` (resumo, `decisao_zigzag.csv`, stdout).
- `rodada_K/`, `rodada_L/` — `kite` 240 s.
