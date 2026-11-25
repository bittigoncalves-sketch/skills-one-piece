# Núcleo e jogador — para quem chega

> Versão para agentes: [`../agentes/nucleo.md`](../agentes/nucleo.md) · arquivos: [`../INDICE.md#nucleo`](../INDICE.md#nucleo)

## O que é

É o personagem que você controla e o que está em volta dele: andar, correr, pular, fazer parkour,
esquivar, a câmera, a vida e a energia, o placar da rodada e os bonecos de treino da arena.

O arquivo central é o `Player.gd`. Ele é grande (~4.550 linhas) porque liga tudo: recebe o que
você aperta, move o corpo, chama o combate e conversa com a rede. Aos poucos a lógica foi tirada
dele e colocada em peças menores na pasta `src/player/` — cada uma cuida de um assunto.

## Como funciona, em poucas linhas

- A cada quadro, o jogo lê o que você pediu (teclas, mouse) uma vez só, e depois passa por
  etapas em ordem fixa: travas, movimento, câmera, combate.
- **Só uma etapa mexe na velocidade do corpo.** Empurrões de golpe e avanços somam nela. Isso
  evita dois sistemas brigando pelo mesmo corpo.
- O corpo sempre olha para onde a câmera mira.
- Quando você leva dano, o personagem fica atordoado por um instante (estado "Stunned").

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| mudar pulo, parkour ou escalada | `src/player/parkour_controller.gd` |
| mudar a esquiva (Q) | `src/player/dash_controller.gd` |
| mudar a câmera | `src/player/camera_rig.gd` |
| mudar vida, energia ou regeneração | `src/player/health_controller.gd` |
| mudar o que acontece quando leva dano | `src/mechanics/RecepcaoDeDano.gd` e `take_damage` no `Player.gd` |
| mudar a rodada, kills e mortes | `src/match/Scoreboard.gd` |
| mudar o que o personagem pode fazer (ex.: Civil do Modo História) | `src/player/capacidades.gd` |

## Cuidado com

- **Não aumente o `Player.gd`.** Ele já passou do limite de 900 linhas; coisa nova vira peça
  separada em `src/player/`.
- **A vida é do servidor.** Mudar a vida só na sua tela não muda nada de verdade.
- **Mexeu em movimento?** Existe um teste que grava o movimento quadro a quadro e compara com a
  referência (o "traço de locomoção"); ele precisa sair idêntico.

## Para saber mais

- [`../../MOVIMENTO.md`](../../MOVIMENTO.md) — parkour, esquiva e travas, com os números
- [`../../ARQUITETURA_PLAYER.md`](../../ARQUITETURA_PLAYER.md) — por que e como o Player foi dividido
- [`../../RODADA_E_PLACAR.md`](../../RODADA_E_PLACAR.md) — rodada, morte e renascimento
