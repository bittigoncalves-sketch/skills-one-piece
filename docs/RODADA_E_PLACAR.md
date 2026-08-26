# Rodada, placar e morte

Escrito em 2026-08-26 por leitura de código. O `Scoreboard` **nunca teve
página**: é o único arquivo de `src/match/`, decide quem ganha a partida, e todo
o desenho dele vivia no cabeçalho do `.gd`.

Arquivos: `src/match/Scoreboard.gd`, `src/ui/MatchHud.gd`,
`Player.die_and_respawn` / `net_force_respawn`, `SkillSystem.process_void_check`.

---

## 1. Os números

| constante | valor | |
|---|---|---|
| `ROUND_TIME` | **300 s (5 min)** | ⚠️ vários docs ainda dizem "10 min" — ver §6 |
| `PODIUM_TIME` | 8 s | painel de fim de rodada |
| `CREDIT_WINDOW` | 10 s | janela do crédito de kill por queda |
| `VOID_Y` | **−40** | abaixo disto, morreu |
| `RESPAWN` | `(0, 6, 0)` | centro do mapa, 6 m acima |
| `SYNC_INTERVAL` | 0,5 s | o servidor reemite o estado 2×/s |
| trava anti-recontagem | 2,0 s | `_dead_until` |

Empate no ranking desempata por **menos mortes** (`ranking()`). Numa rodada
curta a decisão sai por poucas kills, e é por isso que o desempate importa.

---

## 2. Por que o placar não mora no Player

**Cada cliente é autoridade do próprio corpo.** Um cliente que contasse kills
contaria só o que vê. O servidor, ao contrário, tem a `position` de *todos*
(replicada) e já roda a `DamageZone` — então ele vê **a queda** e **o autor do
último golpe**, que são exatamente os dois lados do crédito de kill.

O nó existe nos **dois** lados (filho fixo do `Main`): no servidor decide, no
cliente espelha e serve de fonte para a HUD.

**O cliente também corre o relógio localmente**, e o sync de 0,5 s corrige a
deriva — senão o cronômetro andaria aos saltos entre um pacote e outro.

---

## 3. As duas mortes, e a redundância que é de propósito

Existem **dois caminhos independentes** para declarar uma morte, e isso não é
bug:

```
vida zerada  →  DamageZone (servidor)  →  Player.die_and_respawn()  →  report_death()
queda        →  Scoreboard._watch_falls() (servidor, pela position replicada)
             →  Player.process_void_check() (cliente dono do corpo) → report_death()
```

`report_death()` sai cedo em quem não é servidor, então o caminho do cliente
**não conta nada** — quem de fato declara a morte de um cliente é o
`_watch_falls` do servidor. E `_dead_until[peer] = _clock + 2.0` garante que os
dois caminhos **nunca contem a mesma morte duas vezes**.

⚠️ **`SkillSystem.process_void_check` tem o `-40.0` e o `(0, 6, 0)` escritos à
mão** (`SkillSystem.gd:137` e `:142`), em vez de `Scoreboard.VOID_Y` e
`Scoreboard.RESPAWN`. Mudar a altura do vazio em um lugar deixa o outro para
trás. É o item **16** da [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md).

### Crédito de kill

`register_hit(vítima, atacante)` é chamada **no servidor** a cada acerto e grava
`{"by": atacante, "t": relógio}`. Na morte, o crédito só sai se o último golpe
tiver menos de **10 s**. Passou disso, "foi queda burra": morte para ela, kill
para ninguém.

Dummy e inimigo ficam de fora — `_peer_of()` devolve 0 para qualquer nó cujo nome
não seja um id de peer, e **o nome do nó do player É o peer id** (batizado em
`Main._spawn_player_data`).

---

## 4. ⚠️ A armadilha que aparece três vezes neste arquivo: mandar o RPC para a cópia CERTA

A autoridade de um corpo é do **cliente dono**, não do servidor. Três coisas aqui
só funcionam na cópia certa, e cada uma virou uma linha de código específica:

| o quê | por quê |
|---|---|
| `premiar_kill` | a regeneração roda dentro do `_physics_process`, que **sai cedo** quando `_is_authority` é falso. Premiar a cópia do servidor não faria efeito nenhum. |
| `net_force_respawn` | só o dono pode se teleportar — teleportar no servidor seria sobrescrito no quadro seguinte pela replicação. |
| `restaurar_vida_no_servidor` | consequência do anterior: com `rpc_id(peer)` só o dono respawna, e **a cópia autoritativa — a mesma que a `DamageZone` machuca — ficava com vida 0 para sempre**. Foi o item 19 da lista. |

O padrão, nos três casos:

```gdscript
if not multiplayer.has_multiplayer_peer() or peer == multiplayer.get_unique_id():
    corpo.metodo()                 # singleplayer, ou eu sou o dono
elif multiplayer.get_peers().has(peer):
    corpo.metodo.rpc_id(peer)      # o dono é outro
# senão: o peer caiu fora — nada a fazer
```

⚠️ **A terceira guarda não é defensividade decorativa.** Sem ela, um peer que se
desconecta entre a queda e a ordem derruba um erro `"unknown peer ID"` **a cada
quadro** enquanto o corpo órfão afunda no vazio (`Scoreboard.gd:176-178`).

---

## 5. O bônus de kill (e os números da regeneração)

Matar acelera a regeneração de quem matou por **30 s**. Quem premia é o
**servidor**, porque é quem sabe de quem foi a kill.

Os percentuais são do máximo, não absolutos — continuam válidos se a vida cheia
deixar de ser 2048 (`health_controller.gd:41-53`):

| situação | vida | de 0 a cheio |
|---|---|---|
| base | 0,5%/s = **10,24 hp/s** | 200 s |
| tomou dano nos últimos **5 s** | ×0,10 = **1,02 hp/s** | 2000 s |
| matou alguém (por 30 s) | 2,0%/s = **40,96 hp/s** | 50 s |

A energia (4096) segue exatamente o mesmo formato desde 2026-08-21.

⚠️ **A janela de combate de 5 s é NÚMERO ASSUMIDO**, não pedido pelo dono. É o
primeiro a calibrar se a arena ficar lenta ou rápida demais
(`health_controller.gd:56-61`).

---

## 6. Contradições conhecidas (2026-08-26)

**A rodada tem 5 minutos, não 10.** `ROUND_TIME := 300.0` desde 2026-08-12
(`Scoreboard.gd:27`), a pedido do dono. Ainda dizem "10 min":

- `src/match/Scoreboard.gd:7` — **o cabeçalho do próprio arquivo**;
- `docs/GUIA_DO_PROJETO.md:79`;
- `docs/guia/ONDE_COLOCAR.md:80`;
- `docs/LISTA_DE_CORRECOES.md:331` (usa os 10 min como argumento de balanceamento
  do campo da Ice Age — **o argumento muda com o número**).

O de `Scoreboard.gd` está registrado como item **47** em
[`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md) (é código, e auditoria não
edita código).

---

## 7. O que NÃO existe

- **Nenhuma trava de vitória.** A rodada reinicia para sempre; ninguém "ganha" a
  partida, só a rodada.
- **`_last_hit` guarda um só atacante por vítima.** Não há assistência, nem
  crédito dividido, nem "quem deu mais dano".
- **O pódio não trava o jogo.** Durante os 8 s todo mundo é respawnado e continua
  podendo se bater. `_watch_falls` continua rodando e uma morte depois dos 2 s de
  `_dead_until` **ainda incrementa `scores`** — mas o `podium_snapshot` já foi
  tirado, então o painel não muda, e `_start_new_round()` zera tudo em seguida.
  Ou seja: o que acontece no pódio não aparece e não conta. Funciona, mas é por
  acidente da ordem, não por uma guarda.
- **`scores` nunca é limpo de quem saiu.** Um peer que desconecta continua no
  dicionário e no `ranking()` até a rodada virar.
