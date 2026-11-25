# Rede e multiplayer — para quem chega

> Versão para agentes: [`../agentes/rede.md`](../agentes/rede.md) · arquivos: [`../INDICE.md#rede`](../INDICE.md#rede)

## O que é

O jogo roda em rede com um modelo **cliente-servidor**: um computador é o servidor e tem a palavra
final sobre o que aconteceu (quem acertou quem, quanto de vida cada um tem); os outros são clientes
que pedem ações e mostram o resultado. Jogando sozinho, o jogo sobe um servidor dentro do seu
próprio computador — o código é o mesmo.

## Como entrar numa partida

- **Na mesma rede (casa, LAN):** quem hospeda anuncia a partida sozinho; quem entra clica em
  **CONECTAR POR LAN** e acha o host em meio segundo.
- **Por ID de sala:** 7 letras que representam o endereço do host. Funciona na mesma rede.
- **Pela internet:** é preciso abrir a porta **24565** no roteador de quem hospeda, ou rodar o
  `servidor.sh` numa máquina com endereço público.

## Onde as coisas estão

| assunto | arquivo |
|---|---|
| o servidor | `network/ServerManager.gd` |
| o cliente | `network/ClientManager.gd` |
| achar partidas na LAN | `network/LanDiscovery.gd` |
| abrir a porta para fora | `network/ExposicaoPublica.gd` |
| números da rede (porta etc.) | `network/NetworkConfig.gd` |
| coleta das frutas do mapa | `network/FruitNet.gd` |

As mensagens de cada sistema (golpes, vida, chefe) ficam no próprio sistema, não em `network/`.

## Cuidado com

- **Dano e vida só no servidor.** O cliente pede; o servidor confere e avisa todo mundo.
- **Um teste de rede de cada vez.** Todos usam a mesma porta; em paralelo eles se atrapalham.
- **Mensagem repetida não pode valer duas vezes** (golpe contado em dobro, ação cancelada que volta).
- O Modo História é só para um jogador por enquanto.

## Para saber mais

- [`../../../README.md`](../../../README.md) — seção Multiplayer
- [`../../HOSPEDAR_PARA_FORA.md`](../../HOSPEDAR_PARA_FORA.md) — jogar pela internet
- [`../../RODADA_E_PLACAR.md`](../../RODADA_E_PLACAR.md) — como mandar mensagem para a cópia certa
