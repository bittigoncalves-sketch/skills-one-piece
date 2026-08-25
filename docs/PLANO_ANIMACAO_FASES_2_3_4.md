# Plano — Animação, Fases 2, 3 e 4

> **Este é o ponto de entrada para continuar o trabalho de animação.**
> A Fase 1 está **feita e verificada** (2026-08-25). O diagnóstico completo, com
> os números de cada achado, está em [`AUDITORIA_ANIMACAO.md`](AUDITORIA_ANIMACAO.md).
> As causas dos bugs encontrados no caminho estão em [`erros.md`](erros.md).
>
> Feito para ser lido **frio**, por quem (ou qual agente) pegar a tarefa numa
> máquina nova. Carrega o contexto, os números medidos e os comandos.

---

## 0. Antes de tudo: a máquina nova

O projeto **não depende de nada instalado por gerenciador de pacote**, mas duas
ferramentas têm que existir e nenhuma das duas está no `PATH` por padrão.

| ferramenta | para quê | como o projeto acha |
|---|---|---|
| **Godot 4.6.x** | rodar o jogo, o baker, os testes, a ida/volta do Blender | `./find_godot.sh` — procura `$GODOT`, depois o `PATH`, depois `~/Downloads/Godot_v4.6*` e `~/opt/godot*` |
| **Blender 4.x+** | só o passo `FBX → GLB` (`tools/fbx_to_glb.py`) e a edição manual | caminho chumbado nos scripts `.py` da raiz — **conferir e ajustar** |

⚠️ **Na máquina em que a Fase 1 foi feita o Blender NÃO estava instalado.** Tudo
que precisou dele foi contornado pelo `GLTFDocument` do próprio Godot. Isso quer
dizer que a **ida e a volta do Blender nunca foram exercitadas com o Blender de
verdade** — só provadas pelo round-trip glTF↔glTF do Godot, que dá 0,000° de
desvio nos 33 clipes.

> **Primeira tarefa na máquina nova, antes da Fase 2:**
> abrir `assets/blender/rig_base_completo.glb` no Blender de verdade, conferir
> que os 13 objetos aparecem na hierarquia certa e que as 33 Actions estão lá,
> mexer numa curva, reexportar e reimportar. Se algo quebrar, quebra **aqui** —
> e é barato consertar antes de a Fase 2 empilhar mudanças em cima.

### Preparar o repositório numa máquina nova

```bash
git clone <repo> && cd skills-one-piece
export GODOT=/caminho/do/Godot_v4.6.3-stable_linux.x86_64

# 1. cache de import do Godot (~149 MB, NÃO versionado)
"$GODOT" --headless --import --path .

# 2. o .glb para editar no Blender (derivado, NÃO versionado — ver .gitignore)
"$GODOT" --headless --path . -s tools/exportar_para_blender.gd

# 3. o portão
./validar.sh rapido
```

⚠️ **O passo 1 é obrigatório depois de criar qualquer `class_name` novo.** Sem
ele o Godot não registra a classe no cache global e scripts que a usam falham com
`Identifier "X" not declared` — foi o que aconteceu ao criar o `RigContrato`.

---

## 1. Onde as coisas estão

### O que a Fase 1 entregou

| | antes | depois |
|---|---|---|
| faixas do clipe que resolvem como `NodePath` | 1 de 13 | **13 de 13** |
| chaves por osso (editabilidade) | 145 | **34** |
| giro parasita na cabeça | até 64,01° | **0°** |
| clipes com `loop_mode` | 0 de 29 | 4 de 33 |
| ida e volta pelo Blender | impossível | **33/33, desvio ≤ 0,999°** |

### Os arquivos que passaram a mandar

| arquivo | papel |
|---|---|
| `src/anim/RigContrato.gd` | **fonte única** dos 13 papéis, da hierarquia e do formato da faixa |
| `src/anim/PonteBlender.gd` | as duas conversões do Blender (reamostragem, tempo, decimação) |
| `src/anim/ProceduralAnimator.gd` | o pipeline por quadro — **é aqui que a Fase 2 mora** |
| `src/anim/BodyScanner.gd` | mede o corpo → perfil que escala passada/IK |
| `src/anim/SkeletonDriver.gd` | ponte rig↔`Skeleton3D` (personagens Meshy) |
| `tools/bake_mixamo.gd` | GLB → `.res` (decimação, `loop_mode`) |
| `tools/exportar_para_blender.gd` / `tools/importar_do_blender.gd` | o ciclo do Blender |

### O portão

```bash
./validar.sh rapido      # pula os lentos (test_frutas, traço)
./validar.sh             # tudo
```

**Estado em 2026-08-25: 31 passou / 2 falhou / 1 pulado.** As duas que faltam
estão na seção 5 e não são de animação — é essa a linha de base a bater. Se
aparecer uma terceira, ela é sua.

Dois testes de animação entraram nele na Fase 1 e **têm que continuar verdes**:

- `test_biblioteca_anim` — os 33 clipes contra o contrato do rig;
- `test_ida_e_volta_blender` — o ciclo `.res → .glb → .res` em memória.

---

## 2. FASE 2 — fluidez da movimentação

**É a fase que o dono pediu primeiro** ("trazer fluidez às animações de
movimentação"). Nada aqui muda proporção, nem recalibra o walk aprovado em tela,
nem mexe nos tempos de impacto do `Melee`.

### O problema, medido

```bash
godot --headless --path . -s tools/dev_tests/medir_transicoes.gd
```

```
REGIME PERMANENTE (andando 4,2 m/s)
  maior giro de junta num frame: 16,19°/frame     <- a régua

ENTRADA no clipe 'punching' (play_baked)
  salto no 1º frame: 131,11° (ForeArm_R)  -> 8,1x o passo normal
  torso.y  antes=0,7639  durante=0,7639  (congelado: sim)

SAÍDA do clipe (volta para locomoção)
  maior salto nos 20 frames seguintes: 61,07° (ForeArm_R) no frame +2 -> 3,8x

IDLE -> SPRINT (blend procedural)
  maior salto: 43,73° (Thigh_L) -> 2,7x
```

**A causa é uma linha.** `ProceduralAnimator._apply_baked` escreve a pose do
clipe **direto** no nó:

```gdscript
(_n[role] as Node3D).rotation = euler        # sem lerp, sem peso, sem fade
```

O resto do animador nunca faz isso — acumula offsets num dicionário `off` e
aplica com `1.0 - exp(-STIFFNESS * delta)`. O clipe é a **única** coisa no
sistema que pula o filtro.

### As quatro tarefas

**2.1 — `_baked_w`: o clipe vira uma camada, não um override**

O clipe entra como mais um peso do `off`, subindo e descendo por `exp` como os
outros 29 pesos do arquivo. Entrada ~0,12 s, saída ~0,18 s (a entrada tem que ser
mais rápida: o golpe precisa responder).

- **Alvo: o salto de entrada cai de 131,11° para < 20°/frame.**
- Instrumento: `medir_transicoes.gd`, mesmo comando, antes e depois.
- ⚠️ Cuidado com o `_melee_stance_w`, que hoje é um override **sobre** o clipe
  dentro do próprio `_apply_baked` — ele tem que continuar rodando **antes** do
  `_driver.push()`, senão a postura some nos personagens skinnados.

**2.2 — Máscara por papel**

`play_baked` ganha um modo: `bracos` / `tronco` / `corpo_inteiro`. É o que
permite o soco tocar por cima da corrida sem congelar as pernas — e é
**pré-requisito da Fase 4.1**.

- A lista de quem toma o corpo inteiro já existe em espírito:
  `GuraPoses.CORPO_INTEIRO`. Vale reaproveitar a ideia.
- Quem consome: `Player._net_play_melee` (`src/combat/Melee.gd` → `Melee.passo`
  já devolve um dicionário por golpe; a máscara cabe ali).

**2.3 — O bob do torso não pode congelar**

`update()` tem um `return` antecipado quando `_baked != null`, e ele pula o bloco
que escreve `Torso.position`. O corpo fica pendurado no offset que tinha no
quadro da chamada, o golpe inteiro.

- **Alvo: `torso.y` continua variando durante o clipe** (o `medir_transicoes.gd`
  já imprime `congelado: sim/não`).

**2.4 — Suavizar a troca de regime da IK**

Os 43,73° do `idle → sprint` não são o crossfade de pesos (esse já existe) — são
a **IK**: `_altura_quadril()` e `_passada()` mudam em degrau quando `speed01` e
`is_sprinting` mudam. Filtrar as duas entradas (não a saída) resolve.

- **Alvo: < 25°/frame.**
- ⚠️ **Não filtrar a cadência junto sem pensar.** `cadencia()` é a fonte única
  que casa o pé com o chão (`ω = π·v/passada·ESCALA`); se a passada filtrada e a
  cadência discordarem por um instante, o pé desliza nesse instante. Filtre a
  passada e recalcule a cadência a partir dela, no mesmo quadro.

### Critério de aceite da Fase 2

```bash
godot --headless --path . -s tools/dev_tests/medir_transicoes.gd
./validar.sh rapido      # test_walk_run e test_arena continuam verdes
```

Entrada < 20°/frame, saída < 25°/frame, `idle→sprint` < 25°/frame, bob não
congela — e **nenhum teste que estava verde fica vermelho**.

---

## 3. FASE 3 — o esqueleto (precisa de decisão do dono)

**Esta fase muda proporção, e proporção recalibra coisas aprovadas em tela.**
Não começar sem o dono dizer que sim.

### 3.1 — Os dois construtores voxel montam esqueletos DIFERENTES

| | coxa | canela | tem `Neck`? |
|---|---|---|---|
| `VoxelMeshes._build_skeleton` (nami, ace, …) | 0,30 | 0,30 | **não** |
| `base.scn` / `buggy.scn` (o boneco principal) | 0,25 | 0,375 | **sim** |

O `RigContrato` já declara `Head` sob `Neck`, que é a árvore do `.scn`. Quem
nasce do `VoxelMeshes` **não tem** o nó `Neck` — o `_apply_baked` ignora a faixa
(`if _n.has(role)`) e a cabeça perde o movimento do pescoço. Não quebra, mas
diverge. **Unificar é pré-requisito do resto da fase.**

### 3.2 — As proporções

```bash
godot --headless --path . -s tools/dev_tests/auditar_esqueleto.gd
```

| personagem | coxa (% h) | canela (% h) | canela/coxa | perna total (% h) | simetria L/R |
|---|---|---|---|---|---|
| **cânone humano** | 24,5% | 24,6% | ~100% | **49,1%** | 0% |
| **base** | 12,5% | 18,8% | **150%** | **31,2%** | 0,00% |
| buggy | 10,9% | 16,4% | **150%** | 27,3% | 0,00% |
| nami | 21,8% | 19,1% | 87% | 40,9% | 3,68% ⚠ |
| ace | 22,7% | 15,4% | 68% | 38,1% | 0,01% |
| blackbeard | 20,4% | 11,4% | **56%** | 31,8% | 2,28% ⚠ |
| crocodile | 28,1% | 21,5% | 77% | 49,6% | **26,02%** ⚠ |

**O que isso custa hoje.** O `ProceduralAnimator` documenta que os 45% de deslize
de pé são o preço de `CADENCIA_ESCALA`, e que "o conserto de verdade é reduzir
`Player.SPEED`". **Está incompleto:**

```bash
godot --headless --path . -s tools/dev_tests/simular_perna_canonica.gd
```

```
perna    caso   v(m/s)  passada  passos/s com pé cravado
0,469    WALK    4,2     0,531        7,91          <- hoje
0,737    WALK    4,2     0,834        5,04          <- perna canônica  (−36%)
```

A cadência de pé cravado cai **36%** só por corrigir a perna, sem tocar em
`SPEED` nem em `CADENCIA_ESCALA`. **Metade do orçamento de deslize está preso na
proporção do rig, não na fórmula.**

### 3.3 — Re-rigar os Meshy e USAR o resultado

O `tools/anim_editor/rigger.py` já resolve isso (o README documenta o blackbeard
indo de 54% para 99% de canela/coxa), mas **o resultado nunca foi aplicado ao
runtime** — o jogo continua lendo o esqueleto cru do FBX. O `crocodile` está com
26% de assimetria entre lados.

### ⚠️ O que quebra ao mexer aqui, e como provar que não quebrou

| o que | instrumento |
|---|---|
| o walk aprovado em tela | `tools/dev_tests/test_walk_run.gd` + o dono olhando |
| os tempos de impacto do `src/combat/Melee.gd` | `tools/dev_tests/medir_impacto_res.gd` — **rodar antes e depois** |
| a pose dos 33 clipes | `tools/dev_tests/medir_pose_res.gd` (copie os `.res` atuais para `user://ref_anim/` **antes** de mexer) |
| a anatomia dos skinnados | `tools/dev_tests/test_anatomia_rig.gd` |

---

## 4. FASE 4 — o que sobra

**4.1 — Tirar a animação autoral do GDScript** *(depende da Fase 2.2)*

749 linhas de tabelas de quadros-chave escritas à mão:

| arquivo | linhas | o que anima |
|---|---|---|
| `src/anim/GuraPoses.gd` | 445 | os 4 golpes da Gura Gura |
| `src/anim/FruitPoses.gd` | 112 | Hibashira, Kurouzu, Black Hole, rush |
| `src/anim/MeleePoses.gd` | 102 | postura do combo desarmado |
| `src/anim/WeaponPoses.gd` | 90 | idle e corte da espada |

O próprio `GuraPoses.gd` documenta o porquê no cabeçalho: *"o `play_baked`
SOBREPÕE O CORPO INTEIRO […] As poses daqui SOMAM"*. **Com máscara e blend
(Fase 2), esses quatro arquivos voltam a ser clipes** — editáveis no Blender.

⚠️ Migrar **um golpe** primeiro, comparar em tela com o `medir_gura_rush.gd` /
`test_gura_animacoes.gd`, e só então os outros.

**4.2 — Eventos de impacto no clipe**

Hoje o dano sai por tempo no código do golpe, não pela animação. O
`medir_impacto_res.gd` já sabe achar o quadro de impacto por cinemática direta —
falta gravar isso no clipe e o `Melee` ler de lá.

**4.3 — Root motion**

O baker descarta a translação do quadril (`Sem root motion` em
`ANIMACOES_MIXAMO.md`). Clipe que "anda" no Mixamo fica no lugar.

**4.4 — Ampliar o rig para 17 papéis**

`Hips`, `Shoulder_L/R`, `Hand_L/R`. O Mixamo **já traz essas curvas** e o baker
as joga fora — "animação cujo charme está no punho ou no giro de ombro perde
parte da leitura". Mexe no `RigContrato.PAPEIS` e obriga rebake + re-rig.

---

## 5. Fora do escopo de animação, mas aberto

Estas duas falham no `./validar.sh rapido` e **não são de animação** — ficam para
quem cuida das áreas:

| teste | falha |
|---|---|
| `test_initial_fruit` | esperava `gura_gura`, veio `mera_mera` — regra de jogo |
| `net_mp_probe` | multiplayer com dois processos (as duas sondas foram consertadas na Fase 1; a falha restante não foi investigada) |

---

## 6. Regras desta base que valem para as próximas fases

Estão em [`guia/COMO_TRABALHAR.md`](guia/COMO_TRABALHAR.md), e a Fase 1 pagou
para reaprender duas:

1. **Número, não adjetivo.** Mesmo instrumento antes e depois. Todos os
   instrumentos estão em `tools/dev_tests/` e a seção 9 da
   [`AUDITORIA_ANIMACAO.md`](AUDITORIA_ANIMACAO.md) lista o que cada um mede.

2. **Quando um teste de comportamento visual falha, o primeiro suspeito é a
   SONDA, não o comportamento.** Na Fase 1, cinco falhas do gate que pareciam
   cinco bugs diferentes eram **um campo aposentado** que ninguém varreu ao
   remover. Duas delas acusavam a animação da Gura e o travamento ao morrer —
   ambos intactos. Ver [`erros.md`](erros.md), 2026-08-25.

3. **Remover um membro público-de-fato não é edição local.** `obj.set("campo", x)`
   e `if "campo" in obj` **não avisam** quando o campo some. A única rede é varrer
   os chamadores no mesmo commit.
