# Graph Report - .  (2026-07-26)

## Corpus Check
- Corpus is ~9,456 words - fits in a single context window. You may not need a graph.

## Summary
- 35 nodes · 41 edges · 8 communities (6 shown, 2 thin omitted)
- Extraction: 56% EXTRACTED · 44% INFERRED · 0% AMBIGUOUS · INFERRED: 18 edges (avg confidence: 0.75)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7

## God Nodes (most connected - your core abstractions)
1. `ProceduralAnimator` - 7 edges
2. `Main (orquestrador)` - 6 edges
3. `Player (jogador+câmera)` - 4 edges
4. `SkillSystem (técnicas)` - 4 edges
5. `SandFX (areia)` - 4 edges
6. `FireFX (fogo)` - 4 edges
7. `IceFX (gelo)` - 4 edges
8. `Rig humanoide (nós)` - 4 edges
9. `Hud` - 3 edges
10. `DamageZone (dano+knockback)` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Player (jogador+câmera)` --references--> `ProceduralAnimator`  [EXTRACTED]
  DOCUMENTACAO.md → docs/PLANO_ANIMACAO_PROCEDURAL.md
- `CharacterAnimator` --semantically_similar_to--> `ProceduralAnimator`  [INFERRED] [semantically similar]
  docs/plano_design_personagens_buggy_nami.md → docs/PLANO_ANIMACAO_PROCEDURAL.md
- `Rig humanoide (nós)` --conceptually_related_to--> `Design de personagens`  [INFERRED]
  docs/PLANO_ANIMACAO_PROCEDURAL.md → docs/plano_design_personagens_buggy_nami.md
- `Rig humanoide (nós)` --conceptually_related_to--> `Modelo voxel Buggy`  [INFERRED]
  docs/PLANO_ANIMACAO_PROCEDURAL.md → docs/especificacao_voxel_buggy.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Sistema de Combate** — skill_system, sand_fx, fire_fx, ice_fx, damage_zone [INFERRED 0.75]
- **Pipeline de Animação Procedural** — proc_anim, body_scanner, skeleton_profile, gait_phase, foot_ik [INFERRED 0.75]

## Communities (8 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.25
Nodes (9): BodyScanner (mede o corpo), Modelo voxel Buggy, IK de pé, Oscilador de marcha (fase φ), Rig humanoide (nós), Look-at (cabeça), ProceduralAnimator, SkeletonProfile (+1 more)

### Community 1 - "Community 1"
Cohesion: 0.29
Nodes (8): Hud, Inventory, Main (orquestrador), MapBuilder (mapa fixo+blocos), PickupSpawner (frutos), SkillBar (Z/X/C/V), TreeScatter (árvores nos blocos), WorldEnv (luz/céu)

### Community 2 - "Community 2"
Cohesion: 0.67
Nodes (4): Buggy, CharacterAnimator, Design de personagens, Nami

### Community 3 - "Community 3"
Cohesion: 0.67
Nodes (3): DamageZone (dano+knockback), Hie Hie no Mi, IceFX (gelo)

### Community 4 - "Community 4"
Cohesion: 0.67
Nodes (3): FireFX (fogo), FxUtil (partículas), Mera Mera no Mi

### Community 5 - "Community 5"
Cohesion: 0.67
Nodes (3): Hold-to-cast, Player (jogador+câmera), SkillSystem (técnicas)

## Knowledge Gaps
- **15 isolated node(s):** `jogar.sh script`, `SDL_VIDEODRIVER`, `WorldEnv (luz/céu)`, `PickupSpawner (frutos)`, `SkillBar (Z/X/C/V)` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Player (jogador+câmera)` connect `Community 5` to `Community 0`, `Community 1`?**
  _High betweenness centrality (0.576) - this node is a cross-community bridge._
- **Why does `ProceduralAnimator` connect `Community 0` to `Community 2`, `Community 5`?**
  _High betweenness centrality (0.472) - this node is a cross-community bridge._
- **Why does `SkillSystem (técnicas)` connect `Community 5` to `Community 3`, `Community 4`, `Community 7`?**
  _High betweenness centrality (0.335) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `ProceduralAnimator` (e.g. with `CharacterAnimator` and `IK de pé`) actually correct?**
  _`ProceduralAnimator` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `SkillSystem (técnicas)` (e.g. with `FireFX (fogo)` and `IceFX (gelo)`) actually correct?**
  _`SkillSystem (técnicas)` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `SandFX (areia)` (e.g. with `DamageZone (dano+knockback)` and `FxUtil (partículas)`) actually correct?**
  _`SandFX (areia)` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `jogar.sh script`, `SDL_VIDEODRIVER`, `WorldEnv (luz/céu)` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._