# Personagem base V2

Redesenho baseado em `art_src/references/personagem_base_2026-09-08.png`, fornecida pelo dono em 08/09/2026. Mantém o corpo cinza, cabeça cúbica em camadas, rosto liso, tronco segmentado e juntas aparentes. Mãos e pontas dos pés ganharam segmentos individuais para animação.

## Arquivos

- `art_src/blender/personagem_base_v2.blend`: fonte editável, referência empacotada, esqueleto, controles de IK, iluminação e animação `Rig_Demonstracao` (quadros 1–81, 30 fps).
- `assets/models/base_v2/base_v2_rigged.glb`: malhas com pesos, Skeleton3D e demonstração animada. Contém os 134 ossos.
- `assets/models/base_v2/base_v2_runtime.glb`: mesmas malhas rígidas e mesmos pivôs, exportados como 126 nós articulados para o animador atual do jogo. Os oito controles de IK exclusivos do Blender não entram nesta versão.
- `assets/models/base_v2/rig_manifest.json`: inventário completo dos ossos, pais, posições, categorias, contagens e medições de validação.
- `art_src/previews/base_v2_*.png`: frente, perfil, três quartos, ossos, pose e capturas do personagem no Godot.

O modelo anterior e `personagem_base.blend` foram preservados. `CharacterBuilder.build_character("base")` carrega a nova versão tanto na prévia quanto no jogador e nos alvos de treino.

## Esqueleto

134 ossos no Blender/GLB, 83 deles com vértices diretamente vinculados; os demais compõem hierarquias, metacarpos, controles e pontos de fixação. São 88 peças, 3.872 triângulos e zero vértices sem peso. Cada vértice recebe peso 1 em um osso, preservando o estilo de blocos rígidos.

| Região | Estrutura |
| --- | --- |
| Centro | Root, Torso, Pelvis, SpineLower, SpineMid, Chest |
| Cabeça | Neck, NeckUpper, Head, Jaw e oito pontos faciais bilaterais |
| Braços | Clavícula, escápula, braço, torção de braço, cotovelo, antebraço, torção de antebraço, punho e mão em cada lado |
| Dedos das mãos | Quatro dedos com metacarpo + três falanges e polegar com três segmentos, em cada mão |
| Pernas e pés | Coxa, torção de coxa, joelho, canela, torção de canela, pé/tornozelo, calcanhar e apoio frontal |
| Dedos dos pés | Cinco cadeias por pé, cada uma com metatarso e duas articulações |
| Encaixes | Grip, Weapon e Sole dos dois lados |
| IK | Quatro alvos e quatro controles de direção da dobra, para braços e pernas |

Os pontos faciais são **âncoras sem deformação facial**: o desenho de referência não tem olhos nem boca. A existência desses ossos não cria expressões automaticamente. Metacarpos e outros pais movimentam as peças descendentes mesmo sem vértices diretamente vinculados.

## Animar no Blender

Abra `personagem_base_v2.blend`, selecione `BaseV2_Armature` e entre em Pose Mode. As coleções separam corpo, dedos, pés, encaixes, face e IK. A ação de demonstração abre/fecha os dedos, dobra o braço, gira o punho e flexiona a perna. Volte ao quadro 1 para a pose neutra.

FK é o padrão. Para usar IK, aumente a influência da restrição `IK optional (0 FK / 1 IK)` em `ForeArm_L/R` ou `Shin_L/R` e mova `IK_Arm_*` / `IK_Leg_*`. Os `Pole_*` controlam a direção da dobra. A demonstração usa FK; desligue sua ação ou use uma nova ação ao experimentar IK.

A versão em nós mantém os 13 papéis que os golpes existentes conhecem. As articulações extras estão disponíveis pelo nome para novas animações; os clipes antigos não passam a animar cada dedo automaticamente. No Blender/GLB animado, os eixos locais dos ossos são anatômicos; no runtime, são alinhados ao jogo, com frente −Z e direita +X. A exportação faz essa conversão.

## Integração e verificações

A escala do jogador continua em 1,5 m. O alargamento de profundidade de 1,85× aplicado à base antiga é dispensado para este modelo, preservando a referência. As pistolas usam `Grip_L/R`; itens usam `Weapon_R`; a Ope lê os pontos reais das mãos. A biblioteca legada de animações continua disponível aos alvos de treino.

A importação do GLB animado desliga `optimizer/enabled` no AnimationPlayer: a otimização padrão introduzia aproximadamente 4 mm de diferença na pose da mão. Com a configuração salva, a comparação de todos os pivôs entre GLB animado e nós articulados fica abaixo de 0,001 mm na pose de verificação.

Validações do gerador: pesos completos, deformação rígida comparada com os vértices avaliados e alcance dos quatro alvos de IK (erro máximo de aproximadamente 0,028 mm). As capturas no Godot usam o Player real. A marcha e o deslizamento dos pés continuam sujeitos à animação procedural existente; este redesenho não reautora os golpes nem promete contato perfeito com o chão.

```bash
blender --background --python tools/blender/redesenhar_base.py
GODOT_BIN="$(bash find_godot.sh)"
"$GODOT_BIN" --headless --path . --editor --import
"$GODOT_BIN" --headless --path . -s tools/dev_tests/test_base_v2.gd
"$GODOT_BIN" --headless --path . -s tools/dev_tests/test_player_rig.gd
"$GODOT_BIN" --headless --path . -s tools/dev_tests/test_walk_run.gd
"$GODOT_BIN" --path . -s tools/base_v2_preview.gd
```
