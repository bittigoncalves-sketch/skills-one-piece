# Interface e HUD — para quem chega

> Versão para agentes: [`../agentes/interface.md`](../agentes/interface.md) · arquivos: [`../INDICE.md#interface`](../INDICE.md#interface)

## O que é

Tudo que aparece "por cima" do jogo: menus (principal, personagem, customização), barras de vida
e energia, barra de técnicas, placar da rodada, janela de status do Modo História (tecla M) e os
controles de toque para celular. Tudo em `src/ui/`.

Cada modo tem a **sua** HUD: a da arena (`Hud.gd`) mostra técnicas e inventário; a do Modo
História (`HistoriaHud.gd`) mostra só o que o personagem da história já tem — vida, energia,
avisos de nível e a janela M.

## Como funciona, em poucas linhas

- A aparência (cores, espessura das linhas, inclinação das barras) vem de um arquivo só:
  `src/ui/Estilo.gd`.
- As barras leem a vida e a energia do personagem a cada quadro — não precisam ser avisadas.
- Os controles de toque **imitam** o teclado e o mouse: o jogo não sabe que é toque, e por isso não
  há um segundo jeito de jogar para manter.

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| mudar cores e estilo das barras | `src/ui/Estilo.gd`, `src/ui/BarraHud.gd` |
| mudar as barras do Modo História | `src/ui/VidaEnergiaHud.gd` |
| mudar a janela de status (M) | `src/ui/JanelaDeStatus.gd` |
| mudar o menu principal | `src/ui/MainMenu.gd` |
| mudar os botões de toque | `src/ui/ToqueHud.gd` |
| mudar a HUD da arena | `src/ui/Hud.gd`, `src/ui/StatsHud.gd` |

## Cuidado com

- **A janela só mostra e pede.** Regra de jogo (XP, pontos) mora na progressão, não na tela.
- **Não reaproveite a HUD da arena no Modo História:** ela mostraria botões de poderes que o
  personagem ainda não tem.
- **Topo da tela do Modo História já tem dono:** barras em cima à esquerda, aviso de nível logo
  abaixo, painel de depuração (F10) mais abaixo. Um teste mede que não se sobrepõem.

## Para saber mais

- [`../../MODO_CELULAR.md`](../../MODO_CELULAR.md) — os controles de toque
- [`../../CUSTOMIZACAO.md`](../../CUSTOMIZACAO.md) — o menu de customização
- [`../../PLANO_VISUAL.md`](../../PLANO_VISUAL.md) — Fase 6, o estilo do HUD
