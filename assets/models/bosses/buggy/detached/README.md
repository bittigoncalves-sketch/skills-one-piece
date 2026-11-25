# Mão direita separável

Derivada do `../buggyBoss.glb` fornecido pelo usuário. O original permanece intacto, SHA-256 `e05a9aa859a46ee9d89773ff995a1b2be90c74e6d300c3de51a5bd953ce4eabc`. Mesma procedência/limitações de licença registradas no README do asset original; esta derivação não acrescenta uma licença.

Fonte reproduzível: `tools/build_buggy_hand.gd`, Godot 4.6.3. Execute da raiz do projeto com `godot --headless --path . --script tools/build_buggy_hand.gd`, com caminho de log gravável quando necessário.

O gerador recorta a malha `tripo_part_8` no plano do osso `R_Hand`, perpendicular ao segmento `R_Forearm` → `R_Hand`. Interpola posição, normal, UV e pesos dos vértices de fronteira; preserva materiais importados. As extremidades recebem tampas neutras, sem sangue, construídas a partir do contorno convexo da seção do pulso (670 amostras de interseção, 171 pontos no contorno incluindo fechamento).

- `right_arm.res`: restante da malha original, com tampa no pulso.
- `right_hand_attached.res`: mão com skin para acompanhar o rig enquanto encaixada.
- `right_hand_rigid.res`: mesma parte convertida para coordenadas locais do osso do pulso, sem skin durante o voo.
- `right_hand_binding.tres`: nomes, osso e recursos configuráveis; o código comum de Boss não contém caminhos do GLB do Buggy.

O voo oculta somente a mão com skin e exibe a parte rígida. No retorno, a transformação do osso recebe novamente a parte. A extremidade do braço permanece fechada durante a separação. Fonte e derivação foram comparadas com a mesma câmera e pose nas capturas `art_src/validation/buggy_detached/wrist_original.png` e `wrist_attached.png`.

Esta preparação cobre uma única mão. Não separa automaticamente as outras regiões do corpo, não implementa dedos articulados nem substitui a preparação anatômica de braços, torso e cabeça em etapas futuras.
