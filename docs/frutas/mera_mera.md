# Mera Mera no Mi — fogo

**Id:** `mera_mera` · **Tipo:** Logia · **Passiva declarada:** Combustão
Progressiva — só `speed_mod 1,15` está implementado (as "cargas de chama" da
descrição não existem no código; ver o README da pasta).

Personagem associado: equipar troca a aparência para **`ace`**, se o id estiver
em `Player.ELENCO_LIBERADO` (hoje não está — o elenco está travado em `base` e
`bluebuddy`, então a troca não acontece).

> ⚠️ **Esta fruta foi REESTRUTURADA em 2026-08-21** (commits `59e5a48` e
> `91f0929`), depois da reescrita do dano. **O C e o V não são mais os mesmos
> golpes**: o C virou os *Vagalumes de Fogo* (golpe novo) e o **Entei mudou do
> slot C para o V**. O *Inferno*, que era o V, **não existe mais no código** — e
> o *Hibashira*, que já tinha saído do C antes disso, continua no arquivo como
> função sem chamador. Quem lembrar da fruta antiga vai lembrar errado.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/FireFX.gd` | o despacho dos 4 slots, o Z (`_higan`), o X (`_hiken`), a bala de fogo (`bullet`) e o modelo do sol |
| `src/effects/FirefliesFX.gd` | o **C** inteiro: a nuvem de vagalumes, a deriva e a reação em cadeia |
| `src/effects/FireFXGrande.gd` | o **V** (`EnteiSunController`), a explosão final do Hiken e o Hibashira legado |
| `src/player/disparo_sustentado.gd` | a **rajada** do Z (compartilhada com a Hie Hie) |
| `src/player/cast_controller.gd` | o portão da carga do V (`CARREGAVEIS`) e o `MeraChargeNode` |
| `src/combat/Balance.gd` | **todo o dano** dos quatro slots (a tabela única, desde 2026-08-21) |

O despacho é por **variante** em `FireFX.cast`: `0 = Z`, `1 = X`, `2 = C`,
qualquer outra `= V`. `src/effects/BurnStatus.gd` **não é da Mera** — hoje só o
Red Hawk da Gomu Gomu o instancia.

---

## O que cada tecla faz, hoje

| tecla | golpe | tabela | o que acontece |
|---|---|---|---|
| **Z** | Tiros de Pistola de Fogo (Higan) | MULTI **12 × 16** · teto 200 | rajada de balas de fogo enquanto a tecla estiver segurada |
| **X** | Hiken (Punho de Fogo) | ÚNICO **160** · teto 256 | punho voxel que voa e explode no fim do trajeto |
| **C** | **Vagalumes de Fogo** | ÚNICO **256** · teto 384 | nuvem de 45 vagalumes; um só ser tocado detona todos em cadeia |
| **V** | **Dai Enkai: Entei (Sol Quadrado)** | CARREGADO **512 → 768** em 3,5 s · teto 768 | segura para criar o sol sobre a cabeça, solta para dispará-lo |

Os números saem de `src/combat/Balance.gd` e são **finais** — é o que a barra de
vida perde. Ver a seção "Dano" do [README da pasta](README.md).

### Z — Higan: RAJADA, não um golpe

O Z da Mera (e da Hie) não passa pelo cast normal: `CastController.comecar()`
liga `DisparoSustentado.iniciar_rajada()` no **pressionar** e a rajada corre
sozinha até a tecla soltar, a energia acabar ou o pente terminar.

| | valor |
|---|---|
| cadência | `INTERVALO = 0,09 s` |
| pente | `MAX_BALAS = 16` por rajada |
| bala (`FireFX.bullet`) | dano **12** · kb 9 · `fwd × 55` m/s · vida 0,7 s · raio 0,35 |

**A rajada inteira é UMA conjuração.** As 16 balas dividem o `cast_id` aberto
por `Player._spec_do_disparo`, e o pente cheio vale 12 × 16 = **192**, logo
abaixo do teto de 200 do slot Z. O `CastController` chama `encerrar_disparo()`
antes de abrir a rajada — sem isso, o segundo aperto de tecla nasceria com o
orçamento do primeiro já gasto e não machucaria ninguém.

**Por que a rajada não congela o corpo:** é a única mecânica de tiro sustentado
da fruta; travar o jogador transformaria o golpe de pressão em golpe de risco.
A pistola da Yami segue a mesma regra e mora no mesmo componente.

O `_higan` do `FireFX` (variante 0) é o **outro** caminho do slot Z: as duas
"pistolas de dedo" em voxel aparecem à frente do jogador e disparam 16 zonas,
uma a cada 0,1 s, alternando as mãos — dano **12** · kb 12 · `dir × 35` ·
vida 10 s · raio 0,6, cada uma explodindo ao encostar em qualquer coisa. Em
jogo ele **não roda**, porque o `CastController` intercepta o Z antes; quem o
executa é `tools/dev_tests/test_frutas.gd`, que chama `_fire_skill` direto.
⚠️ Cada tiro dele vale o valor CHEIO da tabela — era `damage * 0,3` antes de
2026-08-21, e hoje quem limita o total é o teto do slot, não uma fração escrita
dentro do efeito.

### X — Hiken

Punho de fogo em voxel (palma, quatro dedos dobrados e polegar) que sai a
`d × 25` m/s: dano **160** · kb 35 · vida 10 s · raio 1,5 (baixado de 2,5 para
não raspar no chão). Ele **explode ao encostar** em qualquer corpo, com uma
guarda de 100 ms para não estourar na parede logo ao nascer, e um temporizador
de 1,15 s fecha o trajeto com `FireFXGrande._explosion` — dano **160** · kb 35 ·
parada · vida 1,6 s · raio 6,0.

As duas partes carregam a mesma spec: 160 + 160 = 320 contra um teto de **256**,
então quem tomar o punho E a explosão leva 256, e o excedente é cortado. É o
caso normal do teto — o segundo acerto ainda empurra.

### C — Vagalumes de Fogo

**Golpe novo, e a única skill da fruta que não é um projétil.** Nascem **45
vagalumes** em volta do **conjurador** (não do ponto mirado): `x` e `z`
sorteados em ±8 m, `y` entre −0,5 e 2,0, o conjunto 1,5 m acima dele.

Cada vagalume é uma `Area3D` de raio 2,5 com luz própria, cor ciclando em RGB e
deriva errática. A cada 0,5 s o controlador procura o corpo vivo mais próximo
dentro de **20 m** (grupos `enemy`, `player` e `enemies`) e a nuvem inteira
escorre na direção dele a 4,5 m/s — ela **caça devagar** antes de qualquer
explosão.

**A reação em cadeia:** basta um vagalume encostar em algo que tenha
`take_damage`. Esse detona na hora, e 2,0 s depois **todos os outros** detonam
em cascata de 0,05 s cada — enquanto isso eles perseguem o alvo marcado a
20 m/s. A nuvem se apaga 3 s depois da cascata. Se ninguém encostar em nenhum
deles, um temporizador de **20 s** detona a nuvem sozinha, sem alvo.

Cada explosão é uma `DamageZone`: dano **256** · kb 6 · parada · vida 0,8 s ·
**raio 8,0**. Todas carregam o mesmo `cast_id`, então o teto de **384** do slot
C fecha a conta em **uma explosão e meia**: a primeira entrega 256, a segunda os
128 que faltam, e as outras 43 são empurrão e espetáculo. É o teto funcionando
como projetado — 45 hitboxes de 256 sem orçamento seriam 11.520 contra uma vida
de 2048.

### V — Dai Enkai: Entei (Sol Quadrado)

**É a única skill carregável da fruta** (`CastController.CARREGAVEIS`).

**Segurando:** o conjurador congela (`congelar_para_cast`), assume a pose
`mera_v_charge`, a energia é cobrada **no aperto** (senão dava para espiar o
golpe de graça) e o `MeraChargeNode` cria um `EnteiSunController` **local e
puramente visual** acima da cabeça — `UP × 7,5 + dir × 1,5`, com tween de 0,9 s.
O sol cresce e acende conforme a carga, e o tremor de câmera sobe junto.

**Soltando:** o sol local é destruído e o servidor instancia o sol de verdade
(`FireFX._entei_sun`), que dispara no mesmo quadro para todos os peers.

| parte | valor |
|---|---|
| sol em voo | dano `valor_do_hit(carga)` = **512 a 768** · kb `7,5 + carga × 2` (até 14,5) · `dir × 28` m/s · vida 3,5 s · raio 3,5 |
| explosão | dano **768** (sempre o máximo) · kb 18 · parada · vida 0,4 s · raio 15 |

O sol detona ao **encostar em qualquer corpo**, ao tocar o chão (`y ≤ 0,9`, só
depois de 1,15 s de voo) ou ao esgotar 4,5 s de viagem. As duas hitboxes dividem
o orçamento de **768**, o maior do jogo — acertar com o sol e com a explosão não
dobra nada.

A carga usa a interpolação linear única do jogo (`DamageSpec.valor_do_hit`).
Antes ela era `damage * (1.0 + carga / 3.0)`, a terceira curva diferente de
carregamento que existia no projeto.

---

## O Entei mudou de slot — e veio com os números do slot antigo

O Entei era o **C carregado**. Quando virou o **V**, a linha da tabela veio
junto com a faixa velha, **256 → 384**, que é a faixa de carga do slot C. O
resultado: a ultimate da Mera valia o mesmo que um C de qualquer outra fruta,
metade do que o slot V promete.

Corrigido em 2026-08-21 para **512 → 768** — quem pegou foi
`tools/dev_tests/test_balance.gd`, checagem [1]:
`"mera_mera/V: carga 256->384 fora da faixa [512, 768]"`. A correção está
comentada em `src/combat/Balance.gd`, na própria linha do V.

**A lição é a mesma do resto da tabela:** faixa de dano pertence ao SLOT. Um
golpe que troca de tecla troca de contrato de balanceamento, e mover a linha de
lugar sem reavaliar o número é como mover o golpe sem ele.

---

## O conserto do Sol Quadrado (commit `91f0929`)

Sintoma relatado jogando: **o sol atravessava os inimigos**. Eram quatro
defeitos no mesmo golpe, e todos no jeito de mover a hitbox:

1. **A hitbox era teleportada para o sol a cada quadro** (`zone.global_position =
   global_position` dentro do `_process`), mas a `DamageZone` já anda sozinha no
   `_physics_process` e é ali que ela **varre o caminho** entre o ponto de antes
   e o de agora (a varredura do item 24, que existe justamente porque projétil
   rápido pula o alvo entre dois quadros). Com o teleporte por cima, o trecho
   varrido não correspondia ao trajeto real.
2. **As duas velocidades discordavam:** o sol andava a `dir × 28` e a hitbox
   tinha `dir × 42 + UP × 8`. Hoje as duas são `dir × 28` e a zona anda pelo seu
   próprio `vel`, que é o que a varredura de caminho entende.
3. **Nada escutava a colisão.** O sol só explodia por chão ou por tempo — acertar
   alguém não o detonava, ele seguia viagem. Hoje `collided_with_any` chama
   `_on_zone_collided`, que detona.
4. **A explosão subia.** A zona final tinha `vel = UP × 32` e vida de 0,4 s: ela
   subia ~13 m durante a própria explosão, saindo de onde o sol bateu. Hoje é
   `Vector3.ZERO` — a bola de 15 m de raio fica onde estourou.

O `_explode()` também passou a liberar a hitbox de voo **antes** de criar a da
explosão, para o sol não continuar ferindo depois de já ter estourado.

---

## Pendências

- **Item 21 da lista:** `FireFX.gd:211` chama `mmi.look_at(...)` **antes** do
  `add_child`, então o transform global é inválido e o `look_at` falha — 16
  ocorrências por conjuração no `_higan`. O tiro nunca é orientado. (Como o
  `_higan` só roda pelas sondas, o erro hoje aparece no teste, não em jogo.)
- ⚠️ **O X provavelmente perde a explosão final quando ACERTA.** O punho chama
  `zone.queue_free()` ao explodir por contato, mas o temporizador de 1,15 s lê
  `zone.global_position` sem checar `is_instance_valid(zone)`
  (`FireFX.gd:334-339`). Quando o Hiken encosta em alguém antes de 1,15 s — o
  caso comum a 25 m/s — a explosão de 160 tende a não sair, e sai um erro de
  instância liberada no lugar. **Não medido em jogo**; conferir com uma sonda
  antes de mexer.
- ⚠️ **A carga do V nunca chega ao sol cheio.** `EnteiSunController.update_charge`
  usa `ratio = clamp((carga * 0.5) / 3.0, 0, 1)` — com o `tempo_de_carga` de 3,5 s
  da tabela, a razão para em **0,58**: escala e luz do sol param a 58% do máximo.
  A conta pressupõe 6 s de carga (o comentário diz "a velocidade foi reduzida
  pela metade") e ninguém a atualizou quando a tabela fixou 3,5 s. É defeito
  **visual** — o dano vem do `valor_do_hit`, que chega ao máximo certinho.
- ⚠️ **Carregar o V não muda o total de dano.** A explosão usa
  `_spec.valor_do_hit(3.5)`, ou seja **o máximo, sempre**, independente do que o
  jogador segurou. Como ela sozinha vale 768 e o teto do slot é 768, quem for
  pego pela explosão leva a ultimate inteira mesmo com carga zero. A carga hoje
  só muda o valor do acerto **em voo** (512 a 768), o knockback e o tamanho do
  sol. Decidir: é intencional (a explosão é o golpe, o voo é bônus) ou a
  explosão deveria usar a carga real?
- **Comentários velhos no código**, todos herdados da versão anterior da fruta:
  - `FireFX.gd:4` diz que as skills são "Higan (Z), Hiken (X), Hibashira (C) e
    Inferno (V)" — três dos quatro estão errados hoje;
  - `FireFX.gd:347` imprime `☀️ [Mera Mera C - Dai Enkai: Entei]` — o Entei é o V;
  - `FireFXGrande.gd:4` anuncia "Hibashira legado, **Inferno** e a explosão", e o
    Inferno **não existe mais** no arquivo;
  - `FireFXGrande.gd:429` diz que sol e explosão "dividem o mesmo orçamento
    (384)" — são **768** desde a correção de slot;
  - `FireFXGrande.gd:424` diz "raio de 18 metros", mas o 18 é o **knockback**; o
    raio é **15**.
- **O Hibashira legado continua no arquivo e continua inalcançável.**
  `FireFXGrande._hibashira_legado` não tem chamador nenhum. Junto com ele ficam:
  - **Item 13:** os `set_meta("is_suppressed")` de `FireFXGrande.gd:191` e `:241`,
    que **ninguém lê** — hoje código morto dentro de função morta;
  - ⚠️ a pose `"hibashira"` ainda concede **imunidade a dano** em `Player.gd:1274`,
    `TrainingDummy.gd:107` e `disabled/enemies/Enemy.gd:129`. Nada liga essa pose
    hoje, então é imunidade adormecida — se o Hibashira voltar, ela volta junto
    sem ninguém decidir isso.
- **A nuvem do C nasce no conjurador, não na mira** (`FireFX.gd:20` passa
  `caster.global_position`). É coerente com um golpe de área em volta de si, mas
  torna o C inútil contra quem está longe: sem alguém a menos de ~20 m, a nuvem
  fica derivando até detonar sozinha aos 20 s.
- Vazamento: a auditoria de 2026-08-10 mediu 9 nós sobrando no V e 1 no Z; a
  releitura mostrou que quase tudo era **duração longa de propósito**, não
  vazamento. Ver as ressalvas em [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md).
  ⚠️ Aquela medição é do V **antigo** (o Inferno) — o V de hoje é outro golpe.
