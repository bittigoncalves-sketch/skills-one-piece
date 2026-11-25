# Entradas: clique, gesto do mouse e InputMap

## As duas ações do InputMap

Este projeto mantém o `InputMap` vazio por convenção (tudo é lido por
`InputEventKey`/`InputEventMouseButton` no `Player.gd`). O combate direcional abriu a
**única exceção**, declarada em `project.godot`:

| ação | botão |
|---|---|
| `combate_atacar` | botão esquerdo do mouse |
| `combate_defender` | botão direito do mouse |

Elas existem para o dono poder reconfigurar os dois cliques sem mexer em código. Quem
quiser trocar o botão, troca ali.

## Ataque: sequência de cliques e direção pelo gesto

`EntradaCorpoACorpo` guarda o movimento do mouse dos últimos `janela` segundos (0,12)
num anel fixo de 64 amostras — tamanho fixo de propósito: nada de alocar por quadro.
No clique, o gesto acumulado nessa janela vira direção:

| gesto | direção |
|---|---|
| horizontal dominante, para a esquerda | PARA_ESQUERDA |
| horizontal dominante, para a direita | PARA_DIREITA |
| vertical para cima | DE_CIMA |
| para baixo | FRENTE |
| gesto menor que a zona morta (0,035) | próximo soco da sequência do boxe; FRENTE nos estilos sem sequência |

O gesto é medido em pixels de mouse × sensibilidade, então ele acompanha a
sensibilidade da mira do jogador.

Desde 07/10/2026, **cada clique sem gesto avança um soco** no boxe: jab → gancho de
direita → gancho de esquerda → overhand (soco de cima) → jab. Após **1,2 s sem
atacar, contados do término do golpe**, o próximo clique reinicia no jab. Esse
intervalo é um valor inicial ajustável em `src/combat/direcional/estilos/boxe.tres`:
`sequencia_cliques` lista direções, `janela_sequencia` define o prazo. O primeiro
clique sempre começa no jab. Nenhum golpe adicional sai sem outro clique.

O clique nos últimos 0,3 s da recuperação guarda **um** próximo soco no buffer
existente. Cliques durante preparo/contato não avançam nem pulam socos; clicar
cedo sem gesto não provoca finta. Um gesto explícito ainda escolhe a direção e
permite a finta existente. A sequência segue a partir do golpe que começou de
verdade, incluindo o escolhido por gesto; aceitar/substituir o buffer não avança
o índice. Defender, sofrer interrupção, abrir menu, suspender a entrada ou trocar
estilo reinicia a sequência. O dano, as poses e a recuperação são os da ficha
original. Espada e IA conservam seus pedidos direcionais.

Implementação: `src/combat/direcional/entrada_corpo_a_corpo.gd`; os sinais do
executor confirmam início/fim, e o relógio da janela avança na física. Testes:
`tools/dev_tests/test_sequencia_socos.gd` e
`tools/dev_tests/test_combate_historia_tela.gd`.

## Defesa: o ESTADO do botão, não o evento

O RMB é lido pelo estado a cada quadro de física (`atualizar_defesa(segurando)`), e não
pelo par pressionar/soltar. O motivo é concreto: abrir um menu segurando o botão faz a
UI engolir o evento de soltar, e a guarda ficaria presa para sempre. Lendo o estado, a
guarda cai sozinha.

Um **aperto novo** (o botão não estava pedido) é o que abre a janela de aparo e, no
começo do preparo de um golpe, é a finta para a guarda. Ver [REGRAS.md](REGRAS.md).

## Quando a entrada é ignorada

- mouse não capturado (menu aberto, jogo sem foco): o clique não vira golpe — ele é o
  clique que recaptura o mouse;
- janela de status (M), editor de mapa ou qualquer menu aberto: `AtorJogador.pode_iniciar`
  responde não;
- corpo preso por fora do combate (atordoado, derrubado, congelado, arremesso, parkour
  de parede, morto): `impedido()` cancela o que estiver em curso.

## Onde isso encosta no `Player.gd`

Só uma linha de ponte no `_unhandled_input`, que entrega o evento para
`EntradaCorpoACorpo.tratar(evento)` e para aí se ele foi consumido. A leitura do estado
do RMB e do gesto acontece dentro da entrada, não no Player.

## Toque e outros controles

O HUD de toque (`ToqueHud`) não foi ligado a este combate: o Modo História é jogado no
teclado/mouse hoje. Um controle de toque para ele entra pelo mesmo caminho — chamando
`pedir_ataque`/`erguer_guarda`/`baixar_guarda` — sem tocar na regra.
