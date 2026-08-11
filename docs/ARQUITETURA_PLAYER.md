# Arquitetura do Player — decisão e plano de execução

**Decidido pelo dono do projeto em 2026-08-11**, a partir do
[`RELATORIO_PLAYER.md`](RELATORIO_PLAYER.md). Este documento é a **fonte da
verdade** do desenho; o relatório é a medição que o embasou.

> **O objetivo NÃO é chegar a 900 linhas.** É que cada componente tenha
> responsabilidade coerente, estado próprio e fronteira clara. As 900 linhas são
> consequência, não meta.

---

## O princípio que resolve os 22 campos compartilhados

**Cada componente é dono do seu estado; o Player combina os resultados.**

Hoje o problema é este:

```
        velocity
           ↑
     Movimento  (escreve)
           ↑
     Knockback  (escreve)     ← dois donos, um campo
```

O desenho novo:

```
  MovementController  →  movement_velocity
  HealthController    →  knockback_velocity
                              ↓
                      Player / física
                              ↓
                        velocity final
```

**Isto não é teoria — já foi provado neste projeto.** O knockback não funcionava
justamente porque a locomoção reatribuía `velocity.x/z` todo quadro. A correção
foi dar ao empurrão um campo próprio (`_kb_impulso`), somado depois pelo ciclo.
Funcionou. O que a refatoração faz é **generalizar esse padrão** para os outros
21 campos compartilhados.

---

## O desenho

```
                         PLAYER
                           │
                    ┌──────┴──────┐
                    │  player.gd  │
                    │ ORQUESTRADOR│
                    └──────┬──────┘
                           │
       ┌──────────┬────────┼────────┬──────────┐
       ↓          ↓        ↓        ↓          ↓
   Movement     Combat   Health   Camera      Rig
       │          │
   ┌───┼───┐   ┌──┼───┐
   ↓   ↓   ↓   ↓  ↓   ↓
 Move Park Dash Skill Buki Melee
```

```
player/
├── player.gd                      ← ORQUESTRADOR (não um repassador burro)
├── movement/
│   ├── movement_controller.gd
│   ├── parkour_controller.gd
│   └── dash_controller.gd
├── combat/
│   ├── skill_controller.gd
│   ├── buki_controller.gd
│   └── melee_controller.gd
├── health/health_controller.gd
├── camera/camera_rig.gd
├── rig/player_rig.gd
└── taming/tame_controller.gd
```

### O que o `player.gd` continua fazendo

Inicialização · referências aos componentes · ciclo principal · autoridade ·
estado global · **ordem de execução** · integração entre sistemas · o que
realmente pertence ao Player.

### Granularidade: controller por domínio, não arquivo por verbo

**Não** fazer `andar.gd`, `correr.gd`, `pular.gd`, `gravidade.gd`. Andar, correr,
pular e gravidade conversam o tempo todo com `velocity`, `is_on_floor()`,
direção, input e estado — separá-los criaria exatamente o problema de
arquitetura que queremos evitar. Módulo interno só quando houver complexidade
real.

---

## Fases

| # | fase | por quê nesta ordem |
|---|---|---|
| **1** | **Quebrar o `_physics_process` em etapas nomeadas — sem mover nada de arquivo** | entender as dependências ANTES de mover código |
| 2 | `CameraRig` | valida o padrão com risco mínimo |
| 3 | `PlayerRig` | valida componente visual; 248 linhas de retorno |
| 4 | `MovementController` → `ParkourController` → `DashController` | o coração do ciclo físico |
| 5 | `BukiController` | tem RPC → exige teste com dois processos |
| 6 | `SkillController` | idem |
| 7 | `MeleeController` | idem |
| 8 | `HealthController` | aqui a posse dos estados é reorganizada |
| 9 | Reduzir `player.gd`, conferir o limite | consequência, não meta |

### Fase 1, em detalhe

```
ANTES                          DEPOIS
_physics_process()             _physics_process()
  ├── movimento                  ├── process_movement()
  ├── parkour                    ├── process_combat()
  ├── dash                       ├── process_health()
  ├── habilidades                ├── process_animation()
  ├── energia                    └── process_network()
  ├── animação
  ├── rede / Buki / câmera
  └── melee            [291 linhas]
```

**Nada sai do arquivo nesta fase.** É o passo que revela as dependências reais —
e é barato de reverter se estiver errado.

---

## ⚠️ Duas correções técnicas ao plano

Levantadas na medição; mudam **como** executar, não o desenho.

### 1. RPC em nó filho FUNCIONA — eu fui pessimista demais no relatório

O relatório dizia que mover método `@rpc` para outro nó "quebra a chamada". A
frase está incompleta. O RPC do Godot resolve por **caminho de nó**, então mover
o método muda o caminho — mas a chamada continua funcionando **se todos os peers
montarem a mesma árvore**.

E eles montam: o player nasce em `Main._spawn_player_data`, que é determinística
e roda igual no servidor e em cada cliente. Basta os componentes serem
adicionados **ali, antes do nó entrar na árvore**, como já é feito com o
`MultiplayerSynchronizer`.

**O que exige cuidado de verdade:** a autoridade é definida com
`set_multiplayer_authority(id)` no player, e ela é **recursiva** — pega os
filhos. Então o componente precisa ser filho **antes** dessa chamada, senão
nasce com autoridade errada e o `_is_authority` dele mente.

### 2. O `MultiplayerSynchronizer` precisa acompanhar a mudança

Hoje ele replica por caminho relativo ao player:

```gdscript
for p in ["position", "net_velocity", "net_facing", "net_on_floor", "current_fruit_id"]:
    cfg.add_property(NodePath(".:" + p))
```

Se `current_fruit_id` passar para o `SkillController`, o caminho vira
`Combat/Skill:current_fruit_id`. **Isso é editado no `Main.gd`, não no player** —
e é fácil esquecer, porque nada quebra na compilação: a propriedade
simplesmente para de replicar, e o sintoma aparece só com dois jogadores.

---

## Como cada fase é validada

```bash
godot --headless --path . --script tools/dev_tests/test_compila.gd   # 0
godot --headless --path . --script tools/dev_tests/test_arena.gd     # 53 checagens
godot --headless --path . --script tools/dev_tests/test_buki_buki.gd # 24
godot --headless --path . --script tools/dev_tests/test_frutas.gd    # 9 frutas, 4/4
godot --headless --path . --script tools/dev_tests/test_walk_run.gd
```

**As fases 5, 6 e 7 exigem, além disso, dois processos:**

```bash
godot --headless --path . --script tools/dev_tests/net_host_probe.gd     # terminal 1
godot --headless --path . --script tools/dev_tests/net_client_probe.gd   # terminal 2
```

⚠️ **O ponto cego que nenhuma suíte cobre:** input, câmera e o que se vê na tela.
Nenhum teste headless acusa mira dessincronizada, arma no lugar errado ou golpe
que parou de responder ao clique. Depois de cada fase de risco, vale abrir o jogo.

---

## Registro de execução

| fase | estado | commit |
|---|---|---|
| 1 — etapas no `_physics_process` | ✅ **feita** — 291 → 32 linhas | ver abaixo |
| 2 — `CameraRig` | ✅ **feita** — componente de 201 linhas; Player 2.167 → 2.128 | ver abaixo |
| 3 — `PlayerRig` | ✅ **feita** — componente com 291; Player 2.128 → 1.959 | ver abaixo |
| 4 — Movement / Parkour / Dash | ⏳ | — |
| 5 — `BukiController` | ⏳ | — |
| 6 — `SkillController` | ⏳ | — |
| 7 — `MeleeController` | ⏳ | — |
| 8 — `HealthController` | ⏳ | — |
| 9 — redução final | ⏳ | — |

---

## Fase 1 — feita em 2026-08-11

`_physics_process` foi de **291 para 32 linhas**, quebrado em 7 etapas nomeadas.
**Nada saiu do arquivo**, como planejado.

| etapa | linhas | corta o quadro? |
|---|---|---|
| `_etapa_estado_de_combate` | 26 | não |
| `_etapa_travamento` | 41 | **sim** — devolve `true` e o quadro acaba |
| `_etapa_locomocao` | 206 | não |
| `_etapa_ticks_de_combate` | 6 | não |
| `_etapa_publicar_rede` | 9 | não |
| `_etapa_vida` | 17 | **sim** — morte no vazio |
| `_etapa_mover` | 14 | não (é o último) |

**Prova de que o comportamento não mudou:** comparando o corpo antes e depois,
**205 das 206 linhas de código são idênticas** — a única diferença é a própria
assinatura `func _physics_process(...)`. Reempacotamento puro. Suíte: compila 0,
arena 53, buki 24, walk_run, rig_unico, anatomia_rig.

### O que a Fase 1 revelou, e que muda a Fase 4

Entrada, parkour, dash, locomoção, facing e animação **ficaram numa etapa só**
(`_etapa_locomocao`, 206 linhas). Isso é conclusão medida, não preguiça: os seis
compartilham os mesmos locais de quadro —

`dir` · `f`/`r` · `is_sprinting` · `on_floor_now` · `wall_normal` · `side_wall` ·
`wall_running` · `dash_step` · `effective_speed`

Separá-los agora obrigaria a passar tudo isso de mão em mão, trocando
acoplamento por cerimônia sem ganhar clareza.

> **Os locais compartilhados são a métrica do acoplamento.** Enquanto forem
> tantos, `MovementController`, `ParkourController` e `DashController` são **o
> mesmo componente**. A Fase 4 começa reduzindo essa lista, não criando três
> arquivos.

Isso refina o plano: a Fase 4 ganha um passo zero — **encolher os locais
compartilhados** — antes de qualquer separação.

---

## Fase 2 — `CameraRig`, feita em 2026-08-11

`src/player/camera_rig.gd`, **201 linhas**. O `Player.gd` foi de 2.167 para
**2.128**. Primeiro componente de verdade extraído: ele **é** o pivô da câmera,
e a cadeia inteira nasce dentro dele —
`CameraRig → Ombro → SpringArm → Camera3D`.

### O conflito que esta fase existia para resolver

`_fov_punch` era um dos 22 campos compartilhados, e um dos piores: **três
domínios escrevendo direto** (corpo a corpo, habilidades e o ciclo). Virou
**pedido**:

```gdscript
_fov_punch = 8.0            # antes: qualquer um escrevia no campo
_camera.pedir_fov_punch(8.0)  # agora: pede, e o dono decide como decai
```

Mesmo padrão do `pedir_shake`, que já existia. **Restam 21 campos
compartilhados.**

### Fronteira: o que o rig é dono, e o que ele só lê

| é dono | só lê, por parâmetro |
|---|---|
| `_shake`, `_fov_punch`, `_bob_t`, perspectiva, `distancia`, os nós da cadeia | velocidade, chão, sprint, `yaw`, luneta |

### O que **não** saiu do Player, e por quê

Três decisões conscientes — vale registrar, porque "não mover" também é escolha:

- **`_yaw` / `_pitch` ficam.** Quem os escreve é o **input** e a mira assistida
  das armas. O rig só **aponta** (`apontar(yaw, pitch)`). Movê-los agora trocaria
  o dono do problema, não resolveria.
- **`_cam` continua no Player**, como atalho para `_camera.camera()`. A mira o
  consulta em **26 lugares**; mantê-lo evitou 26 edições de risco com ganho zero.
- **`add_camera_shake` continua no Player.** Muita coisa de fora chama (efeitos
  das frutas, corpo a corpo, pouso). Ele **repassa** ao rig — melhor do que
  espalhar o componente pelo código todo.

### Validação

`tools/dev_tests/test_camera.gd` (novo, **13 checagens**) ataca exatamente o
ponto cego declarado acima: mede o que a tela mostraria.

| prova | número medido |
|---|---|
| cadeia montada e câmera local ativa | `current == true` |
| `apontar(1.2, -0.3)` gira o rig | `y=1.20  x=-0.30` |
| tremor decai sozinho | `1.00 → 0.00` |
| soco de FOV decai | `8.0 → 0.0` |
| luneta da sniper fecha o FOV e volta | `68 → 23 → 68` |
| perspectiva move o pivô e volta | `2.20 → 0.60 → 2.20` |

Suíte: compila **0**, arena **53**, buki **24**, `walk_run`, `rig_unico`,
`frutas`. Zero referências órfãs aos campos removidos.

⚠️ **Ainda não visto na tela.** Os números provam que o rig responde aos
comandos; não provam que a câmera *parece* certa jogando. Esta fase mexeu em
câmera e input — exatamente o ponto cego — então vale abrir o jogo antes da
Fase 3.

---

## Fase 3 — `PlayerRig`, feita em 2026-08-11

`src/player/player_rig.gd`, **291 linhas**. O `Player.gd` foi de 2.128 para
**1.959** — a maior queda até agora (169 linhas).

### A medição que decidiu o desenho

Antes de mover qualquer coisa, procurei **onde esses campos são escritos**:

```
grep -nE "^\s*(_char_model|_proc_anim|_animator|...)\s*=" Player.gd
```

Todas as 17 escritas estavam **dentro do bloco de construção** (linhas
977–1149). Nenhuma fora. O domínio já era "um construtor e muitos leitores" —
só não tinha nome. Daí a fronteira:

> **O rig CONSTRÓI. O Player USA.**

O componente é dono do ciclo de vida do corpo visível: criar o modelo, medir e
assentar no chão, pendurar as pistolas e o arsenal da Buki, ligar o animador
procedural, soltar tudo na troca de personagem. Quem usa por quadro (facing,
pose, visibilidade, mira) continua no Player.

### Vistas em vez de cópias

O `_char_model` é lido em **~42 pontos** do Player, e o `BukiFX.gd` o pega de
fora **por nome** (`caster.get("_char_model")`). Copiar a referência para o
Player criaria dois donos — exatamente o que esta refatoração combate. Em vez
disso, os campos viraram **propriedades só-leitura que encaminham**:

```gdscript
var _char_model: Node3D:
	get: return _rig.modelo() if _rig else null
```

Um dono só, zero estado duplicado, e nenhum dos 42 pontos precisou mudar. E
escrever nesses campos passou a ser **impossível**: eles não têm setter.

### Por que o rig NÃO é o pai dos nós

Ele é um `Node` puro e adiciona os filhos ao **Player**, deixando a árvore
idêntica à de antes. Foi decisão de risco:

- `_char_model.rotation.y` / `.position.y` são escritos direto pelo facing e
  pelo fit — um nó intermediário entraria na conta das transformações;
- `_animator.animation_player.root_node = NodePath("..")` resolve pelo **pai**;
  com o rig no meio, `".."` deixaria de ser o Player.

> **Gatilho para revisitar:** se o rig algum dia precisar de transformação
> própria (inclinar o corpo inteiro sem mexer no facing), aí vale virar `Node3D`
> e reapontar o `root_node`.

### O conflito que isto resolveu

`_buki_armas` / `_buki_visual` tinham **dois donos** (Rig e Buki) — era o
conflito que o relatório mandava resolver antes deste corte. Ficou: o rig
**monta** as armas (elas nascem e morrem com o modelo), o combate decide **qual
aparece** (`_buki_visual`). **Restam 19 campos compartilhados** (eram 21).

### O que ficou no Player, e por quê

- **A trava de elenco.** `ELENCO_LIBERADO` e a guarda continuam no
  `_setup_character_model`, que virou política + delegação. Quem *pode* ser
  carregado é regra de **jogo**; o rig monta o que mandarem. O ponto de
  estrangulamento único (por onde menu, rede e `equip_fruit` passam) foi
  preservado — é o que o `test_elenco_trancado` prova.
- **O fôlego (`_breath`).** Sobrevive à troca de personagem e é reaproveitado;
  não pertence ao modelo. A condição "só voxel" foi preservada exatamente (no
  código antigo o `return` do ramo skinnado a pulava).

### Validação

`tools/dev_tests/test_player_rig.gd` (novo, **20 checagens**): o rig é dono do
corpo (modelo, procedural, cabeça, 2 pistolas, 4 armas da Buki, pivô), as vistas
do Player entregam **o mesmo objeto**, `get("_char_model")` ainda funciona (o
caminho do BukiFX), a árvore não mudou de forma, as regras do fit valem, e a
troca de personagem reconstrói tudo.

**A/B contra o commit anterior:** o fit do modelo saiu **idêntico bit a bit** —
escala `(0.416667, 0.416667, 0.770833)` e `pos.y = -0.8000` antes e depois.

Suíte: compila 0, arena 53, buki 24, frutas 0, walk_run, rig_unico,
anatomia_rig, elenco_trancado, camera 13.

✅ **Visto na tela** (ao contrário da Fase 2): o jogo foi aberto com renderizador
real, o clique em JOGAR levou ao mundo, e a foto mostra o personagem montado —
membros, marcador dourado das costas, HUD e fruta. Foi assim que o bug do
`class_name` apareceu; a lição pegou.
