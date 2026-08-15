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

## ✅ Resolvido em 2026-08-12 (noite)

### 24. Projétil rápido atravessava o alvo — **corrigido**
`DamageZone` andava por **teleporte** (`global_position += vel * delta`), e a
`Area3D` só enxerga quem está sobreposto **naquele quadro**. A 60 Hz, acima de
~79 m/s a bala pulava o alvo entre dois quadros. **A sniper estava em 95 e
perdia 1 tiro em 6.**

**Sub-passo de posição NÃO resolveria** — e essa foi a parte que quase me
enganou: a `Area3D` detecta uma vez por quadro de física, então mover em pedaços
dentro do mesmo quadro não gera detecção nova.

**Conserto:** `_varrer_caminho()` — um raio da posição anterior até a nova, todo
quadro. O que a bala passou por cima conta como acerto.

**Medido, com a bala mirada no boneco:**

| vel | passo/quadro | antes | depois |
|---|---|---|---|
| 95 | 1,58 m | 20/24 | **10/10** |
| 250 | 4,17 m | — | **10/10** |
| 400 | 6,67 m | — | **10/10** |

Só com isso a sniper pôde dobrar para **250 m/s** a pedido do dono — dobrar
antes teria entregado uma arma pior.

## 🔴 Alta — afeta o jogo hoje

### 25. A luneta da sniper esconde a HUD inteira
Conferido por print: com a luneta ligada, a máscara preta cobre **vida, energia,
cronômetro, placar e lista de skills**. O jogador fica cego para a própria vida
enquanto mira.

*Detectado:* print do jogo rodando, 2026-08-12. O agente pendurou o
`SniperScope` antes do `AmmoHud` justamente para o contador de munição
sobreviver — mas o resto da HUD tem outro pai, e a ordem de irmãos não a
protege.

**Decisão pendente:** é intencional (mirar cega, e isso é o preço da sniper), ou
a vida e o cronômetro devem continuar visíveis por cima da máscara?


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

### 6. 11 frutas têm passiva e descrição prontas, e nenhum golpe
`pika_pika`, `magu_magu`, `ope_ope`, `hana_hana`, `ito_ito`, `zushi_zushi`,
`moku_moku`, `tori_tori_phoenix`, `neko_neko_leopard`, `hito_hito_nika`,
`uo_uo_seiryu`. Três delas têm árvore desenhada, hoje filtrada do mapa.

Não é bug — é o estoque a terminar, e a regra do dono é não criar fruta nova
antes disso.

> **Número corrigido em 2026-08-14: eram "12", são 11.** A conta batia
> (21 passivas − 9 frutas com skill = 12), mas o 12º id é o órfão
> `gura_gura_alt`, que já é o **item 5** desta lista e não é fruta nenhuma. A
> lista de nomes aqui sempre teve 11 — o cabeçalho é que contava o órfão duas
> vezes. Reconferido por leitura de `FruitPassiveSystem` × `SkillSystem`.

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

### 28. `Melee.espelhar()` está sem uso
Ficou quando os socos viraram clipes autorais. Continua correta e validada.
**Gatilho para apagar:** se daqui a alguns golpes nenhum tiver usado, é dívida.

### 26. Projétil rápido pode empurrar o alvo PARA TRÁS (na direção do atirador)
`DamageZone._on_body` calcula o knockback como `alvo − centro da zona`. Isso
pressupõe que a zona está ATRÁS do alvo na hora do acerto — verdade para uma
explosão, nem sempre para uma bala.

Quem registra o acerto de um projétil rápido é o `_varrer_caminho`, e ele roda
**depois** do passo (`global_position += vel * delta`), no mesmo quadro. A 46 m/s
o passo é 0,77 m; a 95 m/s (sniper) é 1,58 m. Se o passo pular por cima do alvo,
no instante do cálculo a zona já está **na frente** dele — e o vetor
`alvo − zona` aponta de volta para o atirador. O alvo leva o dano correto e é
arremessado na direção errada.

*Detectado:* ao desenhar os tiros d'água do Karate Tritão (tarefa 7,
2026-08-13), lendo o `_varrer_caminho` para dimensionar a velocidade do
projétil. **Não corrigido** — o conserto é na `DamageZone`, que estava fora do
escopo daquela tarefa. O caminho seria usar a direção do próprio movimento
(`vel.normalized()`) quando a zona tem velocidade, e só cair no radial quando
ela está parada.

*Mitigação em vigor:* os tiros do Z saem com knockback baixo (6,0) de propósito,
então o erro de direção é quase invisível ali. A **sniper da Buki** (95 m/s, o
dobro do passo) é onde isso mais aparece.

### 27. A `DamageZone` não avisa quando acerta
Não há sinal de impacto: quem cria a zona não tem como saber se ela pegou
alguém, nem onde. Duas consequências já em produção:

* o respingo dos tiros d'água (`WaterFX._agendar_respingo`) é agendado por
  **tempo**, não por acerto — a água quebra no fim do alcance, tenha acertado ou
  não. Fica plausível para água; não ficaria para um impacto de metal.
* nenhum golpe consegue reagir ao acerto (marca no alvo, som de carne, combo).

*Detectado:* na mesma tarefa 7. **Não corrigido** — um `signal acertou(corpo,
ponto)` na `DamageZone` resolveria os dois, mas é mudança numa classe que 9
efeitos usam, e a regra é não alterar fora do escopo sem sua ordem.

---

---

## O que NÃO está nesta lista

Nada testado **em rede com dois PCs de verdade** nem **visto na tela**. As
sondas `net_host_probe.gd` / `net_client_probe.gd` cobrem loopback headless; o
resto é olho humano jogando.

### 29. Os outros QUATRO estilos também têm um golpe só disfarçado de quatro
O mesmo defeito que a tarefa 7 consertou no Karatê Tritão: `_cast_laser`,
`_cast_electro`, `_cast_boxe` e `_cast_cyborg` **recebem `variant` e não leem**.

*Detectado:* conferido por contagem — nos quatro, a palavra `variant` aparece
**uma vez só no arquivo inteiro, na assinatura**. Z, X, C e V de cada estilo
disparam efeito idêntico; o que muda é só o nome na HUD e o número de dano que o
`Player._fire_skill` lê da tabela.

Só o Tritão foi tratado porque só ele estava no pedido. **Pacifista, Mink, Boxe
e Cyborg continuam com quatro nomes e um golpe.**

**Decisão pendente:** tratar os quatro (é o mesmo trabalho da tarefa 7, quatro
vezes), ou deixar como está enquanto o Tritão é o estilo em uso?

### 30. `RECARGA_ESTILO` de 60 s não passa pelo servidor
A recarga de estilo é decidida **só no cliente**, pela `trigger_skill_cooldown`.
É exatamente a forma do buraco de **munição infinita da Buki** (item 14): cliente
adulterado que mande `_net_cast_req` direto ignora a recarga.

*Detectado:* revendo o item 14 depois de escrever a `RECARGA_ESTILO`. A Buki
ganhou carimbo de tempo no servidor (`_srv_recarga_ate`) justamente porque
`_skill_cooldowns` **não anda** na cópia do servidor — o `_physics_process` sai
cedo quando `_is_authority` é falso. O mesmo vale aqui.

**Peso menor que o item 14, e é por isso que não parei para consertar:** lá o
furo dava munição infinita numa arma de tiro rápido; aqui dá golpe de estilo mais
frequente. Mas é o **mesmo furo**, e ele cresce se o estilo virar a via principal
de combate.

**Decisão pendente:** estender o `_srv_recarga_ate` da Buki para todo cast (era
também o item 17, "o servidor não valida `origin`/`aim`"), ou aceitar enquanto o
jogo for entre amigos?

---

## 🆕 Achados de 2026-08-14 — leitura para a documentação das frutas

Os seis itens abaixo saíram de **leitura de código** durante a escrita de
[`frutas/`](frutas/README.md). Nenhum foi corrigido (a tarefa era de
documentação, e três dos arquivos envolvidos estavam sendo editados por outros
agentes na mesma hora). Nenhum foi reproduzido jogando, exceto onde dito.

### 31. `GuraShatterMesh` posiciona a rachadura ANTES de entrar na árvore
`src/effects/GuraShatterMesh.gd:50-51`:

```gdscript
mi.global_position = pos      # nó ainda SEM pai
parent.add_child(mi)          # só agora entra na árvore
```

Fora da árvore, `global_position` grava no transform **local**. Quando o nó
entra como filho, esse local se soma ao do pai — e nos três chamadores de
`GuraFX` o pai é a própria `DamageZone`, que já está em `pos`. Resultado: a teia
de rachaduras nasce em **~2×** a posição pretendida, cada vez mais longe quanto
mais longe da origem do mundo o golpe acontecer.

O único chamador correto é `GuraVNode.gd:80`, onde o pai é a cena (origem).

*Detectado:* leitura, 2026-08-14. **É exatamente a armadilha que a
`AUDITORIA_FRUTAS.md` já registrava** ("`global_position` escrito antes do
`add_child` fazia o efeito nascer em (0,0,0)") — a mesma família, com o sinal
trocado. Conserto: `add_child` primeiro, `global_position` depois.

### 32. O X da Gura Gura só funciona pelo caminho da carga
`GuraFX.cast` trata o parâmetro `dir` da variante 1 como **posição absoluta do
alvo** (`_shockwave(world, dir, …)`), e quem manda posição ali é o
`GuraChargeNode.soltar()`. Qualquer outro caminho para o slot X —
`cast_skill_slot("X")`, um `_net_cast` vindo de outro peer, uma sonda de teste —
manda uma **direção unitária**, e a onda de choque nasce a ~1 m de **(0,0,0)**.

O comentário na linha 13 do `GuraFX.gd` avisa que `dir` "carrega a posição
absoluta", mas nada **verifica** isso.

*Detectado:* leitura, 2026-08-14. **Decisão pendente:** passar posição e direção
em campos separados no pedido de cast, ou marcar o golpe como "só carregável"
e recusar os outros caminhos em voz alta?

### 33. Duas tabelas de recarga, e a do `SkillSystem` está morta E errada
`SkillSystem.get_fruit_skills()` normaliza `cooldown` para 5/7/10/**60** e
`SkillSystem.get_slot_cooldown()` devolve os mesmos números. A recarga que o
jogo aplica é `Player.RECARGA_POR_SLOT` = 5/7/10/**25**.

Conferido por grep: **nenhum arquivo lê o campo `cooldown`** do dicionário, e
`get_slot_cooldown` **não tem chamador**. Ou seja: é documentação embutida que
contradiz o código, no arquivo onde alguém naturalmente procuraria a resposta.

O item 14 desta lista já declarou `Player.RECARGA_POR_SLOT` como **fonte única**
("duas cópias do mesmo número escritas à mão foi como o furo nasceu") — a
segunda cópia continua lá.

*Detectado:* leitura, 2026-08-14. Conserto barato: apagar o campo e a função, ou
fazer o `SkillSystem` importar de `Player.RECARGA_POR_SLOT`.

### 34. `set_character()` escreve `current_fruit_id` sem passar pelo `equip_fruit`
`Player.gd:1003-1021` atribui a fruta direto por personagem (`ace` → `mera_mera`,
`buggy` → `bara_bara`, …). Por esse caminho **não** roda nada do que o
`equip_fruit` garante: a fruta não some da árvore, a anterior não volta ao mapa,
a passiva não é aplicada, a arma da Buki não é guardada e a escala da Gura não é
ligada nem desligada.

É a mesma classe de bug que a **tarefa 4** de 2026-08-12 consertou ("a fruta some
do mapa ao ser equipada por QUALQUER caminho"): aquela varreu três entradas e
esta é uma quarta, que ninguém tinha mapeado.

*Detectado:* leitura, 2026-08-14. **Não reproduzido** — hoje o elenco está
trancado em `base`/`bluebuddy`, então só o ramo `_` (que dá `gomu_gomu`) roda.
Vira bug de verdade no dia em que o elenco for liberado.

### 35. A investida e a captura da Gura escrevem a posição de OUTRO corpo
`Player.gd:1361` (investida do Z) e `cast_controller.gd:344` (captura do X)
gravam `global_position` do alvo, todo quadro, **no cliente do atacante**. A
posição de outro jogador é autoritária no cliente dele e chega pelo
`MultiplayerSynchronizer`; em PvP o agarrão pode ser desfeito pelo próprio dono
do corpo no quadro seguinte, ou "puxar" o adversário só na tela de quem atacou.

*Detectado:* leitura, 2026-08-14. **Não testado em rede** — trate como mecanismo
suspeito, não como bug medido. Contra bonecos e inimigos (sem autoridade
própria) funciona.

### 36. As passivas das frutas são texto: só `speed_mod` e `jump_mod` rodam
`FruitPassiveSystem` descreve 21 passivas com efeitos ricos — cargas de chama da
Mera, volt meter da Goro, cura por drenagem da Suna, esquiva por desmembramento
da Bara, regeneração da fênix, −40% de knockback da Gomu. **`equip_fruit` lê
dois campos e mais nada.**

Conferido por grep: nenhum outro arquivo chama `get_all_passives`, e a API de
instância da classe (`equip_fruit`, sinal `passive_triggered`, `charge_count`,
`volt_meter`) **não tem chamador nenhum**.

Caso à parte, e o mais enganoso: a "Supressão Abissal" da Yami Yami tem
implementação escrita — `SkillSystem.apply_yami_suppression()`, aura de 8 m — e
ela **também não tem chamador**. O silenciamento que existe no jogo vem dos
golpes (X silencia 4 s, V silencia 10 s), não da aura.

*Detectado:* leitura, 2026-08-14. **Não é bug de execução** — nada quebra. É
armadilha de leitura: a descrição existe, tem número, tem nome bonito, e um
balanceamento feito por cima dela estaria contando com efeitos que não rodam.

**Decisão pendente:** implementar as passivas, ou marcar as descrições como
"pretendido, não implementado" na própria tabela?

### 37. 💀 O soco da Gura SEQUESTRA o rig por ~7 s (e o agarrão dura 0,5 s)
`GuraFX._punch` toca o clipe assado a `0.4 / mult`. Com o `charge = 1.0` que a
própria investida do Z manda, `mult = 1,667` e a velocidade vira **0,240**.

O clipe `right_upper_hook_from_guard` tem **1,77 s** (medido em 2026-08-11, ver a
tabela no topo de `src/combat/Melee.gd`). A 0,240× ele fica **7,37 s em tela**.

E o `ProceduralAnimator.update()` faz, na linha 146:

    if _baked != null:
        _apply_baked(delta)
        return

ou seja, enquanto o clipe assado toca, **toda** a animação procedural morre —
locomoção, pulo, idle, tudo. O agarrão da investida dura **0,50 s**. Sobram
**6,87 segundos** com o jogador andando por aí congelado num gancho em câmera
lenta.

*Detectado:* pelo agente que fez a pose do Z, lendo o caminho da investida.
Números reconferidos à mão a partir do comprimento de clipe já documentado.

**Por que isso não apareceu antes:** o `_punch` só recebe `charge > 0` pelo
caminho da INVESTIDA, que é novo. Pelo caminho antigo `charge = 0` → `mult = 1`
→ velocidade 0,4 → 4,4 s. Ruim, mas menos visível.

### 38. O dano do soco da Gura sai ~1,2 s ANTES do golpe animado começar
Mesmo `_punch`: ele chama `play_baked(..., start = 0.0)`.

O comentário do próprio `play_baked` documenta que esse clipe tem **0,392 s de
guarda parada** na abertura (22% dele) e que o parâmetro `start` existe
justamente para pular isso — o `Melee` usa (`"inicio": 0.20`).

Com a velocidade de 0,240 do item 37, esses 0,392 s de clipe viram **1,63 s de
estátua** antes de o braço se mexer. A hitbox nasce em `0.25 * mult` = **0,417 s**.

O dano acontece **~1,2 s antes** de o soco animado começar. É a mesma classe de
erro que o `Melee` corrigiu em 2026-08-11 ("a hitbox saía na retração, não no
chute"), reaparecendo por um caminho novo que não herdou a lição.

**Os dois itens são o mesmo `_punch` e devem ser consertados juntos:** mexer só
na velocidade sem mexer no `start` troca um desencontro por outro.

### 39. 🔴🔴 O MODELO VOXEL TEM OS BRAÇOS E PERNAS TROCADOS DE NOME
Medido no `assets/models/base.scn`, no espaço local do modelo (frente = −Z,
logo direita = +X):

| nó | x local | lado REAL |
|---|---|---|
| `UpperArm_R` / `ForeArm_R` | **−0,375** | **esquerdo** |
| `UpperArm_L` / `ForeArm_L` | **+0,375** | **direito** |
| `Thigh_R` / `Foot_R` | **−0,125** | **esquerdo** |
| `Thigh_L` / `Foot_L` | **+0,125** | **direito** |

**O código está CERTO; o modelo é que está trocado.** `bake_mixamo.gd:51` assa
`mixamorig_RightArm` na faixa `UpperArm_R`, e `SkeletonDriver.gd:46` mapeia
`UpperArm_R` → `RightArm`. A convenção do projeto é `_R` = direita anatômica, e
ela vale em todo o resto.

**Consequência:** no personagem voxel, **as 29 animações do Mixamo tocam
espelhadas** — o movimento do braço direito sai no braço esquerdo. E toda pose
procedural de UM braço só sai no lado errado: `_finger_gun`, `_kurouzu_pose`,
`_black_hole_pose`, `_gura_x_charge_pose`, el_thor, os socos do combo, o ponto de
tiro do `GoroFXGrande._ponto_do_braco` e o do `WaterFX._ponto_da_mao`, e o
arsenal da Buki, que o `PlayerRig` pendura em `ForeArm_R`.

**Por que ficou tanto tempo invisível:** andar, correr e o combo de socos são
quase simétricos, e a T-pose do V abre os DOIS braços com sinais opostos — numa
pose simétrica a convenção de lado não tem como aparecer. O primeiro pedido que
nomeia um lado ("o braço DIREITO levantado", 2026-08-14) foi também o primeiro
capaz de detectar isto.

*Detectado:* por um agente verificador CEGO, que recebeu só o comportamento
esperado e nenhuma informação sobre o código. O agente que escreveu a pose mediu
o ângulo certo e não mediu QUAL BRAÇO — mediu o sinal que ele próprio escolheu.
Reconferido depois de forma independente, direto no `.scn`, sem a sonda dele.

**Decisão pendente — e ela é grande.** Duas saídas, e elas não são equivalentes:

1. **Consertar o `base.scn`** (trocar os nomes dos nós). Conserta as 29
   animações, todas as poses, todos os pontos de encaixe e os dois modelos do
   elenco de uma vez. Mas **inverte todo movimento assimétrico que hoje está em
   tela**, e as poses ajustadas à mão contra o modelo espelhado vão precisar de
   reconferência.
2. **Trocar só a pose do Z para `_L`.** Resolve o pedido de hoje em duas linhas
   e deixa o `bluebuddy` (rig skinnado, que NÃO é espelhado) com o braço errado —
   a mesma pose sairia em lados opostos nos dois personagens do elenco. Também
   cimenta a confusão: o código passaria a dizer `_L` para "direito".

A (2) é mais barata hoje e cobra juros todo mês. A (1) é o conserto de verdade.

### 40. `GuraFX._ring/_bubble/_debris` não recebem posição — a armadilha continua armada
As três criam o nó e **nunca definem posição**: ficam em (0,0,0) *local do pai*.
Se o chamador passa `world` como pai, o efeito nasce na **origem do mapa**.

Foi a causa principal de o V antigo "não fazer nada" — bolha, 200 detritos e 3
anéis apareciam no centro da arena enquanto o jogador estava noutro lugar.

O V novo **contorna** com um nó-âncora já posicionado (`GuraVNode._ancora()`), em
vez de mexer no `GuraFX`, que é compartilhado com Z, X e C. **A armadilha segue
armada para o próximo chamador.**

**Conserto sugerido:** dar um `pos: Vector3` às três. É o mesmo erro do item 21
(`FireFX.gd:200`, `look_at` antes do `add_child`) e do item 31 (a
`GuraShatterMesh`, esta já corrigida pelo V novo): **posicionar nó fora da
árvore**. Três ocorrências da mesma classe já é padrão, não coincidência.

### 41. Três `if` mortos com `Engine.has_singleton("ScreenShatterFX")`
Em `GuraFX._punch`, `_shockwave` e `_eruption`. `Engine.has_singleton()` só
enxerga singleton **nativo/GDExtension**; `ScreenShatterFX` é **autoload**
(`project.godot:21`), então a condição é sempre falsa.

**Inofensivos hoje** — cada um tem um `elif world.get_node_or_null("/root/ScreenShatterFX")`
logo abaixo que funciona. São 3 ramos mortos, não 3 efeitos quebrados. O agente
não os apagou para não arriscar três golpes numa tarefa que era do V; concordo.

Mesmo bloco morto em `src/player/cast_controller.gd:330`.

### 42. ⚠️ ARMADILHA DE GODOT 4 PARA TODA SONDA: objeto liberado compara IGUAL a `null`
Custou um ciclo ao agente do V. A sonda dele checava `no == null` para saber se
ainda estava procurando o nó do golpe. Quando a ultimate acabava e o nó era
liberado, a comparação voltava a dar verdadeiro, o laço voltava a "procurar", e a
sonda concluiu que **o golpe nunca tinha nascido** — logo depois de tê-lo
cronometrado.

**Regra:** toda sonda que espera um nó MORRER precisa de um booleano próprio
("já vi nascer"), nunca de `== null`. Use `is_instance_valid()` para validade, e
guarde o fato de ter encontrado numa variável à parte.

Vale para as sondas que já existem em `tools/dev_tests/` — nenhuma foi auditada
sob essa luz.

### 43. O `base.glb` — a ORIGEM do modelo — continua espelhado
O `base.scn` foi desespelhado em 2026-08-14 (item 39), mas a sonda
`tools/dev_tests/medir_lados.gd` mostra que o **`base.glb`** ainda tem os lados
trocados:

```
== base.scn ==   10 ok, 0 trocados
== base.glb ==   UpperArm_L x=+0.3750  TROCADO
                 UpperArm_R x=-0.3750  TROCADO
```

**Quem reimportar o GLB traz o problema de volta**, e desta vez sem o aviso — o
`base.scn` passaria a discordar da própria origem.

*Detectado:* rodando a sonda de lado depois da cirurgia de rig, por hábito de
conferir os dois modelos.

**Decisão pendente:** consertar o `.glb` na origem (Blender), ou documentar que o
`.scn` é a fonte de verdade e o `.glb` é histórico? A segunda é mais barata e
mais frágil.

### 44. A paralisia da `DamageZone` ainda não anima
`RecepcaoDeDano.paralisar_com_animacao()` existe e foi medida (prende, anima e
solta), mas a `DamageZone` continua no caminho antigo: `set_meta("is_frozen")` +
`StatusFX` na mão, sem pose.

Resultado: o X da Goro paralisa **sem** animação de recepção, enquanto uma
chamada direta anima. Duas paralisias com aparências diferentes.

*Detectado:* ao escrever `docs/MECANICAS.md` e comparar os dois caminhos.

**Não consertei porque** trocar isso mexe no comportamento de um golpe que o dono
aprovou jogando, e a regra é não alterar sem ordem. É uma linha.

### 45. 🔴 `test_arena` REPROVA — o `AutoDummy` faz dois dummies onde o teste espera um
A bateria caiu de 25/25 para **24/25**. A checagem que falha é
`test_arena.gd:81` — `dummies == 1`, "o dummy de treino continua (saco de
pancadas)".

**Causa:** `src/entities/AutoDummy.gd` faz `extends TrainingDummy`, então herda o
`add_to_group("dummy")` da linha 26 do pai. E `Main.gd:85` passou a criar o
`AutoDummy` além do `TrainingDummy`. São **dois** no grupo.

*Detectado:* bateria de 2026-08-14, depois do trabalho de mecânicas. **A causa
NÃO é o trabalho de mecânicas** — nada nele toca em spawn de dummy; o
`AutoDummy` e a linha do `Main.gd` vieram de outra sessão trabalhando no mesmo
repositório em paralelo.

**Decisão pendente, e ela é de quem escreveu o `AutoDummy`:**

1. o `AutoDummy` **não deveria** estar no grupo `dummy` (ele é um inimigo ativo,
   não um saco de pancadas) — nesse caso o conserto é no `AutoDummy`, e o teste
   está certo;
2. ou passaram a existir **dois sacos de pancadas de propósito** — nesse caso o
   teste é que precisa ser atualizado, e a asserção vira `dummies >= 1`.

**Não escolhi por conta própria** porque as duas mexem em intenção de design de
outra pessoa: a (1) muda o comportamento do inimigo novo, a (2) afrouxa um teste
que existe para pegar exatamente esse tipo de spawn acidental (a seção se chama
"inimigos fora do mapa").
