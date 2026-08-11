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
| 1 — etapas no `_physics_process` | ⏳ não iniciada | — |
| 2 — `CameraRig` | ⏳ | — |
| 3 — `PlayerRig` | ⏳ | — |
| 4 — Movement / Parkour / Dash | ⏳ | — |
| 5 — `BukiController` | ⏳ | — |
| 6 — `SkillController` | ⏳ | — |
| 7 — `MeleeController` | ⏳ | — |
| 8 — `HealthController` | ⏳ | — |
| 9 — redução final | ⏳ | — |
