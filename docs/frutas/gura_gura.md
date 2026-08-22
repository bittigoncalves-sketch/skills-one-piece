# Gura Gura no Mi — a fruta do tremor

> 🔧 **Fruta em revisão nesta data (2026-08-14).** `Player.gd`,
> `src/anim/ProceduralAnimator.gd`, `src/effects/GuraFX.gd` e
> `src/effects/GuraVNode.gd` estão sendo editados enquanto este documento é
> escrito. **A estrutura descrita aqui é a de agora**; números soltos (ângulos de
> pose, multiplicadores) podem já ter andado. Onde o número importa, ele está
> marcado com o arquivo e a linha para conferência.

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
`Knockback.PADRAO` — radial + 35% para cima. Ver `src/combat/Knockback.gd`.

---

## Estado, em uma tela

| | |
|---|---|
| **obtível** | sim — Árvore do Abalo (`TreeAndFruitGenerator`, paleta azul-tempestade) |
| **Z/X/C/V com hitbox** | 4/4 |
| **atalho ligado hoje** | o jogador **nasce** com ela equipada (`Player.gd:18`, `Main.gd:114`) — atalho de desenvolvimento, ver o README da pasta |
| **peculiaridade** | equipar dobra a escala do corpo (`scale = Vector3(2,2,2)`) |
| **pendências abertas** | itens **31, 32, 35** da [`../LISTA_DE_CORRECOES.md`](../LISTA_DE_CORRECOES.md) |

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/combat/Balance.gd` | **a tabela de dano** (`FRUTAS.gura_gura`) — a fonte da verdade desde 2026-08-21 |
| `SkillSystem.gd:44-49` | **só nome e cor** dos 4 slots; o `dano` que ele devolve é derivado do `Balance` |
| `src/player/cast_controller.gd:164-168` | **Z** desvia para a investida física, não para o VFX |
| `src/player/cast_controller.gd:68` | `CARREGAVEIS = {… "gura_gura": ["X"]}` — o X é carregável |
| `src/player/cast_controller.gd:306-370` | `GuraChargeNode` — a captura sísmica do X |
| `Player.gd:1336-1391` | `start_gura_rush()` e `_process_gura_rush()` — a investida do Z |
| `Player.gd:838-842` | a locomoção durante a investida (velocidade × 4) |
| `Player.gd:1585-1588` | a escala 2× ao equipar |
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
   efetiva (`Player.gd:840`);
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

⚠️ **A investida escreve `global_position` do alvo direto** (`Player.gd:1361`),
no cliente do atacante. A posição de outro jogador é autoritária **no cliente
dele**; em PvP o agarrão pode ser desfeito pelo próprio dono do corpo no quadro
seguinte. Não foi testado em rede — ver item 35.

### X — Esfera Sísmica: carregar e ARREMESSAR

O X é o **segundo golpe carregável** do jogo (o primeiro é o V da Goro Goro), e
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
plano horizontal (`_ground`), força `y = 0,2` e, após **0,4 s** de espera
(o tempo do uppercut `left_uppercut_from_guard.res`), abre:

| | valor |
|---|---|
| dano nominal | 30 → **3,6 aplicados** |
| knockback | 30, **para CIMA** |
| raio | 5,0 m · vida 0,5 s · estático |
| visual | bolha 3,0 · anel até 7,0 · **90 destroços** com viés para cima · rachadura + `ScreenShatterFX` |

⚠️ O `y = 0,2` é **chão absoluto**, não o chão sob o jogador. Na arena — que é
uma grade de lajes com buracos — isso funciona porque o piso está em y ≈ 0;
num mapa com desnível, a erupção sairia enterrada ou flutuando. Registrado como
limitação conhecida, não como bug: hoje não há mapa com desnível.

### V — Tsunamis Duplos: 4 segundos de imobilidade por dois muros

O V não é um efeito, é um **nó com linha do tempo**: `GuraVNode` entra na cena,
congela o conjurador e caminha por cinco poses, uma por segundo:

| t | pose | o que acontece |
|---|---|---|
| 0 s | `gura_v_prep` | postura firme, respiração |
| 1 s | `gura_v_squat` | agacha, braços atrás · tremor 0,3 |
| 2 s | `gura_v_gather` | agachado vibrando · anel de 8 m + 40 destroços · tremor 0,6 |
| 3 s | `gura_v_lift` | braços sobem · tremor 0,9 |
| 4 s | `gura_v_tpose` | T-pose · tremor 1,5 · **dispara** |

No disparo (`_liberar_tsunamis`): rachadura de escala 4,0, bolha de 8 m, 200
destroços, 3 anéis até 20 m, e **duas** `DamageZone` nascendo a ±6 m dos lados:

| | valor |
|---|---|
| dano nominal | 85 por tsunami → **10,2 aplicados** |
| knockback | 35 (radial — este golpe **não** força UP) |
| velocidade | `±right × 15 + fwd × 30` ≈ **33,5 m/s**, abrindo em leque |
| raio | **15 m** cada · vida 0,8 s |
| limpeza | 0,5 s depois do disparo o nó se libera e devolve pose/animação |

**Por que 4 segundos parado.** É o golpe mais forte da fruta e o único que
cobre a arena de lado a lado; o custo não podia ser só a recarga de 25 s, que o
jogador paga sozinho e escondido. Quatro segundos de T-pose visível é um custo
que **o adversário vê e pode punir** — o poder fica alto sem virar botão grátis.

⚠️ A limpeza mora em **dois** lugares (`_process` no fim e `_exit_tree`), de
propósito: se o nó morrer antes de terminar — morte do conjurador, troca de
cena — o jogador tem que sair de `is_casting` e da pose de qualquer jeito. Foi
essa a família de bug do item 23 ("morrer segurando a tecla travava o jogo").

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
| manutenção | **não replica**: `Main.gd:119` sincroniza `current_fruit_id`, mas `equip_fruit` **não** roda nos outros peers — o adversário te vê em tamanho normal |
| extensão | nenhuma outra fruta usa o mecanismo; é um `if` por id, não uma propriedade de dados |
| custo | duas linhas |
| riscos | passar pelos buracos, escalar paredes e ser atingido mudam de comportamento sem nada avisar |

**Gatilho:** se uma segunda fruta precisar mudar o corpo do jogador, isso vira
campo de dados na `FruitPassiveSystem` (ex.: `escala`), não um segundo `if`.

### Três dos quatro golpes empurram para CIMA

`override_kb_dir = Vector3.UP` no Z, X e C. O padrão da `DamageZone` é radial
(`alvo − centro`), que espalha o alvo para longe. Para a Gura, espalhar é pior:
manda o adversário para fora do raio dos golpes seguintes e, num mapa de buracos,
lançar para cima é o que de fato mata (o alvo cai onde estava, e onde estava pode
ser um buraco). O V é a exceção — ali o efeito **é** varrer a arena.

### O dano é baixo de propósito

Nominal 20/25/30/85 contra 25/40/55/80 da Gomu e 30/50/20/90 da Goro. Com
`DAMAGE_SCALE`, o Z tira ~4 de uma barra de 2048: em atrito puro, a Gura é a
pior fruta do jogo. Ela ganha pelo arremesso. Quem for equilibrar dano precisa
tratar knockback como a moeda dela, não como bônus.

---

## O que está quebrado ou pendente

| # | o que | onde |
|---|---|---|
| **31** | `GuraShatterMesh.spawn` escreve `global_position` **antes** do `add_child` — a rachadura nasce no lugar errado quando o pai não está na origem (Z, X e C) | `GuraShatterMesh.gd:50-51` |
| **32** | o X só funciona pelo caminho da carga; qualquer outro caminho explode perto de (0,0,0) | `GuraFX.gd:13` |
| **35** | a investida do Z e a captura do X escrevem a posição de outro corpo no cliente do atacante — não testado em rede | `Player.gd:1361`, `cast_controller.gd:344` |
| — | Z gasta recarga e energia mesmo sem encostar em ninguém (decisão pendente, não bug medido) | `Player.gd:1336` |
| — | a erupção do C assume piso em `y = 0,2` | `GuraFX.gd:208` |
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
