# Plano — Combate corpo a corpo do Modo História (inspirado em Chivalry 2)

**Estado:** EM EXECUÇÃO — Fases 0–6 e 7a concluídas (16–21/09/2026); faltam o resto da
Fase 7 e a Fase 8. Escrito em 2026-09-16 como plano; o que foi feito está na §14.
**Pedido:** estudar o projeto, escolher skills/agentes e planejar um combate corpo a
corpo **exclusivo do Modo História** com direção, leitura, timing, ataque, defesa,
aparo, riposte, finta, compromisso e recuperação. Frutas intocadas; Roll fora.

**Como ler este documento**

| marca | significa |
|---|---|
| **FATO** | comprovado no código, com `arquivo:linha` |
| **HIPÓTESE** | plausível, ainda não validado |
| **PROPOSTA** | solução nova; não existe no projeto |
| **DECISÃO CONFIRMADA** | dada pelo dono (neste pedido ou registrada antes) |
| **PENDENTE** | depende do dono — ver §12 |

Fontes da auditoria: leitura direta do núcleo (entrada, modo, controlador, FSM,
Yoru, estilos) + dois auditores somente leitura (animação/rig; dano/hitbox/IA),
com as afirmações de maior peso **reconferidas no código** antes de entrar aqui.

---

## 1. Entendimento e critérios de sucesso

O que "pronto" significa, em termos observáveis:

1. No Modo História, com `can_attack`, **LMB** inicia um ataque cuja direção vem do
   movimento do mouse (4 direções), com preparo → ativo → recuperação visíveis.
2. **RMB segurado** ergue a guarda; apertado pouco antes do contato vira **aparo**;
   aparo abre **riposte**; guarda desgastada **quebra**.
3. Finta só numa parte do preparo, no máximo uma por ataque; nada cancela o ativo.
4. Clicar rápido **não** rende mais ataques do que as fases permitem.
5. O dano sai quando o punho/lâmina **passa** pela região (varredura da pose), nunca
   por timer solto.
6. Quem apanha reage **pelo lado** de onde veio o golpe.
7. Um boneco de IA usa **o mesmo executor** (prova de que não depende de input humano).
8. Arena, frutas (Z/X/C/V), Roll e os outros modos se comportam **igual à linha de base**.
9. Animações de corpo inteiro aprovadas por medição (espaço local) e na câmera real.

---

## 2. Skills e agentes escolhidos

### 2.1 Os nomes sugeridos no pedido não existem

`game-director`, `game-designer`, `combat-designer`, `godot-expert`, `gdscript-expert`,
`software-architect`, `animation-specialist`, `character-controller`, `QA`,
`project-manager` e `networking specialist` — **nenhum** está registrado nesta
sessão (conferido na lista de skills e em `~/.claude/agents/`). Mapeamento para o
que existe:

| papel pedido | substituto real | por quê |
|---|---|---|
| game-director / game-designer / combat-designer | skills `direcao-de-jogos` + `desenvolvimento-de-jogos`; agente `critico-de-combate` nos portões | regras de combate com critério observável; o crítico julga game feel **sem consertar** |
| software-architect | skills `raciocinio-pratico` + `planejamento-executavel`; agente `Plan` se for preciso segunda opinião | decisões com hipótese testável e fases verificáveis |
| godot-expert / gdscript-expert | skills `godot-desenvolvimento` + `engenharia-de-codigo` | versão real (4.6.3), contratos, testes proporcionais |
| animation-specialist | skills `design-padrao-ope` + `assets-para-jogos`; agente `avaliador-de-animacao` | régua de acabamento Ope; o avaliador mede trajetória/arco/cadeia em espaço LOCAL |
| character-controller | `godot-desenvolvimento` + leitura de `docs/ARQUITETURA_PLAYER.md` | o controle do corpo é o do `Player.gd`, com regras já decididas |
| QA | agente `avaliador-de-animacao`, `critico-de-combate`; skills `code-review`, `run`, `analise-print-jogo` | validação estrutural, de integração e visual separadas |
| project-manager | `planejamento-executavel` + `comunicacao-de-desenvolvimento` | fases, portões, relatório |
| networking | **não entra na v1**: o Modo História é offline (FATO: `ModoHistoria.gd:17-19`) | gatilho: história ganhar cooperativo |

Sempre ativas pelo processo do dono: `compreensao-senior`, `sempre-perguntar`,
`registrar-erro`. Opcional: `multimodal-dev`, se o dono fornecer vídeo de referência
de Chivalry 2 para comparação medida.

**Não usadas, de propósito:** `editor-de-combate` (é do onepiece-voxel),
`blockbench-*` (servidor MCP desconectado nesta sessão e fora do pipeline deste rig),
`consultar-gemini` (escrita para o onepiece-voxel), equipes `yoru-*` e `boss-*`
(escopos próprios; a Yoru e o Buggy não são alterados aqui).

### 2.2 Como o trabalho será dividido

- **Auditoria:** já feita em paralelo por dois agentes somente leitura (escopos
  disjuntos). Os relatórios foram tratados como entrada e reconferidos.
- **Implementação:** ondas que **editam** rodam **uma por vez na árvore principal**.
  Worktree não serve aqui: `src/historia/`, `src/bosses/` e `YoruController.gd` estão
  **fora do git** (FATO: `git status`), então uma worktree do HEAD não teria o código.
- **Paralelo só onde não há arquivo em comum:** avaliação (crítico, avaliador) e,
  depois de congelado o contrato da `PoseDeCombate`, autoria de poses (dados) em
  paralelo com regras (código).

---

## 3. Auditoria — arquivos relevantes

Risco = risco de **modificar** o arquivo nesta tarefa.

| caminho | responsabilidade | relação com o combate | risco |
|---|---|---|---|
| `Player.gd` (4.474 linhas, diff aberto +397/−66) | input, locomoção, `take_damage`, RPCs, apresentação | toda entrada e todo dano passam por ele; serve arena **e** história | **alto** |
| `src/historia/ModoHistoria.gd` (fora do git) | orquestra a cena; `colocar_civil` monta o jogador | ponto único onde o modo se diferencia | baixo |
| `src/player/capacidades.gd` (fora do git) | permissões (`can_attack`, `can_dash`…) | portão do ataque | baixo |
| `src/historia/progressao.gd` (fora do git) | nível, skills `combate/espada/fruta`, HP | `can_attack = skill combate ≥ 1` (:117) | baixo |
| `src/ui/HistoriaHud.gd` (fora do git) | HUD, menu, janela de status (M) | `is_menu_open()` bloqueia clique (:142) | baixo |
| `src/player/melee_controller.gd` | relógio de fase, trava, buffer, whiff do M1 | arena; lê Player e HUD | **alto** (não mexer) |
| `src/combat/Melee.gd` | tabela do combo M1; `golpear` cria hitbox por timer | arena | **alto** (não mexer) |
| `src/combat/contextual_melee.gd` | variações W/A/S/D, counter hit; lê `Input` direto | arena | médio (não mexer) |
| `src/player/hsm/*` | FSM Idle/Startup/Active/Recovery/Stunned/Dashing | lê `_melee.fase()`; Stunned cancela golpe | médio |
| `src/effects/DamageZone.gd` | hitbox genérica | usada por M1, contextual, Boss e ~33 efeitos de fruta | **alto** (não mexer) |
| `src/combat/CombatResolver.gd` | funil de dano | o novo caminho **chama**, não altera | **alto** (não mexer) |
| `src/combat/SwordSweep.gd` | `contacts()` estático: varredura cápsula entre poses | já reaproveitado pelo Boss (`BossCombat.gd:5,217`) | baixo (só usar) |
| `src/combat/SwordBlade.gd` | lâmina da Yoru; consulta o contrato de aparo | precedente de defesa | médio (não mexer) |
| `src/combat/YoruController.gd`, `YoruMoves.gd`, `src/anim/YoruRig.gd` (fora do git) | relógio único da espada; Guarda da Cruz; IK de braço/perna | melhor referência de relógio único e de aparo | alto (não mexer) |
| `src/anim/ProceduralAnimator.gd` (1.420 linhas, diff aberto) | somas de rotação por papel + `play_baked` | onde a camada de combate precisa entrar | **alto** |
| `src/anim/RigDetalhado.gd` | coluna, clavícula, punho do base_v2 | acabamento de corpo inteiro | médio |
| `src/anim/MeleePoses.gd` | guarda e pernas por cima do clipe do M1 | arena | baixo (não usar) |
| `src/mechanics/RecepcaoDeDano.gd` | hitstun, pose "dano" e knockdown | reação sem direção | médio |
| `src/player/camera_rig.gd` | câmera 3ª pessoa, tremor | legibilidade; `pedir_fov_punch` desligado a pedido (:130) | médio |
| `autoload/GameFlow.gd` | `hit_stop`/`slow_mo` | mexem no `Engine.time_scale` GLOBAL (:270-283) | médio (não usar) |
| `src/bosses/BossCombat.gd`, `BossVisual.gd`, `BossController.gd`, `BossBrain.gd` (fora do git) | IA e execução do Buggy, já separadas | modelo de "decisão × execução" e de hitbox pela pose | médio (não mexer) |
| `src/combat/boxing/BoxingPose.gd`, `BossReactionPose.gd` | IK de boxe em `Skeleton3D` do Boss | referência de mecânica de soco | baixo |
| `src/entities/AutoDummy.gd` | boneco da arena que ataca | tem **cópia** do relógio de combo | baixo (não mexer) |
| `CharacterBuilder.gd` | monta o personagem | `base` → `base_v2_runtime.glb` por nós, sem skin (:33-55) | baixo |
| `src/world/RosaDosVentos.gd` | convenção de direções (frente = −Z) | toda conta direcional | baixo (só usar) |
| `project.godot` | projeto | seção `[input]` inexistente | médio |

---

## 4. Como o combate funciona hoje

### 4.1 Como o Modo História é identificado — FATO

- Não existe enum de modo de jogo para a história. `GameFlow.Mode` é
  `{NONE, SINGLEPLAYER, HOST, CLIENT}` (`GameFlow.gd:9`); a história é uma **cena própria**
  (`STORY_SCENE`, :15), singleplayer offline.
- O jogador é o **mesmo `Player.gd` da arena**, configurado por **injeção** em
  `ModoHistoria.colocar_civil` (`ModoHistoria.gd:126-143`): `capacidades`,
  `ecos_de_movimento_ligados`, `parkour_gasta_energia`, `ponto_de_renascimento`.
- `colocar_civil` é **fonte única**: o "Testar" do editor de mapa chama a mesma função.
- `capacidades` vem da progressão: `can_attack = skills["combate"] >= 1`,
  `can_dash = desbloqueios["dash"]` (`progressao.gd:115-120`).

### 4.2 Entrada — FATO

- Sem InputMap por convenção declarada ("Sem InputMap: le o teclado direto",
  `Player.gd:18`); `project.godot` não tem seção `[input]`.
- LMB: recaptura o mouse se estiver solto e sai (`Player.gd:778-781`); senão
  `_request_melee()` (:837-842) — **porta única** do ataque, com `can_attack` (:2997).
- RMB: `_try_tame()` (:832-836), **desligado** (`TAMING_ENABLED := false`, :1894).
  Buki/Yami usam RMB para mira, mas exigem fruta (o Civil não tem).
- Q = dash com rolamento (`move_frame.gd:89`, `DashController`), portão `can_dash`.
- Toque: o botão M1 simula LMB (`ToqueHud.gd:228`); não há botão de RMB.
- Diálogo e cutscene: **não existem** no código (busca só achou diálogos de arquivo).

### 4.3 O M1 de punho (arena e história compartilham) — FATO

```
LMB → _request_melee → buffer "attack" (400 ms, até 10 entradas, Player.gd:192-213)
    → CombatStateIdle consome → MeleeController.pedir (melee_controller.gd:138-223)
    → pedir_golpe_no_servidor → _do_server_melee → Melee.golpear
    → create_timer(startup * s) → hitbox esférica parada à frente (Melee.gd:660, :719-757)
_net_play_melee → play_baked(clipe m1_*) no mesmo clique (Player.gd:3611-3648)
```

- **Três relógios independentes:** `_t_golpe` do controlador, o timer da hitbox e o
  `_baked_t` do animador. Batem por dados (`pico = startup`), não por construção.
- O timer da hitbox só confere validade de nós (`Melee.gd:660-663`): **não há como
  cancelá-lo** (ver §5, C2).
- Tremor de câmera também por `SceneTreeTimer` no clique (`melee_controller.gd:216-220`).
- Dois buffers: o do Player (400 ms) e o do controlador (0,18 s).

### 4.4 A espada (Yoru) — FATO

- Clique com espada vai para `request_yoru_action("M1")` (`Player.gd:2998-3000`).
- `YoruController`: **um relógio só** (`elapsed`) move a pose e arma a lâmina no mesmo
  quadro; prioridade física 50 (:82).
- **Guarda da Cruz (técnica C):** aparo em 0,06–0,24 s, guarda 0,35× até 0,60 s,
  cone frontal `dot > 0,45`, riposte libera o M1_2 (`YoruController.gd:363-376`).
  Contrato por duck typing `is_parrying / on_parry / guard_multiplier`, consultado
  **só** pelo `SwordBlade` (:221-233). Números fixos no código.
- No Modo História a espada é **inalcançável**: teclas 1/2/3 exigem
  `can_use_skills` (`Player.gd:797-802`), falso no Civil.

### 4.5 Dano e defesa — FATO

- `DamageZone._on_body`: grava metas de derrubada → `antes_do_acerto` →
  `CombatResolver.aplicar` → `hit_landed` → placar → `GameFlow.hit_stop()` global
  (`DamageZone.gd:298-337`).
- `CombatResolver.aplicar` não tem conceito de defesa; chama `take_damage` direto
  (`CombatResolver.gd:82-104`).
- `Player.take_damage` (:2311): imunidades → cancela Yoru/cast → Corpo de Ferro corta
  metade → `sofrer_dano` → hitstun/knockdown → knockback → hitstop local
  (`velocity = Vector3.ZERO`). O parâmetro `attacker_pos` **não é usado** para direção.
- **Bloqueio do jogador não existe.** `CombatStateBlocking` nunca foi criado;
  `pode_cancelar_para_bloqueio()` está pronta sem chamador (`CombatStateAttackRecovery.gd`).

### 4.6 Animação — FATO

- Nenhum `AnimationTree`, `BlendSpace`, `AnimationNodeStateMachine` ou faixa de método
  em `.gd/.tscn/.tres` do jogo. `AnimationPlayer` desligado no jogador
  (`player_rig.gd:199-203`).
- Personagem do Modo História: `base` → `base_v2_runtime.glb` **por nós, sem skin**
  (`CharacterBuilder.gd:33-55`), `ProceduralAnimator` + `RigDetalhado`.
- `play_baked` assume o **corpo inteiro** e retorna cedo (`ProceduralAnimator.gd:380-386`):
  locomoção, `RigDetalhado.juntas` e pose de dano não rodam durante o clipe.
- "Root motion" no projeto é **sempre código** (contextuais: `contextual_melee.gd:292-333`;
  Yoru: `_percurso/_avancar`). Nenhum clipe tem faixa de raiz.
- Reação do jogador: uma pose "dano" e uma "knockdown", **sem direção**
  (`RecepcaoDeDano.gd`). O Boss escolhe o lado da torção pela **paridade da contagem**
  de acertos, não pelo lado do golpe (`BossReactionPose.gd:27`).
- MEDIDO pelo auditor (sonda headless, rig sintético com repouso 0 — o repouso real do
  base_v2 **NÃO CONFIRMADO**): entrada do clipe do M1 salta 58–156° num quadro.

### 4.7 IA — FATO

- Boss: decisão (`BossBrain`/`BossController._decide`) **separada** da execução
  (`BossCombat.begin`), frame data em `BossAbility`, hitbox varrendo `BossVisual.pose_at(t)`
  a 120 Hz com `SwordSweep.contacts` (`BossCombat.gd:198-223`). É o melhor molde
  existente de "IA → executor" e "hitbox pela pose".
- `InimigoDoMapa`: `StaticBody3D` sem IA, sem knockback nem hitstun, vida 250.
- O M1 do jogador **não** é reutilizável por IA: `pedir` lê campos/métodos do Player
  e a HUD; o contextual lê `Input`; a FSM consome o buffer do Player;
  `AutoDummy` mantém uma cópia do relógio de combo.

### 4.8 Premissas do pedido que não batem com o projeto (regra 34)

| premissa | realidade (FATO) | proposta |
|---|---|---|
| "o projeto já possui `CombatExecutor`" | não existe; as opções A/B/C/D não se aplicam literalmente | **executor novo, ator-agnóstico, paralelo** ao M1 da arena (§6, D3) |
| ações de InputMap | `[input]` vazio por convenção declarada | ações **novas e exclusivas** do combate da história (§6, D10) |
| estilos de combate Boxing/Sword/BlackLeg/Staff | no projeto "estilo de luta" = skills **Z/X/C/V** (`FightingStyles.gd`); o clique é punho ou Yoru | `EstiloCorpoACorpo` **separado**; `FightingStyles` intocado |
| AnimationTree / BlendSpace | não usados em nenhum lugar | camada de combate no `ProceduralAnimator` (§6, D7) |
| Root motion em animações | nenhum clipe tem raiz | deslocamento por código (§6, D8) |
| o jogador ataca no Modo História | Civil nasce com `can_attack=false`; espada inalcançável | `can_attack` segue como portão; estilo espada **PENDENTE** (§12) |
| travas de diálogo/cutscene | não existem | ponto único `combate_bloqueado()` preparado para quando existirem |
| Roll bloqueado na história | FATO: `can_dash=false` no Civil | nada muda; Q não é usado |
| números de combate | vida da história = `20 + Vida×5` (`progressao.gd:43-44,106`); inimigo do mapa 250; arena 2.048 | tempos são reaproveitáveis; **danos precisam de escala própria** (§7.4) |

---

## 5. Problemas encontrados

Escopo: **DENTRO** = necessário para o novo combate · **RELACIONADO** = afeta, não
precisa ser resolvido agora · **FORA** = não mexer.

### CRÍTICO

- **C1 — Sem ponto de retorno.** `git status` com 517 entradas; todos os arquivos
  centrais do combate modificados sem commit (`Player.gd`, `Melee.gd`,
  `melee_controller.gd`, `DamageZone.gd`, `CombatResolver.gd`, `ProceduralAnimator.gd`…)
  e `src/historia/`, `src/bosses/`, `YoruController.gd` **não rastreados**.
  Uma mudança deste porte não teria como ser desfeita isoladamente. — **DENTRO**
  (pré-condição da Fase 0).
- **C2 — A hitbox do M1 não pode ser cancelada.** `create_timer(startup*s)` cujo
  callback só checa validade de nós (`Melee.gd:660-663`); `cancelar_golpe` e o
  estado Stunned não o alcançam. Golpe interrompido no preparo ainda acerta, o que
  torna finta/aparo/stagger impossíveis **sobre esse caminho**. O contextual já usa
  token (`contextual_melee.gd:351-356`). Efeito em jogo **não reproduzido**. —
  **RELACIONADO** (é arena; o novo sistema não usa esse caminho).

### ALTO

- **A1 — `Player.gd` com 4.474 linhas** contra 1.498 registradas ao fim da partição
  (`ARQUITETURA_PLAYER.md`, fase 9). Input, dano, rede e apresentação voltaram a se
  concentrar. — **DENTRO** como restrição: o novo sistema vive fora dele.
- **A2 — Hit stop global a cada acerto** (`DamageZone.gd:331-333` →
  `GameFlow.gd:270-275`, `Engine.time_scale = 0,06`). Desacelera a simulação inteira do
  host; clientes não veem. — **RELACIONADO** (o novo sistema usa hitstop por ator).
- **A3 — `play_baked` não serve a este combate:** corpo inteiro, entrada seca
  (58–156°, rig sintético), congela as pernas enquanto o M1 permite andar
  (patinação; `src/tests/test_anim.gd:23-29` × `tools/dev_tests/test_melee_trava.gd:5-15`), esconde a pose de
  dano (`ProceduralAnimator.gd:380-386` × :602). — **RELACIONADO** (decide D7).
- **A4 — Três relógios no M1** (controlador, timer, animador). — **RELACIONADO**.
- **A5 — Defesa fragmentada:** o único contrato de aparo (Yoru) só é consultado
  pela lâmina, com números fixos. — **DENTRO** (generalizar a ideia sem tocar a Yoru).

### MÉDIO

- **M1 — Um bloqueio decidido no Resolver ainda contaria como acerto:** a
  `DamageZone` grava derrubada antes e sempre emite `hit_landed` (:298-324). —
  **DENTRO** (motivo de resolver a defesa **antes** de chamar o Resolver, D6).
- **M2 — Execução de golpe não reutilizável por IA** (§4.7). — **DENTRO**.
- **M3 — Reação sem direção**; `attacker_pos` ignorado em `take_damage`. — **DENTRO**.
- **M4 — Tremor de câmera do M1 sai com golpe cancelado ou errado**
  (`melee_controller.gd:216-220`). — **RELACIONADO**.
- **M5 — Dois buffers de input** (400 ms/10 entradas + 0,18 s) permitem executar
  clique antigo. — **RELACIONADO** (novo sistema: buffer único de 1 posição).
- **M6 — Corpo remoto com knockback sai de `take_damage` antes de
  `die_and_respawn`** (`Player.gd:2393-2406`; é a única chamada). Efeito em partida
  **não confirmado**. — **FORA** (arena/rede).

### BAIXO

- **B1 — InputMap vazio** vs. pedido de ações. — **DENTRO** (decisão D10).
- **B2 — Timers do golpe escalam com `scale.y`, a FSM não** (`Melee.gd:660`). — RELACIONADO.
- **B3 — Menu checado depois de 4 variantes de ataque** (`melee_controller.gd:144-160`). — FORA
  (o novo caminho checa primeiro).
- **B4 — Dados da espada duplicados** (`Melee.COMBO_SWORD` e `YoruMoves`). — FORA.

---

## 6. Decisões de arquitetura

Cada decisão declara: benefício imediato · impacto futuro · manutenção · extensão ·
custo · riscos (regra "Complexidade Adequada"). Horizontes H1/H2/H3.

### D1 — Um módulo próprio, fora do `Player.gd` (PROPOSTA)

```
src/combat/direcional/
├── golpe_direcional.gd        Resource  ficha de UM ataque (tempos, dano, postura, alcance, curvas)
├── estilo_corpo_a_corpo.gd    Resource  4 direções + riposte + regras de defesa do estilo
├── executor_corpo_a_corpo.gd  Node      relógio único + máquina de estados + buffer + postura
├── resolucao_de_contato.gd    estática  ACERTO / BLOQUEIO / APARO / QUEBRA + lado do impacto
├── pose_de_combate.gd         RefCounted avaliação PURA da pose em (ação, tempo)
├── ator_de_combate.gd         RefCounted o que o executor precisa de um corpo (contrato)
├── ator_jogador.gd            RefCounted adaptador do Player
├── ator_boneco.gd             RefCounted adaptador do boneco de duelo
├── entrada_corpo_a_corpo.gd   Node      InputMap → intenção; leitor de direção; bloqueios de UI
├── apresentacao_de_combate.gd Node      hitstop por ator, tremor, som, faísca, reação
├── cerebro_de_treino.gd       Node      IA mínima de sparring (DECISÃO → executor)
├── boneco_de_duelo.gd         CharacterBody3D oponente de teste com o rig base
├── depuracao_de_combate.gd    Node      overlay opcional + desenho da varredura
└── estilos/boxe.tres, estilos/espada.tres   (golpes como sub-recursos)
```

- **Benefício imediato:** nada do combate novo entra no `Player.gd` além de uma ponte
  curta; arena não é tocada.
- **Impacto futuro:** o Buggy e inimigos da história podem usar o mesmo executor.
- **Manutenção:** um arquivo por responsabilidade; alvo de ≤ 300 linhas cada.
- **Extensão:** golpe novo = sub-recurso novo; estilo novo = `.tres` novo.
- **Custo:** médio (~13 arquivos pequenos + dados).
- **Riscos:** vira o **3º executor** (M1 da arena, Yoru, este). **Gatilho de
  convergência:** quando este passar pelas sondas e ganhar rede, decidir com o dono a
  migração do M1 da arena e da Yoru.
- **Contra overengineering:** cada arquivo tem consumidor real na v1 (o boneco e o
  cérebro existem porque **sem alguém atacando não há como testar defesa**; o
  `ator_*` existe porque há dois corpos diferentes desde o início). Sem factories,
  sem interfaces vazias.
- **Precedente de dados em `Resource`:** `BossDefinition`/`BossAbility` (FATO).
  O alerta "`.tres` executa script embutido" do Modo História vale para arquivo
  vindo do usuário (mapas), não para dado autoral versionado.

### D2 — O modo é ativado por injeção em `colocar_civil` (PROPOSTA)

`ModoHistoria.colocar_civil` instala `ExecutorCorpoACorpo` + `EntradaCorpoACorpo` +
`ApresentacaoDeCombate` no jogador, **como já faz com capacidades, ecos e parkour**.
Sem enum `GameMode`, sem `if story_mode` espalhado.

- H1: um ponto só; o "Testar" do editor ganha o combate de graça.
- H2: outro modo que queira o sistema instala no seu próprio ponto de nascimento.
- H3: com cooperativo, a instalação muda para `Main._spawn_player_data` (antes da
  autoridade — ver `ARQUITETURA_PLAYER.md`, "autoridade não desce no `_ready()`").
- **Risco:** o `Player.gd` precisa de uma ponte de ~6 desvios do tipo "se há executor".
  **Gatilho:** se a ponte passar de ~30 linhas, extrair um componente `PonteDeCombate`.

Pontos de ponte previstos no `Player.gd`:

| ponto | o que faz |
|---|---|
| `_unhandled_input` (topo, depois da recaptura do mouse) | se há `EntradaCorpoACorpo` e ela consumiu o evento, sai |
| `_request_melee` | com executor, delega e sai (o buffer da arena não é tocado) |
| `_etapa_locomocao` (velocidade) | `effective_speed *= executor.fator_de_movimento()` |
| `_etapa_locomocao` (frente) | com ação em curso, yaw do corpo com **teto de giro** por fase |
| `_etapa_mover` | `velocity += executor.impulso_do_quadro(delta)` (padrão do knockback) |
| `take_damage` | avisa o executor (cancelar/reagir com direção) |
| `esta_atacando` / `em_startup_de_ataque` | consultar o executor quando ele existe |

### D3 — `CombatExecutor` não existe: executor novo, não extensão (PROPOSTA)

| opção do pedido | avaliação no projeto real |
|---|---|
| A) ampliar `CombatExecutor` | impossível: não existe |
| A') ampliar `MeleeController` | acoplado ao Player/HUD/RPC, hitbox por timer (C2), protegido por testes da arena que exigem o comportamento atual; crescer aqui arrisca a arena |
| A'') ampliar `YoruController` | específico da espada, lê `combat_mode`/`_yoru` do Player, fora do git, com frente própria (`PLANO_YORU`) |
| B) camada acima | não há o que envolver |
| **C) componente paralelo** | **escolhida**: molde do `YoruController` (relógio único) + `BossCombat` (hitbox pela pose, IA separada) |
| D) refatorar pequena parte | adiado: é a migração do gatilho em D1 |

### D4 — Relógio único e máquina de estados explícita (PROPOSTA)

Um contador físico (`_physics_process`) por executor. A pose, a varredura, o buffer,
as janelas de finta/aparo/riposte e as reações **leem esse mesmo relógio**. Nenhum
`SceneTreeTimer`, nenhum `await` para regra de jogo. Cancelar = trocar de estado e
incrementar o **id da ação**; tudo o que foi agendado compara o id.

A FSM do Player (`src/player/hsm`) **não ganha estados novos**: no Modo História ela
fica em Idle, e as consultas públicas (`esta_atacando` etc.) passam a perguntar ao
executor. Levantar, na Fase 1, **todos** os leitores de `_fsm.state.name`,
`hit_confirmed`, `esta_atacando` e `em_startup_de_ataque` antes de decidir o espelhamento.

### D5 — Hitbox pela pose, não por timer (PROPOSTA)

Durante ATIVO, a cada tick físico o executor pede à `PoseDeCombate` a posição do
efetor (punho ou pontos da lâmina) em sub-passos (molde `BossCombat.gd:210-218`) e
chama `SwordSweep.contacts(start, finish, raio, máscara, exclusões)`.
Deduplicação por **(id da ação, alvo)**. Parar de amostrar é o cancelamento.

- Benefício: sincronia por construção (a mesma função move o osso e a hitbox).
- Risco: a `PoseDeCombate` precisa ser **pura** (tempo → pose) — o `ProceduralAnimator`
  atual não expõe amostragem em tempo arbitrário (NÃO CONFIRMADO). Por isso a pose
  do golpe é avaliada fora dele e **aplicada** nele (D7).
- Risco: ordem de execução no quadro (pose aplicada × varredura). Medir na Fase 3.

### D6 — Defesa resolvida no defensor, antes do dano (PROPOSTA)

```
varredura acha alvo
    → ResolucaoDeContato.resolver(golpe_em_curso, atacante, defensor)
        defensor sem executor ............................ ACERTO
        GUARDA + cone frontal + aparável + dentro da janela  APARO
        GUARDA + cone frontal ............................ BLOQUEIO (→ QUEBRA se a postura zera)
        GUARDA fora do cone (flanco/costas) ............... ACERTO
        qualquer outro estado ............................ ACERTO
        (reservados: CONTRA na V2, CHOQUE na V3)
    → só ACERTO chama CombatResolver.aplicar(..., corpo_a_corpo_de = atacante)
```

- **`DamageZone` e `CombatResolver` ficam intocados:** arena e frutas não mudam.
- Consequência declarada: na v1 **só ataques deste executor são bloqueáveis**. Fruta,
  projétil e golpe do Boss atual não são. Gatilho: o primeiro inimigo da história que
  precise ser bloqueável passa a atacar pelo executor.
- Cone medido contra a **posição do atacante**, não a da zona (o Resolver recebe a
  posição da zona como `origem`).

### D7 — Animação híbrida numa camada de combate (PROPOSTA; fonte das poses PENDENTE)

- **Não** `play_baked` (A3), **não** `AnimationTree` (brigaria com o rig por nós e a
  locomoção procedural; o projeto já desliga AnimationPlayers por isso).
- **Poses-chave por ação** (extremo do preparo, contato, follow-through, assentamento),
  com o **tempo deformado pelas fases** do golpe: mudar o frame data não exige re-autorar.
- **Camadas procedurais por cima:** pé de apoio plantado por IK (reaproveitar o
  resolvedor de dois ossos que a Yoru já usa), contra-rotação da cabeça, reação aditiva.
- **Entrada:** mistura de 60–100 ms a partir da pose atual, **dentro** do preparo (lê
  como antecipação); **saída:** rigidez existente.
- **Integração no `ProceduralAnimator`:** um gancho **genérico** de "sobreposição
  externa com peso por papel" — não um caso do Modo História dentro do animador.
  Arquivo com diff aberto: combinar com o dono antes de editar.

### D8 — Deslocamento por código (decisão técnica, não de preferência)

Curva e distância por golpe na ficha (`avanco_m`, `curva_avanco`), aplicada como
impulso somado antes do `move_and_slide` (padrão do knockback), com **pé plantado por
IK**. Root motion de clipe não tem suporte em nenhum caminho do projeto, e o código
mantém colisão, IA e rede futura determinísticas. Nunca `velocity = Vector3.ZERO`
como regra de ataque.

### D9 — Impacto sem mexer no tempo global (PROPOSTA)

- Hitstop **por ator**: pausa o relógio do executor e o animador dos **dois** envolvidos.
  Coordenar com o hitstop local que `take_damage` já aplica (`Player.gd:2400-2402`).
- Tremor leve (`add_camera_shake`) **só no contato confirmado**.
- **Sem soco de FOV:** desligado pelo dono por distorção (`camera_rig.gd:130`).
- Som e faísca reaproveitando `YoruAudio`/`YoruFX.impact` (espada) e `AudioFX` (punho),
  com intensidades nos dados. Reação diferente para acerto, bloqueio, aparo e quebra.

### D10 — InputMap só para este combate (PROPOSTA)

Duas ações em `project.godot`: `combate_atacar` (mouse esquerdo) e `combate_defender`
(mouse direito), lidas **só** por `EntradaCorpoACorpo`. A convenção "sem InputMap" da
arena continua valendo para o resto. O toque segue funcionando: o `ToqueHud` já
sintetiza `InputEventMouseButton`, que casa com a ação.

### D11 — Direção pelo mouse (PROPOSTA)

- Fato de base: o corpo **sempre encara a mira** (decisão do dono, 2026-08-27;
  `Player.gd:1612-1683`) e o mouse gira `_yaw` direto (`MOUSE_SENS 0,0035`, :78, :762).
  Portanto horizontal na tela = horizontal no espaço local do personagem.
- Leitura: soma do movimento relativo **bruto** (antes do clamp do pitch) numa janela
  deslizante de ~0,12 s **antes** do clique, em radianos de câmera (independe de DPI),
  num buffer circular fixo (sem alocação por evento).
- Classificação: abaixo da zona morta → **FRENTE**; horizontal dominante → corte;
  para cima → **DE CIMA**; para baixo → **FRENTE** na v1 (reservado para uppercut).
- **Nomes sem ambiguidade:** `CORTE_PARA_ESQUERDA` = golpe que **viaja** para a
  esquerda do atacante (começa à direita) = mouse para a esquerda, como o pedido.
- **Lado do impacto calculado pela geometria**, não pelo nome: vetor de viagem do
  efetor no espaço do defensor. Um corte para a esquerda do atacante atinge o
  defensor que o encara **pelo lado esquerdo do defensor**.
- Prova: sonda em 12 yaws com modo sabotagem (direção invertida **tem** de reprovar),
  como `medir_direcoes_skills.gd --inverter`.

### D12 — Giro e movimento durante o golpe (PROPOSTA)

`fator_movimento` e `giro_max_graus_s` **por fase** na ficha. Impede o "rodar 360° no
ativo" e deixa aberta a porta para arrasto/aceleração de golpe (V3). Guarda erguida
desliga o sprint.

---

## 7. Regras de combate da v1

### 7.1 Estados

| estado | pode | transições |
|---|---|---|
| NEUTRO | andar, correr | LMB → PREPARO · RMB → GUARDA |
| PREPARO | andar lento | fim → ATIVO · finta (janela) → PREPARO de outra direção ou GUARDA · acertado → REAÇÃO |
| ATIVO | nada; varredura ligada | fim → RECUPERAÇÃO · aparado → REBATIDO |
| RECUPERAÇÃO | andar lento; buffer no fim | fim → NEUTRO/PREPARO (buffer) · RMB após `guarda_liberada_em` → GUARDA |
| GUARDA | andar lento; aparo nos primeiros `janela_aparo` s | soltar → BAIXANDO · LMB → PREPARO (riposte se a janela estiver aberta) · postura 0 → QUEBRA |
| BAIXANDO | andar | fim → NEUTRO (impede spam de aparo sem usar recarga) |
| REBATIDO | nada | fim → NEUTRO |
| QUEBRA | nada, sem guarda | fim → NEUTRO |
| REAÇÃO | nada; pose direcional | fim → NEUTRO |

Regras declaradas:
- **ATIVO → DEFESA instantânea não existe.** O compromisso é o ativo inteiro.
- **Acerto no PREPARO interrompe** (flinch). **Acerto no ATIVO não interrompe:** os dois
  golpes podem trocar dano. Choque de golpes ativos é V3.
- **Finta:** no máximo **uma por ataque**, só nos primeiros `janela_finta` do preparo e
  nunca nos últimos `finta_minimo_restante` s; custa postura. LMB com **outra**
  direção troca o golpe; RMB cancela para a guarda. Riposte não finta.
- **Buffer:** uma posição, só LMB, só nos últimos `buffer` s da recuperação; expira; é
  descartado em reação, rebote e quebra. Clique no preparo nunca vai para o buffer.
- **Riposte:** janela após aparo; o próximo LMB sai com `preparo × fator_riposte`.
  Não é dano garantido (ver invariantes).

### 7.2 Resultado do contato

| resultado | atacante | defensor | apresentação |
|---|---|---|---|
| ACERTO | segue; `hit_confirmed` | dano pelo `CombatResolver`, REAÇÃO direcional | hitstop curto nos dois, tremor leve, som de carne/impacto |
| BLOQUEIO | recuperação normal | sem dano; postura −`dano_de_postura` | recuo curto da guarda; faísca (espada) ou impacto abafado (boxe) |
| APARO | REBATIDO; varredura para | janela de riposte | hitstop maior, som próprio, faísca |
| QUEBRA | recuperação normal | QUEBRA; postura volta a `postura_apos_quebra` | reação pesada, som próprio |

### 7.3 Tempos iniciais (PROPOSTA para calibrar jogando)

Referências usadas: reação visual humana típica fica na ordem de 0,2–0,25 s; o
design do Buggy já prevê preparo de 0,25–0,35 s para soco simples e 0,45–0,65 s para
hook/uppercut (`BOSS_BUGGY_COMBAT_DESIGN.md:363-364`). O M1 da arena (0,20 s de
startup) é rápido demais para ler e reagir, e por isso não serve de base.

**Boxe**

| direção | golpe | preparo | ativo | recuperação | postura no bloqueio | hitstun |
|---|---|---:|---:|---:|---:|---:|
| FRENTE | jab / direto | 0,30 | 0,08 | 0,30 | 15 | 0,25 |
| PARA_ESQUERDA | hook (mão direita) | 0,42 | 0,10 | 0,40 | 25 | 0,35 |
| PARA_DIREITA | hook (mão esquerda) | 0,42 | 0,10 | 0,40 | 25 | 0,35 |
| DE_CIMA | overhand pesado | 0,55 | 0,12 | 0,55 | 40 | 0,50 (pesada) |

**Espada**

| direção | golpe | preparo | ativo | recuperação | postura no bloqueio | hitstun |
|---|---|---:|---:|---:|---:|---:|
| FRENTE | estocada | 0,40 | 0,10 | 0,45 | 20 | 0,30 |
| PARA_ESQUERDA / PARA_DIREITA | corte lateral | 0,45 | 0,14 | 0,45 | 25 | 0,35 |
| DE_CIMA | corte descendente | 0,58 | 0,14 | 0,60 | 40 | 0,50 (pesada) |

**Defesa (os dois estilos, ajustável por estilo)**

| parâmetro | valor |
|---|---:|
| `janela_aparo` | 0,20 s a partir do aperto do RMB |
| cone da guarda | 120° (`dot ≥ 0,5`) |
| `baixar_guarda` | 0,20 s |
| `guarda_liberada_em` | 60% da recuperação |
| postura máx. / regen / atraso | 100 / 25 por s / 1,0 s sem apanhar na guarda |
| custo da finta | 10 |
| `janela_finta` / mínimo restante | 60% do preparo / 0,12 s |
| QUEBRA / `postura_apos_quebra` | 0,90 s / 50 |
| REBATIDO | 0,15 s |
| janela de riposte / `fator_riposte` | 0,60 s / 0,6 |
| buffer | 0,15 s |
| hitstop acerto / pesado / bloqueio / aparo | 0,05 / 0,08 / 0,04 / 0,07 s |

**Movimento por fase (fator × velocidade de andar; giro máx.)**: preparo 0,6 · 360°/s;
ativo 0,35 · 150°/s; recuperação 0,5 · 240°/s; guarda 0,55 · livre.

### 7.4 Dano — escala própria (PROPOSTA; calibrar)

A vida do jogador na história começa em **20** e vai a 245; o inimigo do mapa tem 250.
Os números da arena (48–112 contra 2.048) **não servem**. Proposta inicial:
- jogador → inimigo: jab 20 · hook 30 · pesado 45 · estocada 30 · corte 35 · descendente 50
  (9–13 golpes para derrubar um inimigo de 250);
- boneco/inimigo → jogador: 2 · 3 · 5 (4–10 golpes no nível 1).

Força ainda não tem efeito (decisão registrada no Modo História); o campo de escala
por atributo fica **reservado**.

### 7.5 Invariantes (viram teste)

1. **Riposte nunca é garantido:** `rebatido + reação mínima de guarda ≤ preparo do riposte mais rápido`
   (0,15 s ≤ 0,30 × 0,6 = 0,18 s).
2. **Quebra de guarda é punível de propósito:** `quebra > preparo mais rápido` (0,90 > 0,30).
3. **Sem prisão infinita:** para todo golpe, `hitstun < recuperação + preparo do golpe mais rápido`
   (jab: 0,25 < 0,30 + 0,30).
4. **Spam não paga:** em 1 s de cliques contínuos, ataques ≤ ⌊1 / duração do golpe mais curto⌋ + 1.
5. **Nada de tempo global:** `Engine.time_scale` nunca muda durante um combate da história.

### 7.6 Depois da v1

| versão | conteúdo | por que depois |
|---|---|---|
| V2 | **Contra-ataque:** resposta com o mesmo tipo de golpe dentro do próprio preparo, no timing do golpe recebido (vira aparo + ataque) | exige a v1 calibrada; o valor `CONTRA` já está reservado em D6 |
| V2 | encadeamento acelerado após acerto; Buggy e inimigos da história no executor | depende da escala de dano e da IA |
| V3 | **choque** (ativo × ativo, padrão `SwordBlade.gd:156-173`), arrasto/aceleração de golpe, rede | risco e custo maiores; a arquitetura não impede (varredura por par antes do dano) |

---

## 8. Animação — o que precisa existir e como será julgado

### 8.1 Inventário por estilo

- guarda parada e andando (camada de braços + tronco sobre a locomoção);
- 4 golpes × poses-chave (extremo do preparo, contato, follow-through, assentamento);
- riposte = mesmos golpes com tempo deformado;
- guarda erguida, aparo (golpe seco + retorno), baixar guarda;
- rebatido (atacante aparado), quebra de guarda;
- reações: da esquerda, da direita, frontal, pelas costas, pesada;
- finta: retorno do preparo para a guarda ou para o novo preparo.

### 8.2 Mecânica corporal exigida (checklist por golpe)

Pés → joelhos → quadril → tronco → ombro → braço → mão/arma → cabeça → equilíbrio.
Boxe: jab com passo curto e ombro protegendo o queixo; direto começando no pé de trás;
hook com pivô dos pés, joelhos flexionados e cotovelo no arco. Espada: corte lateral na
sequência de 10 passos do pedido (pés, centro de massa, quadril, tronco, ombro,
aceleração, contato, follow-through, desaceleração, retorno).

### 8.3 Como será medido (não "no olho")

| critério | instrumento |
|---|---|
| amplitude por papel (nenhum papel mudo) | `medir_corrida.gd` (item 5) e sonda nova no mesmo molde |
| pé de apoio plantado (deslize em cm) | posição do pé em espaço local do chão durante o golpe |
| arco e pico de velocidade do efetor **no ativo** | amostragem da `PoseDeCombate` |
| efetor dentro do volume de acerto **só** no ativo | mesma amostragem, contra a janela |
| legibilidade em 3ª pessoa | `Camera3D.unproject_position` no `camera_rig` real: separação mínima em pixels entre as 4 direções no extremo do preparo |
| esquerda/direita na tela | captura real com tela (`run` + `analise-print-jogo`) |
| movimento certo como movimento | agente `avaliador-de-animacao` (espaço local) |
| bom de jogar | agente `critico-de-combate` |

Câmera real (FATO, `camera_rig.gd:42-64`): distância 4 m, pivô 1,0 m, ombro deslocado
1,1 m à direita, FOV 68. HIPÓTESE geométrica a medir: com a câmera à direita, golpes
da mão esquerda ficam parcialmente atrás do tronco e precisam de arco mais aberto.

Rig: `base_v2` por nós, 13 papéis + `RigDetalhado`. Antes de autorar: medir o
**repouso real** dos 13 papéis e o eixo do antebraço/mão neste rig (a nota dos eixos
opostos entre voxel e skinnado exige conferência — NÃO CONFIRMADO para o base_v2).

---

## 9. Fases

A ordem do modelo do pedido foi **ajustada por dependência técnica**: a hitbox vem
antes da defesa (defesa é uma forma de resolver contato), e a autoria final das
animações vem depois de a mecânica estar estável sobre poses **estruturais**
(provisórias e marcadas como tal).

### FASE 0 — Pré-condições (sem código de jogo)

- **Objetivo:** ponto de retorno e linha de base medida.
- **Criados:** `docs/combat/LINHA_DE_BASE.md`.
- **Alterados:** nenhum arquivo de jogo.
- **Passos:** ponto de retorno no git (PENDENTE, §12) · `./validar.sh rapido` comparado
  com 87 passou / 9 falhou / 1 pulado (16/09) · listar leitores de `_fsm.state.name`,
  `esta_atacando`, `em_startup_de_ataque`, `hit_confirmed` · medir repouso e eixos do
  base_v2 · confirmar se a janela de status (M) consome cliques · confirmar tecla livre
  para o overlay.
- **Riscos:** baseline suja por testes de ambiente (`test_sala_publica`).
- **Pronto quando:** baseline registrada com as falhas conhecidas nomeadas.
- **Skills:** `raciocinio-pratico`, `engenharia-de-codigo`, `registrar-erro`.

### FASE 1 — Arquitetura base

- **Criados:** `golpe_direcional.gd`, `estilo_corpo_a_corpo.gd`,
  `executor_corpo_a_corpo.gd` (NEUTRO/PREPARO/ATIVO/RECUPERAÇÃO), `ator_de_combate.gd`,
  `ator_jogador.gd`, `depuracao_de_combate.gd`, `estilos/boxe.tres` (tempos da §7.3),
  `tools/dev_tests/test_executor_corpo_a_corpo.gd` (headless, **sem Player**).
- **Alterados:** `ModoHistoria.gd` (instalação), `Player.gd` (desvio de entrada,
  delegação do `_request_melee`, consultas públicas).
- **Responsabilidade:** relógio único, transições, cancelamento por id de ação.
- **Riscos:** merge com o diff aberto do `Player.gd`; `class_name` novo exige
  `--headless --editor --quit`; compilação só é provada por `test_compila.gd`.
- **Dependências:** Fase 0.
- **Pronto quando:** testes do executor verdes (inclusive "cancelado não avança");
  `test_modo_historia` 75 ✅; na arena `test_arena`, `test_melee_trava` e o traço de
  locomoção **idênticos**; overlay mostra as fases ao clicar no Modo História.

### FASE 2 — Ataques direcionais

- **Criados:** `entrada_corpo_a_corpo.gd` (InputMap, leitor de direção, bloqueios,
  buffer), `tools/dev_tests/test_leitor_de_direcao.gd`,
  `tools/dev_tests/medir_direcoes_corpo_a_corpo.gd` (12 yaws + `--inverter`).
- **Alterados:** `project.godot` (`[input]`), `Player.gd` (fator de movimento, teto de
  giro, impulso).
- **Riscos:** a primeira seção `[input]` do projeto; sensibilidade/zona morta ruins
  para mouse de DPI alto (medir); toque sem arrasto.
- **Dependências:** Fase 1.
- **Pronto quando:** 4 direções certas em 12 yaws e a sabotagem reprova; menu (ESC),
  janela M, mouse solto e editor → 0 ataques; 30 cliques/s respeitam o invariante 4;
  atacar andando nunca zera a velocidade.

### FASE 3 — Hitboxes (antes da defesa, por dependência)

- **Criados:** `pose_de_combate.gd` (poses **estruturais** do boxe, marcadas
  provisórias), `resolucao_de_contato.gd` (só ACERTO + lado), `apresentacao_de_combate.gd`,
  `ator_boneco.gd`, `boneco_de_duelo.gd`, `tools/dev_tests/test_hitbox_corpo_a_corpo.gd`.
- **Alterados:** `ProceduralAnimator.gd` (gancho genérico de sobreposição — combinar
  antes, diff aberto), `Player.gd` (`take_damage` avisa o executor).
- **Riscos:** ordem pose × varredura no quadro; hitstop por ator × hitstop local já
  existente; colisão côncava do inimigo do mapa (o soco atual acerta, medido em 16/09).
- **Dependências:** Fases 1–2.
- **Pronto quando:** efetor dentro do volume **só** no ativo (amostrado); golpe
  cancelado no preparo **não** dá dano e o controle positivo (sem cancelar) dá; lado da
  reação certo em 4 direções × 8 orientações do defensor; `Engine.time_scale`
  constante; inimigo do mapa continua morrendo e dando XP.

### FASE 4 — Defesa

- **Criados:** `cerebro_de_treino.gd` (padrões fixos: atacar direção X, segurar guarda),
  `tools/dev_tests/test_defesa_corpo_a_corpo.gd`.
- **Alterados:** `executor_corpo_a_corpo.gd` (GUARDA, BAIXANDO, postura, QUEBRA,
  REAÇÃO), `resolucao_de_contato.gd` (BLOQUEIO, QUEBRA, cone).
- **Riscos:** cone medido contra a posição errada (zona × atacante); postura sem
  leitura visual (sem barra por decisão — resolver na pose/som).
- **Dependências:** Fase 3.
- **Pronto quando:** boneco atacando jogador em guarda frontal → 0 dano e postura cai;
  pelas costas → dano; postura 0 → QUEBRA pelo tempo da ficha; invariantes 2 e 3.
- **Portão:** `critico-de-combate` sobre o vaivém ataque × guarda.

### FASE 5 — Aparo, riposte e finta

- **Alterados:** executor (janela de aparo, REBATIDO, riposte, finta, buffer final),
  `resolucao_de_contato.gd` (APARO), `cerebro_de_treino.gd` (aparar, fintar),
  testes da Fase 4 ampliados.
- **Riscos:** janela de aparo fácil demais (spam de RMB) — contida pelo BAIXANDO;
  finta infinita — contida por "uma por ataque" + postura.
- **Dependências:** Fase 4.
- **Pronto quando:** RMB a −0,25/−0,15/−0,05 s do contato → só dentro da janela vira
  aparo; riposte fora da janela sai normal; invariante 1; finta fora da janela é
  recusada; segunda finta no mesmo ataque é recusada.
- **Portão:** `critico-de-combate` (risco/recompensa do aparo e da finta).

### FASE 6 — Animações finais

- **Criados:** poses finais de **boxe** como dados versionados (§12); a espada fica para a fase própria depois da v1;
  sondas de legibilidade e deslize de pé.
- **Alterados:** `pose_de_combate.gd` (troca das poses estruturais pelas finais, sem
  mudar o contrato), `estilos/*.tres`.
- **Riscos:** a fonte das poses (PENDENTE); câmera no ombro direito escondendo golpes
  da esquerda; soma de Euler em arcos grandes (HIPÓTESE de artefato).
- **Dependências:** contrato da `PoseDeCombate` congelado na Fase 3. Pode andar em
  paralelo às Fases 4–5.
- **Pronto quando:** todos os critérios da §8.3 medidos; `avaliador-de-animacao` sem
  reprovação; capturas em 3ª pessoa aprovadas pelo dono.
- **Skills:** `design-padrao-ope`, `assets-para-jogos`, `godot-desenvolvimento`;
  `multimodal-dev` se houver vídeo de referência.

### FASE 7 — Integração com o Modo História

- **Alterados:** `progressao.gd`/`ModoHistoria.gd` (estilo liberado pelas skills,
  conforme §12), seção TESTE da janela de status (trocar estilo, invocar boneco — só em
  build de desenvolvimento), `HistoriaHud.gd` se o overlay precisar de lugar.
- **Criados:** `docs/combat/` — arquitetura, máquina de estados, fluxo de ataque,
  defesa, aparo, riposte, entradas, como criar estilo, como criar golpe, como integrar
  animação.
- **Riscos:** mapa vivo do dono (testes usam `ModoHistoria.mapa_forcado`/`progresso_forcado`);
  atalho principal nunca vira lançador de teste (usar `jogar_historia.sh`).
- **Pronto quando:** Civil sem skill não ataca; com skill ataca; "Testar" do editor
  tem o mesmo combate; `test_modo_historia`, `test_inimigos_historia`,
  `test_editor_mapa` verdes.

### FASE 8 — Testes e validação final

| teste pedido | como | tipo |
|---|---|---|
| Ataque (LMB) | `test_executor` + jogador real no Modo História com mapa forçado | integração |
| Direcionais | `test_leitor_de_direcao` + sonda 12 yaws com sabotagem | estrutural + integração |
| Defesa (RMB) | boneco ataca jogador em guarda | integração |
| Aparo | RMB em −0,25/−0,15/−0,05 s do contato | integração |
| Riposte | LMB dentro e fora da janela | integração |
| Spam | 30 cliques/s; buffer nunca > 1 | integração |
| Movimento | atacar andando; velocidade ≠ 0 | integração |
| Câmera | 8 yaws × 4 direções: lado e hitbox em espaço local | integração |
| 3ª pessoa | captura com tela + projeção na câmera real | visual |
| UI | ESC, janela M, mouse solto, editor | integração |
| Frutas | bateria de frutas e `medir_direcoes_skills` iguais à linha de base; `git diff` sem arquivo de fruta | regressão |
| Outros modos | `test_arena`, `test_melee_trava`, `test_counter_hit`, traço de locomoção idêntico, `test_modos_de_combate` | regressão |

Revisão final: `code-review`, `simplify`, `critico-de-combate`, `avaliador-de-animacao`.
Relatório final no formato de 12 seções do pedido.

---

## 10. Riscos e mitigação

| risco | probabilidade | mitigação |
|---|---|---|
| mexer no `Player.gd` com diff aberto de outra frente | alta | ponte mínima; ponto de retorno antes; reler o arquivo antes de cada edição |
| `ProceduralAnimator` com diff aberto | alta | um gancho genérico, combinado antes |
| regressão silenciosa na arena | média | executor ausente = comportamento idêntico; traço de 492 quadros e `test_arena` |
| sincronia pose × hitbox quebrada por ordem de quadro | média | medir na Fase 3 antes de autorar poses |
| animação "correta nos números" e feia na tela | média | captura real + avaliador + dono |
| valores de combate ruins | alta (é normal) | tudo em `.tres`, calibração em playtest, invariantes como teste |
| teste que não sabe reprovar | média | toda sonda com controle positivo ou sabotagem |

---

## 11. Dívida com gatilho

| adiado | gatilho para revisitar |
|---|---|
| migrar M1 da arena e Yoru para o executor | executor com rede e sondas verdes, decisão do dono |
| bloquear golpes que não são deste executor | primeiro inimigo da história que precise ser bloqueável |
| rede do executor | história ganhar cooperativo |
| ponte do `Player.gd` virar componente | um desvio passar de 3 linhas de lógica, ou surgir o 10º ponto (revisto na Fase 3) |
| dividir `executor_corpo_a_corpo.gd` (746 linhas em 17/09) | passar do teto de 900 do projeto (`docs/LIMITE_DE_TAMANHO.md`) — a fatia natural é a camada de defesa/aparo |
| IK de dois ossos compartilhado com o `YoruRig` | um TERCEIRO IK de dois ossos no projeto (hoje são dois: Yoru e este) |
| polegar do punho fechado | personagem aparecer em close-up (cutscene, retrato, câmera de foto) — em jogo é sub-pixel |
| gesto de entrada na base saindo do idle (0,14 s durante a carga) | playtest reclamar do primeiro golpe depois de parado |
| barra de postura visível | playtest mostrar que a quebra de guarda não é legível só por pose/som |
| `InimigoDoMapa` reagir com o corpo | primeiro inimigo com IA na história |
| C2, A2, M4, M5, M6 (arena) | tarefa própria; registrados em `LISTA_DE_CORRECOES.md` |

---

## 12. Decisões do dono (respondidas em 2026-09-16)

1. **Início da implementação:** **só o plano por agora.** Nada de jogo é alterado até o
   dono mandar começar. O ponto de retorno no git (C1) continua sendo pré-condição da
   Fase 0 e será tratado quando a implementação for autorizada.
2. **Fonte das poses-chave (D7):** **dados agora, estúdio depois.** Poses como dados
   versionados (rotações por papel + alvos de IK), medidas e ajustadas por captura; o
   contrato da `PoseDeCombate` fica pronto para trocar a fonte pelo estúdio de animação
   quando ele exportar, sem mexer no executor.
3. **Estilos:** **boxe primeiro** — a v1 jogável entrega o boxe completo com animações
   finais. A **espada vem em seguida** no mesmo executor (dados e poses novos), liberada
   quando a skill **Espada** do status chegar a 1 (`progressao.gd`, trilha `espada`).
   Consequência no plano: Fases 1–6 são de boxe; `estilos/espada.tres` e as poses da
   espada entram numa fase própria depois da Fase 8 da v1.

Decisões menores **já tomadas com valor padrão**, revisáveis sem retrabalho (estão em dados):
mouse para baixo = FRENTE; guarda liberada a 60% da recuperação; acerto no ativo não
interrompe; escala de dano da §7.4; overlay de depuração desligado por padrão.

---

## 13. Registro de decisões

| # | decisão | origem |
|---|---|---|
| 1 | frutas, Z/X/C/V, Roll/Q, inventário, mundo e terreno fora desta tarefa | CONFIRMADA — pedido de 16/09 |
| 2 | combate exclusivo do Modo História | CONFIRMADA — pedido de 16/09 |
| 3 | LMB ataca, RMB defende | CONFIRMADA — pedido de 16/09 |
| 4 | jogador e IA pelo mesmo executor | CONFIRMADA — pedido de 16/09 |
| 5 | corpo sempre encara a mira | CONFIRMADA — dono, 27/08 |
| 6 | sem soco de FOV (distorção) | CONFIRMADA — dono (`camera_rig.gd:130`) |
| 7 | câmera 4 m, pivô na cabeça | CONFIRMADA — dono, 16/09 |
| 8 | executor novo paralelo; `DamageZone`/`CombatResolver`/`Melee`/`MeleeController` intocados | PROPOSTA (D3, D6) |
| 9 | ativação por injeção em `colocar_civil` | PROPOSTA (D2) |
| 10 | deslocamento por código | PROPOSTA técnica (D8) |
| 11 | hitstop por ator, sem `Engine.time_scale` | PROPOSTA (D9) |
| 12 | parar no plano; implementar só com autorização | CONFIRMADA — dono, 16/09 |
| 13 | poses-chave como dados agora; estúdio de animação depois, pelo mesmo contrato | CONFIRMADA — dono, 16/09 |
| 14 | v1 = boxe; espada depois, liberada pela skill Espada ≥ 1 | CONFIRMADA — dono, 16/09 |
| 15 | implementação autorizada ("iniciar implementação") | CONFIRMADA — dono, 16/09 |
| 16 | ponto de retorno = snapshot local + patch por fase, sem mexer no git | CONFIRMADA — dono, 16/09 |
| 17 | combate novo nasce DESLIGADO (`ModoHistoria.combate_direcional_ligado`) até o fim da Fase 3; `SOP_COMBATE_DIRECIONAL=1` liga | DECIDIDO na Fase 1 — gatilho: fim da Fase 3 |
| 18 | padrões dos `Resource` de combate são NEUTROS; todo número real fica explícito no `.tres` | DECIDIDO na Fase 1 (o Godot omite campo igual ao padrão) |
| 19 | o buffer de clique é do executor (regra), não da entrada | DECIDIDO na Fase 1 |
| 20 | cancelamento por dano sem gancho no `take_damage`: o executor lê o `Stunned` pelo adaptador | DECIDIDO na Fase 1 |
| 21 | hitbox amostra a posição REAL do punho (pós-suavização do animador), não a pose-alvo | DECIDIDO na leitura para a Fase 3 (revisa D5) |
| 22 | a janela de aparo conta de um APERTO NOVO do RMB; guarda que volta sozinha (botão segurado) não apara | DECIDIDO na Fase 5 |
| 23 | o aparo congela (hitstop) só quem APAROU; o atacante vai direto a REBATIDO — congelá-lo somaria tempo e tornaria o riposte dano garantido | DECIDIDO na Fase 5 |
| 24 | finta = clique novo em OUTRA direção ou aperto novo do RMB, no começo do preparo, uma por ataque, paga em postura; riposte não finta | DECIDIDO na Fase 5 |
| 25 | sair do golpe pela guarda não encurta nem reinicia: a recuperação pendente continua e o clique segue a regra do buffer | DECIDIDO na Fase 5.1 (portão do `critico-de-combate`) |
| 26 | pé de apoio travado no MUNDO (sob o antepé), com passo automático — compensar o avanço nos dados erraria no acerto, que interrompe o avanço | DECIDIDO na Fase 6 |
| 27 | toda postura herda o que não escreve da GUARDA DO ESTILO (herança explícita), não do primeiro argumento | DECIDIDO na Fase 6 |
| 28 | a leitura da direção é medida pelo VETOR da carga na tela do defensor, não pela posição absoluta do punho (punhos das duas mãos vivem perto da linha central) | DECIDIDO na Fase 6 |
| 29 | acerto no ATIVO não interrompe para NENHUM corpo: o golpe que trocou ignora o atordoamento do dano até acabar; trava dura (derrubado, congelado, morto) cancela sempre | DECIDIDO na Fase 7a (correção de defeito contra a §7.1) |
| 30 | boneco de duelo invocável pela janela M → TESTE (só desenvolvimento), adiantado da Fase 7 para destravar o playtest do dono | CONFIRMADA — dono, 21/09 |

---

## 14. Registro de execução

Ponto de retorno: `~/dev/sop-snapshots/2026-09-16-combate-historia/` — árvore de
código/texto antes de qualquer edição, `git_status.txt`, hashes dos arquivos-alvo,
traço de locomoção de referência e um patch por fase em `fases/faseN/`
(`patch -R -p1 < faseN.patch` desfaz só aquela fase).

### Fase 0 — linha de base (16/09/2026)

| medição | resultado |
|---|---|
| bateria headless (sem `test_frutas` e sem `test_sala_publica`, que abre porta no roteador) | **85 passou / 8 falhou** — as 8 pré-existentes: `test_balance`, `test_bara_combat`, `test_compila` (6 do estúdio), `test_corte_horizontal`, `test_mera_z_saque`, `test_ope_animacoes`, `test_studio_playback`, `test_trava_fruta_dano` |
| testes com tela (`test_melee_trava`, `test_segurar_ataque`, `test_toque`) | **3 / 3** |
| traço de locomoção | reprova contra `traco_esperado.txt` (defasado, item 52); o traço de HOJE virou a referência desta frente (`traco_linha_de_base.txt`, sha256 `92c55d24…`) |
| sonda: `Input.mouse_mode` em headless | **não fica CAPTURED** — clique real só é testável com tela (item 64) |

### Fase 1 — arquitetura base (16/09/2026) ✅

- **Criados:** `src/combat/direcional/` (`golpe_direcional.gd`, `estilo_corpo_a_corpo.gd`,
  `executor_corpo_a_corpo.gd`, `ator_de_combate.gd`, `ator_jogador.gd`,
  `depuracao_de_combate.gd`, `estilos/boxe.tres`), `tools/dev_tests/test_executor_corpo_a_corpo.gd`,
  `tools/dev_tests/test_combate_historia.gd`.
- **Alterados:** `Player.gd` (+~35 linhas: campo `combate_direcional`, `esta_atacando`,
  `em_startup_de_ataque`, `corpo_livre_para_golpe`, desvio no `_request_melee`, trava do
  dash), `src/historia/ModoHistoria.gd` (chave de ativação + `instalar_combate_direcional`).
- **Validação:** executor **42/42**; integração no Modo História **20/20** headless + clique
  real com tela ✅; `test_compila` = as 6 falhas do estúdio; `test_arena`,
  `test_ataques_contextuais`, `test_counter_hit`, `test_inimigos_historia`,
  `test_modo_historia`, `test_modos_de_combate`, `test_fsm`, `test_melee_trava` verdes;
  traço de locomoção **idêntico** à referência.
- **Estado visível:** nenhum no jogo normal (chave desligada). Com
  `SOP_COMBATE_DIRECIONAL=1 ./jogar_historia.sh` e combate liberado em M → TESTE, o
  clique passa pelas fases (F10 mostra o painel), ainda **sem pose e sem dano**.

### Fase 2 — ataques direcionais (16/09/2026) ✅

- **Criados:** `src/combat/direcional/entrada_corpo_a_corpo.gd` (InputMap, gesto do mouse
  num anel fixo de 64 amostras, classificação), `tools/dev_tests/test_entrada_corpo_a_corpo.gd`,
  `tools/dev_tests/test_combate_historia_tela.gd` (com tela).
- **Alterados:** `project.godot` (seção `[input]`: `combate_atacar`, `combate_defender` —
  as únicas ações do projeto), `Player.gd` (campo `entrada_combate_direcional`, ponte no
  `_unhandled_input`, fator de movimento, teto de giro do corpo, parkour de parede solta o
  golpe), `ModoHistoria.gd` (instala a entrada), `validar.sh` (teste com tela no bloco
  com tela), `test_combate_historia.gd` (+giro, +mobilidade).
- **Validação:** entrada **21/21**; integração headless **26/26**; com tela **9/9** (as
  4 direções pelo gesto real, câmera e golpe no mesmo sentido, janela M bloqueia);
  medido: no ATIVO o corpo gira 0,0436 rad/quadro (= teto da ficha) contra 1,225 do
  controle; no PREPARO anda ×0,60 do controle (= ficha). Regressão: 17 testes (arena,
  contextuais, counter hit, câmera, walk_run, editor, Modo História, inimigos, FSM,
  trava do M1, segurar ataque, toque) verdes; `test_compila` só com as 6 do estúdio;
  traço de locomoção **idêntico**.
- **Dívida no gatilho:** a ponte no `Player.gd` chegou a ~31 linhas de código (fora
  comentários) — o gatilho de D2 era ~30. Reavaliar a extração de um `PonteDeCombate`
  ANTES de a Fase 3 somar qualquer linha ao Player.

### Fase 3 — contato, pose e reação (16/09/2026) ✅

- **Criados:** `src/combat/direcional/` → `chave_de_pose.gd` (pose-chave como dado: alvo do
  punho + rotações), `pose_de_combate.gd` (avaliação pura, Hermite, cache por golpe),
  `aplicador_de_pose.gd` (pose DEPOIS do animador + IK de dois ossos + tampas de
  cotovelo/joelho), `resolucao_de_contato.gd` (lado pela geometria; resultado),
  `ator_boneco.gd`, `boneco_de_duelo.gd` (mesmo rig e executor do jogador),
  `apresentacao_de_combate.gd` (som e tremor a partir dos sinais). Testes:
  `test_pose_de_combate.gd`, `test_resolucao_de_contato.gd`, `test_contato_historia.gd`.
  Instrumentos (fora da bateria): `medir_pose_combate.gd`, `capturar_pose_combate.gd`.
- **Alterados:** `executor_corpo_a_corpo.gd` (camada de pose, varredura no ATIVO com
  `SwordSweep.contacts`, estado REAÇÃO, hitstop por ator, avanço, multiplicador de dano,
  postura de combate), `golpe_direcional.gd` (contato, avanço, chaves), `estilo_corpo_a_corpo.gd`
  (guarda, transições, postura, 5 reações), `ator_de_combate.gd` (o que é comum a corpo com
  rig), `ator_jogador.gd`, `depuracao_de_combate.gd`, `estilos/boxe.tres` (poses),
  `Player.gd` (`modelo_visual()` + avanço somado em `_etapa_mover`), `ModoHistoria.gd`
  (apresentação; **chave apagada — combate direcional é o padrão do Modo História**),
  `test_modo_historia.gd` (controle do ataque pergunta `esta_atacando()`),
  `test_inimigos_historia.gd` (aproxima o jogador: não há puxão automático).
- **Decisões desta fase (revisões declaradas do plano):**
  - D7 revisado: a pose é aplicada **depois** do animador, não por gancho dentro dele — o
    `ProceduralAnimator` (diff aberto de outra frente) ficou **intocado**. Mãos por alvo + IK;
    coluna e cabeça por rotação.
  - IK de dois ossos **próprio**, não o do `YoruRig` (que arrasta arquivos da frente da espada,
    fora do git). Gatilho: terceiro IK de dois ossos → extrair compartilhado.
  - Estado REAÇÃO entrou já nesta fase (a reação por lado era critério da Fase 3).
  - **Guarda após a ação** (`guarda_apos_acao` = 2,5 s): a guarda fica erguida depois de cada
    ação. Motivo medido abaixo.
  - **Multiplicador de dano por ator** (jogador 1,0; boneco 0,1) em vez de um estilo por escala.
  - Acerto no ATIVO não interrompe (troca de golpes), como a §7.1.
- **Medido no rig real (`medir_pose_combate.gd`):** erro da IK ≤ 2 cm; alcance máximo do
  punho no ATIVO nos 4 golpes (jab 0,53 m; ganchos 0,44; overhand 0,46); **pico de velocidade
  do punho no ATIVO nos 4** (jab 8,5; ganchos 5,8; overhand 7,4 m/s). Antes da correção o pico
  caía no PREPARO (12–15 m/s): entrada de pose curta demais e arco no fim do preparo.
- **Validação:** pose **21/21**; resolução **41/41** (40 casos em 8 orientações + controle que
  sabe reprovar); contato com dois corpos **tudo verde** — jab a 4 m não acerta (controle), a
  1,1 m acerta uma vez, no ATIVO, com o dano da ficha e hitstop; 20/20 lados (4 direções +
  costas × 4 orientações); golpe interrompido no preparo não machuca; o boneco bate no
  jogador pelo mesmo executor sem input; `Engine.time_scale` constante; pré-condição de
  posicionamento garantida (0 inválidos). **Bateria completa: 95 passou / 8 falhou — as 8 da
  linha de base**; traço de locomoção **idêntico**; `test_compila` só com as 6 do estúdio.
- **Visual (capturas em 3ª pessoa e lateral):** jab, ganchos e overhand leem como golpe; o
  boneco reage de forma legível. **Limites reais, para a Fase 6:** corpo de baixo parado (sem
  passo, joelho ou transferência de peso); mãos abertas (sem punho fechado); reação pesada
  exagerada (~45° para trás); a câmera no ombro direito **tampa golpes da mão esquerda** (o jab
  lê mais pela reação do alvo); margem de alcance curta — o jab erra a 1,6 m de um inimigo de
  1,4 m (margem medida zero) e o gancho falhou a 1,21 m do boneco; sem partículas/faíscas.
- **Problemas achados e registrados (erros.md + cérebro):** teleporte de dois corpos no mesmo
  quadro despenetra; corpo criado sobreposto vira plataforma; pico de velocidade fora do ATIVO;
  `.tres` omite campo igual ao padrão; headless não captura mouse; citar classe que tipa
  `Player` num teste `-s` envenena o Player. Um diagnóstico meu estava errado (knockback) e
  está registrado como descartado.
- **Gatilho de D2 reavaliado:** a ponte no `Player.gd` soma ~37 linhas de código em 9 pontos.
  **Mantida sem extração:** são desvios posicionais no ciclo do Player (entrada, velocidade,
  frente, mover, consultas públicas), sem lógica — extrair mudaria só onde as expressões moram,
  e cada ponto continuaria existindo. Novo gatilho: um desvio passar de 3 linhas de lógica ou
  surgir o 10º ponto.

### Fase 4 — defesa: guarda, postura e quebra (16/09/2026) ✅

- **Criados:** `src/combat/direcional/cerebro_de_treino.gd` (IA mínima: parado, guarda
  sempre, ataque em ciclo — decide pelos MESMOS pedidos do jogador),
  `tools/dev_tests/test_defesa_historia.gd`.
- **Alterados:** `executor_corpo_a_corpo.gd` (estados GUARDA, BAIXANDO, QUEBRA; guarda como
  INTENÇÃO resolvida pela máquina de estados; postura com atraso e regeneração; resultado do
  contato BLOQUEIO/QUEBRA antes do dano; poses de guarda erguida, tranco e quebra),
  `resolucao_de_contato.gd` (cone da guarda e tabela pura acerto/bloqueio/quebra),
  `estilo_corpo_a_corpo.gd` (grupo Defesa + invariantes §7.5 cobrados na validação),
  `golpe_direcional.gd` (`dano_de_postura`), `entrada_corpo_a_corpo.gd` (RMB lido pelo
  ESTADO do botão), `apresentacao_de_combate.gd` (som e tremor de bloqueio e quebra),
  `depuracao_de_combate.gd` (postura), `pose_de_combate.gd` (mistura sem papel velho),
  `estilos/boxe.tres`, `test_executor_corpo_a_corpo.gd` (+26 checagens),
  `test_resolucao_de_contato.gd` (+64 casos de defesa), `test_combate_historia_tela.gd` (RMB real),
  `capturar_pose_combate.gd` (fotos da defesa). **`Player.gd` e `ModoHistoria.gd` não foram
  tocados** — a ponte não cresceu.
- **Renomeado:** `postura_apos_acao` → `guarda_apos_acao` (a "postura" passou a ser só a
  resistência da guarda; dois conceitos com o mesmo nome confundiriam).
- **Decisões:**
  - A guarda é uma intenção (`_guarda_pedida`), não um evento: entra assim que o estado deixa
    (neutro, fim de BAIXANDO, fim de reação, 60% da recuperação). Com o RMB segurado, o corpo
    volta sozinho à guarda depois de um golpe.
  - O RMB é lido pelo estado a cada quadro: abrir menu segurando o botão derruba a guarda (a UI
    engoliria o evento de soltar e a guarda ficaria presa).
  - Da guarda se ataca direto (o preparo é o custo); guarda pedida no PREPARO não interrompe
    (é finta, Fase 5).
  - Quebra de guarda sem dano; o castigo é o próximo golpe entrar (medido).
  - Postura sem barra visível (§7); fica no painel F10.
- **Números do boxe (calibráveis no `.tres`):** cone 120°; postura 100, regenera 25/s depois de
  1,0 s; quebra 0,9 s saindo com 50; baixar a guarda 0,2 s; guarda liberada a 60% da
  recuperação; movimento ×0,55 em guarda e ×0,3 na quebra; dano de postura jab 15, ganchos 25,
  overhand 40.
- **Validação:** executor **68/68** (26 novas da defesa: BAIXANDO impede re-erguer por 0,20 s;
  guarda entra na recuperação em 0,563 s com liberação em 0,560 s; quebra dura 0,900 s;
  sabotagens dos invariantes reprovadas); resolução **4/4** checagens cobrindo 40 casos de lado e
  64 de defesa em 8 orientações; defesa com dois corpos **tudo
  verde** — as 4 direções bloqueadas com a postura exata (85/75/75/60), de costas entra, postura
  10 contra gancho quebra sem dano e o jab seguinte ENTRA durante a quebra, o boneco em guarda
  segura o jab do jogador, o cérebro atacou 3× e as 3 foram bloqueadas; com tela **14/14** (RMB
  real ergue, soltar baixa, menu aberto derruba a guarda). **Bateria completa: 96 passou / 8
  falhou — as 8 da linha de base**; traço de locomoção **idêntico**.
- **Visual:** guarda erguida, tranco na guarda e quebra leem na tela; a pose de quebra está
  exagerada (cabeça muito para trás) — calibração da Fase 6.
- **Erros meus no teste, corrigidos antes de concluir:** boneco posicionado de costas (yaw 0
  olha para −Z); vida comparada com igualdade exata sem contar a regeneração; estado do
  defensor lido depois da resolução.

### Fase 5 — aparo, riposte e finta (16/09/2026) ✅

- **Criados:** `tools/dev_tests/test_aparo_historia.gd` (dois corpos reais: aparo na hora ×
  cedo, varredura a partir do contato, riposte, riposte bloqueável, finta contra aparo, cérebro).
- **Alterados:** `executor_corpo_a_corpo.gd` (estado REBATIDO; janela de aparo por aperto novo;
  janela e relógio do riposte; finta para outro golpe ou para a guarda; APARO antes do dano;
  mistura de transição só entre AÇÕES diferentes), `resolucao_de_contato.gd` (resultado APARO e
  parâmetro `aparando`), `estilo_corpo_a_corpo.gd` (grupo "Aparo, riposte e finta" + invariante
  do rebote), `golpe_direcional.gd` (`aparavel`), `cerebro_de_treino.gd` (modo APARA_E_RIPOSTA),
  `apresentacao_de_combate.gd` (som e tremor do aparo e do rebote), `depuracao_de_combate.gd`
  (aparo/riposte/finta no F10), `estilos/boxe.tres`, `test_executor_corpo_a_corpo.gd` (+22
  checagens; uma asserção da Fase 4 atualizada — aperto novo do RMB no preparo agora é finta),
  `test_resolucao_de_contato.gd` (assinatura), `capturar_pose_combate.gd` (foto do aparo).
  **`Player.gd` e `ModoHistoria.gd` não foram tocados** — a ponte continua com 9 pontos.
- **Números do boxe (calibráveis no `.tres`):** janela de aparo 0,20 s; rebatido 0,15 s; janela
  de riposte 0,6 s; riposte com 0,6 do preparo; finta nos primeiros 60% do preparo, com pelo menos
  0,12 s pela frente, custando 10 de postura.
- **Risco/recompensa, pela regra (não por sensação):** o spam de RMB não apara — soltar e reapertar
  passa por BAIXANDO (0,20 s), e quando a guarda sobe a janela (0,20 s) já venceu. O riposte do jab
  (0,18 s) é mais longo que o rebote (0,15 s) e ainda paga o hitstop do aparo (0,045 s) — medido:
  o boneco rebatido que aperta a guarda logo SEGURA o riposte. A finta é uma por ataque e custa
  postura: sem postura, não há finta.
- **Validação:** executor **90/90** (22 novas: janela fecha em 0,217 s com ficha 0,20 — quantização
  de quadro; guarda segurada não abre janela; spam não apara; riposte usa a janela e dura 0,183 s com
  ficha 0,180; rebote 0,150 s; mesma direção não finta; segunda finta e finta tardia recusadas; sem
  postura não finta; RMB novo finta para a guarda já na janela; sabotagem do invariante do rebote
  reprovada); resolução **4/4**; aparo com dois corpos **20/20** — varredura do "pronto quando":
  RMB a 0,25 s do contato BLOQUEIA, a 0,15 s e 0,05 s APARA (medidos 0,250/0,150/0,050); aparo sem
  custo de vida e postura; riposte sai em 0,233 s contra 0,30 s (0,18 da ficha + hitstop do aparo +
  quadro) e acerta quem não defende; riposte bloqueado por quem reage; overhand fintado para gancho
  faz a janela do aparo do boneco vencer (vira BLOQUEIO); o cérebro apara o jab do jogador e o
  riposte dele acerta. **Bateria completa: 97 passou / 8 falhou — as 8 da linha de base**; traço de
  locomoção **idêntico**; `test_compila` só com as 6 do estúdio.
- **Visual:** o rebote do boneco lê na tela. **Limite real, para a Fase 6:** o gesto de APARO do
  jogador é quase igual à guarda — hoje o aparo se distingue pelo som (mais grave) e pelo rebote de
  quem bateu, não pela pose.
- **Pego antes de rodar:** capturar transição também entre fases do MESMO golpe (PREPARO→ATIVO)
  atrasaria o punho justo no início da hitbox; a mistura ficou restrita a ações diferentes.
- **Portão `critico-de-combate` (Fases 4 e 5):** ainda não rodado — próximo passo, antes da Fase 6.

### Fase 5.1 — portão do crítico de combate (17/09/2026) ✅

O `critico-de-combate` (agente, só leitura) avaliou as Fases 4–5 e achou duas
estratégias degeneradas e uma invariante furada. Conferi cada achado no código e com
sabotagem antes de aceitar — uma das contas dele estava sem o hitstop.

- **Alterados:** `executor_corpo_a_corpo.gd` (recuperação pendente; finta pendente;
  `_guardar_no_buffer`/`_soltar_buffer_pendente`; sofrer descarta o clique guardado),
  `estilo_corpo_a_corpo.gd` (invariante da quebra reescrita + `FOLGA_DA_QUEBRA`),
  `estilos/boxe.tres` (quebra 0,9 → 1,1 s; buffer 0,15 → 0,30 s),
  `test_executor_corpo_a_corpo.gd` (seção 13 nova; asserção da Fase 4 que afirmava o
  atalho foi reescrita), `test_defesa_historia.gd` (quebra por gancho e por overhand).
- **Medido (sabotando a correção):** com o RMB segurado o ciclo caía para jab 0,567 s
  (golpe 0,680), ganchos 0,767 (0,920), overhand 1,000 (1,220) — os números do crítico.
  Com a correção, o menor intervalo é ≥ duração − 1 quadro, com a guarda tendo
  interrompido a recuperação 2 a 4 vezes em 3 s.
- **Buffer 0,30 e não 0,25:** a conta do crítico não contava o hitstop do contato que
  quebra (gancho 0,055 s). Com 0,25 o clique de reação a 0,25 s ainda era descartado;
  com 0,30 a quebra por gancho rende jab num clique só, e a por overhand rende
  martelando. Efeito colateral aceito: a recuperação inteira do jab passa a aceitar
  buffer (a cadência continua presa pela duração do golpe).
- **Validação:** executor **100/100**, defesa **22/22**, aparo **19/19**; as duas
  sabotagens (recuperação pendente e finta herdada) reprovam como esperado.
- **Hipóteses do crítico que ficaram para o playtest do dono:** janela de aparo 0,20
  pode ser fácil demais (ele propôs 0,15); overhand pode ser punível demais; ganchos são
  o golpe mais fraco do kit (esquerda e direita só mudam a animação até existir contra-ataque);
  recuo livre do defensor (4,2 m/s) contra quem prepara (2,52 m/s).

### Fase 6 — animações finais do boxe (17/09/2026) ✅

- **Criados:** `src/combat/direcional/impacto_de_combate.gd` (impacto visual por
  resultado), `tools/dev_tests/medir_leitura_combate.gd` (leitura na câmera real),
  `docs/combat/` (README, ARQUITETURA, REGRAS, DADOS, ENTRADAS — entrega da Fase 7
  adiantada), autoria reproduzível em `fases/fase6/autorar_boxe_fase6.gd` (snapshot).
- **Alterados:** `chave_de_pose.gd` (pés, joelhos e quadril por alvo),
  `estilo_corpo_a_corpo.gd` (`maos`, grupo "Pés de apoio" + validação),
  `pose_de_combate.gd` (alvos novos; **herança explícita da guarda do estilo**),
  `aplicador_de_pose.gd` (IK das pernas com a direção REAL do filho; quadril sem
  acúmulo; pé de apoio travado no antepé com passo automático e um pé de cada vez;
  dedos), `ator_de_combate.gd` (o avanço do golpe não conta como andar; corpo empurrado
  derrapa), `executor_corpo_a_corpo.gd` (avanço aplicado do quadro; estados de sofrimento),
  `apresentacao_de_combate.gd` (chama o impacto visual), `estilos/boxe.tres` (base,
  punho fechado, corpo de baixo nos 4 golpes, aparo, reações calibradas),
  `medir_pose_combate.gd` (pés, quadril, erro do pé travado),
  `capturar_pose_combate.gd` (guarda/mãos e filtro de captura),
  `test_pose_de_combate.gd` (seção 3b da herança). **`Player.gd` e `ModoHistoria.gd`
  não foram tocados.**
- **Medido no rig real (`medir_pose_combate.gd`):** erro da IK do braço 0,000 m (overhand
  0,021); alcance do efetor jab 0,539 m, ganchos 0,438/0,444, overhand 0,454; **pico de
  velocidade do punho nos 4 golpes dentro do ATIVO** (7,89 / 9,26 / 9,23 / 7,31 m/s);
  pé travado desliza ≤ 1,7 cm e erro antepé × âncora ≤ 8 mm; 0–2 passos por golpe, nunca
  os dois pés no ar; sola nunca abaixo de −0,9 cm; quadril mínimo 0,58–0,60 m (base com
  joelhos dobrados, contra 0,685 m em repouso).
- **Medido na câmera do jogo (`medir_leitura_combate.gd`, 1280×720, adversário a 1,1 m):**
  os punhos do adversário ficam VISÍVEIS nas 4 direções durante a carga; o vetor da carga
  na tela separa as direções — jab (−4, +17) px, gancho de direita (−25, +9), gancho de
  esquerda (+25, +9), overhand (−18, −22) — com **menor ângulo de 58°** entre duas
  direções. O jab é o de menor amplitude de propósito (é o mais rápido e o mais fraco).
- **Limite estrutural medido:** na câmera do PRÓPRIO atacante (ombro direito, 4 m), o
  punho fica escondido atrás do tronco/cabeça em todo contato, e as 4 direções ficam a
  ~15 px umas das outras. É geometria de câmera sobre o ombro, não pose: o atacante lê o
  próprio golpe pelo corpo, pelo som e pelo impacto; quem precisa ler direção é o
  DEFENSOR, e para ele a leitura está medida acima.
- **Erros corrigidos (todos em `docs/erros.md` + cérebro):** IK da perna supondo o osso em
  −Y (tornozelo 3,9 cm fora, virava deslize no pivô); dois pés em passo ao mesmo tempo;
  posturas herdando da própria pose (guarda erguida sem pés).
- **Validação:** executor 100/100, pose 24/24, contato 35/35, defesa 22/22, aparo 19/19,
  integração 26/26, inimigos 18/18, Modo História 75/75.
- **Portão `avaliador-de-animacao` (17/09):** ele mediu com sondas próprias a 1 kHz (a
  minha sonda amostrava a 60 Hz e media o jab FRIO, saindo do idle — buraco de cobertura
  que ele achou e que fechei: agora a sonda aquece o corpo e mede o salto do tornozelo).
  Aceitos e corrigidos:
  1. **pé teleportava ao soltar a âncora** (14,9 cm num quadro, 8,9 m/s — mais rápido que o
     punho): toda soltura passa por passo; soltar por ALCANCE não espera o outro pé.
     Depois: salto máximo 5,5 cm (3,3 m/s), deslize do pé travado 0,0 cm em todos.
  2. **overhand com o braço travado em 179° por 134 ms**: o alvo da carga estava 2,1 cm fora
     do alcance. Carga (0,29; 1,42; 0) → (0,26; 1,36; 0,02): erro de IK 0,000.
  3. **quadril SUBIA no contato** (jab +1,5 cm, ganchos +1,0): os quadris dos golpes ficaram
     para trás quando a guarda foi para −0,095. Todos rebaixados 2 cm.
  4. **cadeia cinética inexistente** (quadril e peito picavam com 0–3 ms): a escada foi
     autorada na chave do começo do ATIVO dos ganchos e do overhand. Medido depois:
     peito − quadril = +78 ms (gancho direita), +43 (esquerda), +39 (overhand).
  5. **reações esquerda e direita não eram espelho** (34° de diferença) e **costas era 39%
     mais rasa**: as duas laterais saem agora do mesmo par de valores com sinal trocado, as
     costas ganharam profundidade, e as três levam as MÃOS junto com o tronco (elas ficavam
     presas no ar enquanto o peito andava 5 cm).
  6. **o giro do quadril morria ao andar**: `Torso` saiu da lista de papéis que voltam para a
     marcha do animador — só o DESLOCAMENTO do quadril acompanha as pernas.
  Recusados, com motivo:
  - **espelhar os ganchos** (cotovelo 127° × 102°): a base ortodoxa é assimétrica de
    propósito — o gancho da frente é mais curto e mais fraco que o de trás. Não é defeito.
  - **chave de antecipação no jab**: tentei, medi e desfiz — ela fazia o punho PARAR no meio
    (0,1 m/s entre 0,23 e 0,27 s) e estalar a 11,7 m/s depois. O jab é golpe de braço:
    quadril e ombro chegam juntos, por decisão medida.
  - **suavizar a subida da guarda** (punhos a 8,2 m/s vindos do idle): erguer a guarda é
    ação defensiva e precisa ser responsiva; o pico dura 1–2 quadros.
  - **as pernas voltarem para a pose ao ANDAR** (o divisor de 1,5 m/s): mexer nisso exige
    decidir se o combate anda em base de lutador (passinhos) ou em marcha — é decisão de
    jogo, não de animação. Fica como pendência declarada para o playtest do dono.
- **Visual:** base de lutador com joelhos dobrados e pés escalonados; punho fechado lê na
  câmera do jogo; pivô do gancho no antepé; overhand com passo da frente antes do contato
  e quadril caindo; boneco empurrado absorve o golpe (antes parecia correr); aparo com
  clarão e anel, distinto do bloqueio. **Limitações conhecidas:** o polegar só se resolve
  em close-up (sub-pixel em jogo); a primeira ação saída do idle ainda entra na base
  durante a carga (o passo de entrada leva 0,14 s).

### Fase 7a — troca no ATIVO e boneco de duelo no jogo (21/09/2026) ✅

Pedido do dono depois de uma análise do estado do combate: corrigir a troca no ATIVO e
adiantar da Fase 7 só o boneco invocável, para o playtest da defesa acontecer.

- **Defeito achado na análise (confirmado por sonda com dois corpos reais):** acerto no
  ATIVO cancelava o golpe do JOGADOR no quadro seguinte (`impedido`), e o do boneco
  seguia — a §7.1 valia de um lado só. Causa: o `take_damage` do Player atordoa em todo
  dano, e `AtorJogador.impedido()` contava o atordoamento; o boneco ignora hitstun.
  Detalhe em `docs/erros.md` (21/09).
- **Alterados:** `Player.gd` (`corpo_livre_para_golpe(contar_atordoamento := true)` — o
  mesmo ponto da ponte, sem ponto novo; continua com 9), `ator_de_combate.gd`,
  `ator_jogador.gd`, `ator_boneco.gd` (`impedido(contar_atordoamento)`),
  `executor_corpo_a_corpo.gd` (`_id_que_trocou`: o golpe acertado no ATIVO só cai por trava
  dura), `ModoHistoria.gd` (`invocar_boneco`/`remover_boneco`, direções sorteadas entre as
  do estilo, um boneco por vez, sem XP), `JanelaDeStatus.gd` (linha "Boneco de duelo" na
  seção TESTE: Parado, Só guarda, Ataca, Apara e responde, Remover — só pede, por sinal),
  `docs/combat/` (README, REGRAS, ARQUITETURA), `docs/erros.md`.
- **Testes novos:** `test_executor_corpo_a_corpo` seção 14 (6 checagens, com controles:
  atordoado no PREPARO cai; o golpe seguinte não herda a marca; trava dura cancela até o
  golpe que trocou); `test_contato_historia` seção F (4: acerto nas costas durante o ATIVO
  do jogador e troca de frente) — **reprovou 2 antes da correção**; `test_combate_historia`
  seção 8 (10: botões da janela, posição 1,80 m no chão, mesmo estilo, "Parado" não ataca
  em 2,5 s como controle, "Ataca" ataca, trocar modo mantém o mesmo boneco, guarda, remover).
- **Validação:** executor 106/106, contato 39/39, integração 36/36, pose 24/24,
  resolução 4/4, entrada 21/21, defesa 22/22, aparo 19/19, Modo História 75/75,
  inimigos 18/18. **Bateria headless (mesmo recorte da Fase 0): 87 passou / 8
  falhou — exatamente as 8 da linha de base**; `test_compila` só com as 6 do estúdio;
  `test_gomu_leak` verde com o tempo do `validar.sh` (240 s).
- **Não rodado:** traço de locomoção e `test_combate_historia_tela` — os dois capturam o
  mouse do desktop real. O `corpo_livre_para_golpe` só é chamado pelo `AtorJogador` e o
  padrão do parâmetro mantém o comportamento antigo; a arena não passa por ele.
- **Limites do boneco (declarados):** não anda — o empurrão dos golpes o afasta e "Ataca"
  passa a socar o ar até ser chamado de novo (pedir outro modo o traz de volta); a escala de
  dano dele contra o jogador é a da §7.4 (0,1), então o Civil de vida 20 cai em ~10 golpes.
  Gatilho para um boneco que persegue: o playtest pedir pressão contínua.

### Fase 7b — pés do boneco crescendo (21/09/2026) ✅

- **Reportado pelo dono:** o boneco "Ataca" (janela M) tinha os pés crescendo a cada golpe, sem
  voltar. **Causa** (detalhe em `docs/erros.md`, 21/09): o `AplicadorDePose` reescrevia
  `global_basis` carregando a escala lida do global; o erro numérico da IK virava escala LOCAL do
  pé, que o animador (só escreve `rotation`) preservava — crescimento acumulado a cada quadro.
- **Alterados:** `aplicador_de_pose.gd` (`_girar_global`: só rotação local no pé, na IK da perna e
  no `_apontar` dos braços), `test_contato_historia.gd` (seção G), `docs/erros.md`,
  `docs/LISTA_DE_CORRECOES.md` (item 65: o `YoruRig` tem o mesmo padrão), contextos de agentes.
- **Medido:** pé R de (0,99; 0,61; 1,67) em 13 golpes para (1,000; 1,000; 1,000); seção G reprovou
  antes (desvio 233.119) e passa (0,0000). `medir_pose_combate`: 116/119 linhas idênticas, 1–6 mm
  de diferença na sola/quadril, erro da IK e deslize do pé inalterados.
- **Validação:** contato 41/41, executor 106, pose 24, resolução 4, defesa 22, aparo 19, integração
  36, Modo História 75, inimigos 18, vida/energia 19; `test_compila` só com as 6 do estúdio.
