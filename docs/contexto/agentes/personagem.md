# Contexto (agentes) — Personagem, rig e animação

> 21/09/2026 · versão para pessoas: [`../pessoas/personagem.md`](../pessoas/personagem.md) · arquivos e ★:
> [`INDICE.md#personagem`](../INDICE.md#personagem) · donos do detalhe: [`ESQUELETO.md`](../../ESQUELETO.md),
> [`PERSONAGEM_BASE_V2.md`](../../PERSONAGEM_BASE_V2.md), [`ANIMACOES_MIXAMO.md`](../../ANIMACOES_MIXAMO.md),
> [`PLANO_ANIMACAO_PROCEDURAL.md`](../../PLANO_ANIMACAO_PROCEDURAL.md), [`CUSTOMIZACAO.md`](../../CUSTOMIZACAO.md)

## Escopo

Construção do modelo (`CharacterBuilder.gd`, `VoxelMeshes.gd`), customização (`src/customizacao/`:
corpo, raças, acessórios, adornos, paleta), rig e animação (`src/anim/`: animador procedural, ponte
para esqueleto, poses autorais por fruta e arma, rig da Yoru) e o pipeline de arte (Blender,
Mixamo). **Não** é daqui: poses do combate direcional (dados em `.tres`, contexto `historia`).

## Arquivos que mais pesam

| arquivo | papel |
|---|---|
| `src/anim/ProceduralAnimator.gd` (★5, ~1.420 linhas) | animação procedural do rig por nós; acima do teto de 900 |
| `src/customizacao/Visual.gd` | o que o jogador escolheu → a ÚNICA função que vira modelo |
| `src/customizacao/Corpo.gd` (★5) | traços do corpo (não roupa); muito citado |
| `CharacterBuilder.gd` | `build_character("base")` monta o base V2 no jogador, na prévia e nos alvos de treino |
| `src/anim/SkeletonDriver.gd` | ponte rig LÓGICO (13 papéis, nós-proxy) ↔ `Skeleton3D` real |
| `src/anim/BodyScanner.gd` | varre o rig e mede (fonte das medidas do `ESQUELETO.md`) |
| `src/anim/GuraPoses.gd`, `GoroPoses.gd`, `PikaPoses.gd`, `FruitPoses.gd`, `WeaponPoses.gd` | poses autorais |
| `src/anim/rocket_poses.gd` | poses da Rocket. A chave é `rocket_` + **comportamento da ficha** (`rocket_missil`, `rocket_bombardeio`, `rocket_mergulho`, `rocket_voo`), não a tecla: chave sem caso no `match` cai calada na sequência genérica de soco — foi assim que os três golpes da história ficaram socos até 23/09 |
| `src/anim/YoruRig.gd` | pega dupla da espada, IK de dois ossos |

## Contratos

- **13 papéis, hierarquia rasa:** `Torso, Neck, Head, UpperArm_L/R, ForeArm_L/R, Thigh_L/R,
  Shin_L/R, Foot_L/R`. Todo personagem cumpre esse contrato; nos skinados via proxies.
- **Base V2** (08/09): `assets/models/base_v2/base_v2_rigged.glb` (134 ossos) e
  `base_v2_runtime.glb` (126 nós articulados para o animador); manifesto em `rig_manifest.json`;
  fonte editável em `art_src/blender/personagem_base_v2.blend`.
- **Elenco trancado no `base`** (`ELENCO_LIBERADO`); F6 cicla quando liberado.
- **FRENTE = −Z; direita anatômica = +X local.** O rig já esteve espelhado por meses (armadilha 9).

## Armadilhas

- **Meça em espaço LOCAL**: o mundo tem escala não uniforme e mente (armadilha 8). O agente
  `avaliador-de-animacao` mede assim.
- 11 dos 29 clipes Mixamo têm o tronco tombado (`ESQUELETO.md` §4); `play_baked` congela as pernas
  e entra seco (A3 do plano da história).
- Reaproveitar mecanismo ≠ reaproveitar curva: animação ruim não se copia para golpe novo.
- `art_src/` tem `.gdignore`: o `.blend` derrubaria a importação do Godot. Não tire.
- Pose aplicada por fora do animador (combate direcional) roda DEPOIS dele no quadro.
- **Nunca `global_basis = R * from_scale(global_basis.get_scale())` num osso**: o animador só escreve
  `rotation` e guarda a escala local, então qualquer erro vira crescimento acumulado (pés do boneco,
  21/09). Escreva rotação LOCAL (`AplicadorDePose._girar_global`). O `YoruRig` ainda tem o padrão (item 65).

## Validar

`test_anatomia_rig`, `src/tests/test_anim.gd` (espada: pega o tronco), `test_ope_animacoes` (hoje falha),
`test_studio_playback` (hoje falha), capturas com `tools/base_v2_preview.gd`. Blender em
`/home/gabriel-bitti/opt/blender/blender`; bake Mixamo em `tools/bake_mixamo.gd`.
Skills: `design-padrao-ope`, `assets-para-jogos`; agente `avaliador-de-animacao`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "papel osso proxy skeleton" --area personagem
python3 tools/contexto/indice.py buscar "customizacao raca acessorio"
python3 tools/contexto/indice.py buscar "mixamo bake clipe" --docs
```
