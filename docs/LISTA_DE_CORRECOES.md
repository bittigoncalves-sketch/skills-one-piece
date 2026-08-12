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

---

## 🔴 Alta — afeta o jogo hoje

### 14. MUNIÇÃO INFINITA na Buki Buki: o saque não olha a recarga
`Player.gd:1641` (`_do_server_buki_sacar`) reenche `_srv_buki_municao` até o
pente cheio **sem consultar `_skill_cooldowns`**. A recarga do slot é decidida
**só no cliente**, em `_buki_empunhar` (`Player.gd:1598`).

Ou seja: quem manda `_net_buki_sacar_req` direto pula a única penalidade da
fruta. A munição *é* o balanceamento da Buki — e hoje ela é opcional para quem
trapaceia.

*Detectado:* sonda de rede de dois processos (`net_buki_host_probe.gd` /
`net_buki_client_probe.gd`), 2026-08-12. **Medido:** com a recarga local de Z
quente (5,0s → 2,8s → 0,5s), repetindo o pedido de saque, o pente autoritativo
voltou **9 → 12 duas vezes**, rendendo **6 zonas de dano onde o jogador honesto
teria 3**.

**Decisão pendente:** o servidor passa a manter o próprio relógio de recarga por
slot (o certo, mas é estado novo no lado autoritativo), ou basta o
`_do_server_buki_sacar` recusar quando o slot estiver quente na cópia dele?

### 15. O servidor não valida `origin`/`aim` do tiro
`_do_server_bullet` (`Player.gd:1332`) valida munição e arma, mas cria a
`DamageZone` exatamente no `origin` que o **cliente** mandou.

*Detectado:* leitura de código + mecanismo confirmado na sonda (as zonas
nasceram e acertaram onde o cliente pediu). **Não foi testada** uma distância
absurda — trate como mecanismo confirmado, não como exploit medido.

**Decisão pendente:** validar distância entre `origin` e a posição do corpo no
servidor (e recusar acima de um limite), ou aceitar como custo de precisão
cliente-lado?

### 16. `combat_mode` não replica — o saque remoto funciona por acidente
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

### 8. `Player.gd` com 1.689 linhas, 1,9× o limite
**Em tratamento.** A partição está em curso, em fases, por
[`ARQUITETURA_PLAYER.md`](ARQUITETURA_PLAYER.md): fase 1 (etapas nomeadas) e
fase 2 (`CameraRig`, 2.167 → 2.128), fase 3 (`PlayerRig`, → 1.959),
fase 4 (movimento, → 1.776) e fase 5 (`BukiController`, → 1.689) feitas. Ver também
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

### 13. `Melee.espelhar()` está sem uso
Ficou quando os socos viraram clipes autorais. Continua correta e validada.
**Gatilho para apagar:** se daqui a alguns golpes nenhum tiver usado, é dívida.

---

## O que NÃO está nesta lista

Nada testado **em rede com dois PCs de verdade** nem **visto na tela**. As
sondas `net_host_probe.gd` / `net_client_probe.gd` cobrem loopback headless; o
resto é olho humano jogando.
