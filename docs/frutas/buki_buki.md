# Buki Buki no Mi — o corpo vira arsenal

**Id:** `buki_buki` · **Tipo:** Paramecia · **Passiva:** Corpo-Arsenal (sem
modificadores — `speed_mod` e `jump_mod` = 1,0).

> ⚠️ **A regra da fruta foi TROCADA pelo dono em 2026-08-11.** Antes era
> transformação instantânea no golpe (a arma nascia, disparava e sumia). Essa
> regra **morreu**. Se você achar documento que ainda a descreva, ele é velho —
> e a substituta da Gasu Gasu está registrada em
> [`../MUDANCAS_2026-08-06.md`](../MUDANCAS_2026-08-06.md), item 8.

**Hoje a fruta é um jogo de FPS dentro do jogo:**

- a tecla do slot **EMPUNHA** a arma, e ela **fica na mão**; sacar **não** atira;
- o **botão esquerdo** atira enquanto houver bala;
- **munição é a penalidade da fruta** — cada arma tem um número fixo de balas;
- acabou a bala (ou trocou de slot) → a arma some e **aquele slot** entra em
  recarga. É isso que empurra o jogador para o rodízio de armas;
- **botão direito** = auxílio de mira — menos na sniper, onde vira **luneta** e o
  auxílio fica desligado.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/BukiFX.gd` | o **ARSENAL** (tabela), a aparência das armas e o disparo |
| `src/effects/BukiProjeteis.gd` | a bala com cara própria de cada arma (obus, dardo, traçante…) |
| `src/player/buki_controller.gd` | a máquina de estado: empunhar, trocar, acabar munição, **e a autoridade do servidor** |
| `src/ui/AmmoHud.gd` | o contador de munição e as armas disponíveis |
| `src/ui/SniperScope.gd` | a luneta desenhada em `_draw`, sem arquivo de imagem |

---

## O arsenal

Uma linha por slot em `BukiFX.ARSENAL` — do calibre ao som. Mudar a identidade
de uma arma é editar **uma linha**; antes isso era uma escada de `if slot ==`
espalhada pelo `disparo`.

| slot | arma | balas | cadência | vel | raio | kb | dano/bala |
|---|---|---|---|---|---|---|---|
| **Z** | Pistola | 12 | 0,20 s | 42 m/s | 0,18 | 4,0 | 24 |
| **X** | Canhão (corpo inteiro) | 3 | 0,95 s | 22 m/s | 0,55 | 24,0 | 90 |
| **C** | Sniper (+ luneta) | 5 | 1,05 s | **250 m/s** | 0,16 | 10,0 | 72 |
| **V** | Minigun | 100 | 0,06 s | 46 m/s | 0,14 | 1,6 | 9 |

⚠️ **`dano` aqui é POR BALA, não por golpe** — por isso o minigun vale 9 e o
canhão 90.

### O teto de velocidade é de FÍSICA, não de gosto

A `DamageZone` anda por teleporte a 60 Hz. Com raio 0,16 contra o colisor de
1,0 m, a janela de acerto tem 1,32 m: **acima de ~79 m/s a bala atravessa o alvo
entre dois quadros.** Medido, 24 disparos por velocidade:

| 79 | 95 | 110 | 125 | 200 |
|---|---|---|---|---|
| 24/24 | 20/24 | 17/24 | 16/24 | 9/24 |

**A sniper estava em 95 e perdia 1 tiro em 6, sem ninguém saber.** Só depois da
varredura de caminho (`DamageZone._varrer_caminho`, item 24) foi seguro dobrar
para 250 m/s: **10/10 a 95, 250 e 400 m/s**. Dobrar antes teria entregado uma
arma pior, não melhor.

---

## A munição é do SERVIDOR — e por quê

**Item 14 da lista, resolvido em 2026-08-12.** `_do_server_buki_sacar` reenchia
o pente autoritativo **sem olhar recarga nenhuma**: a penalidade era decidida só
no cliente, e quem mandasse `_net_buki_sacar_req` direto pulava a única
penalidade que a fruta tem.

Duas coisas que não são óbvias e custaram caro:

1. **"Perguntar se o slot está quente" não resolvia.** A recarga do jogador
   **não anda** na cópia do servidor: `_physics_process` sai cedo quando
   `_is_authority` é falso, e para o corpo de um cliente, no servidor, ele é
   falso. `_skill_cooldowns` fica em zero lá para sempre. Por isso o servidor
   tem **carimbo de tempo** próprio (`_srv_recarga_ate`), que não exige tique.
2. **Duas guardas, e as duas são necessárias** (`BukiController.servidor_sacar`):
   sacar com arma na mão põe a **anterior** em recarga (senão o trapaceiro nunca
   manda `guardar_req` e o slot nunca esfria); **só então** se pergunta se o
   slot pedido está frio. Sem a primeira, a segunda não barra nada.

**Folga de 250 ms** na checagem do servidor: a recarga do dono começa na hora, a
do servidor só quando o `guardar_req` chega. Sem folga, apertar no fim da
recarga levaria recusa **muda**. 250 ms é 5% da menor recarga.

Medido, mesmos 17 pedidos de tiro: o trapaceiro caiu de 6 zonas de dano para 3 —
exatamente o que o jogador honesto tem.

---

## Pendências

- **Item 25:** a luneta da sniper **esconde a HUD inteira** — vida, energia,
  cronômetro, placar e lista de skills. O `SniperScope` foi pendurado antes do
  `AmmoHud` para o contador sobreviver, mas o resto da HUD tem outro pai.
  **Decisão pendente:** mirar cega é o preço da sniper, ou vida e cronômetro
  devem ficar por cima?
- **Item 26:** projétil rápido pode empurrar o alvo **para trás**, na direção do
  atirador — o knockback é `alvo − centro da zona`, e a 250 m/s a zona já passou
  do alvo quando o acerto é registrado. **É na sniper que isso mais aparece.**
- **Item 17:** o servidor **não valida** `origin`/`aim` do tiro — a `DamageZone`
  nasce onde o cliente pediu.
- **Item 18:** `combat_mode` não replica; o saque remoto é aceito **por
  acidente** (a cópia do servidor fica presa no default `"fruit"`). Se o default
  mudar, todo saque remoto quebra em silêncio.

Teste dedicado: `tools/dev_tests/test_buki_buki.gd`. Sondas de rede:
`net_buki_host_probe.gd` / `net_buki_client_probe.gd`.
