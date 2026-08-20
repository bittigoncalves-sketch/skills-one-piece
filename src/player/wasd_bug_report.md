# Relatório de Correção do Bug de Movimentação (WASD)

## O Problema
O movimento horizontal (W, A, S, D) parava de funcionar, enquanto outras mecânicas como gravidade e geppo continuavam operando (como evidenciado pelo rastro `vel.y = 12.2667` no `traco.txt`). A causa raiz encontrava-se em `MoveFrame.gd` e sua dependência restrita do estado do cursor e layouts de teclado.

## Causas Encontradas
1. **Wayland Mouse Capture Sync:** No `MoveFrame.gd`, a leitura dos inputs estava condicionada exclusivamente a `Input.mouse_mode == Input.MOUSE_MODE_CAPTURED`. Devido a peculiaridades do Wayland no Godot 4 no Linux, a janela às vezes perde a sincronia do estado de captura do mouse logo ao trocar de cena (ao clicar em "Jogar Singleplayer"), fazendo com que o `mouse_mode` não reporte como capturado até que um novo clique aconteça, silenciando todas as teclas de movimento.
2. **Layouts de Teclado (Physical vs Logical Key):** O uso de `Input.is_key_pressed(KEY_W)` estava atrelado à tecla lógica "W". Jogadores com teclados não-QWERTY (ex: AZERTY) não conseguiriam se mover com a configuração física WASD. O ideal é ler a posição física do teclado usando `Input.is_physical_key_pressed()`.

## Solução Aplicada
1. Modificamos `Player.gd` (`_etapa_input`) para verificar ativamente se os menus (`Hud.is_menu_open()`) estão fechados.
2. Atualizamos `MoveFrame.gd` (`ler()`) para aceitar o estado do menu como fonte de verdade para a variável `ativo`, funcionando em fallback mesmo quando o `mouse_mode` dessincroniza.
3. Trocamos `is_key_pressed()` por `is_physical_key_pressed()` para garantir suporte robusto aos inputs WASD independente do layout do teclado do usuário.

A física não estava sendo sobrescrita por `_etapa_travamento`; o `velocity.x` e `velocity.z` zerados no traço eram unicamente devido à leitura vazia do `q.dir` no `MoveFrame`.
