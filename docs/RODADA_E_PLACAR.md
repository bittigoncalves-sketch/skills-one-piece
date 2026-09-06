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
| `PODIUM_TIME` | **10 s** | painel de fim de rodada (era 8; mudou em 2026-09-01) |
| `FLOOD_RISE` | **0,5 m/s** | velocidade da água — escolhida em jogo (testadas 3,0 e 1,5) |
| `DROWN_TIME` | 3 s | tempo completamente submerso até morrer |
| `FLOOD_START_Y` | 0 | topo da plataforma |
| `FLOOD_MAX_Y` | 80 | teto de segurança da água (ver §8) |
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
- **O pódio não trava o jogo.** Durante os 10 s todo mundo é respawnado e continua
  podendo se bater. `_watch_falls` continua rodando e uma morte depois dos 2 s de
  `_dead_until` **ainda incrementa `scores`** — mas o `podium_snapshot` já foi
  tirado, então o painel não muda, e `_start_new_round()` zera tudo em seguida.
  Ou seja: o que acontece no pódio não aparece e não conta. Funciona, mas é por
  acidente da ordem, não por uma guarda.
- **`scores` nunca é limpo de quem saiu.** Um peer que desconecta continua no
  dicionário e no `ranking()` até a rodada virar.

---

## 8. A enchente do fim da rodada (2026-09-01)

Pedido do dono: *"o que acontece quando o tempo zera? Ao invés de apenas zerar o
tempo, a plataforma começa a alagar (não permitir que a água vaze da
plataforma), a água vai subindo e qualquer jogador que caia na água e seja
completamente coberto por ela morre em 3 segundos. A água sobe até todos estarem
mortos e por fim exibe o placar e começa uma contagem de 10 segundos para a
próxima partida."*

O `time_left` chegar a zero **não abre mais o pódio**. Ele abre a enchente:

```
tempo zera ──► _start_flood() ──► água sobe 1,5 m/s
                                     │
                    cabeça coberta ──┴──► 3 s ──► _afogar()  (sem respawn)
                                     │
                       ninguém vivo ─┴──► _start_podium() ──► 10 s ──► rodada nova
```

### As três regras que sustentam a fase

**1. Quem morre na enchente NÃO respawna.** É a regra que faz a fase existir:
com respawn, o afogado voltaria ao centro, cairia na água outra vez e a condição
de fim (*"até todos estarem mortos"*) nunca seria alcançada. Vale para
**qualquer** morte durante a enchente, não só o afogamento — levar o último golpe
com a água na cintura também tira o jogador da rodada.

O corpo eliminado fica na arena, afundando: `Player._eliminado` corta o quadro
logo depois do portão de autoridade, deixando passar só a gravidade e a
publicação de rede. A rede continua de propósito — sem publicar, o corpo
congelaria na tela dos outros no lugar onde afundou.

**2. "Completamente coberto" é medido pelo TOPO DA CABEÇA**
(`Player.topo_da_cabeca()`), que sai do **colisor**, não do modelo. É o colisor
que a raça escala, então um gigante precisa de mais água que um humano para
morrer — que é o que a palavra "completamente" quer dizer. Água pela cintura não
mata, e sair da água **zera** a conta: o contador é de fôlego, não de castigo.

**3. A água não vaza porque nunca é fluido.** `AguaDaArena` é uma caixa do lado
exato da plataforma (200 × 200) que cresce para cima. Não vaza porque não passa
da borda, e cobre os buracos do mapa porque a caixa é maciça e o piso furado fica
dentro dela. Simular escoamento pelos buracos custaria um sistema inteiro para um
efeito que dura ~20 s por rodada. **Sem colisão**: o jogador cai na água, não
anda sobre ela.

### O nível tem um dono só

`flood_y` é do `Scoreboard` (servidor-autoridade, já replicado no mesmo pacote do
cronômetro). `AguaDaArena` só lê e desenha; `MatchHud` só lê e escreve
`🌊 ALAGANDO — N m` no lugar do relógio, que a essa altura está parado em 00:00.
Dois donos para o mesmo número é como nasce a divergência entre o que se vê e o
que mata.

Como no cronômetro, o **cliente também sobe a água localmente** entre os syncs de
0,5 s — uma parede de água andando aos saltos entregaria a rede.

### Quanto dura a fase

A 0,5 m/s a água leva **~3 s** para cobrir a cabeça de quem está no chão (topo em
~1,6 m), mais os 3 s de fôlego: a primeira morte sai por volta dos **6 s**. Quem
subir nos blocos ganha o tempo proporcional à altura deles.

No pior caso — alguém inalcançável — a água leva **~2 min 40 s** para chegar aos 80
m do teto de segurança. Com 1,5 m/s eram 53 s. É o preço de uma água lenta, e só
aparece quando a condição normal de fim (todos mortos) falha.

### `FLOOD_MAX_Y` não é o fim esperado

O fim esperado é não sobrar ninguém de pé. O teto de 80 m existe só para a água
não subir para sempre se alguém ficar inalcançável (num bloco alto, num bug de
colisão, com o corpo preso fora da arena). Quando ele é atingido com gente viva,
o log diz `a água chegou ao teto com N de pé — encerrando mesmo assim`: isso é
sintoma, não comportamento normal.

### A subida é gradual, e isso é código

`flood_y` só muda no `_physics_process` (60 Hz), e a tela desenha bem mais
rápido. `AguaDaArena` lendo o valor cru fazia a água andar em **degraus** —
medido: metade dos quadros não subia nada e a outra subia o dobro (passo máximo
2,4× a média). Por isso o nó visual tem **nível próprio**: sobe por quadro de
render à velocidade da fase, e o valor do servidor entra como **correção**
amortecida. É o mesmo arranjo do cronômetro, pelo mesmo motivo — e quem mata
continua sendo o `flood_y` do placar; o nível visual é desenho.

| caso | passo máximo por quadro | |
|---|---|---|
| subida normal | 0,0037 m (1,1× a média) | gradual |
| com correção de rede a cada 0,5 s | 0,020 m | gradual |
| divergência grande (> `AJUSTE_MAXIMO`) | 5,0 m | **salta de propósito** |

A última linha é o controle ao contrário: divergência grande **não é deriva**, é
troca de estado (entrou na partida agora, a fase começou ou acabou), e aí saltar é
o certo. Se ela também fosse suavizada, o amortecimento estaria engolindo o nível
de verdade.

`AMORTECIMENTO` (8/s) precisa absorver uma correção inteira dentro do
`SYNC_INTERVAL` de 0,5 s. Com 3/s sobrava resíduo, o erro se acumulava de pacote
em pacote e estourava o `AJUSTE_MAXIMO` — aparecia um salto de 0,63 m.

Medidor: `tools/dev_tests/medir_subida_agua.gd`.

### Desempenho (medido em 2026-09-01)

`tools/dev_tests/medir_fps_enchente.gd`. Ele **desliga o V-Sync** — com ele
ligado os três casos davam 6,94 ms cravados, que é o teto de 144 Hz e não o custo
de nada. E ele mantém um segundo corpo vivo em cena: sem isso o jogador se afoga,
a fase termina, a água some e o "pior caso" acaba medindo a arena seca.

| caso | tempo de quadro | vs. arena seca |
|---|---|---|
| arena seca (referência) | 3,80 ms | — |
| água subindo | 3,88 ms | **+2,1 %** |
| câmera submersa | 3,93 ms | **+3,4 %** |
| mesma fase, água escondida | 3,74 ms | −1,7 % (ruído) |

A última linha é o controle que separa desenho de conta: **a lógica da enchente
não custa nada** — subida do nível, varredura de jogadores e afogamento somados
ficam dentro do ruído. O custo é todo de renderização.

E ele era 4× maior antes: iluminar por pixel uma superfície de 200 × 200 m
custava **+13,5 %**. `SHADING_MODE_UNSHADED` derrubou para +2,1 % — e a água
ficou visualmente melhor, porque iluminada o sol lavava o azul.

> **Gatilho:** se a arena ganhar reflexo, névoa volumétrica ou água com shader
> próprio, medir de novo com o mesmo script antes de aceitar. O número que
> importa é a coluna "vs. arena seca", não o FPS absoluto da máquina de quem mede.

### Teste

```
DISPLAY=:1 godot --path . -s tools/dev_tests/test_enchente.gd   # 20 checagens
```

Ele monta um **segundo corpo** em cena (um `Node3D` chamado `2`, que é tudo que o
placar precisa: o nome do nó é o peer id). Sem ele, a morte do único jogador
encerraria a fase no mesmo quadro e não daria para observar nem o afogamento nem
o não-respawn.
