# Lista de correções pendentes

Coisas **encontradas e NÃO corrigidas**, esperando decisão do dono do projeto.
Nada aqui foi alterado.

Ordem: gravidade decrescente. Cada item diz **como foi detectado** — sem isso a
lista vira palpite.

---

## 2026-10-17 — Besta bovina: teste da sequência de ataques

`test_ataques_agua_bestas.gd` terminou com 39/40 verificações: a bovina ficou em
`idle`, agressiva, junto ao jogador, sem alternar as cinco bolhas e o raio (0
disparos). Reproduzido com o novo `BarrasDeCriaturas` ativo e, numa cópia do teste,
removido antes das verificações da IA; ambos 39/40, mesma asserção. As outras três
espécies passaram. Logs em `art_src/validation/vida_forja/logs/`. Causa da IA ainda
não investigada; nenhuma alteração nos ataques nesta frente.

## 2026-10-15 — Portão geral: arena sem dummy e editor de animação

Detectado por `DISPLAY= WAYLAND_DISPLAY= ./validar.sh rapido`, durante sobrevivência/tripulação. Seis testes de arena também falham no HEAD `9301956` sob preferências idênticas: `test_arena`, `test_asas_de_anjo`, `test_ataque_aereo`, `test_ataques_contextuais`, `test_bomu_z_rush`, `test_chute_giratorio`. Os testes dependem de boneco de treino, mas a preferência salva o deixa ausente. Logs A/B: `art_src/validation/sobrevivencia/logs/base_head/`. Pendência: isolar explicitamente os pré-requisitos das sondas sem alterar preferências do jogador.

`test_compila` também reprova seis scripts não versionados de `tools/anim_editor/studio`: `rig_scene.gd`, `main.gd`, `timeline.gd`, `test_selection.gd`, `test_studio.gd`, `view.gd`. Referências `res://document.gd` e semelhantes apontam à raiz do jogo, onde faltam. Observação sem A/B: não há snapshot anterior desses arquivos. Nenhuma edição no studio nesta frente. Pendência: definir se é projeto Godot independente ou módulo e ajustar os caminhos na frente correspondente.

Exceção de entrega autorizada pelo Claude por delegação do usuário, sem mudar o portão geral. Antes da próxima grande frente, versionar o estado atual para permitir comparação completa. O texto “25 testes” em `docs/guia/COMO_TRABALHAR.md:66` está desatualizado; gatilho para corrigi-lo: portão novamente com zero falhas.


## ⚔️ O corte horizontal ainda reprova 3 asserções (era 9)

**O que se vê.** `test_corte_horizontal` reprova 3 de 22: a mão esquerda larga o
cabo no meio do golpe (pior caso 0,84 m, contra um piso de rig de ~0,15 m), o fio
não fica deitado (37,4° onde 90° é horizontal) e o tronco gira só 42,2° em vez de
rodar em bloco.

**O que JÁ FOI consertado, e por quê valia a pena.** Em 10/09/2026 o mesmo teste
reprovava **9** asserções com a espada CONGELADA nos 16 quadros do corte. A causa
era o `YoruController` aplicando a pose parada por cima do golpe: `Melee` +
`ProceduralAnimator` cortam sem passar por ele, então `action_id` fica vazio, e
como o controlador roda com prioridade 50 — depois do Player — era ele quem
escrevia por último. A guarda nova tornou isso visível (subiu para 11, com a
espada presa em x=+0,78 / z=+1,53, que é a própria guarda) e levou ao conserto:
`YoruController._golpe_procedural_em_curso()` cede o corpo enquanto o caminho
antigo estiver cortando. De 11 para 3.

**⚠️ CORREÇÃO DE UM REGISTRO ANTERIOR DESTA MESMA LISTA.** A versão anterior deste
item concluía que a causa estava "em alguma das outras mudanças não commitadas".
A apuração por worktree estava certa no que mediu — o teste passa 22/22 no HEAD,
e passava com os sete arquivos da frente Yoru copiados por cima — mas a conclusão
que tirei dela era larga demais: faltava o `YoruRig.gd` e o `Player.gd` da árvore
suja nessa cópia, e era justamente na interação entre eles que o conflito vivia.
Worktree prova o que roda nela, não o que NÃO foi copiado para dentro.

**As 3 que sobram** são do caminho procedural antigo (`WeaponPoses`, `Melee`,
`ProceduralAnimator`), e não da Yoru nova: o `YoruController` não participa mais
do golpe quando esse caminho está ativo.

---

## 🎨 Os "Vagalumes de Fogo" da Mera Mera saem ARCO-ÍRIS

**Detectado em 2026-08-25**, ao ligar o glow: com brilho, o problema deixou de
ser sutil — os vagalumes brilham em ciano, magenta, verde e azul.

`FirefliesFX.gd`, no `_process` de cada vagalume:

```gdscript
# Trocar cores em RGB constantemente
var c = Color.from_hsv(fmod(time_passed * 0.5, 1.0), 1.0, 1.0)
```

Isso percorre a **roda de matiz inteira**. O golpe se chama "Vagalumes de
**Fogo**" e pertence à **Mera Mera**, cuja paleta é laranja/amarelo/vermelho.

**Não foi corrigido** porque é decisão de arte do dono, não defeito técnico: se
o arco-íris for intencional (leitura de "energia", não de fogo), a linha está
certa. Se não for, a correção é trocar a faixa de matiz por uma janela quente
(ex.: 0,00–0,12) e manter o ciclo.

⚠️ E vale notar: cada conjuração cria **10 `RigidBody3D`** com caixa e colisão.
Para um efeito visual isso é caro; medido no `_diag` da sessão.

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

---

## 🆕 Achados de 2026-08-26 — auditoria de documentação

Os itens abaixo saíram de **leitura de código** durante o levantamento do que
faltava documentar (`docs/MOVIMENTO.md`, `docs/RODADA_E_PLACAR.md`,
`docs/NUMEROS_MEDIDOS.md`, `docs/ESTILOS_DE_LUTA.md`). Nenhum foi corrigido: a
tarefa era de auditoria, e a regra do [`AGENTES.md`](AGENTES.md) é *"agente de
auditoria não altera arquivo do projeto"*. Nenhum foi reproduzido jogando.

### 46. ✅ RESOLVIDO em 2026-08-26 — `MoveFrame.ler()` imprimia A CADA QUADRO DE FÍSICA

> Corrigido pelo orquestrador na mesma sessão em que a auditoria o achou: era
> uma linha, e o ruído dela poluía o log de TODO teste desta base (é o
> `MoveFrame: ativo=...` que aparecia em toda saída). Território de ninguém, sem
> risco de conflito com os agentes em obra.

`src/player/move_frame.gd:70`:

```gdscript
print("MoveFrame: ativo=", ativo, " f=", f, " r=", r, " dir=", dir)
```

`ler()` é chamada uma vez por quadro em `Player._etapa_locomocao`
(`Player.gd:1025`), ou seja **~60 linhas por segundo por jogador com autoridade**.
Numa partida cheia o console vira ruído e o log de qualquer sonda fica ilegível.

*Detectado:* lendo `move_frame.gd` inteiro para escrever `docs/MOVIMENTO.md`. É
resto de depuração do bug de WASD — o relatório dessa correção está em
`src/player/wasd_bug_report.md`, e o `print` claramente vem dela.

**Não corrigi porque** auditoria não edita código. É **uma linha para apagar**, e
é o item mais barato desta lista.

⚠️ Vale conferir de carona os `print` de gameplay em
`src/player/health_controller.gd:152/170/173` (disparam a cada knockback) — a
mesma classe de ruído, custo menor.

### 47. O cabeçalho do `Scoreboard` diz "rodada de 10 minutos"; o código diz 5
`src/match/Scoreboard.gd:7` promete *"Rodada de 10 minutos"*. Vinte linhas
abaixo, `src/match/Scoreboard.gd:27` define `const ROUND_TIME := 300.0`, com o
comentário certo (*"5 minutos de rodada (pedido do dono, 2026-08-12 — era 600)"*).

O arquivo se contradiz em vinte linhas, e o cabeçalho é a parte que se lê
primeiro.

*Detectado:* conferindo `ROUND_TIME` contra os docs ao escrever
`docs/RODADA_E_PLACAR.md`. O erro **vazou para a documentação**:
`docs/GUIA_DO_PROJETO.md:79`, `docs/guia/ONDE_COLOCAR.md:80` e o item 7 desta
lista (linha 331) também dizem 10 min — e no item 7 o número é **argumento de
balanceamento**, então a conclusão muda com ele.

**Não corrigi porque** é código. Os três de `docs/` estão listados no §6 de
`docs/RODADA_E_PLACAR.md` para quem for passar o pente.

### 48. O comentário do teto de velocidade da sniper ficou para trás em dois pontos
`src/effects/BukiFX.gd:49-58` diz:

- *"`vel` da sniper (95 -> 125 em 2026-08-13)"* — o valor na linha 60 é **250,0**;
- *"Enquanto a `DamageZone` não andar em sub-passos, subir daqui é trocar
  consistência por velocidade"* — a `DamageZone` **passou a varrer o caminho com
  um raio** (`_varrer_caminho`), que é exatamente o remédio que o comentário
  pedia.

O comentário continua carregando a melhor medição do projeto (24 disparos por
velocidade, 79→24/24 até 200→9/24) e **ao mesmo tempo** desaconselha uma mudança
que já foi feita. Quem ler só o comentário conclui que a sniper está quebrada.

*Detectado:* montando a tabela de números medidos para `docs/NUMEROS_MEDIDOS.md`
e batendo o número citado contra o valor do `ARSENAL`.

**Não corrigi porque** é código **e** porque a `DamageZone` está sendo editada por
outro agente em 2026-08-26 — reescrever este comentário exige saber onde o
`_varrer_caminho` vai parar. Reavaliar quando aquele trabalho fechar.

### 49. `Scoreboard.scores` nunca esquece quem saiu, e o pódio conta o que não mostra
Dois comportamentos pequenos do mesmo arquivo, os dois por ausência de guarda:

1. **`scores` não é limpo na desconexão.** Um peer que sai continua no dicionário
   e no `ranking()` até a rodada virar. Se ele estava na frente, o pódio premia um
   jogador que não está mais na partida.
2. **Durante o pódio, `_watch_falls` continua rodando.** Passados os 2 s de
   `_dead_until`, uma morte nos 8 s de pódio **ainda incrementa `scores`** — mas o
   `podium_snapshot` já foi tirado (o painel não muda) e `_start_new_round()` zera
   tudo em seguida. O resultado certo sai por **acidente da ordem**, não por uma
   guarda.

*Detectado:* seguindo os dois caminhos de morte para escrever o §3 de
`docs/RODADA_E_PLACAR.md`.

**Não corrigi porque** é código, e porque (1) é decisão de design de partida —
"quem sai perde o lugar" ou "o placar é da rodada, não dos presentes" é escolha do
dono, não do auditor. O (2) hoje não tem sintoma visível; vira sintoma no dia em
que o pódio deixar de zerar a rodada.

### 50. `Balance.gd` diz `hits` 8 no V da Yami e declara 6 — e o golpe não alcança o próprio teto
`src/combat/Balance.gd:162` abre com *"O `hits` de 8 é quantos escombros precisam
acertar para o golpe chegar ao teto"*. Doze linhas abaixo, a linha 173 declara
`"hits": 6`.

O parágrafo ⚠️ do meio (2026-08-22, quando a `reserva` da onda entrou) está
**certo** e fecha a conta: *"6 blocos de 96 + onda de 128 = 704"*. Só a frase de
abertura ficou com o número velho.

E 704 **não é** o teto do slot V, que é **768**. Ou seja: pelas partes declaradas,
o Liberation não chega ao próprio teto nem acertando tudo — sobram 64. Pode ser
intencional (a Mera declara `teto` próprio de 640 justamente para ficar abaixo do
slot), mas aqui **não há `teto` declarado**, então o golpe herda 768 e nunca o
usa. As duas leituras são plausíveis, e é por isso que isto é decisão e não
conserto.

⚠️ Isto se soma ao defeito que a página da fruta já registra
(`docs/frutas/yami_yami.md:143-150`): `YamiFX.gd:946` ainda faz
`damage = maxf(d * 0.25, 12.0)`, então cada escombro entrega **24** e não 96. Os
dois juntos significam que **nenhum número declarado do V da Yami é o número que
sai**.

*Detectado:* conferindo as tabelas das páginas por fruta contra o `Balance.gd`
durante a auditoria de documentação de 2026-08-26.

**Não corrigi porque** é código, e porque a escolha entre "apagar o `× 0,25`" e
"baixar a tabela" é de balanceamento — pertence a quem joga a fruta. `test_balance.gd`
não pega nenhum dos dois: ele valida a tabela contra a faixa do slot, não os
arquivos de efeito contra a tabela.

---

## 🆕 Achados de 2026-09-06 — trabalho de colisão e som da Pika Pika

Os defeitos de colisão que eu **corrigi** estão em [`erros.md`](erros.md) e na
página da fruta. O que segue é o que achei e **não** mexi.

### 51. 🟡 A Pika Pika não tem árvore no mapa (deixou de ser urgente em 2026-09-08)

> **Atualização de 2026-09-08:** a `FRUTA_INICIAL` passou para a `ope_ope`, que
> **tem** árvore. Ninguém mais nasce com a Pika, então o buraco deixou de ser
> "a fruta de largada não volta". O fato permanece: a Pika continua sendo a
> única fruta jogável que não dá para pegar no mapa. O `test_frutas_somem`, que
> falhava por causa disso, **passou a passar**.

O texto original:

**Detectado em 2026-09-06**, cruzando `SkillSystem.gd` com
`TreeAndFruitGenerator._todas_as_definicoes()`:

```
com skill mas SEM árvore: ['pika_pika']
com árvore mas SEM skill: ['hito_hito_nika', 'tori_tori_phoenix']
```

O filtro do `get_tree_definitions()` planta o que tem skill **e** arte de árvore
autorada. A Pika tem os quatro golpes, é `Player.FRUTA_INICIAL`, e não tem a
arte — então **não existe pé de Pika Pika em lugar nenhum do mapa**.

Consequência prática: quem trocar de fruta durante a partida **não consegue a
Pika de volta**. É a única fruta jogável nessa situação.

**Não foi corrigido** porque é decisão de design, não defeito: pode ser
deliberado que a fruta de largada seja exclusiva do início. Se não for, a
correção é uma entrada de árvore em `_todas_as_definicoes()` — o filtro a planta
sozinho depois disso.

### 52. 🔴 `traco_esperado.txt` está defasado — e agora dá para consertar de vez

> **Atualização de 2026-09-08 — a explicação anterior estava errada, e o
> defeito é maior do que se pensava.**
>
> O texto abaixo culpava a passiva da `suke_suke` (`4,2 × 1,05 = 4,41`).
> Medido: **a `suke_suke` tem `speed_mod` 1,0**, não 1,05
> ([FruitPassiveSystem.gd:49](../FruitPassiveSystem.gd#L49)). Ela nunca poderia
> produzir os 4,41 gravados. A arqueologia do commit que gravou a linha de base
> (`cdc3b44`, 12/08) mostra o que de fato aconteceu:
>
> - `FRUTA_INICIAL` **não existia** naquele commit; quem equipava era o
>   `Main.gd:114`, com **`suna_suna`** — `speed_mod` **1,05**. Daí, e só daí,
>   os `4,2 × 1,05 = 4,410 m/s` que o arquivo registra em 179 quadros.
>
> **E há uma segunda causa, independente da fruta.** A fórmula da velocidade
> mudou depois da gravação:
>
> ```gdscript
> # 12/08 (cdc3b44):  SPEED * speed_multiplier * (1.5 se sprint) * parkour
> # hoje:             SPEED * speed_multiplier * (1.5 se sprint) * impulso_corrida * parkour
> ```
>
> O `impulso_corrida` é o `RunAccelerationController`, que **rampa de 1,0 a 2,0
> ao longo de 3 s de corrida**. A linha de base é anterior a esse sistema: os
> 90 quadros gravados em 6,615 m/s (o patamar de corrida) hoje aceleram. Ou
> seja, **a física mudou de propósito** desde 12/08 — a linha de base não é só
> "de outra fruta", é de outro motor de locomoção.
>
> A comparação é `diff -q`, **byte a byte, tolerância zero**
> ([validar.sh:340](../../validar.sh#L340)) — qualquer uma das duas causas
> sozinha já reprova o arquivo inteiro.
>
> **Regravar agora é o melhor momento**, por um motivo que continua valendo: com
> a `ope_ope` (`speed_mod` 1,0) o traço anda a **4,2000 m/s**, o `SPEED` cru,
> sem multiplicador de fruta nenhum — a única linha de base que se pode
> re-derivar sem saber qual fruta estava equipada. **Continua sendo decisão do
> dono**, porque regravar redefine o que a bateria considera correto, e apaga a
> rede de segurança de tudo que mudou entre 12/08 e hoje.
>
> **O diagnóstico foi feito (2026-09-08).** Regravei o traço com a fruta da
> gravação original (`suna_suna`) e comparei com o arquivo de 12/08:
>
> | | resultado |
> |---|---|
> | quadros com velocidade idêntica | **393 de 491** |
> | primeiro quadro divergente | **76** — exatamente onde o roteiro começa a correr |
> | caminhada (quadros 1–75) | **byte a byte idêntica**, 4,4100 m/s |
>
> A caminhada inteira bate. A divergência começa no primeiro quadro de corrida e
> **rampa**:
>
> | quadro | gravado | atual | fator |
> |---|---|---|---|
> | 75 | 4,4100 | 4,4100 | 1,0000 |
> | 76 | 6,6150 | 6,6518 | 1,0056 |
> | 85 | 6,6150 | 6,9825 | 1,0556 |
> | 95 | 6,6150 | 7,3500 | 1,1111 |
> | 105 | 6,6150 | 7,7175 | 1,1667 |
>
> O fator cresce **0,3333 por segundo** (medido: 0,1611 em 29 quadros a 60 Hz).
> O `RunAccelerationController` declara `(MULTIPLICADOR_MAXIMO 2,0 − 1,0) /
> TEMPO_PARA_MAXIMO 3,0` = **0,3333 por segundo**. Bate na quarta casa.
>
> **Veredito: não há regressão escondida.** As 98 divergências são inteiramente
> a aceleração de corrida — um sistema adicionado de propósito depois da
> gravação — e as posições a jusante que ela desloca em cascata. Regravar a
> linha de base **não enterra bug nenhum**; só passa a registrar a física que o
> jogo de fato tem hoje. **Continua sendo decisão do dono**, e agora é uma
> decisão informada.

O texto original:

**Detectado em 2026-09-06**: o `traco_locomocao` reprova no `validar.sh`, e a
causa não é física.

A caminhada em regime traça **5,25 m/s** contra os **4,41 m/s** gravados. A
conta fecha exata:

| | conta | resultado |
|---|---|---|
| esperado (gravado) | `SPEED 4,2 × 1,05` (passiva da `suke_suke`) | **4,41** |
| atual | `SPEED 4,2 × 1,25` (passiva da `pika_pika`) | **5,25** |

A linha de base foi gravada quando `Player.FRUTA_INICIAL` era `suke_suke`; ela
virou `pika_pika` em 2026-09-04 ([Player.gd:94](../Player.gd#L94)) e o traço
nunca foi regravado. As 113 linhas divergentes vêm todas daí: com o personagem
mais rápido, a sequência de comandos roteirizada chega a outras posições nos
mesmos quadros, então dash, salto e contato com o chão caem em quadros
diferentes — divergência em cascata a partir de uma única causa.

**Não foi regravado** porque regravar a linha de base é decidir o que a bateria
considera correto. Se a Pika continua sendo a fruta inicial, o traço precisa ser
refeito; se a fruta inicial ainda vai mudar, refazer agora é trabalho perdido.

### 53. O Z da Pika alcança 98 de um teto de 200

**Detectado em 2026-09-06** pelo `test_balance`, que reprova a tabela:

```
❌ pika_pika/Z: total alcançável 98, menos de 85% do teto 200
```

`Balance.FRUTAS.pika_pika.Z` é `MULTI 7 × 14 = 98`, e o teto canônico do slot Z
é 200. O comentário na própria tabela diz que o 14 por raio foi decisão do dono
por vizinhança (Mera Z tira 25 num acerto só, Buki Z faz 12 × 16), não leitura
de vídeo — então a tabela pode estar certa e o **critério dos 85%** é que não se
aplica a uma salva que raramente conecta inteira.

**Não foi corrigido**: mexer aqui é mexer em equilíbrio, e o número é do dono.
As duas saídas são subir o dano por raio para ~24 (7 × 24 = 168, dentro dos 85%)
ou declarar a exceção no teste. Vale notar que a correção de colisão desta data
faz a salva **conectar mais vezes do que antes** — o dano por acerto não mudou,
mas o dano que realmente chega ao alvo subiu.

### 54. 🔴 A espada é LOCAL: em multiplayer o servidor resolve SOCO

**Detectado em 2026-09-06**, na revisão.

> ⚠️ **CORRIGIDO EM 2026-09-08: a premissa original deste item estava errada.**
> Ele afirmava que as propriedades replicadas eram só `net_velocity`,
> `net_facing`, `net_on_floor`, `net_charge_pose` e `net_charge_progress`. A
> lista real (`Main.gd:288`) é maior:
>
> ```
> position, net_velocity, net_facing, net_on_floor, net_charge_pose,
> net_charge_progress, current_fruit_id, combat_mode, current_style_idx
> ```
>
> **`combat_mode` JÁ replica.** O buraco não é o dado — é o **efeito**: o
> `MultiplayerSynchronizer` faz escrita crua da propriedade, então a cópia remota
> nunca passa por `set_combat_mode()` e o efeito colateral que saca a espada
> nunca roda lá. `equipped_weapon`, esse sim, não replica.
>
> Isso muda o conserto: replicar `equipped_weapon` sozinho não basta, e replicar
> `combat_mode` de novo seria trabalho inútil. O que falta é o caminho que
> **executa o saque** na cópia remota.
>
> Verificado com host e cliente reais na etapa 0 do
> [`PLANO_YORU.md`](PLANO_YORU.md); evidência em
> `multimodal/cache/yoru-validation/rede_medicoes.txt`.

O que continua verdadeiro:

- **`equipped_weapon` não está entre as propriedades replicadas**;
- `sacar_ou_guardar_espada()` e `set_combat_mode()` não têm RPC nenhum.

E a auditoria de 2026-09-08 acrescentou **cinco falhas reproduzidas** que este
item não previa, todas em `_do_server_melee` (`Player.gd:3467`), que são cinco
linhas **sem validação nenhuma** — nem índice, nem estado, nem recarga, nem
sequência:

| | falha | evidência medida |
|---|---|---|
| R4 | mensagem repetida **duplica dano** | 2× `_net_melee(0)` no mesmo quadro = −96,0 |
| R5 | golpe cancelado **ressuscita** | `cancelar_golpe()` aos 0,05 s e a hitbox nasce assim mesmo |
| R6 | **índice de golpe não é validado** | 5× no mesmo quadro = **−560,0 de uma vida de 2048 num tick** |
| R7 | trocar de modo no startup | vira `BOX 4,00 × 1,00 × 3,75 m` com dano de espada |

O caminho contextual (`_do_server_contextual_melee`) já tem `sequencia` e RPC de
cancelamento — serve de modelo para o M1 básico.

Consequências em partida com mais de um jogador:

1. **Os outros não veem a Yoru.** Você aparece golpeando de mãos vazias.
2. **O servidor resolve o golpe errado.** `_do_server_melee` roda na cópia
   remota, onde `equipped_weapon == ""` e `_yoru == null` — então
   `Melee.golpear` cai em `COMBO` (punho) em vez de `COMBO_SWORD`. Dano 48 em
   vez de 64, frame data de 0,40 s em vez de 0,76 s, e uma caixa na frente do
   peito em vez das bolinhas do fio.
3. **A animação também diverge**: `_net_play_melee` nos outros peers toca o
   clipe de punho, não o corte procedural.

**Como isso passou:** a espada nasceu como tecla de DEBUG (a pedido, para não
mexer no spawn do mapa) e virou o **modo 3** de combate depois. A rede nunca foi
revisitada quando o escopo mudou.

**Não foi corrigido** porque é decisão de escopo: replicar arma é acrescentar
estado à rede e mexer no caminho autoritativo do combate. As duas saídas são
replicar `equipped_weapon` + o saque (e fazer o servidor montar a lâmina na
cópia remota), ou declarar a espada como recurso de treino local até haver um
plano de arma em rede.

### 55. 🔵 Dois desenhos de conferência continuam LIGADOS

**Detectado em 2026-09-06.** São temporários e pedidos pelo dono, mas ficam na
tela de quem jogar:

| constante | o que desenha |
|---|---|
| `PikaFXGrande.C_MOSTRAR_HITBOX` | a pirâmide de dano do C da Pika, em **vermelho** |
| `SwordBlade.MOSTRAR_ZONAS` | as sete bolinhas do fio da Yoru, em **azul** |

Virar as duas para `false` quando a conferência terminar.

### 56. ✅ RESOLVIDO — o botão de PULO cobria a zona de câmera com a Ope equipada

**Detectado em 2026-09-08**, ao tornar a `ope_ope` a fruta inicial; **já
corrigido no mesmo dia**, na frente da Ope. Fica registrado porque documenta um
acoplamento fácil de reintroduzir.

**O que era.** A `SkillBar` sobe quando a Ope está equipada, para não ficar por
baixo do painel de treino. Só que o `ToqueHud` deriva **toda** a régua de botões
do retângulo dessa barra — então a régua inteira subia junto, ~94 px. Medido na
época: o PULO ia de `(1000, 422)` para `(1000, 328)`, e o toque de câmera do
`test_toque`, em `(0,8 × largura, 0,5 × altura)` = **(1024, 360)**, caía a
**40 px** do centro do PULO, dentro do raio de 50. Arrastar no meio-direita da
tela para olhar em volta apertava pular.

**A correção** ([src/ui/SkillBar.gd:211](../src/ui/SkillBar.gd#L211)) condiciona
a subida ao contexto, em vez de amarrá-la só à fruta:

```gdscript
var bottom := -108.0 if _ope_equipped and not ToqueHud.ativo() else -14.0
```

No PC a barra sobe e reserva o painel de treino; no toque conserva a régua
original.

**Verificado:** `test_toque` fecha em **25 conferem / 0 divergem** com a
`ope_ope` equipada, na bateria completa e isolado.

**O que continua valendo como risco.** A causa de fundo não é a Ope: é o
`ToqueHud` posicionar botões a partir do retângulo da `SkillBar`. Qualquer
mudança de tamanho ou posição da barra move a régua de toque junto. Foi o mesmo
mecanismo que mordeu em 2026-09-06, quando encurtar um *rótulo* do HUD estreitou
a barra e encostou dois botões (ver `docs/erros.md`). **GATILHO para desacoplar:
na terceira vez que um ajuste de HUD mexer na posição de um botão de toque.**

### 57. 🟡 A explosão do Hiken pode não criar hitbox quando o punho expira

**Achado em 2026-09-08**, de raspão, ao trocar o visual da Mera. **Não foi
corrigido: mexe em hitbox, e o trabalho autorizado era visual.**

**A evidência.** No `test_frutas`, com a `mera_mera`:

```
ERROR: Parent node is busy setting up children, `add_child()` failed.
ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()
   at: get_global_transform
       [0] _explosion (res://src/effects/FireFXGrande.gd:286)
       [1] <anonymous lambda> (res://src/effects/FireFX.gd:314)
```

A linha 286 é `zone.global_position = pos + Vector3.UP * 1.0`. Ela só reclama
porque o `world.add_child(zone)` da linha anterior **falhou** — e falhou porque
o pai estava bloqueado. A lambda de `FireFX.gd:314` é o `explode` do Hiken, que
está ligado a **dois** gatilhos: `collided_with_any` e `tree_exiting`.

**Confirmado na rodada limpa de 2026-09-08:** contando pelo quadro `[0]` do
backtrace, a chamada que falha é literalmente o `world.add_child(zone)` da
`FireFXGrande.gd:285` — uma ocorrência por execução da fruta. O erro de
`get_global_transform` na linha seguinte é consequência, não causa.

**A hipótese.** Quando o `explode` corre pelo `tree_exiting` — o punho acabando
o tempo de vida sem acertar ninguém —, o pai está no meio da saída da árvore e
recusa filhos novos. A `DamageZone` da explosão não nasce, e os **96 de dano**
que o `Balance` reserva para a parte `"explosao"` não são entregues.

**⚠️ NÃO CONFIRMADO EM JOGO.** A pilha acima é do teste, e no teste o
`tree_exiting` também dispara no desmonte do cenário — o que produziria o mesmo
erro por um motivo que não acontece jogando. **Antes de mexer, medir:** soltar
um Hiken no vazio, deixar expirar por tempo, e contar se nasce `DamageZone` no
fim do trajeto.

**Se confirmar, o conserto já existe ao lado.** A fachada visual da Mera passou
a anexar com `add_child.call_deferred()` exatamente por causa deste bloqueio
(ver `MeraVfx._anexar`); o mesmo remédio serve para a zona — com o cuidado de
que uma hitbox um quadro atrasada é decisão de jogo, não de desenho.


---

### 58. 🟡 `test_bara_combat`: o canhão (C) não dá dano em área fora da trajetória

**Achado em 2026-09-14**, rodando `./validar.sh rapido` para validar o Modo História.
**Não foi corrigido: é da Bara, fora do escopo.**

**A evidência.** Falha 2 de 2 rodando sozinho: `FAIL C causa dano em área fora da
trajetória central` (`checks=30 failures=1`). O teste põe o boneco 2 m ao lado e
16 m à frente, atira o C levemente para baixo e espera 2,5 s: a vida continua 2048.

**Não é do Modo História.** Com as travas de capacidade e o geppo do parkour desfeitos
à mão (cópia dos arquivos, só as linhas próprias revertidas), a falha é idêntica. O
teste não estava na lista de 13/09, e o `erros.md` registra trabalho do Codex na Bara
nesta mesma manhã (`BaraPoses.gd`). **Começar por aí.**

---

## 🆕 Achados de 2026-09-16 — auditoria para o combate do Modo História

Levantados por leitura de código (não reproduzidos em jogo) durante o planejamento
de [`PLANO_COMBATE_HISTORIA.md`](PLANO_COMBATE_HISTORIA.md). **Nenhum foi corrigido:
são da arena, e o novo combate da história não usa esses caminhos.**

### 59. 🔴 A hitbox do M1 de punho não pode ser cancelada

`Melee.golpear` agenda a hitbox com `create_timer(startup * s)`, e o callback só confere
se `caster` e `world` ainda são válidos (`Melee.gd:660-663`). Nem
`MeleeController.cancelar_golpe` nem o estado `Stunned` alcançam esse timer.
**Consequência esperada:** um golpe interrompido no startup (apanhou, morreu, trocou
de modo) ainda cria a `DamageZone`. O contextual já resolve com token de sequência
(`contextual_melee.gd:351-356`). **Antes de mexer, medir:** atacar, aplicar hitstun
no atacante antes de 0,20 s e contar se nasce zona.

### 60. 🟠 Hit stop global a cada acerto no servidor

`DamageZone._on_body` chama `GameFlow.hit_stop()` a cada corpo atingido
(`DamageZone.gd:331-333`), e ele põe `Engine.time_scale = 0,06` por 0,05 s reais
(`GameFlow.gd:270-275`). No host de uma partida isso desacelera a simulação **de
todos**; nos clientes não aparece. Não empilha (sai se `time_scale < 1`).

### 61. 🟡 O tremor de câmera do M1 sai com golpe cancelado ou errado

O tranco é agendado por `SceneTreeTimer` no clique (`melee_controller.gd:216-220`) e
dispara no fim do startup mesmo se o golpe foi cancelado ou não acertou nada.

### 62. 🟡 Dois buffers de clique para o mesmo M1

`Player._input_buffer` guarda até 10 cliques por 400 ms (`Player.gd:192-213`) e o
`MeleeController` tem outro de 0,18 s. Um clique de até 400 ms atrás pode virar golpe
quando a FSM volta a Idle — o próprio controlador diz que "clique de 1 s atrás não é
intenção de agora".

### 63. 🟡 Corpo remoto com knockback sai de `take_damage` antes de morrer

No servidor, para vítima de outro peer com knockback > 0,1, `take_damage` envia
`net_apply_knockback` e dá `return` (`Player.gd:2393-2397`) antes do
`if morreu: die_and_respawn()` (:2405-2406), que é a **única** chamada de
`die_and_respawn` no `Player.gd`. `net_vida_do_servidor` só atualiza a vida no dono,
sem tratar a morte. **NÃO CONFIRMADO em partida** — pode haver outro caminho de
eliminação (placar/rodada) que cubra isso; medir com dois processos antes de mexer.

### 64. 🟡 "Civil: clique esquerdo não ataca" passa sem medir nada em headless

`test_modo_historia` (`_tecla_mouse`) atribui `Input.mouse_mode = CAPTURED` e entrega o
clique ao `_unhandled_input`. **Medido em 16/09/2026:** em `--headless` o `mouse_mode`
continua `VISIBLE` depois da atribuição (sonda de 3 linhas). O clique cai no ramo de
recaptura do mouse (`Player.gd`, topo do `_unhandled_input`) e sai **antes** de chegar
ao `_request_melee` — o teste passaria mesmo sem trava nenhuma. O controle positivo da
mesma seção usa `_request_melee()` direto, não o clique. **Conserto sugerido:** julgar o
clique só quando a captura pegar (o `test_combate_historia` já faz assim e roda o trecho
com tela) ou mover o trecho para o bloco com tela do `validar.sh`.

## O painel de treino cobre a barra de técnicas — vale para quase toda fruta

**Achado em 2026-09-12**, ao dar ícones próprios à Goro Goro. Não é regressão:
é anterior, só não aparecia porque quase nenhuma fruta tinha o que mostrar ali.

**Sintoma.** O painel de bonecos (`[x] Boneco de treino F1` / `Boneco automático
F2`), ancorado no canto inferior direito, passa por cima dos slots **C** e **V**
da `SkillBar`. Na captura da Goro antes do conserto, "Shunshin (Teleporte Raio)"
e "Mamaragan (Tempestade)" aparecem cortados ao meio pelo painel.

**Causa.** `SkillBar._atualizar_posicao_ope()` eleva a barra em 108 px para
reservar esse espaço, mas só quando `_ope_equipped or _sword_equipped`. A flag
nasceu específica da Ope, na época a única fruta com arte na barra — o nome da
função ainda registra isso.

**O que foi feito agora:** a Goro entrou na condição, porque ganhou os quatro
ícones nesta passagem e o painel comia metade da barra dela.

**O que ficou aberto — decisão do dono.** Todas as **outras** frutas continuam
cobertas: Gomu (que também tem ícones), Mera, Gura, Bara, Buki, Pika, Yami, Hie,
Suna, Bomu. Três saídas:

1. **Elevar sempre** — a barra sobe para qualquer fruta. Mais simples e
   consistente; muda o enquadramento de todo mundo.
2. **Elevar quando há ícone** (`ICONES_POR_FRUTA.has(fruit_id)`) — cobre Ope,
   Gomu e Goro hoje, e cada fruta nova entra sozinha ao ganhar arte.
3. **Mover o painel de treino** em vez da barra — ele é ferramenta de
   depuração, e talvez seja ele que devesse ceder espaço.

⚠️ **No toque a régua é outra:** `ToqueHud.ativo()` já impede a elevação, porque
subir a barra empurraria o botão PULO para dentro da zona de câmera. Qualquer
uma das três saídas precisa preservar isso.

---

## Auditoria Bara Bara para Buggy — 2026-09-12

Achados anteriores à integração visual, **sem alterações no kit nesta tarefa**. Evidência e funções em [BOSS_BUGGY_IMPLEMENTATION_PLAN.md](BOSS_BUGGY_IMPLEMENTATION_PLAN.md), seção 9, e [BOSS_BUGGY_COMBAT_DESIGN.md](BOSS_BUGGY_COMBAT_DESIGN.md), seções 2–4.

- `BaraFX.BaraCleaveController._process`: duração é checada antes do tick e o acumulador perde sobra. Simulação aritmética da ordem indica quatro ticks a 120 FPS versus cinco a 30/60; ainda requer reprodução instrumentada do controlador na engine.
- `BaraDomainController`: altera cores do WorldEnvironment sem restauração, acessa câmera sem guarda para ausência e seleciona alvos por distância sem oclusão. Confirmado por inspeção; não alegar teste de servidor dedicado.
- C/V aplicam `CombatResolver` diretamente, contornando o crédito `Scoreboard.register_hit` de `DamageZone`; revisar atribuição de impactos antes de recompensas.
- `_net_spawn_single_slash` aceita `any_peer` sem validação interna: limitar eventos visuais à autoridade. O dano já permanece no servidor.
- Z/X não marcam `is_projectile`; X adiciona 2,2 m à origem e a explosão é somente visual. São comportamentos observados; adequação de origem/explosão exige decisão e medição, não correção automática.
- `Engine.has_singleton("ScreenFX")` consulta singleton nativo; o ScreenFX deste jogo é autoload. Os flashes desses ramos precisam usar a referência correta na futura migração.
- `FightingStyles._cast_boxe` ignora `variant`, gerando o mesmo projétil nos quatro slots. Não tratar esse código como os quatro golpes de boxe prontos.

A passiva Bara apenas declarada já está registrada nesta lista e não foi duplicada. Não corrigir esses itens incidentalmente durante importação de modelo.

## 🆕 Achados de 2026-09-21 — pés do boneco de duelo crescendo

### 65. 🟡 `YoruRig` escreve `global_basis` com escala do global — mesmo padrão que fez os pés crescerem

**Como foi detectado:** ao corrigir os pés do boneco "Ataca" do Modo História, que cresciam a cada
golpe (causa e medidas em [`erros.md`](erros.md), 21/09). O `AplicadorDePose` escrevia
`global_basis = R * from_scale(global_basis.get_scale())` e `pai.global_basis = Basis(Quaternion(de, para)) * pai.global_basis`;
com o pai levemente fora de escala uniforme, o cisalhamento virava escala LOCAL e o animador
(que só escreve `rotation`) a guardava. No aplicador o pé explodia; os braços, com o segundo padrão,
derivavam devagar (antebraço 0,997/1,002 em 20 s de golpes).

O `src/anim/YoruRig.gd` tem as duas formas: `wrist.global_basis = wrist_basis.scaled(s)` (~linha 369)
e `parent.global_basis = Basis(Quaternion(from, to)) * parent.global_basis` (~linha 388). **Não
reproduzido**: é leitura de código. **Não corrigido**: é arquivo da frente da espada (agentes `yoru-*`).

**Antes de mexer, medir:** Yoru equipada fazendo M1 em ciclo por 30 s, lendo `scale` local de
`UpperArm/ForeArm/Wrist/Hand` dos dois lados (sonda igual à seção G do `test_contato_historia`).
Se derivar, a correção provada é a do aplicador: escrever só rotação local
(`AplicadorDePose._girar_global`), nunca a escala.


## Achados da validação de barcos e cavalo — 04/10/2026

Fonte: `art_src/validation/navios/regressao_geral.log`, execução de `./validar.sh rapido` (120 passou / 16 falhou / 5 pulado). A expectativa antiga de dois pets no teste de doma foi atualizada para comparar inventário antes/depois; reexecução passou, conforme `pomar_final.log`.

Ocorrências adicionais às nove falhas já registradas na base de nado/montaria:

- `test_clipes_parkour`: `sprinting_forward_roll`, interpolação de 38,7° entre chaves do `UpperArm_L` em 0,117 s. Detectado pelo teste de 32 clipes; animações de parkour não foram alteradas nesta correção. Investigar o recurso do clipe em tarefa própria.
- `test_frutas_na_historia`: excedeu 120 s, log avançava pelos ataques das frutas e chegou a Suna/Sables. Timeout não comprova defeito do golpe; antes de corrigir código, medir a duração necessária da bateria específica de frutas.
- `test_sala_publica`: não abriu porta UPnP nem descobriu endereço público/ID de sala.
- `test_lan_discovery`: não encontrou host; `net_mp_probe` e `net_dano_probe`: corpos dos peers não apareceram. Os testes offline de campanha passaram. Reproduzir em ambiente com rede local disponível antes de concluir que há regressão; não alterados rede, roteador ou regras de conexão.

As nove falhas anteriores (balance, bara_combat, compila/studio, corte_horizontal, ilha_inicial, mera_z_saque, ope_animacoes, studio_playback, trava_fruta_dano) continuam fora do escopo desta correção. Evidência comparativa: `art_src/validation/nado_montaria/regressao.log`. Não foram corrigidas incidentalmente.

## Achado da bateria de 06/10/2026 (noite) — Buki Buki × vaca, intermitente

### 66. 🟡 `test_frutas_acertam_npcs`: X e C da Buki Buki às vezes não ferem a vaca

- **Sintoma:** na bateria completa de 06/10 (noite) falhou "golpe que machuca um NPC machuca os três (faltando: buki_buki/X→animal)".
- **Medição:** só com a Buki (`SOP_FRUTAS=buki_buki`), 6 de 7 rodadas passaram; a que falhou errou X **e** C no animal (dano 0), com inimigo e boneco feridos normalmente.
- **Depuração:** com `SOP_DEPURAR=1`, quando o golpe erra, a vaca está viva, parada (`estado=0`), na camada 1, visível, nos grupos `animais` e `alvo_de_golpe`, na raia (40, 0, −4).
- **Fora de escopo:** nenhuma mudança desta sessão toca frutas da arena ou animais (Noro, loja de projéteis, corrida de caranguejos). Mais cedo no mesmo dia a auditoria tinha passado com 0 lacunas. Não corrigido por conta (regra 7).
- **Próximo passo:** gravar o traço da forma do X da Buki (posição e alcance da hitbox × centro da vaca) numa rodada que falhe.

## Achado do Skills Builder em 07/10/2026 — clipes Mixamo com o tronco inclinado de lado

### 67. ✅ Corpo a corpo (`play_baked`) usa clipes cujo tronco foi bakeado inclinado de lado

- **Resolvido pela causa (07/10/2026, noite):** a inclinação vinha do baker, que convertia as rotações no espaço do esqueleto do .glb (girado 90° em X). Os 61 clipes foram reassados na conversão v3, e o M1 recebe os clipes certos pelo mesmo `play_baked`. A correção paliativa do Builder (`endireitar`) saiu. Detalhes em `docs/ANIMACOES_MIXAMO.md` e `docs/erros.md`.

- **Achado:** relato do dono sobre o Builder ("todas viram o personagem meio de lado, a única correta é a investida"). Medido em `assets/animations/*.res`: a inclinação LATERAL média do tronco, que é a RAIZ do corpo no rig, é `idle` 34°, `punching` 44°, `kicking` 46°, `bouncing_fight_idle` 51°, `roundhouse_kick` 73°, contra −3° e 8° em `running` e `sprint` (os clipes da marcha). Alguns (`idle_4`, `idle_5`, os de cobertura) ficavam quase de cabeça para baixo (~170°).
- **No Builder:** corrigido (`ClipesDeSkill.endireitar`: tira a inclinação lateral média, menos nos clipes que giram o corpo de propósito), igual na prévia, no jogador e na cópia remota. Medido em `test_animacoes_do_builder`, com fotos.
- **Fora de escopo (regra 7):** o combo M1 toca esses mesmos `.res` por `ProceduralAnimator.play_baked` (o `MeleePoses` sobrepõe pernas e braços, mas o tronco vem do clipe). Não foi conferido se o M1 aparece tombado e nada foi mudado nele.
- **Próximo passo:** foto do M1 (soco e chute) de frente; se tombar, aplicar a mesma correção do tronco em `_apply_baked`, ou refazer o bake desses clipes (`tools/bake_mixamo.gd`) tirando a orientação do quadril.

### 68. 🟡 Personagens skinnados (Meshy) têm o zero do braço em pose A, não pendurado

- **Achado (07/10/2026, ao reassar os clipes):** os clipes, as poses procedurais, as MeleePoses e as do Builder partem do zero do rig voxel, com o braço pendurado (Base aberto 19°, Buggy reto). O `SkeletonDriver` aplica a rotação do papel como delta sobre o repouso do PRÓPRIO esqueleto. Medido o repouso do braço esquerdo em relação à vertical: `ace` ~48°, `nami` ~20°, `blackbeard` ~33°, `crocodile` ~50°. Nesses personagens, todo clipe e toda pose saem com o braço aberto por essa diferença.
- **Fora de escopo (regra 7):** já existia antes do rebake e não muda com ele.
- **Próximo passo:** no `SkeletonDriver`, compor um alinhamento por osso (do pendurado canônico até o repouso do modelo) entre o delta e o `rest_global`, e medir os 4 Meshy contra o Base num mesmo clipe.

### 69. 🟡 Bestas: ataques de água (outra frente, 08/10 11:14–11:19) deixaram dois testes vermelhos

- **Achado (08/10/2026, na bateria dos bandidos):** outra frente pôs bolhas em leque e o raio "compressor" nas pacíficas. Mudou `besta_do_mar.gd`, `perfis.json` (alcance 10 → 35 m) e criou `test_ataques_agua_bestas.gd`. Ela parou às 11:19 e não atualizou o checkpoint.
- **`test_ataques_agua_bestas`, 39/40.** A bovina "dispara 0" por causa do CENÁRIO do teste, não do jogo. O teste põe a besta em (0, 0, 0), onde o jogador nasce: a besta pisa na cápsula do jogador e, quando o teste teleporta o jogador, o `CharacterBody3D` a leva junto, como faz numa plataforma móvel (medido: a besta salta para o XZ exato do jogador, em um quadro, com velocidade 0; a pilha do salto é só física). A distância fica 0, a "alinhada" fica indefinida e ela nunca atira. Correção sugerida no teste: tirar o jogador de baixo antes de soltar a física da besta, ou pôr a besta longe do nascimento.
- **`test_comportamento_bestas_mar`, 61/64** (era 64/64 depois da postura de foca, às 10:55). "Revide usa run e alcança ataque" espera `atacando`; com o ataque à distância é `disparando_ataque`. "Afastamento acalma" e "volta à rotina" foram calibrados com alcance 10 m.
- **Fora de escopo:** é trabalho em andamento da outra frente; nada foi mexido.


## Achados de 08/10/2026 — Ilha dos Macacos

### 70. 🟡 O píer `dock_long` aparece sem as tábuas (só postes e cordas), no porto e na Ilha dos Macacos

- **Achado:** nas fotos `art_src/validation/ilha_dos_macacos/09_pier_de_perto.png` e `10_pier_do_porto_de_perto.png`, os dois píeres mostram postes e cordas sobre a água, sem deck.
- **Hipótese (não medida):** `gerar_ilha.gd` (`_porto`) põe o deck a +0,6 m supondo que ele fica a `t.y − 2,14` = 5,66 m da base do modelo, a altura do `dock_long_no_rope`. Se as tábuas do modelo estiverem mais baixas, ficam embaixo d'água. A leitura dos vértices no headless voltou zerada, então a altura real das tábuas não foi conferida.
- **Fora de escopo:** já era assim no porto. O píer dos macacos copia a altura do porto de propósito.
- **Próximo passo:** medir a altura das tábuas do `dock_long.glb` (Blender ou Godot com GPU) e corrigir `topo_deck` em `gerar_ilha.gd` e `gerar_ilha_dos_macacos.gd`.

### 71. 🟡 `SkillsPublicadas.atribuidas` lê `mapas/skills/frutas.json` como se fosse skill (um aviso por bandido)

- **Sintoma:** ao abrir o Modo História aparecem 6 avisos "[SkillsPublicadas] res://mapas/skills/frutas.json inválida: Formato de skill inválido...", um por bandido que nasce (`NinhoDeInimigo._nascer` → `UsuarioDeSkills.ligar` → `atribuidas`).
- **Causa:** `atribuidas` pula só o `ARQUIVO_DO_KIT`; o catálogo de frutas (`ARQUIVO_DE_FRUTAS`, criado em 07/10) fica na mesma pasta e não é pulado.
- **Efeito:** só o aviso, nenhuma skill a menos.
- **Fora de escopo:** visto no teste da Ilha dos Macacos; o código é da frente do Skills Builder.
- **Próximo passo:** pular também `ARQUIVO_DE_FRUTAS` (uma linha) e conferir se outro `Dados.listar(pasta())` lê a pasta inteira.

### 72. 🟡 O contorno do estilo desenha faixas pretas grossas sobre o mar

- **Achado (08/10/2026):** nas fotos do mar aberto (`art_src/validation/ilha_dos_macacos/lod_*_mar_*.png`) aparecem faixas pretas longas sobre a água, a algumas dezenas de metros da câmera.
- **Já existia:** a foto `art_src/validation/agua/02_boiando.png`, de 01/10, mostra as mesmas faixas. Não vem do fundo do mar por ilha.
- **Hipótese (não medida):** o `Contorno` (pós-processo do `WorldEnv`) acha bordas na profundidade, e o oceano transparente deixa passar a profundidade do fundo do mar e das ondas.
- **Fora de escopo:** é estilo e água, não a ilha nova.
- **Próximo passo:** conferir no `Contorno` se dá para ignorar o oceano (máscara ou profundidade da superfície) e comparar com fotos antes e depois.



## Detectado em 13/10/2026 — regressão durante machado/bicicleta

- Atualizar a expectativa antiga do Z em `test_hie_builder.gd`: mede a sequência
  estendida (1,72 s), mas espera 0,7 s totais, anterior à decisão de 10/10.
  Não alterado nesta tarefa. `test_hie_z_imunidade` passou.
- Bateria rápida parcial reprovou em saída da água pela praia, testes de arena
  com AutoDummy desativado, tabela Pika Z e sequência da besta bovina, entre outros.
  Não investigados/corrigidos por estarem fora do pedido; evidência em
  `art_src/validation/machado_bicicleta/regressao_rapida.log`.
- `test_compila` mantém os seis erros já documentados do projeto separado
  `tools/anim_editor/studio`. Detalhes no checkpoint desta tarefa.


## Reobservado em 14/10/2026 — validação da fênix

- A regressão geral parcial voltou a acusar arena sem dummy, saída da água,
  Pika Z, bestas e os seis scripts do editor de animação, já citados em 13/10.
  41 testes passaram / 12 reprovaram antes da interrupção; não houve correção
  fora do modelo da fênix. Evidência em
  `art_src/validation/phoenix_referencia_2026-10-14/regressao_rapida.log`.
- O aviso de `mapas/skills/frutas.json` reapareceu na captura do mapa real
  (item 71 já registrado); não impediu transformação ou voo.
- O verificador do índice apontou a referência antiga ausente
  `historia/equipamentos/bicicleta_de_gelo.gd` em
  `docs/contexto/agentes/historia.md`. Fora desta reconstrução; conferir o
  caminho atual antes de atualizar o contexto (log indice.log da fênix).

### 73. 🟡 `test_modo_historia` reprova "o Civil não tem Akuma no Mi" desde o Estilo de Combate Base
- **Achado (14/10/2026, na E2 do mar — `docs/MAR_HISTORIA_PLANO.md`):** 89 ✅ e 1 ❌. O Civil
  nasce com o item "Luta" na mão e, com Z/X do estilo base publicados no Builder,
  `ProgressaoDoPersonagem.fruta_a_equipar()` devolve `KitDoBuilder.ID_ESTILO_BASE`
  (`src/historia/progressao.gd:434`, mudado às 09:09 de 14/10 por outra frente) — o
  `current_fruit_id` deixa de ser "".
- **Não é do mar:** o mar não toca fruta, progressão nem kit.
- **Próximo passo:** o dono decidir se a checagem passa a aceitar o estilo base como "kit
  da Luta" (não é Akuma no Mi) ou se o estilo base deve usar outro campo que não
  `current_fruit_id`.

### 74. 🟡 `progressao.gd` passou do teto de 900 linhas (gatilho de 10/10 vencido)
- **Achado (14/10/2026, E4 do mar):** 901 linhas antes da E4; o gatilho anotado em
  `docs/PEDIDO_2026-10-10_HISTORIA.md` era "perto de 880, tirar ilhas/missões/barcos para
  arquivo próprio". A E4 somou 21 linhas (922) com um ponto GENÉRICO de estado por sistema
  (`sistemas`, `dados_de`, `gravar_dados`) para que sistemas novos não precisem de campo
  próprio aqui.
- **Próximo passo:** extrair ilhas, missões e barcos (e migrar barcos para `sistemas`) numa
  sessão sem outra frente mexendo na progressão — o arquivo foi alterado por outra frente
  em 14/10 às 09:09.

### 75. 🟡 `cel.gdshader`: luz omni/spot vaza o piso de sombra para fora do alcance (blocos)
- **Achado (14/10/2026, E3 do mar):** no `light()`, `ATTENUATION` entra como TETO
  (`min(luz, mix(sombra_min, 1, som))`). Para o sol ela é só sombra; para omni/spot ela
  carrega a DISTÂNCIA — fora do alcance o teto fica em `sombra_min` e a luz soma
  `sombra_min × cor` em toda a área de tela que o Forward+ atribuiu a ela: aparecem
  QUADRADOS iluminados (foto `art_src/validation/mar/naufragio_e3_naufragio_3_bau.png`,
  com a `LuzSubaquatica` de 32 m e piso 0,5 no fundo do mar).
- **Corrigido só no include novo** (`src/fx/shaders/luz_cel.gdshaderinc`: `LIGHT_IS_DIRECTIONAL`
  → teto; senão `luz *= ATTENUATION`). O `cel.gdshader` tem a mesma conta com piso 0,16.
- **Próximo passo:** o gatilho anotado no include — o `cel.gdshader` passar a incluir o
  `luz_cel.gdshaderinc` — corrige o resto do mundo. Conferir com captura antes/depois perto
  de tochas e mergulhando.

### 76. 🟡 `test_arena` depende das configurações REAIS do jogador (boneco de treino)
- **Achado (14/10/2026, bateria rápida da frente do mar):** 2 falhas — "o dummy de treino
  continua" e "jogador e boneco de treino na árvore". O `GameFlow` lê
  `user://settings.cfg` (`dummy_TrainingDummy`), e no computador do dono está `false` (boneco
  desligado no menu). Não é regressão de código.
- **Próximo passo:** o teste ligar o boneco antes (`GameFlow.set_dummy("TrainingDummy", true)`)
  ou rodar com dados de usuário isolados.
