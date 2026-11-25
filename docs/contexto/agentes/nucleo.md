# Contexto (agentes) — Núcleo e jogador

> 21/09/2026 · versão para pessoas: [`../pessoas/nucleo.md`](../pessoas/nucleo.md) · arquivos e ★:
> [`INDICE.md#nucleo`](../INDICE.md#nucleo) · donos do detalhe: [`ARQUITETURA_PLAYER.md`](../../ARQUITETURA_PLAYER.md),
> [`MOVIMENTO.md`](../../MOVIMENTO.md), [`RODADA_E_PLACAR.md`](../../RODADA_E_PLACAR.md)

## Escopo

O corpo do jogador e o que o cerca: `Player.gd` (casca), componentes em `src/player/`, FSM de
combate `src/player/hsm/`, mecânicas comuns (`src/mechanics/`: knockback, recepção de dano),
rodada e placar (`src/match/`), bonecos de treino da arena (`src/entities/`), fachada dos modos
(`autoload/GameFlow.gd`) e o orquestrador da arena (`Main.gd`). **Não** é daqui: o combo de golpes
(combate), o que cada fruta faz (frutas), o rig e as poses (personagem).

## Arquivos que mais pesam

| arquivo | papel |
|---|---|
| `Player.gd` (★5, ~4.550 linhas) | casca: entrada, etapas do ciclo físico, RPCs, ponte para cada componente. Ponto de contato de quase tudo |
| `autoload/GameFlow.gd` (★5) | fachada dos 3 modos (`start_story`, arena, editor); usada por 58 testes |
| `src/player/cast_controller.gd` | DECIDE técnica (recarga, energia, supressão, casos por fruta) antes do RPC. Desde 23/09 também guarda a MIRA da fruta do Modo História: `comecar` arma (`mirando()`), `soltar` dispara. Na arena `perfil_de_frutas` é nulo e o toque dispara como sempre |
| `src/player/melee_controller.gd` | combo do clique na arena (soco D, soco E, chute) |
| `src/player/move_frame.gd` | o que o jogador PEDIU no quadro (lido uma vez; ninguém lê `Input` solto) |
| `src/player/parkour_controller.gd`, `dash_controller.gd` | 8 movimentos de parkour; esquiva Q (12 m em 0,28 s) |
| `src/player/camera_rig.gd` | câmera 3ª pessoa a 4 m, pivô na cabeça (decisão 16/09); F5 alterna 1ª pessoa |
| `src/player/player_rig.gd` | corpo visível: montar, medir, vestir |
| `src/player/health_controller.gd` | vida/energia, regeneração 0,5%/s (10% disso por 5 s depois de apanhar) |
| `src/player/capacidades.gd` | o que o corpo pode: `can_attack`, `can_dash`, `can_double_jump`, `can_use_skills` (modos 1/2/3, T, E, Corpo de Ferro) e, desde 22/09, `can_use_fruit`/`can_fly` (a fruta do Modo História) |
| `src/player/voo_foguete.gd` | voo curto da Rocket (F): devolve velocidade à etapa, não escreve |
| `src/player/mira_de_fruta.gd` | indicador de mira da fruta: segurar mostra onde o golpe cai, soltar apaga. Só na autoridade, nunca replicado; usa a mesma conta do controlador (`src/combat/mira_de_rocket.gd`) |
| `src/mechanics/RecepcaoDeDano.gd` | pose e duração do tranco de dano (sem testes — risco) |
| `src/match/Scoreboard.gd` | rodada de 10 min, kills, mortes; servidor-autoridade |

## Contratos

- **Ciclo físico do Player:** etapas em ordem fixa; **só a etapa de locomoção escreve `velocity`**
  (knockback e avanço de golpe entram como parcela somada nela). Ver `MOVIMENTO.md` §1.
- **Corpo encara a mira** (decisão 27/08); o giro durante golpe tem teto pelo modo de combate.
- **Dano recebido:** `take_damage` → `_feedback_de_dano` → `RecepcaoDeDano` + FSM em `Stunned`
  (em TODO dano, só na autoridade). Quem consulta travas do corpo usa `corpo_livre_para_golpe()`.
- **Vida é do servidor:** o servidor aplica e manda por RPC (`net_vida_do_servidor`); nunca por
  `MultiplayerSynchronizer`.
- **Números base:** arena vida 2048 / energia 4096 (skill custa 180); Modo História começa em
  20 / 10 (fórmulas do PDF em `src/historia/progressao.gd`).
- **Modos de combate:** teclas 1 fruta · 2 estilo · 3 espada (`docs/MODOS_DE_COMBATE.md`); no Modo
  História o clique vai para o executor direcional (ponte de ~9 pontos no Player).

## Armadilhas desta área

- `Player.gd` passou de novo do teto: extrair componente em vez de somar linhas (gatilho vigente
  no `PLANO_COMBATE_HISTORIA.md`: ponte do combate direcional não ganha 10º ponto sem extração).
- `multiplayer` é de `Node`, não da `SceneTree` (as sondas `test_peer.gd`/`test_spawner.gd` da raiz
  existem por isso e não afirmam nada — não mova para `dev_tests/`).
- Estado que só se apaga pelo caminho que ele fecha trava o jogo (item 23: morrer segurando tecla).
- Cópia remota do corpo não roda o `tick` da recepção: estado entra e não sai se escrito fora da
  autoridade (bug B2 do `PLANO_COMBATE_BATTLEGROUNDS.md`).

## Validar

`test_compila`, `test_arena`, `src/tests/test_fsm.gd`, `test_walk_run`, `test_morte`, `test_player_rig`, `test_melee_trava` (com tela),
`test_modos_de_combate`, traço de locomoção (com tela; referência em `tools/dev_tests/`).
Mexeu em física/locomoção: o traço tem que sair idêntico.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "etapa locomocao velocity" --area nucleo
python3 tools/contexto/indice.py buscar "take_damage stunned recepcao"
python3 tools/contexto/indice.py buscar "rodada placar respawn" --docs
```
