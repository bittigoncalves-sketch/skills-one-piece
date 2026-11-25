# Frutas e técnicas — para quem chega

> Versão para agentes: [`../agentes/frutas.md`](../agentes/frutas.md) · arquivos: [`../INDICE.md#frutas`](../INDICE.md#frutas)

## O que é

As Akuma no Mi (frutas do diabo): cada uma dá quatro técnicas nas teclas Z, X, C e V. Há uma dúzia
de frutas — Pika Pika, Mera Mera, Gomu Gomu, Goro Goro, Hie Hie, Yami Yami, Suna Suna, Gura Gura,
Buki Buki, Bomu Bomu, Bara Bara, Ope Ope e a Rocket (a primeira do Modo História). Na arena o
jogador nasce com a Ope Ope; as outras aparecem em
árvores no mapa da arena.

Cada fruta tem um arquivo de efeitos em `src/effects/` (por exemplo `FireFX.gd` para a Mera Mera)
e uma página própria de documentação em [`../../frutas/`](../../frutas/README.md).

## Como funciona, em poucas linhas

1. Você aperta (ou segura) Z/X/C/V.
2. O jogo confere se pode: recarga, energia, se algo está bloqueando.
3. O pedido vai para o servidor, que confirma e avisa todos os jogadores.
4. Cada computador desenha o efeito; **só o servidor aplica o dano**.

Os efeitos e sons das frutas são **gerados por código**, não por imagens ou arquivos de som.

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| mudar o visual de uma técnica | `src/effects/<Fruta>FX.gd` |
| mudar o dano de uma técnica | `src/combat/Balance.gd` |
| mudar recarga ou custo de energia | `src/player/cast_controller.gd` e `Balance.gd` |
| mudar a hitbox (a área que acerta) | `src/effects/DamageZone.gd` e o `cast` da fruta |
| mudar as árvores com fruta | `TreeAndFruitGenerator.gd` |

## Cuidado com

- **Efeito bonito não é prova de acerto.** Uma técnica pode rodar inteira sem hitbox nenhuma: já
  aconteceu com três frutas por meses.
- **Todo efeito criado tem que sumir depois.** Um teste confere que o número de objetos volta ao
  normal depois de cada técnica.
- **Mudou uma técnica? Atualize a página da fruta** na mesma tarefa. Algumas páginas estão com a
  tabela de dano velha — quem manda é o `Balance.gd`.
- O teste completo das frutas é lento (até 8 minutos).

## Para saber mais

- [`../../frutas/README.md`](../../frutas/README.md) — regras de todas as frutas e o estado de cada uma
- [`../../PLANO_FRUTAS.md`](../../PLANO_FRUTAS.md) — os critérios de uma fruta pronta
