# Mão esquerda real do Buggy — Bara Bara do jogador

Fonte fornecida pelo usuário: `assets/models/bosses/buggy/buggyBoss.glb`, preservada sem alteração. SHA-256 `e05a9aa859a46ee9d89773ff995a1b2be90c74e6d300c3de51a5bd953ce4eabc`. A derivação mantém a procedência e as limitações de licença do arquivo de origem.

Gerador editável: `tools/build_bara_buggy_left_hand.gd`, Godot 4.6.3. É uma derivação explícita do gerador da mão direita existente, sem modificar o asset nem o código do Boss.

```bash
godot --headless --path . --log-file /tmp/bara-left-build.log --script tools/build_bara_buggy_left_hand.gd
```

O corte separa `tripo_part_9` pelo plano de `L_Hand`, perpendicular a `L_Forearm → L_Hand`. Posições, normais, UV e pesos da borda são interpolados; materiais e texturas importados são reutilizados. Tampa neutra, sem sangue, fecha ambas as extremidades: 614 interseções, 188 pontos no contorno convexo incluindo fechamento.

- `left_arm.res`: antebraço com extremidade fechada.
- `left_hand_attached.res`: mão com skin enquanto encaixada.
- `left_hand_rigid.res`: mesma geometria em coordenadas locais do osso do punho.

`src/characters/BaraHandBinding.gd` utiliza estes recursos para a esquerda e os derivados existentes para a direita. No avatar base, usa as palmas e os dedos reais já separados em `base_v2_runtime.glb`, cuja fonte é `tools/blender/redesenhar_base.py`; não há recorte caro por conjuração. A apresentação oculta as malhas originais e mostra as mesmas geometrias no voo, sem duplicar armas, alterar sockets ou disputar a hierarquia com o animador. Retorno e descarte restauram a apresentação original.

Validação estrutural/integrada de montagem: `tools/dev_tests/test_bara_hand_binding.gd`, 30 verificações aprovadas, sem abrir arena ou porta ENet. Capturas reais no renderer Vulkan/Godot 4.6.3: `tools/dev_tests/capture_bara_hands.gd`, arquivos em `art_src/validation/bara_bara/hands/`. Foram inspecionados modelo encaixado, mãos separadas e close dos encaixes no Buggy e no avatar base; os punhos permanecem fechados e os materiais conservados. A calibração de movimento e pose durante golpes pertence ao playtest das skills completas.
