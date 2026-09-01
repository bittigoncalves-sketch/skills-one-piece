# Modo celular — controles de toque

**Última revisão:** 2026-08-31.
**Estado:** controles de toque implementados e testados. O APK (Android SDK,
keystore, preset) ainda **não** foi feito — é a fase seguinte.

---

## A decisão central: injetar, não duplicar

O HUD de toque **não cria um segundo caminho de input**. Ele injeta os mesmos
eventos que o teclado e o mouse já produzem (`Input.parse_input_event`): o
joystick vira W/A/S/D, os botões viram as teclas deles, o arrasto vira
movimento de mouse.

⚠️ **Por quê.** Nove arquivos leem teclado ou mouse direto — `MoveFrame`,
`Player`, os controladores de dash, buki e disparo. Um caminho paralelo exigiria
mexer nos nove e mantê-los em sincronia para sempre: toda regra nova (uma trava,
um cancelamento) teria de ser escrita duas vezes, e a segunda seria esquecida.
Injetando, o jogo inteiro continua com **um** caminho de entrada, e o toque é só
mais uma fonte dele.

O preço é o analógico virar digital. Não se perde nada: `MoveFrame.ler()` já
trata `f` e `r` como −1/0/1 mesmo no teclado.

---

## O layout

**Esquerda anda, direita olha** — a convenção que todo jogo 3D de celular usa, e
que o jogador já conhece de outros.

| | |
|---|---|
| metade esquerda | joystick, que **nasce onde o dedo tocou** em vez de ocupar um canto fixo o tempo todo |
| metade direita | arrasta para girar a câmera |
| botões | M1, PULO, DASH, F, Z, X, C, V |

O arrasto da direita só vale **fora dos botões**: sem isso, apertar uma skill
perto da borda giraria a câmera junto.

Empurrar o joystick além de 82% do raio equivale a segurar Shift — é o que
substitui a corrida, que não tem dedo sobrando.

---

## Testar no PC, sem aparelho

```gdscript
ToqueHud.forcar = true
```

O HUD se esconde sozinho fora de Android/iOS (`ToqueHud.ativo()`); a flag liga à
força. `test_toque.gd` usa exatamente isso.

---

## Três ajustes que o resto do jogo precisou

1. **A câmera.** O `Player` só girava com `MOUSE_MODE_CAPTURED`, que **nunca** é
   verdade num celular — sem uma segunda condição, a câmera não giraria lá.
2. **O movimento.** `MoveFrame.ler()` descartava o teclado sem mouse capturado.
   Android e iOS entraram na mesma exceção que Linux já tinha, senão o jogador
   arrastaria o joystick e o boneco não andaria.
3. **A ordem no HUD.** O toque é adicionado **por último**, para ficar por cima:
   no meio da lista, um painel desenhado depois cobriria os botões e a skill
   simplesmente não sairia.

---

## A sensibilidade da câmera foi calibrada, não escolhida

Com o valor inicial (1,35), a medição deu **75° para 160 px** — meia volta a
cada ~220 px, que um polegar percorre sem querer. Com **0,55**, a meia volta fica
perto de 500 px: um arrasto deliberado.

---

## O teste, e por que ele é instável se mal escrito

`test_toque.gd` mede **deslocamento do jogador**, não estado do HUD. Um teste que
só confere "o joystick registrou o toque" passa com o boneco parado — entre a
injeção e o personagem andar existem o `MoveFrame`, a FSM e a física.

Duas armadilhas custaram medição:

- **os blocos interferiam entre si.** Com o joystick antes, o pulo falhava em 1
  de 3; invertendo a ordem, o pulo passou a funcionar sempre e quem falhava era o
  joystick. O problema nunca foi a ordem — era um bloco herdar o corpo em
  movimento do anterior. Cada bloco agora começa com `_assentar()`, que espera a
  **condição** (parado, no chão), não conta quadros;
- **precisa de tela.** `InputEventScreenTouch` só chega ao `_input` com um
  viewport. Em headless o dedo não chega ao HUD e três asserções reprovam um
  joystick que funciona. Por isso ele roda no bloco com tela do `validar.sh`,
  junto de `test_melee_trava` e `test_segurar_ataque`.

---

## O que falta para jogar no celular

1. **Android SDK + JDK** e um keystore de debug;
2. **preset Android** no `export_presets.cfg`;
3. avaliar trocar o renderer: o projeto usa `forward_plus`, e o Godot recomenda
   `mobile` em aparelho;
4. conferir a UI dos menus em tela pequena — o HUD de toque foi feito para
   caber, os menus não foram revistos.
