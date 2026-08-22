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

| slot | arma | balas | cadência | vel | raio | kb | dano/bala | pente inteiro | teto |
|---|---|---|---|---|---|---|---|---|---|
| **Z** | Pistola | 12 | 0,20 s | 42 m/s | 0,18 | 4,0 | **16** | 192 | 200 |
| **X** | Canhão (corpo inteiro) | 3 | 0,95 s | 22 m/s | 0,55 | 24,0 | **85** | 255 | 256 |
| **C** | Sniper (+ luneta) | 5 | 1,05 s | **250 m/s** | 0,16 | 10,0 | **76** | 380 | 384 |
| **V** | Minigun | 100 | 0,06 s | 46 m/s | 0,14 | 1,6 | **7** | 700 | 768 |

⚠️ **`dano` aqui é POR BALA, não por golpe** — por isso o minigun vale 7 e o
canhão 85. A coluna vem de `Balance.FRUTAS.buki_buki`; as demais, de
`BukiFX.ARSENAL`. Os números são **finais** — é o que a barra de vida perde. Ver
a seção "Dano" do [README da pasta](README.md).

### O dano por bala não é escolhido: é `teto do slot ÷ nº de balas`

É a única fruta em que a tecla **empunha** em vez de lançar, e a munição é a
penalidade — o que significa que o número de balas é **desenho de arma**, não
orçamento. Se o dano por bala fosse escolhido à mão, a arma com mais munição
seria automaticamente a mais forte, e era exatamente isso que acontecia: com a
tabela antiga o minigun somava **108** contra os **32** do canhão. Uma arma de
100 balas com o mesmo dano/bala de uma de 3 não é uma arma pesada, é um bug de
aritmética.

Hoje o valor sai da divisão, e por isso a soma do pente encosta no teto do slot
por baixo (192 de 200, 255 de 256, 380 de 384). A divisão é arredondada **para
baixo** de propósito: o teto continua sendo a garantia dura — quem mexer no
`balas` do `ARSENAL` sem mexer no `Balance` não consegue estourar o slot —, mas
no caso normal o jogador esvazia o pente inteiro sem nunca ver o corte, o que
mantém a última bala tão valiosa quanto a primeira.

A folga sobra onde há mais balas para arredondar: o minigun perde 0,68 por bala e
fica em 700 de 768, contra 8 de folga na pistola. Não incomoda — a 0,06 s de
cadência, esvaziar o pente é 6 s de gatilho preso, e ninguém fica 6 s na frente
do minigun. O teto ali é rede de segurança, não a régua.

> **Nota (2026-08-21):** havia um comentário no `ARSENAL` citando um campo
> `dano_mult` por arma. Ele **nunca existiu** no dicionário — era documentação de
> um desenho que não chegou a ser escrito, e mandava quem lesse procurar um
> multiplicador inexistente para explicar a diferença entre o canhão e o minigun.
> Foi corrigido junto com a tabela.

### O PENTE INTEIRO é uma conjuração só

`Player._spec_do_disparo` abre **uma** `DamageSpec` por (fruta, slot) e a
reaproveita em cada tiro, então todas as balas de um pente carregam o mesmo
`cast_id` e o mesmo teto. **As 100 balas do minigun somam o mesmo teto que os 3
tiros do canhão.**

A conjuração é fechada por `Player.encerrar_disparo()`, e o "quando" importa:

- **ao sacar** (`_net_buki_sacar`) — encerra ANTES de mostrar a arma, senão sacar
  a *mesma* arma duas vezes reaproveitaria o orçamento já gasto (a troca entre
  armas **diferentes** já seria pega pela chave de `_spec_do_disparo`);
- **ao guardar** (`_net_buki_guardar`) — o próximo saque começa cheio;
- **ao morrer** (`Player.gd:1522`) — um pente com o teto gasto que sobrevivesse
  ao respawn faria a primeira arma da vida nova não machucar ninguém.

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
