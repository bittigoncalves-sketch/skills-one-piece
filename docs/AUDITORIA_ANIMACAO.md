# Auditoria do sistema de animação e do esqueleto do jogador

> Data: 2026-08-25 · Godot 4.6.3 · personagem de referência: `base`
> **Estado: a Fase 1 do plano (seção 10) está IMPLEMENTADA — ver seção 11.**
> Escopo: `src/anim/`, `assets/animations/*.res`, `tools/bake_mixamo.gd`,
> `tools/anim_editor/`, e o rig de 13 papéis.
>
> Todo número abaixo é reprodutível pelo comando que acompanha o achado. As
> seções 1–10 descrevem o estado **antes** da intervenção; a seção 11 diz o que
> foi feito e com que resultado medido.

---

## 1. Resumo

O pedido tem três alvos: **fluidez** na movimentação, **edição humana** das
animações, e **importação no Blender**. Os três batem no mesmo lugar, e é um
lugar mais raso do que parece:

> **Os `.res` do jogo não são `Animation` válidas do Godot.** Doze das treze
> faixas de cada clipe apontam para caminhos que não existem na cena. Elas só
> tocam porque o `ProceduralAnimator._apply_baked` lê a string do caminho à mão
> e resolve num dicionário próprio.

Isso explica, de uma vez, por que não há preview no editor do Godot, por que não
há `AnimationPlayer`, por que não há blend, e por que o caminho de volta para o
Blender nunca fechou. E explica o efeito colateral mais caro: como o
`play_baked` sobrepõe o corpo inteiro sem mistura, **toda animação autoral do
jogo teve que ser escrita em GDScript** — 749 linhas de tabelas de quadros-chave
em `GuraPoses`/`FruitPoses`/`MeleePoses`/`WeaponPoses`, que é exatamente o
oposto de "editável por humano".

O esqueleto tem dois problemas independentes: um **erro de hierarquia** que
injeta até 64° de rotação parasita na cabeça de todo personagem voxel, e
**proporções fora do cânone humano** que são a causa geométrica de metade do
deslize de pé que hoje é tratado como limite matemático.

| # | Achado | Medida | Alvo do pedido |
|---|---|---|---|
| 1 | Faixas dos clipes não resolvem como `NodePath` | 1 de 13 | Blender, edição |
| 2 | Entrada em clipe estala | 131,11°/frame (8,1× o normal) | Fluidez |
| 3 | Saída de clipe estala | 61,07°/frame (3,8×) | Fluidez |
| 4 | Bob do torso congela durante o clipe | Δ = 0,0000 m | Fluidez |
| 5 | Nenhum clipe tem `loop_mode` | 0 de 29 | Fluidez |
| 6 | Chaves redundantes | 54.548 → 12.659 a 1° (−77%) | Edição |
| 7 | `Head` declarado no pai errado | até 64,01° parasitas | Esqueleto |
| 8 | Perna curta demais | 31,2% da altura (cânone 49,1%) | Esqueleto, fluidez |
| 9 | Canela mais longa que a coxa | 150% (humano ~100%) | Esqueleto |
| 10 | Assimetria L/R nos Meshy | até 26,02% (crocodile) | Esqueleto |
| 11 | Animação autoral em GDScript | 749 linhas | Edição |

---

## 2. Achado 1 — os clipes não são `Animation` de verdade

Cada `.res` tem 13 faixas `TYPE_VALUE` com caminho `"<Papel>:rotation"` —
**plano**, sem hierarquia. Mas o rig é uma árvore: `Head` está sob `Torso`,
`Shin_L` sob `Thigh_L`. O caminho `Head:rotation` só resolveria se `Head` fosse
filho direto da raiz.

```
godot --headless --path . -s tools/dev_tests/testar_export_gltf.gd

A) faixas do .res que resolvem como NodePath real: 1/13
```

**O que isso custa hoje:**

- **Nenhum `AnimationPlayer` toca esses arquivos.** O jogo funciona porque
  `_apply_baked` faz `String(path).get_slice(":", 0)` e procura o papel no
  próprio dicionário `_n`. É um formato privado usando a casca de um público.
- **Sem preview no editor do Godot.** Abrir o `.res` no dock de animação mostra
  13 faixas vermelhas.
- **Sem exportação.** O exportador glTF do Godot precisa resolver o nó da faixa;
  ele falha em 12 e emite `glTF: Cannot get node for animated track`.
- **Sem blend, sem máscara, sem `AnimationTree`.** Toda a infraestrutura nativa
  de mistura do Godot fica inacessível — e é essa ausência que gera os achados
  2, 3, 4 e 11.

**E a correção é pequena.** Reescrevendo o caminho para a forma hierárquica
(`Torso/Head:rotation`) o mesmo clipe exporta inteiro:

```
B) append_from_scene err=0 / write err=0
   reimport 'punching': faixas=13  dur=1.25s
     Torso                tipo=2 (ROTATION_3D) chaves=39
     Torso/Neck           tipo=2 chaves=39
     Torso/Head           tipo=2 chaves=39
     Torso/UpperArm_L     tipo=2 chaves=39
```

As 13 faixas viram canais de **quaternion** no glTF — o formato que o Blender
importa nativamente, sem script. O caminho de volta (Blender → `.glb` → Godot)
já existe e é o mesmo que o `bake_mixamo` usa para ler o Mixamo.

> Nota: a exportação glTF do Godot reamostra a 30 fps (988 → 507 chaves). Para
> ida-e-volta sem perda, o melhor é decimar por tolerância **antes** (achado 6),
> e não deixar o exportador reamostrar uma curva de 60 fps.

---

## 3. Achados 2, 3 e 4 — a fluidez se perde nas bordas do clipe

`ProceduralAnimator._apply_baked` escreve a pose do clipe **direto** no nó:

```gdscript
(_n[role] as Node3D).rotation = euler        # sem lerp, sem peso, sem fade
```

O resto do animador nunca faz isso — ele acumula offsets e aplica com
`1.0 - exp(-STIFFNESS * delta)`. O clipe é a única coisa no sistema que pula o
filtro. Medido andando a 4,2 m/s e chamando `play_baked("punching")`:

```
godot --headless --path . -s tools/dev_tests/medir_transicoes.gd

REGIME PERMANENTE (andando 4,2 m/s)
  maior giro de junta num frame: 16,19°/frame

ENTRADA no clipe 'punching' (play_baked)
  salto no 1º frame: 131,11° (ForeArm_R)  -> 8,1x o passo normal
  torso.y  antes=0,7639  durante=0,7639  (congelado: sim)

SAÍDA do clipe (volta para locomoção)
  maior salto nos 20 frames seguintes: 61,07° (ForeArm_R) no frame +2 -> 3,8x

IDLE -> SPRINT (blend procedural)
  maior salto: 43,73° (Thigh_L) -> 2,7x
```

- **131° num frame** é o braço teleportando da pose de corrida para a guarda do
  clipe. É o estalo mais visível do jogo, e acontece em **todo** golpe desarmado.
- **61° na saída**: quando `_baked = null`, o `off` volta a acumular do zero e o
  filtro tem que recuperar a distância inteira.
- **O bob do torso congela** no valor que tinha no frame da chamada — o `return`
  antecipado de `update()` pula o bloco que escreve `Torso.position`. O corpo
  fica pendurado num offset arbitrário durante todo o golpe.
- O `idle → sprint` (2,7×) é o único que já tem mistura, e mesmo assim salta:
  os pesos fazem crossfade, mas a **IK da perna** muda de passada e de altura de
  quadril ao mesmo tempo, e nada suaviza essa troca.

**A correção é um peso.** O clipe precisa entrar como mais uma camada do `off`,
com `_baked_w` subindo e descendo por `exp` como os outros 29 pesos do arquivo,
e com máscara por papel (só braços, só tronco, corpo inteiro). É a mesma
mudança que resolve o achado 11.

---

## 4. Achado 5 — nenhum clipe cicla

```
godot --headless --path . -s tools/dev_tests/auditar_clipes.gd
```

Todos os 29 têm `loop_mode = 0` (`LOOP_NONE`). Para os golpes está certo. Para
o `bouncing_fight_idle` — que é *idle de combate*, feito para ciclar — está
errado, e o arquivo até fecha bem: a diferença entre a primeira e a última chave
é de **0,49°**. O ciclo existe; falta o campo. Mesmo caso do `pivot` (0,15°),
`smash` (0,10°) e dos oito clipes que fecham em 0,00°.

Clipes que **não** fecham (e portanto não devem ciclar): `chapa_giratoria_2`
138,01°, `dying` 111,08°, `jumping_over_into_combat` 105,48°, `flying_kick`
93,18°, `running_dive_roll` 87,85°.

---

## 5. Achado 6 — 77% das chaves são ruído

O baker amostra a 60 fps **toda faixa em todo frame**, sem decimação. Resultado:

| | total | por clipe | por osso |
|---|---|---|---|
| hoje | 54.548 chaves | 1.881 | 145 |
| decimado a 0,5° | 16.944 (31%) | 584 | 45 |
| decimado a 1,0° | **12.659 (23%)** | 437 | **34** |
| decimado a 2,0° | 8.789 (16%) | 303 | 23 |

```
godot --headless --path . -s tools/dev_tests/medir_reducao_chaves.gd
```

Casos extremos: `dying` cai de 4.537 para 568 chaves a 1°; `bouncing_fight_idle`
de 2.353 para 247 — **89% do arquivo é redundante**.

Isto é o achado de **edição humana**. Ninguém ajusta uma curva com 145 chaves
por osso, nem no Blender nem no editor em Python. Com 34, ajusta. E a
decimação por tolerância angular garante que a pose não muda mais que 1° em
nenhum instante — o mesmo critério que o `medir_pose_res.gd` já usa para provar
que um rebake não mexeu no movimento.

---

## 6. Achado 7 — `Head` está declarado no pai errado

Três arquivos declaram a hierarquia do rig, e os três dizem a mesma coisa:

| arquivo | declaração |
|---|---|
| `src/anim/SkeletonDriver.gd` (`RIG_PARENT`) | `"Head": "Torso"` |
| `tools/bake_mixamo.gd` (`MAP`) | `"Head": [..., "Torso"]` |
| `docs/ANIMACOES_MIXAMO.md` | "`Head` \| `mixamorig_Head` \| Torso" |

Mas a árvore real do `base.scn` (e do `buggy.scn`) é:

```
Torso
 └─ Neck
     └─ Head        ← o pai REAL é Neck, não Torso
```

```
godot --headless --path . -s tools/dev_tests/auditar_esqueleto.gd

========== BASE ==========
papeis resolvidos: 13/13
  ⚠ HIERARQUIA: 'Head' declarado filho de 'Torso' mas o pai REAL é 'Neck'
```

**Consequência.** O baker grava a faixa do `Head` como delta relativo ao
**Torso**, e a do `Neck` também. Na hora de tocar, o `Head` herda a rotação do
`Neck` (porque é filho dele) **e** aplica a própria. A rotação do pescoço entra
duas vezes na cabeça.

```
godot --headless --path . -s tools/dev_tests/medir_erro_cabeca.gd

armada.res                 64,01°       running_dive_roll.res      44,98°
kicking.res                39,28°       jumping_over_into_combat   38,07°
meia_lua_de_compasso.res   30,97°       flying_kick.res            27,72°
...  (mediana ~20° nos 29 clipes)
```

Até **64° de rotação parasita na cabeça**, em todo personagem voxel, em todo
clipe. Nos personagens skinnados o `SkeletonDriver` acerta por acidente — ele
percorre a cadeia de ossos real, então a conta fecha lá.

A `DOCUMENTACAO` inclusive afirma que "o rig voxel não tem nó `Neck`". Tem: o
`base.scn` e o `buggy.scn` têm, e é justamente ele que causa o erro.

**Duas correções possíveis**, e a escolha é de projeto:
- **(a)** declarar `"Head": "Neck"` nos três lugares e reassar — mantém o
  pescoço como junta articulável (bom para look-at e para o Blender);
- **(b)** remover o nó `Neck` dos `.scn` e pendurar `Head` direto no `Torso` —
  bate com o `VoxelMeshes._build_skeleton`, que nunca criou `Neck`, e com o que
  a documentação já diz.

A (a) é a que ganha expressividade; a (b) é a que fecha a divergência entre os
dois construtores de corpo voxel — que hoje montam **esqueletos diferentes**.

---

## 7. Achados 8, 9 e 10 — as proporções do esqueleto

Todos os personagens são normalizados para 1,50 m (`PlayerRig.CHAR_TARGET_H`).
Comparando com o cânone humano de 7,5 cabeças:

| personagem | coxa (% h) | canela (% h) | canela/coxa | perna total (% h) | simetria L/R |
|---|---|---|---|---|---|
| **cânone humano** | 24,5% | 24,6% | ~100% | **49,1%** | 0% |
| **base** | 12,5% | 18,8% | **150%** | **31,2%** | 0,00% |
| buggy | 10,9% | 16,4% | **150%** | 27,3% | 0,00% |
| nami | 21,8% | 19,1% | 87% | 40,9% | 3,68% ⚠ |
| ace | 22,7% | 15,4% | 68% | 38,1% | 0,01% |
| blackbeard | 20,4% | 11,4% | **56%** | 31,8% | 2,28% ⚠ |
| crocodile | 28,1% | 21,5% | 77% | 49,6% | **26,02%** ⚠ |

Três coisas saem daqui:

**(8) A perna do `base` tem 31,2% da altura; a humana tem 49,1%.** Isso não é
estilo — o `base` é um boneco de proporção realista, não um chibi. E é a causa
geométrica direta do deslize de pé.

O `ProceduralAnimator` documenta longamente que o deslize de 45% é o preço de
`CADENCIA_ESCALA = 0.55`, e que "o conserto de verdade é reduzir `Player.SPEED`".
**Está incompleto.** Rodando a mesma geometria com a perna canônica:

```
godot --headless --path . -s tools/dev_tests/simular_perna_canonica.gd

perna    caso   v(m/s)  passada  passos/s com pé cravado
0,469    WALK    4,2     0,531        7,91          <- hoje
0,737    WALK    4,2     0,834        5,04          <- perna canônica  (−36%)
0,469    RUN     7,0     0,580       12,06
0,737    RUN     7,0     0,911        7,68          <- (−36%)
```

A cadência de pé cravado cai **36%** só por corrigir a perna, sem tocar em
`Player.SPEED` nem em `CADENCIA_ESCALA`. Os 7,91 passos/s que o comentário do
código chama de "o dobro de um humano correndo" viram 5,04. É o mesmo orçamento
de deslize comprado de graça — e sem o agachamento que a tabela do código lista
como preço em silhueta.

**(9) A canela do `base` é 50% mais longa que a coxa.** No humano são
praticamente iguais. É por isso que o joelho fica alto demais e a IK dobra num
ponto que o olho lê como errado. Vem do modelo de origem: no `base.glb` a peça
`Thigh` mede 0,25 e a `Shin` 0,375 (`base_glb_stats.json`).

**(10) O `crocodile` tem 26% de assimetria entre lados** — o rig do Meshy nasceu
torto e nunca foi corrigido. O `nami` (3,68%) e o `blackbeard` (2,28%) também
passam do limiar de 2%. O `tools/anim_editor/rigger.py` já resolve isso (o
README documenta o blackbeard indo de 54% para 99% de canela/coxa), mas o
resultado **nunca foi aplicado ao runtime** — o jogo continua lendo o esqueleto
cru do FBX.

---

## 8. Achado 11 — a animação autoral mora em GDScript

749 linhas de tabelas de quadros-chave escritas à mão:

| arquivo | linhas | o que anima |
|---|---|---|
| `src/anim/GuraPoses.gd` | 445 | os 4 golpes da Gura Gura |
| `src/anim/FruitPoses.gd` | 112 | Hibashira, Kurouzu, Black Hole, rush |
| `src/anim/MeleePoses.gd` | 102 | postura do combo desarmado |
| `src/anim/WeaponPoses.gd` | 90 | idle e corte da espada |

E o próprio `GuraPoses.gd` documenta o porquê, no cabeçalho:

> "o `play_baked` **SOBREPÕE O CORPO INTEIRO**: durante o clipe a locomoção, o
> parkour e a mira sumiam. As poses daqui SOMAM, que é o contrato do projeto."

Ou seja: **o achado 2 é a causa do achado 11.** Como o clipe não sabe misturar,
quem precisava de mistura teve que sair do formato de clipe. O `ProceduralAnimator`
acumulou 29 pesos de pose (`_gura_rush_w`, `_kurouzu_w`, `_hibashira_w`,
`_black_hole_w`, …) que são, na prática, um `AnimationTree` escrito à mão.

Com blend e máscara no `play_baked`, esses quatro arquivos voltam a ser clipes —
edináveis no Blender, no editor em Python, ou no dock do Godot.

---

## 9. Instrumentos criados

Nove scripts headless. Os sete primeiros só leem; os dois `test_*` entraram
no `./validar.sh rapido` e também não gravam nada no jogo:

| arquivo | mede |
|---|---|
| `tools/dev_tests/auditar_clipes.gd` | tipo de faixa, papéis, chaves, fps, loop, fechamento de ciclo, maior salto |
| `tools/dev_tests/testar_export_gltf.gd` | prova A/B do achado 1: quantas faixas resolvem, e o round-trip glTF |
| `tools/dev_tests/auditar_esqueleto.gd` | hierarquia real vs. declarada, proporções vs. cânone, simetria L/R |
| `tools/dev_tests/medir_transicoes.gd` | salto angular por frame na entrada/saída de clipe e nas trocas de estado |
| `tools/dev_tests/medir_erro_cabeca.gd` | rotação parasita da cabeça por clipe |
| `tools/dev_tests/medir_reducao_chaves.gd` | chaves que sobram por tolerância angular |
| `tools/dev_tests/simular_perna_canonica.gd` | cadência/passada/deslize com perna medida vs. canônica |
| `tools/dev_tests/test_biblioteca_anim.gd` | a pasta inteira contra o contrato do rig (entrou no gate) |
| `tools/dev_tests/test_ida_e_volta_blender.gd` | o ciclo `.res → .glb → .res` em memória (entrou no gate) |

Todos seguem a regra do projeto: **número, não adjetivo**, e o mesmo instrumento
antes e depois.

---

## 10. Plano proposto

> As Fases 2, 3 e 4 foram destacadas para
> [`PLANO_ANIMACAO_FASES_2_3_4.md`](PLANO_ANIMACAO_FASES_2_3_4.md), que é o
> **ponto de entrada para continuar** — lá elas estão detalhadas com alvos,
> comandos, armadilhas e o preparo de uma máquina nova. O resumo abaixo fica
> como registro do que foi decidido em 2026-08-25.

Ordenado por *quanto destrava* dividido por *quanto arrisca*. As fases 1 e 2 não
mexem em nada que já foi aprovado em tela.

### Fase 1 — o contrato do clipe (destrava Blender e edição) ✅ FEITA
> Implementada em 2026-08-25 — os números do resultado estão na seção 11.
1. **Caminhos hierárquicos** nas faixas: `Torso/Head:rotation` em vez de
   `Head:rotation`. Toca `bake_mixamo.gd`, `_apply_baked` e o exportador do
   `anim_editor`. Os `.res` existentes são reassados.
2. **Decimação a 1°** no baker. −77% de chaves, pose idêntica dentro de 1°.
   Prova: `medir_pose_res.gd` (já existe) tem que dar DIFF_max < 1° nos 29.
3. **`loop_mode`** por clipe, a partir do fechamento de ciclo medido.
4. **`tools/exportar_para_blender.gd`**: `.res` → `.glb` com armature de 13
   ossos. Fecha o ciclo com o `tools/importar_animacao.sh` que já existe.

**Critério de aceite:** abrir qualquer um dos clipes no Blender por
`File > Import > glTF`, mexer numa curva, reexportar, e o jogo tocar a versão
editada — sem script intermediário.
✅ **Atendido**, e verificado nos 33 clipes pelo
`tools/dev_tests/test_ida_e_volta_blender.gd`, que entrou no `./validar.sh rapido`.

### Fase 2 — fluidez (destrava a movimentação) — ABERTA
5. **`_baked_w` com fade**: o clipe entra como camada do `off`, com peso subindo
   por `exp` (entrada ~0,12 s, saída ~0,18 s) em vez de escrita direta.
   **Alvo: o salto de entrada cai de 131,11° para < 20°/frame** (medido pelo
   `medir_transicoes.gd`).
6. **Máscara por papel** (`braços` / `tronco` / `corpo inteiro`) — é o que
   permite o soco por cima da corrida sem congelar as pernas.
7. **Bob do torso continua** durante o clipe (tirar o `return` antecipado de
   `update()`).
8. **Suavizar a troca de regime da IK** (altura de quadril e passada entram
   filtradas, não em degrau) — ataca os 43,73° do `idle → sprint`.

### Fase 3 — esqueleto (o que muda proporção; precisa de decisão do dono) — ABERTA
> O item 9 (`Head` sob `Neck`) foi antecipado para a Fase 1, na variante (a): a
> hierarquia é declarativa e não mexe em proporção nenhuma. O resto continua aberto.
9. **`Head` sob `Neck`** (ou remover o `Neck`): −64° de rotação parasita.
   Escolher entre (a) e (b) da seção 6.
10. **Unificar os dois construtores voxel** — `VoxelMeshes._build_skeleton`
    (coxa 0,30 / canela 0,30, sem `Neck`) e `base.scn` (0,25 / 0,375, com
    `Neck`) montam esqueletos diferentes hoje.
11. **Reproporcionar a perna do `base`** para o cânone: coxa ≈ canela, perna
    total ~49% da altura. Ganho medido: −36% na cadência de pé cravado.
    ⚠️ **Isto recalibra o walk aprovado e os tempos de impacto do
    `src/combat/Melee.gd`.** Não fazer sem rodar `medir_impacto_res.gd` depois.
12. **Re-rigar os Meshy** com o `rigger.py` que já existe e **carregar o
    resultado no runtime** — hoje o rig por marcadores é usado só pelo editor.

### Fase 4 — o que sobra — ABERTA
13. Migrar `GuraPoses`/`FruitPoses`/`MeleePoses`/`WeaponPoses` para clipes
    (depende da fase 2).
14. **Eventos de impacto no clipe** — hoje o dano sai por tempo no código; o
    `medir_impacto_res.gd` já sabe achar o frame.
15. **Root motion** — o baker descarta a translação do quadril.
16. Ampliar o rig para 17 papéis (`Hips`, `Shoulder_L/R`, `Hand_L/R`) — o Mixamo
    já traz essas curvas e o baker as joga fora.

---

## 11. O que foi implementado (Fase 1)

Escopo aprovado: **Fase 1** do plano acima, mais o item 9 da Fase 3 na variante
**(a)** — `Head` passa a pender de `Neck`.

### 11.1 `src/anim/RigContrato.gd` — fonte única do contrato

A hierarquia do rig estava declarada em três lugares independentes
(`SkeletonDriver.RIG_PARENT`, `bake_mixamo.MAP`, a tabela do
`ANIMACOES_MIXAMO.md`) e os três discordavam da árvore real. Agora mora num
arquivo só, e os outros importam de lá: papéis, hierarquia, aliases de osso,
construção e leitura do caminho da faixa, espelhamento L↔R.

`papel_de()` aceita **os dois formatos** de caminho de propósito — um `.res`
antigo continua tocando enquanto não for reassado.

### 11.2 Caminho hierárquico

`"Head:rotation"` → `"Torso/Neck/Head:rotation"`.

| | antes | depois |
|---|---|---|
| faixas que resolvem como `NodePath` | **1 de 13** | **13 de 13** |
| `AnimationPlayer` toca o clipe | não | sim |
| preview no dock de animação do Godot | não | sim |
| exportação glTF | recusada em 12 faixas | 13 canais de quaternion |

### 11.3 `Head` sob `Neck`

Corrigido nos três lugares (agora um só) e nos 29 clipes reassados. Saiu a
rotação parasita de até **64,01°** da cabeça.

### 11.4 Decimação a 1° no baker

| | total | por clipe | por osso |
|---|---|---|---|
| antes | 54.548 chaves | 1.881 | 145 |
| depois | **12.659** (23%) | 437 | **34** |

### 11.5 `loop_mode`

Lista explícita (`CICLICOS`) no baker, com conferência do fechamento real do
ciclo (teto 5°). Hoje ciclam quatro: `bouncing_fight_idle` (fecha em 0,49°),
`alert` (0,00°), `walking` (4,50°) e `walk_backward_inplace` (3,86°). O `running`
está na lista e **não** recebeu o loop — abre 12,05°, e o baker avisa em vez de
gravar metadado errado em silêncio.

### 11.6 Ida e volta pelo Blender

Dois novos scripts headless e um teste:

```bash
GODOT=/caminho/do/godot
# IDA — todos os clipes num arquivo; cada um vira uma Action no Blender
$GODOT --headless --path . -s tools/exportar_para_blender.gd
#      abre assets/blender/rig_base_completo.glb no Blender e edita
# VOLTA
$GODOT --headless --path . -s tools/importar_do_blender.gd -- assets/blender/rig_base_completo.glb
# PROVA
$GODOT --headless --path . -s tools/dev_tests/test_ida_e_volta_blender.gd
```

**Resultado: os 33 clipes voltam com a duração idêntica e desvio ≤ 0,999°** — que
é exatamente a tolerância da decimação que o importador aplica na volta. O
transporte glTF em si é **exato**: medido sem a decimação, o desvio é 0,000° em
todos os 33.

O importador decima com a mesma tolerância do baker de propósito: sem isso um
clipe que atravessa o Blender volta com uma chave por quadro e o ganho de edição
(seção 11.4) some na primeira ida-e-volta.

O teste faz a ida e a volta sozinho, em memória — não precisa dos dois comandos
acima — e por isso entrou no `./validar.sh rapido`.

Chegar nesse número exigiu resolver dois problemas do exportador glTF do Godot,
os dois medidos:

1. ele **reamostra a 30 fps fixos** e `GLTFState.bake_fps` não muda isso na
   exportação (pôr 60 ou 120 devolve as mesmas 39 chaves de 1,25 s);
2. ele trata a faixa `:rotation` como **rotação** e interpola por **slerp**,
   enquanto o jogo interpola a mesma faixa em **euler linear**. Longe do gimbal
   as duas curvas coincidem; perto dele, não. No `chapa_2`, entre duas chaves em
   que a canela cruza x ≈ −π/2, o euler salta de (−1,44; 2,38; −2,21) para
   (−1,78; 3,65; −3,50) — a mesma rotação andando pouco — e as duas
   interpolações se afastam **6,04°** no meio do intervalo.

Esticar o tempo sozinho não resolvia o (2): subir a superamostragem de 3× para
10× só levava o desvio de 6,4° para 6,0° — platô. A solução ataca os dois:
**reamostrar o clipe com a interpolação do próprio jogo** antes de exportar, e
**esticar o tempo por 2** para a grade de 30 fps do exportador cair exatamente
em cima dessas chaves. O fator viaja no nome da animação (`punching__x2`), então
o importador desfaz o esticamento no que saiu daqui e deixa em paz um `.glb`
autorado do zero no Blender.

As duas conversões moram em **`src/anim/PonteBlender.gd`**, e as três pontas
(exportador, importador e o teste) chamam de lá — o teste faz a volta inteira em
memória, então ele exercita o mesmo código que as ferramentas usam. Reimplementar
a conversão dentro do teste o deixaria passar com as ferramentas quebradas.

O importador **recusa** um arquivo em que falte a faixa de algum papel — importar
meio clipe deixaria o membro congelado na pose de repouso, e isso não aparece em
teste automático nenhum, só em jogo.

### 11.7 Editor em Python alinhado

`tools/anim_editor/` grava `.tres` com caminho hierárquico, tirado da hierarquia
**real** do personagem carregado (`Rig.pais`), não de uma tabela fixa. O
`PAI_CANONICO` também passou a ter `Head` sob `Neck`, e a posição de repouso da
cabeça virou relativa ao pescoço (0,54 − 0,34 = 0,20).

### 11.8 Verificação

| instrumento | resultado |
|---|---|
| `medir_pose_res.gd` (29 clipes × 13 papéis, contra cópia anterior) | `DIFF_max ≤ 0,999°` em 12 dos 13 papéis, **0 clipes fora da tolerância**. O 13º é o `Head` — mudou em todos os 29, que é o bug saindo |
| `medir_impacto_res.gd` (calibra o `src/combat/Melee.gd`) | **7 das 8 medições idênticas** (Δ 0,0000 s). A única que andou (0,067 s) é a perna esquerda do `punching`, membro que não bate |
| `test_ida_e_volta_blender.gd` | **33/33 com desvio ≤ 0,999°** (o teto da decimação), durações idênticas. Sem a decimação da volta: 0,000° nos 33. Entrou no `./validar.sh rapido` — faz o ciclo sozinho, sem preparo |
| `test_compila.gd` | as mesmas 3 falhas de antes (`test_peer.gd`, `test_singleplayer.gd`, `test_spawner.gd` — scripts soltos na raiz). Conferido rodando o mesmo teste num worktree do `HEAD`: idêntico |
| `test_biblioteca_anim.gd` | 33/33 no contrato. Verificado que REPROVA, com quatro defeitos fabricados de propósito (ver 11.9.1) |
| `./validar.sh rapido` | ver 11.9 |

### 11.9 O gate: o que estava vermelho, e por quê

O gate saiu de **25 passou / 7 falhou** para **31 passou / 2 falhou**.

Nenhuma das 7 falhas iniciais vinha desta intervenção — todas foram reproduzidas
num worktree do `HEAD`, sem nenhuma das mudanças. Cinco foram consertadas; as
duas que sobram (`test_initial_fruit` e `net_mp_probe`) não são de animação.

Cinco delas tinham a **mesma causa raiz**, e não era animação: o campo
`_movement_locked_timer` foi aposentado quando a trava de movimento virou estado
da FSM (`Player._fsm`, commit "Fix Tela Cinza"), e **sete pontos do projeto
continuaram falando com ele**. Em GDScript isso falha de duas maneiras, as duas
péssimas:

- **escrever** num campo inexistente (`obj.campo = x`) é erro de runtime que
  **aborta a corrotina na hora** — o teste morre no meio e relata o sintoma
  errado;
- **`obj.set("campo", x)`** e `if "campo" in obj` são **no-op silenciosos** — o
  código acha que fez e não fez, sem erro nenhum.

| teste | o que estava errado | agora |
|---|---|---|
| `test_gura_animacoes` | **a sonda**, não a animação: `_player._movement_locked_timer = 0.0` abortava `_conjurar()`, e os 4 golpes reprovavam com "não consegui amostrar o corpo" | ✅ verde — o T sai em 80,3° simétrico, com ultrapassagem de +8,4° |
| `test_morte_limpa_cast` | **LER** o mesmo campo abortava o teste antes do `quit()` — o gate acusava TIMEOUT de 120 s, como se o jogo travasse ao morrer (o bug que o teste vigia) | ✅ verde, exit 0 |
| `test_player_rig` | **o teste**, não o rig: exigia `scale.z = scale.y × 1,85`, regra de antes de a profundidade migrar para a geometria. Reprovava o conserto que o `PLANO_ANIMACAO_PROCEDURAL` pedia | ✅ verde — mede escala uniforme **e** o engrossamento na malha (1,85× medido) |
| `test_compila` | 3 scripts de rascunho na raiz usavam `multiplayer` (que é de `Node`) dentro de `SceneTree` | ✅ verde — trocado por `get_multiplayer()` |
| `net_mp_probe` | as duas sondas liam `HealthController.REGEN_ENERGIA`, constante que virou percentual (`REGEN_ENERGIA_PCT`) — o script **não compilava**, e era isso que também mantinha o `test_compila` vermelho depois dos 3 rascunhos | corrigido: derivam a taxa da constante viva |
| `test_initial_fruit` | esperava `gura_gura`, veio `mera_mera` | **aberto** — regra de jogo, fora do escopo |

(A sétima falha era o `test_ida_e_volta_blender` novo, que dependia de arquivos
preparados à mão. Foi reescrito para fazer o ciclo inteiro em memória.)

**O mesmo campo estava quebrando o JOGO, não só os testes.** Três pontos de
efeito soltavam o jogador no fim do golpe escrevendo nele — e como usavam
`set()` e `if "campo" in`, não faziam **nada**, em silêncio:

| arquivo | o que deveria acontecer |
|---|---|
| `src/effects/YamiFX.gd` `_unlock_caster()` | soltar o caster no fim do Kurouzu |
| `src/effects/YamiFX.gd` (Black Hole) | soltar o caster no fim do Black Hole |
| `src/effects/GoroFXGrande.gd` `_liberar_jogador()` | soltar o caster no fim do Mamaragan |

Correção: `Player.unlock_movement()` — o **inverso exato** do que o
`lock_movement` faz hoje (limpar a meta `active_skill`), e nada além disso. Quem
é dono do resto da trava é a FSM, e mexer nela de dentro de um nó de VFX seria
adivinhação. Os três pontos passaram a chamar esse método.

Varredura final: **zero usos vivos** de `_movement_locked_timer` e de
`HealthController.REGEN_ENERGIA` no projeto.

**As duas famílias são o mesmo erro:** um membro público-de-fato removido sem
varrer os chamadores. Uma falhou em silêncio (`set()` e `"campo" in obj`), a
outra ruidosamente (não compila) — e as duas sobreviveram meses, a segunda
porque o `test_compila` afoga o erro real em dezenas de
`Identifier not found: <autoload>` que são esperados num `--script`.

### 11.9.1 Guarda nova: a biblioteca inteira, clipe a clipe

`tools/dev_tests/test_biblioteca_anim.gd` varre **todo** `.res`/`.tres` da pasta
e confere cinco coisas: os 13 papéis presentes, o caminho resolvendo na árvore
real do personagem, faixas com chaves de verdade, o clipe não estar congelado, e
`loop_mode` só onde o ciclo de fato fecha.

Existe porque as duas falhas silenciosas desta base passaram por aí: o `.res`
com zero chaves de 2026-08-10 e o caminho plano de agora. Nos dois casos o
arquivo existia, o jogo rodava e nenhum teste falhava.

**Verificado que ele reprova**, fabricando os quatro defeitos de propósito:

```
_mau_plano.res       ❌ caminho não resolve no rig: Neck, Head, UpperArm_L, … (12)
_mau_sem_head.res    ❌ sem faixa para Head
_mau_congelado.res   ❌ CONGELADO — nenhum papel se move (amplitude máx 0.00°)
_mau_loop.res        ❌ loop_mode ligado mas o ciclo abre 111.08° (teto 5.0°)
```

### 11.10 Efeitos colaterais declarados

- **Quatro clipes novos** apareceram: `alert`, `walking`, `running`,
  `walk_backward_inplace`. Vêm do mesmo `meshy_blue_block_buddy.glb` que já dava
  os dois socos de guarda, e surgiram porque o bake completo assa o arquivo
  inteiro. Apagar não estabiliza (o próximo bake os recria), então viraram
  **decisão declarada**: auditados (nenhum membro congelado), os três de
  locomoção entraram no `CICLICOS` do baker com `loop_mode`, e ficam como
  referência humana no mesmo rig para calibrar a marcha procedural nas Fases 2 e
  3. O `running` está na lista e **não** recebeu o loop — abre 12,05°, e o baker
  avisa em vez de gravar metadado errado.
- **O aviso `<<< SALTO ALTO` do baker foi removido.** Ele media o passo entre
  chaves vizinhas, e esse número perdeu sentido com a decimação: ela afasta as
  chaves de propósito, e o que garante é o **erro de pose** (≤ 1°), não o
  espaçamento. Tentei realertar pela versão geodésica e foi pior — marcava 8
  clipes sadios em 33, porque um chute rápido tem 71° de giro real entre duas
  chaves e está correto. O alarme voltou para o que de fato pode falhar: o
  destorcimento do euler (gimbal), acima de 180°. Hoje: **zero alertas em 33**.
- **`assets/blender/` entrou no `.gitignore`**: é derivado dos `.res` por um
  comando só e mudaria a cada rebake.
- **`Player.unlock_movement()` é API pública nova.** Foi o mínimo necessário
  para os três efeitos soltarem o jogador de verdade (11.9) — o inverso exato do
  `lock_movement`, sem tocar na FSM.

### 11.11 O que continua aberto

> Detalhado, com alvos e comandos, em
> [`PLANO_ANIMACAO_FASES_2_3_4.md`](PLANO_ANIMACAO_FASES_2_3_4.md).

As **Fases 2, 3 e 4** do plano, inteiras. Em particular, e sem elas a
movimentação não fica fluida:

- os **131,11°/frame** na entrada do clipe e os **61,07°** na saída;
- o **bob do torso congelado** durante o clipe;
- a **perna do `base` com 31,2% da altura** (cânone 49,1%) e a **canela 50% mais
  longa que a coxa**;
- as **749 linhas de pose autoral em GDScript**, que só voltam a ser clipes
  depois que o `play_baked` souber misturar.
