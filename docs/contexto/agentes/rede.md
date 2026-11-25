# Contexto (agentes) — Rede e multiplayer

> 21/09/2026 · versão para pessoas: [`../pessoas/rede.md`](../pessoas/rede.md) · arquivos e ★:
> [`INDICE.md#rede`](../INDICE.md#rede) · donos do detalhe: [`README.md`](../../../README.md) §Multiplayer,
> [`HOSPEDAR_PARA_FORA.md`](../../HOSPEDAR_PARA_FORA.md), [`RODADA_E_PLACAR.md`](../../RODADA_E_PLACAR.md)
> (padrão de RPC para a cópia certa), [`PLANO_COMBATE_BATTLEGROUNDS.md`](../../PLANO_COMBATE_BATTLEGROUNDS.md) (bugs B1–B6)

## Escopo

ENet cliente-servidor, **servidor-autoritário**: os autoloads de rede (`network/`), descoberta na
LAN, ID de sala, abertura de porta, e os RPCs que moram nos donos de cada sistema (`Player.gd`,
controladores de fruta, Boss, placar). O Modo História é singleplayer puro (servidor local, sem
spawner); cooperativo é gatilho declarado, não plano.

## Arquivos

| arquivo | papel |
|---|---|
| `network/ServerManager.gd` (autoload) | a AUTORIDADE: sobe o servidor, aceita peers |
| `network/ClientManager.gd` (autoload) | o lado cliente: conectar, cair, reconectar |
| `network/FruitNet.gd` (autoload, ★5) | coleta e respawn das frutas do mapa |
| `network/NetworkConfig.gd` | constantes; único lugar a mudar para servidor dedicado; porta **24565** |
| `network/LanDiscovery.gd` | farol UDP a cada 1 s; "CONECTAR POR LAN" acha o host em ~0,5 s |
| `network/ExposicaoPublica.gd` | abrir a porta para fora (UPnP) — `test_sala_publica` depende do roteador |
| `autoload/GameFlow.gd` | fachada dos modos: singleplayer = servidor local no mesmo código |

## Contratos

- **Cliente pede, servidor decide, todos veem.** Padrão da técnica: `pedir_cast_no_servidor` →
  RPC ao servidor → validação → `_net_play_cast` (`call_local`) em todos os peers.
- **Dano e vida só no servidor.** A vida atravessa por RPC (`net_vida_do_servidor`, `call_remote`);
  `MultiplayerSynchronizer` replica DA autoridade do corpo, que é o cliente — pôr vida nele deixaria
  cliente adulterado imortal (item 20).
- **Estado de FSM em cópia remota**: só a autoridade escreve estado que só a autoridade limpa (B2).
- **ID de sala** = IP do host em base32 (7 caracteres) — IP PRIVADO: vale na mesma rede; internet
  exige port-forward da 24565 ou `servidor.sh` com IP público.
- Identidade nunca inferida de `peer_id` ou nome visual (ex.: `BossEncounter`).

## Armadilhas

- **Uma porta, um processo** (armadilha 11): testes disputam a 24565; rode em série ou use
  `SOP_PORTA` por agente.
- Mensagem repetida não pode duplicar dano nem ressuscitar golpe cancelado (validação por
  identidade de ação — vale para Yoru e combate direcional).
- `multiplayer` é de `Node`, não da `SceneTree`.
- Corpo remoto com knockback sai de `take_damage` antes de `die_and_respawn` (M6, não confirmado
  em partida).

## Validar

Dois processos (host juiz + cliente ator), via `./validar.sh mp` ou direto: `net_mp_*_probe`,
`net_dano_*_probe`, `net_cast_*_probe`, `net_fruit_*_probe`, `net_sweep_*_probe`,
`net_contextual_*_probe`, `net_buki_*_probe`; testes `test_spawn_sync`, `test_lan_discovery` (pede
farol), `test_yoru_network`, `test_boss_network`, `test_ope_rede`, `test_bara_network`.

## Buscar

```bash
python3 tools/contexto/indice.py buscar "rpc servidor autoridade vida" --area rede
python3 tools/contexto/indice.py buscar "net_play_cast call_local"
python3 tools/contexto/indice.py buscar "porta roteador sala publica" --docs
```
