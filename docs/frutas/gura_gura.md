# Gura Gura no Mi — a fruta do tremor

> 🔧 **Esta página foi escrita durante uma revisão da fruta (2026-08-14) e
> reconferida contra o código em 2026-08-21/22**, depois da reescrita do dano.
> Nesta passagem foram corrigidos: os números de dano do **C** e do **V** (ainda
> estavam na escala do `DAMAGE_SCALE`), a seção do **V** inteira (descrevia o
> golpe anterior ao commit `6268a6e`), a direção do knockback e as linhas de
> arquivo, que tinham andado com o crescimento do `Player.gd`.

**Id:** `gura_gura` · **Tipo:** Paramecia · **Passiva:** Homem-Tremor (Quake
Force) — nenhum bônus de mobilidade (`speed_mod` e `jump_mod` = 1,0).

**A identidade da fruta é o KNOCKBACK.** Os quatro golpes usam empurrão
altíssimo e mandam o alvo **para cima** tanto quanto para longe. Numa arena cujo
chão tem 16 buracos e cuja morte principal é a queda, arremessar para o alto é o
golpe mais letal que existe.

> 🔄 **O dano parou de ser o preço disso em 2026-08-21.** A frase que estava
> aqui dizia que a Gura tinha "o menor dano nominal do jogo (20/25/30/85)". Na
> escala nova (`src/combat/Balance.gd`) ela vale **96 / 192→256 / 224 / 384 por
> onda** — topo da faixa do slot Z, a faixa carregada inteira do X, meio da faixa
> do C, e o teto do V nas duas ondas (768). Ela não compra mais o arremesso com
> dano baixo; o preço agora é o tempo parado (a carga do X, os 0,9 s do V) e o
> fato de três dos quatro golpes exigirem chegar perto.

⚠️ **A nota sobre `override_kb_dir = Vector3.UP` saiu porque não é o que o código
faz.** Hoje só duas zonas fixam direção, e nenhuma delas fixa `UP`: o **Z** fixa
`fwd` (empurra na direção da investida) e as ondas do **V** fixam o rumo da onda.
O **X** e o **C** usam o radial padrão da `DamageZone`, que já é
`Knockback.PADRAO` — radial + 35% para cima. Ver `src/mechanics/Knockback.gd`.

---

## Estado, em uma tela

| | |
|---|---|
| **obtível** | sim — Árvore do Abalo (`TreeAndFruitGenerator`, paleta azul-tempestade) |
| **Z/X/C/V com hitbox** | 4/4 |
| **atalho de nascimento** | ⚠️ **não é mais a Gura.** `Player.gd:25` nasce com `bara_bara` e `Main.gd:127` equipa `mera_mera` no spawn. O atalho de desenvolvimento continua existindo (ver o README da pasta), só mudou de fruta em 2026-08-21 |
| **peculiaridade** | equipar dobra a escala do corpo (`scale = Vector3(2,2,2)`, `Player.gd:2085`) |
| **pendências abertas** | itens **32 e 35** da [`../LISTA_DE_CORRECOES.md`](../LISTA_DE_CORRECOES.md) — o **31** está corrigido no código |

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/combat/Balance.gd` | **a tabela de dano** (`FRUTAS.gura_gura`) — a fonte da verdade desde 2026-08-21 |
| `SkillSystem.gd:44-49` | **só nome e cor** dos 4 slots; o `dano` que ele devolve é derivado do `Balance` |
| `src/player/cast_controller.gd:177-181` | **Z** desvia para a investida física, não para o VFX |
| `src/player/cast_controller.gd:68` | `CARREGAVEIS = {… "gura_gura": ["X"]}` — o X é carregável |
| `src/player/cast_controller.gd:387-451` | `GuraChargeNode` — a carga do X |
| `Player.gd:1752-1810` | `start_gura_rush()` e `_process_gura_rush()` — a investida do Z |
| `Player.gd:1035-1038` | a locomoção durante a investida (velocidade × 4) |
| `Player.gd:2085-2087` | a escala 2× ao equipar |
| `src/effects/GuraFX.gd` | os quatro efeitos + os blocos visuais (`_ring`, `_bubble`, `_debris`) |
| `src/effects/GuraVNode.gd` | o nó gerenciador da ultimate (V), com a linha do tempo de 4 s |
| `src/effects/GuraShatterMesh.gd` | o "ar rachando" — teia de linhas procedural (`SurfaceTool`) |
| `src/anim/GuraPoses.gd` | **as animações autorais dos 4 golpes** (Z/X/C/V), em quadros-chave |
| `src/anim/FruitPoses.gd` | as duas poses SUSTENTADAS: `gura_rush_pose` e `gura_x_charge_pose` |
| `tools/dev_tests/test_gura_animacoes.gd` | trava a pose de T e os três tempos do soco em número |
| `tools/dev_tests/captura_gura.gd` | filma a linha do tempo de um golpe em PNGs, para julgar com o olho |

**Contrato entre golpe e animação:** o efeito **não** toca animação. Ele escreve
`caster.set_meta("custom_pose", <nome>)` e o `ProceduralAnimator` faz o resto,
com peso interpolado. Os nomes válidos hoje são:

| nome | quem escreve | o que é |
|---|---|---|
| `gura_rush` | `Player.start_gura_rush` | pose **sustentada** da investida (meia-T) |
| `gura_x_charge` | `cast_controller` | pose **sustentada** da captura sísmica |
| `gura_z_soco` | `GuraFX._punch` | o soco que fecha a investida |
| `gura_x_arremesso` | `GuraFX._shockwave` | o arremesso da esfera |
| `gura_c_kabutsuchi` | `GuraFX._eruption` | o golpe de cima para baixo |
| `gura_v_lift` | `GuraVNode._armar` | armar a ultimate |
| `gura_v_tpose` | `GuraVNode._socar` | **a pose de T socando o ar** (obrigatória) |

> 🔄 **Mudou em 2026-08-15.** Z, X e C tocavam clipes **genéricos do Mixamo** por
> `play_baked` (`right_upper_hook_from_guard`, `punching`,
> `left_uppercut_from_guard`) — animação de boxeador, e o `play_baked` **sobrepõe
> o corpo inteiro**, apagando locomoção, parkour e mira enquanto o clipe rodava.
> Agora os cinco golpes são autorais, em `GuraPoses`, e **somam**.
>
> Os estados `gura_v_prep`, `gura_v_squat` e `gura_v_gather` foram **apagados**:
> nenhum efeito jamais os escreveu: eram código morto desde que nasceram.

Os nomes de golpe (os cinco de baixo) vivem em `GuraPoses.GOLPES` — o animador
não os conhece um a um, ele pergunta `GuraPoses.e_golpe(nome)`. É o único lugar
onde o acoplamento por string é conferido.

Por que assim: a pose precisa **somar** com locomoção, parkour e mira, que já
estão no animador. Um `AnimationPlayer` por golpe substituiria o corpo inteiro e
perderia a reação à física. O preço é que o nome da pose é um acoplamento por
string — quem renomear no animador quebra o golpe **em silêncio**.

---

## O que cada tecla faz, hoje

### Z — Gura Punch: uma INVESTIDA, não um projétil

O Z é o único golpe do jogo cujo cast **não** começa pelo caminho normal. Em
`CastController.comecar()` ele desvia para `Player.start_gura_rush(aim)` e
retorna. O que acontece:

1. cobra recarga (5 s) e energia (180), congela o cast e liga a pose `gura_rush`;
2. por até **0,6 s** o jogador corre na direção da mira a **4× a velocidade**
   efetiva (`Player.gd:1036`);
3. todo quadro, uma esfera de raio **1,2 m**, a 1,5 m à frente e 1,0 m acima do
   centro, procura qualquer corpo com `take_damage()` que não esteja congelado;
4. ao encostar em alguém: o alvo recebe `is_frozen` e `StatusFX.CONGELADO` por
   1 s, fica **grudado** a 1,5 m à frente por 0,5 s, e só então o golpe é pedido
   ao servidor com `charge = 1.0`;
5. `GuraFX._punch` liga a pose autoral `gura_z_soco` (era o clipe
   `right_upper_hook_from_guard.res` até 2026-08-15), espera `0,25 × mult` e abre
   a hitbox à frente do corpo.

**Números do impacto** (`GuraFX.gd:123-177`, com `charge = 1.0` → `mult ≈ 1,67`):

| | valor |
|---|---|
| dano | **96**, e é o que a barra perde (`Balance.FRUTAS.gura_gura.Z`) |
| knockback | 30 × mult ≈ **50**, fixo em `fwd` (`override_kb_dir`) |
| raio | 1,8 × mult ≈ **3,0 m** |
| deslocamento da zona | `fwd × 22` m/s, vida 0,5 s |
| teto da conjuração | 200 (slot Z) — um acerto só, nem chega perto dele |

> 🔄 **O Z NÃO é carregável (esclarecido em 2026-08-21).** Ele não passa pelo
> charge-up: a investida o dispara sempre com `charge = 1.0`, o que fazia o
> `mult ≈ 1,67` multiplicar um dano que ninguém tinha escolhido. Hoje o `mult`
> manda **só no espetáculo** — raio da onda, detritos, tremor de tela e volume —
> e o dano sai reto da tabela (`GuraFX.gd:127-132`).

**Por que agarrar antes de socar.** Sem o passo 4 o soco saía enquanto o alvo
ainda estava se movendo e a animação não casava com nada. Prender por 0,5 s dá
ao golpe um alvo parado para acertar — é o mesmo truque de "sincronizar a
animação" que o comentário do código descreve.

⚠️ **Se a investida não encostar em ninguém, nada acontece** — nem VFX, nem
hitbox. A recarga de 5 s e os 180 de energia **já foram gastos** no início. Isso
é consequência do desenho (o Z é um golpe de aproximação, não um disparo), mas
não está declarado como decisão em lugar nenhum do código; se for indesejado, o
conserto é devolver recarga/energia quando `_gura_rush_timer` expira sem alvo.

⚠️ **A investida escreve `global_position` do alvo direto** (`Player.gd:1777`),
no cliente do atacante. A posição de outro jogador é autoritária **no cliente
dele**; em PvP o agarrão pode ser desfeito pelo próprio dono do corpo no quadro
seguinte. Não foi testado em rede — ver item 35.

### X — Esfera Sísmica: carregar e ARREMESSAR

O X é **uma das três skills carregáveis** do jogo — as outras duas são o V da
Goro Goro (a primeira a existir) e o V da Mera Mera, e desde 2026-08-21 as três
usam a mesma reta de interpolação (`DamageSpec.valor_do_hit`). O X
usa toda a mecânica de charge-up documentada em
[`../PEDIDO_2026-08-12.md`](../PEDIDO_2026-08-12.md#charge-up--implementado-em-2026-08-12-noite):
a skill nasce **no clique**, cresce enquanto a tecla está segurada, e **levar
dano dispara** em vez de cancelar.

No aperto, `GuraChargeNode` (`cast_controller.gd:387`):

- pendura uma `SeismicOrb` no antebraço direito e liga a pose sustentada
  `gura_x_charge`; a câmera treme proporcionalmente à carga;
- a carga sobe até **3,0 s**, e quem manda nesse teto é o `tempo_de_carga` da
  tabela — não um literal escrito no controlador (`cast_controller.gd:412-414`).

Ao soltar, o pedido de cast leva `origem + aim × 100` no campo `aim`, e
`GuraFX._shockwave` lança dali uma `DamageZone` **projétil** (dano 0, raio 3,2,
`fwd × 25` m/s, vida 4 s). Quem fere é a explosão que nasce no primeiro corpo
tocado.

| | valor |
|---|---|
| dano | **192 → 256**, reta ao longo dos 3,0 s de carga (`DamageSpec.valor_do_hit`) |
| multiplicador `mult` | `1 + clamp(carga / 1,5 ; 0 ; 3)` → 1,0 a 3,0 — **só tamanho e tremor** |
| knockback | 34 × mult → até **102**, radial (`Knockback.PADRAO`) |
| raio da explosão | 6,0 × mult → **6 a 18 m** |
| vida da zona | 0,4 s (estática), após 0,3 s de espera |
| teto da conjuração | 256 (slot X) — a carga cheia entrega **exatamente** o teto |

**Por que a carga mexe no dano E no tamanho.** Até 2026-08-21 as três skills
carregáveis do jogo tinham três curvas próprias (`1 + carga/1,5` grampeado em 3
aqui, `1 + carga/3,0` na Mera, uma máquina de estados no Mamaragan) e nenhuma
delas dizia onde o golpe começava e onde terminava. Agora a faixa está escrita na
tabela (192 → 256) e a interpolação é **linear**, igual para as três; o `mult`
antigo sobreviveu só onde ele sempre foi honesto, que é o espetáculo.

> 🔄 **REDESENHADO — e a versão antiga deste documento descrevia a CAPTURA.**
> O texto que estava aqui contava que o `GuraChargeNode` lançava um raio de 30 m,
> congelava o alvo, o mantinha suspenso a 5 m à frente e detonava **em cima
> dele**, e concluía que "a captura transforma o tempo de carga em garantia de
> acerto". Nada disso existe hoje em `cast_controller.gd` — não há raio, `_target`
> nem `is_frozen` no arquivo inteiro. O X é projétil, e **pode errar**.
> ⚠️ Não achei registro de quando a captura saiu; a data acima é a desta revisão,
> não a da mudança.

### C — Kabutsuchi: o chão racha

Sem captura e sem carga. `GuraFX._eruption` mira o ponto **5 m à frente** no
plano horizontal (`_ground`), força `y = 0,2` e, após **0,4 s** de espera (o
tempo da pose autoral `gura_c_kabutsuchi`, que substituiu o uppercut do Mixamo —
o clipe antigo era um gancho de baixo para cima enquanto o chão rachava, ou seja
contava a história ao contrário), abre:

| | valor |
|---|---|
| dano | **224** (`Balance.FRUTAS.gura_gura.C`) |
| knockback | 30, **radial** — `Knockback.PADRAO`, com o viés de 35% para cima |
| raio | 5,0 m · vida 0,5 s · estático |
| teto da conjuração | 384 (slot C) — um acerto só, não chega perto dele |
| visual | bolha 3,0 · anel até 7,0 · **90 destroços** com viés para cima · rachadura + `ScreenShatterFX` |

⚠️ O `y = 0,2` é **chão absoluto**, não o chão sob o jogador. Na arena — que é
uma grade de lajes com buracos — isso funciona porque o piso está em y ≈ 0;
num mapa com desnível, a erupção sairia enterrada ou flutuando. Registrado como
limitação conhecida, não como bug: hoje não há mapa com desnível.

### V — Seaquake: duas paredes de água vindas das bordas do mapa

> 🔄 **REESCRITO DO ZERO em 2026-08-14** (commit `6268a6e`). A versão que este
> documento descrevia — cinco poses de um segundo cada, quatro segundos de
> imobilidade e duas zonas de raio 15 m nascendo a ±6 m do jogador — **não
> existe mais**. Aquele golpe nem tsunami tinha: eram duas nuvens de partículas
> que subiam em vez de avançar, e o clímax (bolha, 200 destroços, 3 anéis)
> nascia na **origem do mapa**, não no jogador.

O V não é um efeito, é um **nó com linha do tempo** (`GuraVNode`), e o pedido do
dono era literal: *"o personagem entra em pose de T socando o ar e rachaduras
brancas como o quebrar de uma tela aparecem a partir das mãos do jogador, e dos
dois lados do mapa são spawnados tsunamis gigantes que quando colidirem encerram
o ataque"*. Quatro tempos, cada um com um dono no arquivo:

| t | fase | o que acontece |
|---|---|---|
| 0 s | `_armar()` | pose `gura_v_lift`, `is_casting`, `lock_movement(0,90 s)` · tremor 0,5 |
| 0,45 s | `_socar()` | entra `gura_v_tpose` — a pose de T **abre recuando** os braços · tremor 0,35 |
| `T_IMPACTO` | `_impacto()` | o punho chega: tremor 1,6, soco de FOV 14, e as **rachaduras nascem nas duas mãos** (duas teias por mão + anel + 30 destroços) |
| 0,90 s | `_lancar_tsunamis()` | as duas ondas nascem **nas bordas** e o corpo é solto |
| medido | `_encontro()` | quando o vão entre as frentes cai a 8 m: anéis de até 70 m, bolha de 22 m, 220 destroços, vidro de 9,0 · tremor 2,5 |

`T_IMPACTO` é `T_SOCO + GuraPoses.V_GOLPE_ATE` — as rachaduras esperam o punho
**chegar**, senão o vidro trincava com os braços ainda voltando, que é o efeito
antes da causa.

**As ondas** (`_um_tsunami`), uma em cada borda oposta do eixo escolhido:

| | valor |
|---|---|
| dano | **384 por onda** (`Balance.FRUTAS.gura_gura.V`, MULTI 384 × 2) |
| teto da conjuração | **768** — exatamente 2 × 384 |
| knockback | `KB = 60`, **fixo no rumo da onda** (`override_kb_dir`) com viés para cima |
| velocidade | `VEL = 40` m/s — 100 m de borda até o centro = **2,5 s** |
| hitbox | **caixa** de `200 × 24 × 12` m (`LARGURA × ALTURA × HITBOX_FUNDO`), não esfera |
| berço | `BORDA = 100 m` (metade de `MapBuilder.PLATFORM_SIZE`), no chão |
| vida | travessia inteira + 1 s; quem mata as ondas antes é o `_encontro()` |

**Cada onda acerta cada corpo uma vez** (`DamageZone._hit`), então o teto do
orçamento e o teto físico do golpe coincidem: quem é pego pelas duas leva a
ultimate inteira (768), quem desvia de uma leva metade. **As duas contas
baterem é o sinal de que a skill está declarada certo na tabela.**

**Por que caixa e não esfera.** Uma esfera que cobrisse 200 m de frente teria
100 m de raio e acertaria quem estivesse 100 m **atrás** da onda. O parâmetro
`forma` do `DamageZone.setup` nasceu para isto. Pelo mesmo motivo o knockback é
fixo no rumo: o radial padrão mede `alvo − centro da zona`, e numa parede de
200 m o centro pode estar a 100 m de lado — o alvo sairia empurrado de lado, não
para a frente da onda.

**O eixo é arredondado para o cardeal mais próximo da mira** (`_escolher_eixo`):
o mapa é um quadrado de 200 m, e uma onda na diagonal nasceria numa quina, faria
283 m de caminho e cortaria só metade da arena.

**O fim é MEDIDO, não cronometrado.** A cada quadro o nó lê a posição real das
duas zonas e projeta a distância no eixo; quando o vão cai abaixo de
`FOLGA_ENCONTRO = 8 m`, o clímax dispara no ponto médio. Um cronômetro mentiria
se uma onda fosse destruída ou se o `VEL` mudasse — a pergunta é "quando
colidirem", e isso é geometria. `TETO_TRAVESSIA = 6 s` é rede de segurança.

**O jogador só fica travado 0,90 s**, o tempo do soco. Depois disso ele anda,
corre e desvia enquanto as ondas fecham — o dono avisou que prender o jogador
por 8 s é problema, não espetáculo. **As ondas passam POR CIMA dos 16 buracos**
de propósito: fazer a crista afundar em cada vão exigiria geometria por célula e
uma hitbox que a acompanhasse, e o resultado ("a onda some e volta") lê pior que
a água atravessando. 📌 Gatilho para revisitar: se os buracos ganharem parede ou
fundo visíveis, a onda reta vira erro de leitura.

⚠️ **As ondas são FILHAS do nó**, de propósito: se ele morrer (jogador morreu,
cena trocada), elas morrem junto e não sobra hitbox invisível varrendo o mapa.
E a limpeza do corpo mora em **dois** lugares (`_encerrar` e `_exit_tree`), pela
mesma razão — seja qual for o caminho da morte, o jogador tem que sair de
`is_casting` e da pose de T. Foi essa a família de bug do item 23 ("morrer
segurando a tecla travava o jogo").

---

## Decisões de projeto, e o porquê

### Equipar a Gura dobra o tamanho do jogador

`Player.equip_fruit` faz `scale = Vector3(2,2,2)` para `gura_gura` e volta a
`Vector3.ONE` para qualquer outra. A intenção é óbvia (o usuário canônico é um
gigante) e o efeito é bem mais do que visual: **escala o colisor, o alcance
aparente e a altura da câmera**.

**A declaração que faltava:**

| | |
|---|---|
| benefício imediato | leitura instantânea de quem está com a fruta mais forte da arena |
| impacto futuro | qualquer sistema que assuma jogador de tamanho fixo (parkour, buracos de 1×1 laje, mira, hitbox de melee) passa a ter um caso especial |
| manutenção | **não replica**: `Main.gd:132` sincroniza `current_fruit_id`, mas `equip_fruit` **não** roda nos outros peers — o adversário te vê em tamanho normal |
| extensão | nenhuma outra fruta usa o mecanismo; é um `if` por id, não uma propriedade de dados |
| custo | duas linhas |
| riscos | passar pelos buracos, escalar paredes e ser atingido mudam de comportamento sem nada avisar |

**Gatilho:** se uma segunda fruta precisar mudar o corpo do jogador, isso vira
campo de dados na `FruitPassiveSystem` (ex.: `escala`), não um segundo `if`.

### Dois golpes fixam a direção do empurrão; dois usam o radial

Só **Z** e **V** escrevem `override_kb_dir`, e nenhum dos dois fixa `UP`:

| golpe | direção do knockback | por quê |
|---|---|---|
| **Z** | `fwd` — a direção da investida | o soco fecha uma corrida; empurrar de lado desmentiria o movimento |
| **X** | radial (`Knockback.PADRAO`) | explosão esférica: radial **é** a leitura certa |
| **C** | radial (`Knockback.PADRAO`) | a cratera abre embaixo do alvo; o viés de 35% para cima já ergue |
| **V** | o rumo da onda | numa parede de 200 m o "centro da zona" pode estar a 100 m de lado, e o radial jogaria o alvo para os lados em vez de à frente da água |

O componente vertical **não some em nenhum deles**: `Knockback.PADRAO` é radial
+ **35% para cima** (`FRACAO_VERTICAL`), e é ele que tira o alvo do plano num
mapa onde quem mata é o buraco. Ver
[`../../src/mechanics/Knockback.gd`](../../src/mechanics/Knockback.gd).

> ⚠️ **A versão antiga deste documento dizia `override_kb_dir = Vector3.UP` no
> Z, X e C.** Não é o que o código faz, e não era em nenhuma versão recente —
> conferido linha a linha em `GuraFX.gd` e `GuraVNode.gd`.

### O dano deixou de ser o preço do arremesso

O texto que estava aqui dizia "nominal 20/25/30/85… com `DAMAGE_SCALE` o Z tira
~4 de uma barra de 2048: em atrito puro, a Gura é a pior fruta do jogo".
**Nada disso vale desde 2026-08-21:** o `DAMAGE_SCALE` foi removido, os números
da tabela são finais, e a Gura hoje vale **96 / 192→256 / 224 / 384 por onda**,
dentro da faixa do slot como todas as outras.

O preço do arremesso agora é **tempo e distância**, não dano: a carga do X, os
0,90 s travado no V, e o fato de o Z ser uma investida que só existe se encostar
em alguém. Quem for equilibrar esta fruta ajusta esses tempos — mexer no dano
para baixo recria o desequilíbrio que a tabela acabou de fechar.

---

## O que está quebrado ou pendente

| # | o que | onde |
|---|---|---|
| **31** | ✅ **corrigido.** `GuraShatterMesh.spawn` posiciona **depois** do `add_child`, e o motivo ficou escrito no código (fora da árvore, `global_position` escreve no transform local, e a rachadura nascia a ~2× a posição pedida) | `GuraShatterMesh.gd:56-65` |
| **32** | o X só funciona pelo caminho da carga: `cast` passa `dir` como **posição absoluta do alvo**, então um cast direto (sem `GuraChargeNode`) manda a esfera para perto de (0,0,0) | `GuraFX.gd:15` |
| **35** | a investida do Z escreve a posição de outro corpo no cliente do atacante — não testado em rede. (A **captura do X já não existe**: o `GuraChargeNode` não tem raio, `_target` nem `is_frozen`.) | `Player.gd:1777` |
| — | Z gasta recarga e energia mesmo sem encostar em ninguém (decisão pendente, não bug medido) | `Player.gd:1752` |
| — | a erupção do C assume piso em `y = 0,2` | `GuraFX.gd:277` |
| — | `GuraVNode._encerrar()` **não chama** `CombatResolver.encerrar(cast_id)`, embora o cabeçalho do `CombatResolver` cite o V da Gura como o exemplo de golpe longo que "sabe a hora em que acaba". Sem impacto em jogo — o orçamento é recolhido pelo varredor de 90 s —, mas as duas pontas discordam | `GuraVNode.gd:410`, `CombatResolver.gd:106-110` |
| — | `Knockback.gd:52` diz que o perfil `ARREMESSO` é "o V da Gura usa". Ele **não usa**: a `DamageZone` chama sempre `Knockback.PADRAO`, e `ARREMESSO`/`SO_HORIZONTAL` não têm chamador nenhum no jogo | `DamageZone.gd:178-180` |
| — | nenhum teste automatizado cobre a Gura especificamente; o `test_frutas.gd` só conta nós e hitboxes | `tools/dev_tests/` |

**Nunca foi medido:** dano real em alvo, alcance efetivo do Z (a investida
percorre ~`velocidade × 4 × 0,6 s`, mas a velocidade efetiva depende de sprint e
passiva), e o comportamento de qualquer golpe da Gura com dois jogadores de
verdade.

---

## Histórico

- `a71a20a` — commit misto: trouxe o trabalho em andamento da Gura (Z/V +
  animação) junto com o Karatê Tritão, e o atalho de nascer com a fruta.
- [`../PEDIDO_2026-08-12.md`](../PEDIDO_2026-08-12.md) — a mecânica de charge-up
  que o X reaproveita, incluindo o motivo de o dano **liberar** em vez de
  cancelar.
- [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md) — a Gura tinha os 4 golpes
  prontos e **nenhuma árvore**: era impossível de obter jogando. Achado ali,
  consertado em `TreeAndFruitGenerator` (o comentário do motivo ficou no código).
