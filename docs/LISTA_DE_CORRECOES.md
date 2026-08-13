# Lista de correções pendentes

Coisas **encontradas e NÃO corrigidas**, esperando decisão do dono do projeto.
Nada aqui foi alterado.

Ordem: gravidade decrescente. Cada item diz **como foi detectado** — sem isso a
lista vira palpite.

---

## ✅ Resolvidos em 2026-08-11

| # | o que era | conserto | medido |
|---|---|---|---|
| 1 | tornado da Suna a 142,4 (14× o resto) | passou pelo `DAMAGE_SCALE`, como todas as outras fontes | 142,4 → **4,8** no disparo medido (teto ~17) |
| 2 | jogador tomava dano preso no Black Hole; inimigo e dummy não | guarda `in_black_hole` acrescentada ao `Player` — o golpe é **controle puro** | preso: 2048 intacto · solto: 2048 → 1548 |
| 3 | escombros do V da Yami só feriam `"enemy"` | o laço varre `"enemy"` **e** `"player"` | outro jogador 2048 → **2037** |

## ✅ Resolvido em 2026-08-12

### 14. MUNIÇÃO INFINITA na Buki Buki — **corrigido**
`_do_server_buki_sacar` reenchia o pente autoritativo **sem olhar recarga
nenhuma**: a penalidade era decidida só no cliente. Quem mandasse
`_net_buki_sacar_req` direto pulava a única penalidade que a fruta tem.

**Por que "perguntar se o slot está quente" não resolvia:** a recarga do jogador
**não anda** na cópia do servidor — o `_physics_process` sai cedo quando
`_is_authority` é falso, e para o corpo de um cliente, no servidor, ele é falso.
`_skill_cooldowns` fica em zero lá para sempre. O servidor precisava do próprio
relógio, e ele é **carimbo de tempo** (`_srv_recarga_ate`), que não exige tique.

**Duas guardas, e as duas são necessárias** (`BukiController.servidor_sacar`):
1. sacar com arma na mão põe a **anterior** em recarga — senão o trapaceiro
   simplesmente nunca manda `guardar_req` e o slot nunca esfria;
2. só então se pergunta se o slot pedido está frio.

Sem a (1), a (2) sozinha não barra nada — era exatamente esse o buraco.

A tabela de recargas virou `Player.RECARGA_POR_SLOT`, **fonte única**: duas
cópias do mesmo número escritas à mão foi como o furo nasceu.

**Folga de 250 ms** na checagem do servidor: a recarga do dono começa na hora, a
do servidor só quando o `guardar_req` chega (meia viagem depois), então sem folga
quem apertasse no fim da recarga levaria recusa **muda**. 250 ms é 5% da menor
recarga (5 s) — absorve latência sem reabrir o furo.

**Medido na sonda de rede, mesmos 17 pedidos de tiro:**

| | pente do último saque de Z | zonas de dano | total |
|---|---|---|---|
| antes | `12→12` (mín 9) — recarregou 2× | **6** | 14 |
| depois | `12→9` (mín 9) — só desce | **3** | 11 |

O trapaceiro caiu para exatamente o que o jogador honesto tem. Bateria: 16/16.

---

## ✅ Resolvidos em 2026-08-12 (tarde)

### 19. A vida da cópia AUTORITATIVA nunca voltava — **corrigido**
`Scoreboard._order_respawn` mandava `net_force_respawn.rpc_id(peer)`: **só o
dono executava**, e o `_vida.restaurar()` mora dentro desse método. A cópia do
servidor — a mesma que a `DamageZone` machuca — ficava em **0 para sempre**.

**Conserto:** o `_order_respawn` passou a chamar também
`victim.restaurar_vida_no_servidor()`, que restaura a cópia autoritativa **e**
avisa os peers.

**Medido pela sonda de rede, 96,61 s depois do golpe:** era `0,0 de 2048`,
agora é **2048,0**.

### 20. `health` não atravessava a rede — **corrigido**
A vítima morria com a **barra cheia** na tela dela: sem flash, sem som, sem
número de dano. Medido: `on_player_damaged` recebido **0 vezes**.

**Conserto:** `net_vida_do_servidor` — um `@rpc` que o **servidor** dispara
sempre que a vida muda na cópia autoritativa.

> ⚠️ **Por que RPC e não `MultiplayerSynchronizer`.** O pedido original era
> "replicar `health`". Isso teria sido pior que o bug: o synchronizer replica
> **da autoridade** para os outros, e a autoridade do corpo é o **cliente**. Pôr
> `health` lá deixaria a vida nas mãos dele — cliente adulterado ficaria
> **imortal** — e o dano aplicado pelo servidor seria **sobrescrito** no quadro
> seguinte. Com RPC, o servidor continua dono e só **anuncia** o resultado.

O `call_remote` é de propósito: quem emitiu já aplicou e já deu o feedback;
repetir localmente piscaria e tocaria o som duas vezes.

**Medido:** o dono passou de **0** para **2 avisos** de dano.

**Efeito colateral no teste, que vale registrar:** a sonda checava
"a vida autoritativa chegou a ZERO". Depois do conserto o zero **deixou de ser
observável** — `take_damage → die_and_respawn → restaurar` acontece na mesma
chamada. A checagem virou "o dano ENTROU" + "a vida VOLTOU cheia", e quem prova
a morte é o placar. Mesma lição que o `test_morte` já tinha aprendido com o
"fundo do poço".


---

## ✅ Resolvido em 2026-08-12 (noite)

### 23. 💀 Morrer SEGURANDO a tecla travava o jogo — **corrigido**
Relatado jogando. Quem morria com a tecla de uma skill pressionada ficava com
`_charging` e `is_casting` verdadeiros **para sempre**. Duas consequências, as
duas permanentes:

- `_slot_em_uso()` devolvia aquele slot eternamente, e o laço de recarga
  **congelava todos os outros** — *"o contador trava e nunca recarrega"*;
- `CastController.comecar()` saía no `if _carregando: return` — **nenhum poder
  funcionava mais** pelo resto da partida.

O `net_force_respawn` devolvia vida, fruta e recarga, e **deixava o cast
pendurado**.

**Conserto:** o respawn passou a abortar o cast e limpar `is_casting`,
`active_skill`, `yami_black_hole_active`, `_movement_locked_timer`, a rajada e
a pistola da Yami.

**Reproduzido antes e medido depois:** `_charging=true / slot_em_uso='V'` mesmo
3 s após o respawn → agora `false / ''`, e a recarga volta a andar
(6,48 → 5,06 em 1,5 s).

**Travado por teste:** `tools/dev_tests/test_morte_limpa_cast.gd`, 8 checagens.

---

## 🔴 Alta — afeta o jogo hoje

### 22. Morte e recarga de skill — **resolvido em 2026-08-12**
A recarga atravessava a morte sem zerar. **Medido:** cast de `C` (10 s), morte
em t=2,036 s com 7,967 s restantes, e 2 s depois do respawn ainda valia 5,967 s.
Como o respawn devolve a fruta à árvore, o jogador voltava **sem poder nenhum e
com o relógio andando no vazio**.

**Decisão do dono:** morrer **zera** a recarga.

**Conserto em dois lugares, e os dois eram necessários:**
- `net_force_respawn` zera `_skill_cooldowns` — roda no **dono**;
- `restaurar_vida_no_servidor` limpa `_srv_recarga_ate` da Buki — roda no
  **servidor**.

Zerar só um lado deixaria o jogador vendo o slot livre e o servidor recusando em
silêncio: o sintoma "apertei e não aconteceu nada".

**Medido depois:** `0,000 s` onde a hipótese "continuou correndo" previa 7,972 s.

### 21. `FireFX.gd:200` chama `look_at` antes de o nó entrar na árvore
`mmi.look_at(...)` roda **antes** de `zone.add_child(mmi)`, então
`get_global_transform` é inválido e o `look_at` falha. **32 ocorrências por
processo** durante o Z da Mera Mera. Efeito: a bala de fogo nunca é orientada.

*Detectado:* ruído no log da sonda de multiplayer, 2026-08-12. Pré-existente,
sem relação com as sondas.

### 15. A morte por queda dispara por DOIS caminhos, com trava de 2 s
`SkillSystem.process_void_check` (roda no dono do corpo) e
`Scoreboard._watch_falls` (roda no servidor) veem a **mesma** queda. Só o
`_dead_until` de 2 s impede contar duas vezes.

Funciona hoje, mas a corretude da contagem depende inteiramente de uma janela
de tempo fixa: se um respawn demorar mais de 2 s (lag, pódio, cliente travado),
a mesma queda pode ser contada de novo.

*Detectado:* pelo `test_morte.gd`, ao mapear os caminhos de morte, 2026-08-12.
**Não reproduzido** — é risco à vista, não bug medido.

### 16. `process_void_check` tem o `-40.0` escrito à mão
`SkillSystem.gd:120` usa o literal `-40.0` em vez de `Scoreboard.VOID_Y`. Hoje
os dois batem; se alguém mudar a constante do placar, o Player continua morrendo
em −40 e o placar declara a morte em outro lugar.

*Detectado:* `test_morte.gd`, 2026-08-12.

### 17. O servidor não valida `origin`/`aim` do tiro
`_do_server_bullet` (`Player.gd:1332`) valida munição e arma, mas cria a
`DamageZone` exatamente no `origin` que o **cliente** mandou.

*Detectado:* leitura de código + mecanismo confirmado na sonda (as zonas
nasceram e acertaram onde o cliente pediu). **Não foi testada** uma distância
absurda — trate como mecanismo confirmado, não como exploit medido.

**Decisão pendente:** validar distância entre `origin` e a posição do corpo no
servidor (e recusar acima de um limite), ou aceitar como custo de precisão
cliente-lado?

### 18. `combat_mode` não replica — o saque remoto funciona por acidente
`Main.gd:119` replica só `position, net_velocity, net_facing, net_on_floor,
current_fruit_id`. Como `_buki_ativa()` (`Player.gd:1574`) lê o `combat_mode`
**da cópia local**, no servidor ele fica preso no default `"fruit"` para sempre.

Hoje isso **ajuda** (o saque é aceito), mas é acidente: um cliente em modo
`"style"` continua sendo aceito como se estivesse na fruta, e **se o default
mudar, todo saque remoto quebra em silêncio**.

*Detectado:* sonda de rede, 2026-08-12.

## 🔴 ~~Alta~~ — histórico

### 1. `suna_suna` X causa 142,4 de dano; todo o resto causa 3–10
`SandTornado` chama `take_damage(_dps * _tick)` **direto**, pulando o
`DamageZone.DAMAGE_SCALE = 0.12` que todas as outras fontes respeitam. São
50 × 0,4 = 20 por tique, 8 tiques em 3,2 s.

Antes isso só alcançava o boneco de treino (o tornado varria só o grupo
`"enemy"`); depois da correção de 2026-08-11 ele alcança **jogadores**, e o
desequilíbrio ficou exposto.

*Detectado:* medição de dano no `TrainingDummy`, comparando os 4 slots das 9
frutas. **Decisão pendente:** pôr na mesma escala (viraria ~17) ou manter como o
golpe pesado da Suna e ajustar por cadência/alcance.

### 2. Jogador preso no Black Hole toma dano; inimigo e dummy não
`TrainingDummy.gd:64` e `disabled/enemies/Enemy.gd:129` **recusam** dano quando
`in_black_hole` é verdadeiro. `Player.gd:1129` **não tem essa guarda**.

Ou seja, a mesma habilidade tem regra diferente dependendo de quem está preso.

*Detectado:* ao dar hitbox ao Black Hole, o dano não chegava no dummy — a
investigação revelou a imunidade nas entidades e a ausência dela no jogador.
**Decisão pendente:** o Black Hole é controle puro (aí falta a guarda no
`Player`) ou moedor (aí sobra a guarda nas entidades)?

### 3. Escombros do V da Yami só ferem o grupo `"enemy"`
A onda de repelão foi corrigida para atingir qualquer corpo com `take_damage`,
mas os `YamiBlock` que voam continuam varrendo só `"enemy"` no
`_physics_process` deles. Numa arena PvP, os escombros **atravessam outros
jogadores**.

*Detectado:* leitura do código durante o conserto da onda. **Decisão pendente:**
cada escombro vira uma `DamageZone` (15 áreas por conjuração — custo de física)
ou o laço passa a varrer `"player"` também?

---

## 🟡 Média — dívida que ainda não mordeu

### 4. `hurricane_kick` continua sem substituto
O clipe foi **apagado** (veio quebrado do Mixamo, sem curvas de membro). A
biblioteca tem 29 clipes e nenhum golpe usa esse nome. Para trazer de volta:
baixar de novo em mixamo.com e rodar `./tools/importar_animacao.sh`.

### 5. `gura_gura_alt` é um id órfão em `FruitPassiveSystem`
Aparece nas passivas e não corresponde a nenhuma fruta, árvore ou skill.

*Detectado:* cruzamento entre `FruitPassiveSystem` (21 passivas) e `SkillSystem`
(9 skills).

### 6. 12 frutas têm passiva e descrição prontas, e nenhum golpe
`pika_pika`, `magu_magu`, `ope_ope`, `hana_hana`, `ito_ito`, `zushi_zushi`,
`moku_moku`, `tori_tori_phoenix`, `neko_neko_leopard`, `hito_hito_nika`,
`uo_uo_seiryu`. Três delas têm árvore desenhada, hoje filtrada do mapa.

Não é bug — é o estoque a terminar, e a regra do dono é não criar fruta nova
antes disso.

### 7. O campo da Ice Age não tem dano por tique — só a entrada
Resolvido em parte: o campo **passou a causar dano** (30/s) em 2026-08-11. O que
segue em aberto é se o **congelamento repetido** (5 s congelado + 2 s de
imunidade, em ciclo) é o comportamento desejado numa rodada de 10 minutos.

---

## 🟢 Baixa — armadilhas conhecidas, documentadas

### 8. `Player.gd` com 1.531 linhas, 1,7× o limite
**Em tratamento.** A partição está em curso, em fases, por
[`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md): fase 1 (etapas nomeadas) e
fase 2 (`CameraRig`, 2.167 → 2.128), fase 3 (`PlayerRig`, → 1.959),
fase 4 (movimento, → 1.776) fase 5 (`BukiController`, → 1.689), fase 6 (habilidades, → 1.590) e
fase 7 (`MeleeController`, → 1.545) e fase 8 (`HealthController`, → 1.531)
feitas. Ver também
[`RELATORIO_PLAYER.md`](RELATORIO_PLAYER.md) e
[`LIMITE_DE_TAMANHO.md`](LIMITE_DE_TAMANHO.md). **Gatilho:** o arquivo não pode
crescer mais — qualquer tarefa que precise adicionar código nele deve primeiro
extrair um componente.

### 9. `YamiFX.gd` (811) e `ProceduralAnimator.gd` (762) perto do teto de 900
Não estouraram. Vigiar.

### 10. Os proxies do rig giram mas não transladam
No personagem skinnado, a arma nasce na pose de repouso do membro e acompanha a
**rotação**, não o deslocamento do osso. O caminho completo seria
`BoneAttachment3D` — que herda escala e espaço Z-up do esqueleto, então não é
troca trivial.

### 11. `IceFX` nunca levanta a mão do conjurador (condição impossível)
`src/effects/IceFX.gd:166` faz `caster.has_node("_char_model")`. `_char_model`
é **campo**, não nome de nó — `has_node` procura um filho chamado
`"_char_model"`, que não existe. A condição é sempre falsa, então o bloco
inteiro (o tween que levanta o braço direito no gelo) **nunca roda**.

O jeito certo, que o `BukiFX.gd:140` já usa, é `caster.get("_char_model")`.

*Detectado:* ao mapear quem lê o modelo de fora, antes da Fase 3 da partição.
**Não corrigido** — é mudança de comportamento visual (o golpe passaria a ter
uma animação que hoje não tem), então é decisão sua.

### 12. O impulso horizontal do GEPPO é código morto
No geppo (pulo duplo), quando há direção, o código faz:

```gdscript
vel.x = q.dir.x * vel_efetiva * 1.35   # impulso de 1,35x
vel.z = q.dir.z * vel_efetiva * 1.35
```

Só que **logo abaixo, no mesmo ramo**, a locomoção normal reescreve os dois:

```gdscript
velocity.x = q.dir.x * effective_speed   # sem o 1,35
velocity.z = q.dir.z * effective_speed
```

O `y` sobrevive (o pulo funciona), o impulso horizontal **nunca** chega a valer.
Se `dir` for zero o geppo nem entra nesse caminho — ou seja, o 1,35x é morto em
todos os casos.

*Detectado:* ao mover o parkour para o componente na Fase 4, comparando a ordem
de escrita na velocidade. **Não corrigido** — ligar o impulso muda o feel do
pulo duplo, e isso é decisão de design sua. O comportamento foi preservado
exatamente como estava.

### 13. `FireFXGrande` marca `set_meta("is_suppressed")` e ninguém lê
`src/effects/FireFXGrande.gd:185` faz `body.set_meta("is_suppressed", true)` e
`:234` desfaz. **Metadado não é o campo** — são coisas diferentes, e
`grep -rn 'get_meta("is_suppressed")'` no projeto inteiro não devolve nada.

**Não é bug de recurso:** a supressão real acontece na linha seguinte,
`body.suppress_skills_temporarily(0.25)`. As duas linhas de `set_meta` são
código morto que só confunde quem for ler.

*Detectado:* ao mapear o domínio de supressão para o passo 6d da partição,
2026-08-12. **Não corrigido** — apagar linha morta ainda é mexer num golpe que
funciona, e a regra é não alterar sem sua ordem.

### 14. `Melee.espelhar()` está sem uso
Ficou quando os socos viraram clipes autorais. Continua correta e validada.
**Gatilho para apagar:** se daqui a alguns golpes nenhum tiver usado, é dívida.

---

## O que NÃO está nesta lista

Nada testado **em rede com dois PCs de verdade** nem **visto na tela**. As
sondas `net_host_probe.gd` / `net_client_probe.gd` cobrem loopback headless; o
resto é olho humano jogando.
