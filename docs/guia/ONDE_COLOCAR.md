# Onde colocar cada coisa

Estrutura **real**, levantada do repositório. Se você vai criar um arquivo,
procure aqui primeiro.

---

## Regra geral

**A pasta é decidida pelo DONO do comportamento, não pela fruta nem pela tela.**

Um golpe da Gura Gura não vai numa pasta "gura" — o VFX vai em `src/effects/`, a
pose vai em `src/anim/`, a regra de recarga vai em `src/player/`. É por isso que
um agente consegue trabalhar só num arquivo sem disputar com outro.

---

## `src/effects/` — VFX e dano (48 arquivos, a pasta mais movimentada)

**Entra:** o efeito visual de um golpe e a hitbox que ele cria. Um arquivo por
fruta ou por família de efeito: `GomuFX`, `GuraFX`, `GoroFX`, `YamiFX`, `FireFX`,
`IceFX`, `SandFX`, `BaraFX`, `BukiFX`, `WaterFX`. Quando um golpe cresce demais,
ganha arquivo próprio (`GoroFXGrande`, `FireFXGrande`, `GuraVNode`,
`SandTornado`, `GomuGatling`).

**Também mora aqui:** `DamageZone.gd` (a hitbox de todo o jogo), `FxUtil.gd`
(partículas, gradientes, grãos, `autofree`) e `AudioFX.gd`.

**NÃO entra:** pose de personagem (é `src/anim/`), regra de recarga ou energia (é
`src/player/`), HUD (é `src/ui/`).

**Gatilho de divisão:** passou de 900 linhas, quebra. `YamiFX` está em 811 e é o
próximo candidato (item 9 da lista de correções).

## `src/player/` — o jogador em componentes (11 scripts)

**Entra:** um componente que é dono de um pedaço do estado do jogador —
`camera_rig`, `player_rig`, `move_frame`, `parkour_controller`, `dash_controller`,
`buki_controller`, `disparo_sustentado`, `cast_controller`, `health_controller`,
`mira`.

**O princípio, e ele é a espinha do projeto:** *cada componente é dono do seu
estado; o `Player` combina os resultados.* Leia
[`../ARQUITETURA_PLAYER.md`](../ARQUITETURA_PLAYER.md).

**NÃO entra:** VFX. Se o seu componente está criando partícula, ele está fazendo
trabalho de `src/effects/`.

## `src/anim/` — animação procedural e rig

`ProceduralAnimator.gd` (poses, locomoção, IK das pernas), `SkeletonDriver.gd`
(os 13 papéis canônicos → ossos do Mixamo), `BodyScanner.gd`.

⚠️ **`ProceduralAnimator.gd` está no teto de 900 linhas.** O gatilho já está
declarado: **a próxima pose de fruta que entrar** obriga a extrair
`_hibashira_pose`, `_kurouzu_pose`, `_black_hole_pose`, `_gura_rush_pose`,
`_gura_x_charge_pose` e `_gura_v_poses` para `src/anim/FruitPoses.gd` (~150
linhas, funções puras de `(off, w)`).

## `src/combat/` — regras de combate independentes do jogador

`Melee.gd` (o combo do botão esquerdo), `FightingStyles.gd` (a tabela dos 6
estilos), `StatusFX.gd` (congelado, queimando, sugado, silenciado, invulnerável).

**A diferença para `src/player/`:** aqui mora regra que vale para **qualquer**
corpo, não só o jogador. O `TrainingDummy` também lê `StatusFX`.

## `src/ui/` — HUD e menus (10 scripts)

`Hud`, `SkillBar`, `AmmoHud`, `SniperScope`, `CharacterMenu`, `MatchHud`.

⚠️ `set_anchors_preset` **sozinho não mexe nos offsets** — o painel do placar
ficou em x = −320, fora da tela, por semanas. Use
`set_anchors_and_offsets_preset`.

## `src/historia/`, `src/editor_mapa/` e `mapas/` — Modo História (14/09/2026)

- **`src/historia/`** — a cena do Modo História. `ModoHistoria.colocar_civil()` é o
  único jeito de pôr o jogador do modo no mundo (o editor usa a mesma função).
  `progressao.gd` é o status do personagem (XP, níveis, atributos) — regra sem nó; a
  janela (`src/ui/JanelaDeStatus.gd`) só mostra e pede.
- **`src/editor_mapa/`** — o editor de mapa. Metade é lógica sem nó (documento,
  histórico, seleção, operações, matemática do gizmo); a outra metade é cena e
  painéis. **Mudança no mapa passa por `OperacoesDoEditor`**, senão não ganha desfazer.
- **`mapas/`** — dado de mapa em JSON. **Não é código e não é asset importado**: é
  lido por `MapaArquivo` e entra no pacote exportado pelo `include_filter`.
  `mapas/modelos/` guarda as cópias dos .glb da loja do editor e o `catalogo.json`;
  **não copie modelo para lá à mão** — use a loja, que valida e registra no catálogo.
- Leitura/montagem de mapa que o jogo e o editor compartilham mora em `src/world/`
  (`mapa_arquivo.gd`, `mapa_montador.gd`).

Guia completo: [`../MODO_HISTORIA.md`](../MODO_HISTORIA.md).

## `src/world/`, `src/match/`, `src/entities/`, `src/fx/`, `src/utils/`, `src/audio/`

- **`world/`** — `MapBuilder` (plataforma 200×200 m com buracos em grade),
  `TreeScatter`, geração de árvore/fruta.
- **`match/`** — `Scoreboard`, regra de rodada (10 min), pódio, respawn.
- **`entities/`** — corpos que não são o jogador: `TrainingDummy`, `AutoDummy`,
  `PickupSpawner`.
- **`fx/`** — efeitos de **tela inteira** (`ScreenFX`, `ScreenShatterFX`), não de
  mundo. São **autoload**, então nada de `Engine.has_singleton` (ver
  [`ARMADILHAS.md`](ARMADILHAS.md#5-enginehas_singleton-não-enxerga-autoload)).
- **`utils/`** — `TargetSystem`, `PlayerModelKit`.
- **`audio/`** — `audio_manager`, `audio_events`, biblioteca de sons.

## `autoload/` e `network/`

`autoload/GameFlow.gd` é o fluxo de partida. `network/` tem `ServerManager`,
`ClientManager`, `FruitNet`, descoberta na LAN.

⚠️ **Dano é autoridade do servidor.** `MultiplayerSynchronizer` replica **da
autoridade do nó** — que para o corpo de um jogador é o **cliente**. Por isso a
vida **não** pode ir num synchronizer (viraria cliente-dono, logo trapaceável):
ela viaja por RPC do servidor para os peers. Item 20 da lista.

## `tools/` e `tools/dev_tests/`

**`tools/`** — ferramentas de linha de comando: `bake_mixamo.gd` (retarget das 29
animações), `export_rig.gd`, `engrossar_base.gd`, o editor de animação.

**`tools/dev_tests/`** — **os testes da bateria**. Um arquivo por teste, nome
`test_*.gd`, e o `validar.sh` os descobre sozinho.

⚠️ **Sonda descartável NÃO vai aqui.** Vai no scratchpad da sessão. `tools/dev_tests/`
é para teste que vale rodar de novo amanhã; o resto polui a bateria e o `git status`.

## `assets/`

`models/` (`.scn` do rig voxel), `animations/` (`.res` assados do Mixamo),
`animations_glb/` (a origem), `audio/`.

⚠️ Os `.res` de animação são **assados** por `tools/bake_mixamo.gd`. Não edite à
mão: reassar é a fonte da verdade.

## `data/` — **não existe mais** (removida em 2026-09-12)

Guardava `characters.json`, `fighting_styles.json` e `akuma_no_mi.json`. Os três
eram **dados mortos**: nenhum `.gd` do projeto carregava `res://data/`, e os
números já estavam errados (`characters.json` dava 120 de vida ao Buggy quando o
jogo trabalha com 2048).

A fonte de verdade de cada assunto:

| Assunto | Onde vive de verdade |
|---|---|
| Frutas e suas skills | `SkillSystem.gd` |
| Definição das árvores/frutas do mapa | `TreeAndFruitGenerator._todas_as_definicoes()` |
| Estilos de luta | `Balance.ESTILOS` (`src/combat/Balance.gd`) |
| Personagens | `CharacterBuilder.gd` |

## A raiz

`Player.gd` (1.5k linhas, o orquestrador), `Main.gd`, `SkillSystem.gd`,
`TreeAndFruitGenerator.gd`, `CharacterBuilder.gd`, `VoxelMeshes.gd`,
`FruitPassiveSystem.gd`, e os scripts de shell (`jogar.sh`, `validar.sh`,
`checar_cache.sh`, `servidor.sh`).

**Não acrescente arquivo novo na raiz.** Ela já é o problema, não o lugar. Item 8
da lista: `Player.gd` está 1,7× acima do limite.

---

## Onde colocar documentação

| o que você escreveu | onde vai |
|---|---|
| como uma **fruta** funciona | `docs/frutas/<fruta>.md` |
| uma **mecânica** de combate | `docs/MECANICAS.md` / `docs/mecanicas/` |
| bug achado e **não** consertado | `docs/LISTA_DE_CORRECOES.md`, **com como foi detectado** |
| o **motivo** de um erro que você cometeu | `docs/erros.md` |
| decisão de arquitetura | `docs/ARQUITETURA_PLAYER.md` ou doc próprio |
| registro do que mudou num dia | `docs/MUDANCAS_<data>.md` — **histórico, nunca apague** |
