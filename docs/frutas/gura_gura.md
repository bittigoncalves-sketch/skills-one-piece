# Gura Gura no Mi — a fruta do tremor

> 🔧 **Fruta em revisão nesta data (2026-08-14).** `Player.gd`,
> `src/anim/ProceduralAnimator.gd`, `src/effects/GuraFX.gd` e
> `src/effects/GuraVNode.gd` estão sendo editados enquanto este documento é
> escrito. **A estrutura descrita aqui é a de agora**; números soltos (ângulos de
> pose, multiplicadores) podem já ter andado. Onde o número importa, ele está
> marcado com o arquivo e a linha para conferência.

**Id:** `gura_gura` · **Tipo:** Paramecia · **Passiva:** Homem-Tremor (Quake
Force) — nenhum bônus de mobilidade (`speed_mod` e `jump_mod` = 1,0).

**A identidade da fruta é o KNOCKBACK, não o dano.** Os quatro golpes usam
números de dano baixos e empurrão altíssimo, e três deles forçam
`override_kb_dir = Vector3.UP`: o alvo vai **para cima**, não para longe. Numa
arena cujo chão tem 16 buracos e cuja morte principal é a queda, arremessar para
o alto é o golpe mais letal que existe — e é por isso que a Gura pode ter o
menor dano nominal do jogo (20/25/30/85) sem ser a fruta mais fraca.

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
| `SkillSystem.gd:29-34` | nomes, cores e dano **nominal** dos 4 slots |
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
5. `GuraFX._punch` toca `right_upper_hook_from_guard.res`, espera `0,25 × mult` e
   abre a hitbox à frente do corpo.

**Números do impacto** (`GuraFX.gd:137`, com `charge = 1.0` → `mult ≈ 1,67`):

| | valor |
|---|---|
| dano nominal | 20 → ~33 com o multiplicador → **~4,0 aplicados** (`× DAMAGE_SCALE`) |
| knockback | 30 × mult ≈ **50, todo para CIMA** (`override_kb_dir = UP`) |
| raio | 1,8 × mult ≈ **3,0 m** |
| deslocamento da zona | `fwd × 22` m/s, vida 0,5 s |

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

### X — Shockwave: capturar, carregar, e detonar EM CIMA DO ALVO

O X é o **segundo golpe carregável** do jogo (o primeiro é o V da Goro Goro), e
usa toda a mecânica de charge-up documentada em
[`../PEDIDO_2026-08-12.md`](../PEDIDO_2026-08-12.md#charge-up--implementado-em-2026-08-12-noite):
a skill nasce **no clique**, cresce enquanto a tecla está segurada, e **levar
dano dispara** em vez de cancelar.

No aperto, `GuraChargeNode` (`cast_controller.gd:306`):

- lança um raio de **30 m** na mira; se acertar um corpo com `take_damage()`, ele
  vira `_target`, ganha `is_frozen` + `CONGELADO` por 4 s;
- todo quadro o alvo é puxado (lerp, fator 10/s) para **5 m à frente e 2,5 m
  acima** do conjurador — ou seja, **fica suspenso no ar, na sua frente**;
- a carga sobe até o teto de **3,0 s**; a câmera treme proporcionalmente.

Ao soltar, o pedido de cast leva **a posição do alvo** no campo `aim` — não uma
direção. `GuraFX.cast` sabe disso (`variant 1` passa `dir` cru para
`_shockwave`), e a explosão nasce **no corpo capturado**.

| | valor |
|---|---|
| multiplicador | `1 + clamp(carga / 1,5 ; 0 ; 3)` → **1,0 a 3,0** |
| dano nominal | 25 × mult → **3,0 a 9,0 aplicados** |
| knockback | 34 × mult → até **102, para CIMA** |
| raio | 6,0 × mult → **6 a 18 m** |
| vida da zona | 0,4 s (estática), após 0,3 s de espera |

**Por que a explosão vai ao alvo em vez de sair do punho.** Um golpe carregado
de 3 segundos que ainda pode errar não recompensa o risco: o jogador fica parado,
congelado, visível e vulnerável durante a carga. A captura transforma o tempo de
carga em **garantia de acerto** — o preço já foi pago na imobilidade.

⚠️ **Só o caminho da carga manda posição.** Qualquer outro caminho para o slot X
(`cast_skill_slot("X")`, um RPC vindo de outro peer, um teste) manda uma
**direção unitária**, e a onda nasce a ~1 m da origem do mundo. Item 32.

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
