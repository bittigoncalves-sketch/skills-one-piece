# Plano — combate corpo a corpo estilo Battlegrounds (Roblox)

Pedido do dono (2026-08-18): pesquisar e planejar a conversão do corpo a corpo
(botão esquerdo) para o estilo dos *battlegrounds* do Roblox — The Strongest
Battlegrounds (TSB), Jujutsu Shenanigans (JJS), Untitled Boxing Game (UBG),
Alternate Battlegrounds (AB) — e refazer as animações do combo.

> **Isto é PLANEJAMENTO, não implementação.** Cinco agentes especializados
> trabalharam em paralelo (auditoria do código, pesquisa externa, desenho de
> FSM/frame data, rede, animação), seguindo a regra de divisão do
> [`AGENTES.md`](AGENTES.md). Nenhum arquivo do projeto foi alterado por eles.

**Nota sobre o momento da auditoria:** durante a pesquisa (2026-08-18), havia
mudanças **locais não commitadas** em `Melee.gd`, `melee_controller.gd`,
`DamageZone.gd`, `ProceduralAnimator.gd` e `Player.gd` — parte de trabalho
paralelo do próprio dono/outra sessão (troca do chute frontal por lateral,
início de auto-mira/lunge, esboço de "combo breaker", threading de `hitstun`
pela `DamageZone`). Este plano já foi conferido contra esse estado — ver
§0 — e não contradiz esse trabalho; em vários pontos ele já anda na mesma
direção.

---

## 0. O que já existe e muda o ponto de partida

Achados de conferência direta (não vieram dos agentes, vieram de checar o
working tree depois que eles entregaram):

1. **A FSM já não é mais o `enum CombatState` de 5 estados.** Foi trocada por
   objetos: `PlayerStateMachine` + `PlayerState` em `src/player/hsm/`, com
   `CombatStateIdle`, `CombatStateAttacking`, `CombatStateDashing` como nós
   filhos. `"Stunned"` já é **referenciado** em várias checagens
   (`Player.gd:237`, `:799`, `:942`, `:1052`, `:1513`) mas **não tem classe
   própria ainda** — é exatamente o buraco que o agente de FSM/frame data
   também encontrou (via `test_fsm.gd`, que já assumia `ATTACK_RECOVERY`).
   Este plano deve criar `CombatStateStunned.gd`, `CombatStateBlocking.gd` etc.
   como **novos `PlayerState`**, não como valores de enum.
2. **`find_best_melee_target()` e `perform_melee_lunge()` já existem**
   (`Player.gd:1463-1504`), chamados de `CombatStateAttacking.enter()`: cone
   frontal, raio 12 m, pontuação por ângulo+distância, giro instantâneo (yaw
   snap) para o alvo e impulso de velocidade de 18 m/s na entrada do ataque.
   **Isto já é o "auto-face + lunge" que a pesquisa recomendou** (JJS: puxão
   de ~0,28 m; TSB/JJS: hitbox orientada pela mira). Falta calibrar a
   distância/força para os números-alvo (§3) e ligar ao cone/hitbox novos —
   não precisa ser inventado do zero.
3. **Há um esboço de "combo breaker"** (`Player.gd:1507-1516`, tecla **G**),
   ativável só sob stun, com `cooldown 45.0s` comentado como "punitivo" — é
   claramente um placeholder, não um valor calibrado. **Isto consome a tecla
   G**, que os agentes listaram como candidata a bloqueio/feint — G fica
   reservado para o combo breaker; bloqueio vai para **F** (§5).
4. **`DamageZone.setup()` já recebe `hitstun_dur`** e emite `hit_landed`
   (usado por `Melee.gd` para setar `hit_confirmed` no dash-cancel). O
   `ProceduralAnimator.trigger_hitstop(duration, shake)` **já existe como
   método**, mas **ainda não é chamado por ninguém do lado de quem bate** —
   confirma o achado do agente de animação: é alavanca pronta e ociosa.
5. **O chute do combo já não é mais `kicking` (frontal, perna D)** — virou
   `roundhouse_kick` (lateral, perna E), com overlay `melee_guarda: "perna_L"`
   já encaminhado para `MeleePoses.pernas_v()`/`guarda_bracos()`. Isso
   **confirma que o mecanismo de overlay que o agente de animação recomendou
   usar para os 4 M1 novos já está em produção e funcionando** — não é uma
   proposta nova, é extensão de um padrão que já existe.

Este plano incorpora esses cinco pontos como base; o resto das seções usa os
achados dos agentes, com correções pontuais onde o código mudou.

---

## 1. A decisão que só o dono pode tomar

**A explicitada em 2026-08-15** (registrada em
`tools/dev_tests/test_melee_trava.gd`): *"ao clicar não vai ser possível se
mover até que a animação do combate se encerre"*. É por isso que
`Melee.TRAVA_DA_ANIMACAO = 1.0` prende o corpo pela duração inteira do clipe
— hoje **4,99 s** no combo de 4 golpes.

Um M1 de battlegrounds trava por ciclo (startup+ativo+recuperação) de
**~0,40 s**, encadeando 4 em **~1,6 s**.

**Isto NÃO é a contradição que parecia ser numa primeira leitura.** Se as
animações forem refeitas para caber em 0,40 s cada (§6) — em vez de aceleradas
—, a trava continua sendo "não se move até a animação acabar", só que a
animação passou a durar 0,40 s em vez de 1,2-1,5 s. A regra do dono continua
valendo ao pé da letra; o que muda é a duração do clipe que ela tranca.

**A única exceção genuinamente nova** (não uma releitura da regra existente):
o design de frame data (§4) propõe que a RECUPERAÇÃO de um golpe seja
cancelável em bloqueio/dash **quando o golpe conectou** (`hit_confirmed`).
Isso já tem precedente no próprio projeto — o dash-cancel de hoje é
exatamente essa exceção, só que restrita ao dash. A pergunta em aberto é se
essa mesma exceção deve valer também para **bloquear** durante a recuperação.
Recomendação: sim, é o padrão do gênero (JJS/TSB permitem side-dash cancelar
o startup; nenhum permite dash de bloqueio DURANTE o bloqueio, mas cancelar
PARA o bloqueio na recuperação é diferente) — mas é uma extensão de regra que
o dono deveria confirmar antes de implementar, porque ele que fixou o
princípio original.

---

## 2. Estado atual — diagnóstico (auditoria de código)

### 2.1 Fluxo de um clique, hoje

`_unhandled_input` (clique) → `_request_melee` (empilha em `input_buffer`,
15 quadros) → FSM (`CombatStateIdle`→`CombatStateAttacking`, só se `IDLE`) →
`MeleeController.pedir` → `pedir_golpe_no_servidor` → RPC `_net_melee` →
`_do_server_melee` → `Melee.golpear` (cria hitbox via `SceneTreeTimer` após
`atraso`) → `DamageZone._on_body` → `take_damage` → `_net_play_melee` (RPC de
volta, toca a animação em todos).

### 2.2 Frame data de hoje (medido, não estimado)

| # | golpe | anim | trava (`recuo`) | atraso (nasce a hitbox) | hitstun causado | dano real (×0,12) |
|---|---|---|---|---|---|---|
| 0 | Soco D | `boxing_1` | 1,489 s | 0,378 s | 0,30 s (default fixo) | 3,60 |
| 1 | Soco E | `left_uppercut_from_guard` | 1,210 s | 0,250 s | 0,30 s | 4,08 |
| 2 | Chute (lateral, `roundhouse_kick`) | — | 1,15 s (recalculado 2026-08-18) | 0,467 s | 0,30 s | 4,80 |
| 3 | Finalizador | `meia_lua_de_compasso` | 1,178 s | 0,711 s | 0,30 s | 8,40 |

**Combo completo ≈ 4,8-5,0 s.** Dano total ≈ 20,9 HP de 2048 (0,3 % da vida —
quem mata é o buraco, não o combo, e isso continua valendo depois da mudança).

### 2.3 A regra matemática que explica por que hoje não existe combo de verdade

```
vantagem_no_acerto = hitstun − (ativo + recuperação)
combo trava  ⟺  vantagem_no_acerto ≥ startup do próximo golpe (+ margem)
```

Com trava = animação inteira e hitstun fixo em 0,30 s, a vantagem de cada
golpe de hoje é **negativa** (de −49f no soco 1 a −10f no finalizador, a
60 fps): **acertar um M1 hoje é uma jogada perdedora** — a resposta ótima do
alvo é levar o golpe e punir, porque o atacante ainda está travado quando o
alvo já pode agir de novo. Isto não é intuição de design, é aritmética da
tabela acima.

### 2.4 Bugs confirmados (não são decisões de design — são defeitos)

| # | bug | evidência | efeito |
|---|---|---|---|
| B1 | Dash-cancel não funciona em rede | `hit_confirmed` setado pela `DamageZone` na cópia do **servidor**, lido em `Player.gd` na cópia do **cliente**, sem RPC entre as duas | Só funciona em singleplayer/host |
| B2 | Estados de stun podem vazar em cópias remotas | escrita em `_feedback_de_dano` roda em todas as cópias; o reset fica atrás do `return` de não-autoridade | risco de stun "eterno" percebido só pelos outros jogadores |
| B3 | `_net_melee` não valida nada além de `is_server()` | `Player.gd` | cliente adulterado pode pedir o Finalizador em loop |
| B4 | Hitstop é GLOBAL (`Engine.time_scale`) e a hitbox nasce de `SceneTreeTimer`, que respeita esse `time_scale` | `GameFlow.hit_stop()` + `Melee.golpear` | o hit de UM jogador deforma o relógio da hitbox de TODOS numa arena cheia |
| B5 | Hitbox de melee não varre o caminho (`vel = ZERO` desliga `_varrer_caminho`) | `Melee.gd` | alvo rápido pode atravessar a esfera entre dois quadros |
| B6 | `trigger_hitstop()` existe e não é chamado por ninguém do lado do atacante | `ProceduralAnimator.gd` | quadro de leitura do impacto (game feel) não está sendo usado, é ganho de graça |

Nenhum destes é causado pelo redesenho — todos já existem hoje e devem ser
corrigidos como parte do trabalho, porque o redesenho os torna mais visíveis
(golpes rápidos expõem mais rede/tempo por segundo do que golpes de 1,5 s).

---

## 3. Referências externas — números-alvo

Pesquisa em wikis de TSB, JJS, UBG, AB e HBG (26 fontes, ver §9). Legenda:
**[W]** dado de wiki/comunidade · **[D]** derivado por engenharia, sem fonte
direta · convergências entre jogos independentes marcadas.

### 3.1 Cadeia de M1

| Parâmetro | Valor-alvo | Fonte |
|---|---|---|
| Golpes na cadeia | **4** (3 normais + 1 finalizador) | TSB+JJS+HBG convergem [W] |
| Dano do combo | **3/3/4/4 = 14 % do HP** | TSB e JJS chegam ao MESMO split, independentemente [W] |
| Startup por M1 | **0,20 s** | JJS mede 0,16-0,23 s [W] |
| Janela ativa | **0,06 s** (~4 ticks a 60 Hz) | [D] — 16 ms do JJS é 1 frame, inviável num servidor de tick 30-60 Hz |
| Recuperação on-hit | **0,14 s** | [D] fecha ciclo de 0,40 s |
| **Ciclo total por M1** | **0,40 s** — cadeia completa **1,6 s** | conferido por dois caminhos independentes (pesquisa + matemática de frame data, ver §4) |
| Recuperação on-block | **0,28 s (dobro)** | JJS: "M1 bloqueado gera o dobro do endlag" [W] |
| Punição de whiff (4º golpe) | **1,0 s de stun no próprio atacante** | TSB [W] |
| Reset da cadeia por inatividade | **2,0 s** | AB+JJS convergem [W] |
| Cooldown após o 4º hit | **2,0 s** | JJS+AB convergem [W] |

### 3.2 Hitstun / true combo

| Parâmetro | Valor | Fonte |
|---|---|---|
| Hitstun por M1 | **0,75 s** | JJS [W] |
| É true combo? | **Sim, por construção**: ciclo 0,40 s < hitstun 0,75 s | design |
| Stun sempre substitui o anterior, mesmo mais curto | regra explícita | AB [W] — evita bug de "stun eterno" |
| Imunidade a stun no wakeup | **0,5 s** | TSB/HBG [W] |

### 3.3 Hitbox e movimento

| Parâmetro | Valor | Fonte |
|---|---|---|
| Forma/tamanho | **caixa de ~2,2 m de aresta** (~1,6× a altura do personagem) | JJS: 8×8×8 studs [W] — deliberadamente grande, é o que compensa latência |
| Orientação | pela **câmera/mira**, não pelo corpo | JJS+TSB [W] — o projeto já faz isso (`fwd` do yaw travado no clique) |
| Lunge (puxão) | **~0,3 m** por hit | JJS [W] — já existe esboço em `perform_melee_lunge`, calibrar |

### 3.4 Bloqueio

| Parâmetro | Valor | Fonte |
|---|---|---|
| Tecla | **F** (segurar) | unânime nos 4 jogos [W] |
| Cone | **180° à frente** | TSB+JJS [W] |
| Modelo | **medidor (100 pts)**, não nulificação binária | UBG/AB [W] — melhor para jogo com latência |
| Custo por M1 bloqueado | **10 pts** | AB [W] — 10 M1s até quebrar |
| Chip damage | 10 % do dano, regenerável | [D] |
| Stun de block break | **2,0 s** | UBG [W] |

### 3.5 Dash

| Parâmetro | Valor | Fonte |
|---|---|---|
| Lateral/trás: distância | **5,0 m** | JJS [W] |
| Lateral/trás: cooldown | **2,0 s** | TSB+JJS+HBG, três fontes [W] |
| Lateral/trás: i-frames | **0,2 s** | AB [W] |
| **O dash de hoje (12 m / CD 1,5 s) está 2,4× longe demais e recarregando rápido demais** para o combo de 1,6 s — com CD de 1,5 s dá para escapar 1× de cada combo; hoje quase 2×. | | |

### 3.6 Ragdoll

| Parâmetro | Valor | Fonte |
|---|---|---|
| Duração | **2,0 s** | TSB+HBG [W] |
| Cancel | side dash + **1,0 s** de i-frames, custa recurso (não cooldown) | JJS [W] |
| Imunidade ao levantar | **0,5 s** | TSB/HBG [W] |

### 3.7 O achado mais importante para a arquitetura: netcode do TSB

> *"Side/Back Dashes são tratados pelo CLIENTE — zero delay local,
> independente do ping. Forward Dash termina em animação de ataque, então é
> tratado pelo SERVIDOR — com 150 ms de ping, o Forward Dash leva
> exatamente 0,15 s para começar a se mover."* — wiki do TSB [W]

Isto é literalmente o modelo que este projeto **já usa** (§0, §5): movimento é
autoridade do cliente dono, dano é autoridade do servidor. O jogo nº 1 do
gênero aceita o delay de 1 RTT no ataque como normal — o projeto não precisa
"esconder" a rede, precisa só parar de fazer o atacante ver a PRÓPRIA
animação atrasada (§5).

---

## 4. Desenho novo — máquina de estados e frame data

### 4.1 Estados novos (como `PlayerState`, não enum — ver §0.1)

| Estado | Move | Ataca | Dash | Bloqueia | Entra por | Sai por |
|---|---|---|---|---|---|---|
| `CombatStateIdle` | ✓ | ✓ | ✓ | ✓ | padrão | qualquer entrada |
| `CombatStateAttackStartup` | avanço scriptado (lunge) | buffer | ✗ | ✗ | clique aceito | fim de `atraso` |
| `CombatStateAttackActive` | ✗ | ✗ | ✗ | ✗ | fim do startup | fim de `vida` |
| `CombatStateAttackRecovery` | ✗ | buffer | ✓ só se `hit_confirmed` | ✓ após alguns quadros | fim do ativo | fim da recuperação |
| `CombatStateBlocking` | 35 % vel | ✗ | ✓ | — | segurar F | soltar F |
| `CombatStateBlockstun` | 20 % vel | ✗ | ✓ (cancel) | mantém | golpe absorvido | timer |
| `CombatStateBlockBreak` | ✗ | ✗ | ✗ | ✗ | guarda ≤ 0 | timer 1,4 s |
| `CombatStateStunned` | ✗ | ✗ | ✗ | ✗ | golpe desbloqueado | timer = hitstun |
| `CombatStateRagdoll` | física manda | ✗ | ✗ | ✗ | finalizador / kb alto | chão + baixa velocidade, ou teto |
| `CombatStateGetup` | ✗ | ✗ | últimos quadros | últimos quadros | fim do ragdoll | timer |
| `CombatStateDashing` | dash manda | ✗ | — | ✗ | Q solto | fim do dash |

Arbitragem: um único `state_machine.transition_to()` decide por prioridade —
mata a dupla fonte de verdade que existe hoje (o corpo do `combat_state`
sombreando `_melee._trava`, já resolvido em parte pela migração para objetos,
mas ainda precisa da prioridade explícita entre estados concorrentes).

### 4.2 Frame data proposto (substitui a tabela de §2.2)

| # | Golpe | startup | ativo | recuperação | **trava total** | hitstun causado | vantagem no acerto | vantagem no bloqueio |
|---|---|---|---|---|---|---|---|---|
| 1 | Jab | 0,20 s | 0,06 s | 0,14 s | **0,40 s** | 0,75 s | **+0,21 s** | ~ −0,05 s |
| 2 | Soco 2 | 0,20 s | 0,06 s | 0,14 s | **0,40 s** | 0,75 s | **+0,21 s** | ~ −0,05 s |
| 3 | Chute | 0,20 s | 0,06 s | 0,17 s | **0,43 s** | 0,80 s | **+0,23 s** | ~ −0,05 s |
| 4 | Finalizador | 0,25 s | 0,08 s | 0,35 s | **0,68 s** | ragdoll 2,0 s | n/a | punição garantida |

**Combo completo ≈ 1,6-1,9 s** (contra 4,8-5,0 s hoje), com vantagem
**positiva** em todos os golpes — o combo trava de verdade, ao contrário de
hoje.

### 4.3 Contra-jogo (por que não é "quem clica primeiro ganha")

| Escape | Custo | Contra o quê |
|---|---|---|
| Bloquear (F) | 65 % de mobilidade, guarda finita | todo o combo |
| Dash lateral | CD 2,0 s (recalibrar do atual 1,5 s), i-frames 0,2 s | 1 escape por combo, não 2 |
| Punição de whiff | recuperação ×1,35 se errar | rusher que clica sem alcance |
| Combo decay | hitstun cai a partir do 5º-6º golpe seguido | evita loop infinito com skills |
| Getup i-frames | 0,5 s ao levantar do ragdoll | evita okizeme garantido |

---

## 5. Rede

O projeto **já é híbrido** (achado central, corrige a descrição inicial deste
plano): `Main.gd` faz `set_multiplayer_authority(id)` recursivo — movimento e
pose são do **cliente dono**; dano/hitbox são do **servidor**
(`DamageZone` recusa agir fora dele). É o mesmo modelo documentado pelo TSB
(§3.7). **Não é preciso trocar de modelo — é preciso ajustar o que já existe
para golpes 3-4× mais rápidos.**

### 5.1 O problema concreto do startup curto

Com startup de 0,20 s e RTT típico de 80-150 ms, o caminho atual (cliente
pede → servidor cria a hitbox → RPC de volta toca a animação) faz o
**atacante ver a própria animação com até 1 RTT de atraso** — quase o
startup inteiro. Correção, independente do resto: **tocar a animação
localmente no clique**, e o RPC de apresentação (`_net_play_melee`) passa a
ser só para os OUTROS jogadores (`call_remote`, não broadcast com
`call_local`).

### 5.2 Correção dos bugs de rede (§2.4) no novo desenho

- **B1** (`hit_confirmed` só no servidor): trocar por
  `net_acerto_confirmado.rpc_id(atacante, seq)` — RPC dedicado
  servidor→atacante.
- **B2** (stun vazando em cópia remota): `combat_state` deriva de um carimbo
  absoluto (`net_stun_ate`, em ms de relógio), nunca de um booleano só —
  idempotente, combinável por `max()`, nunca "esquece" de resetar.
- **B3** (`_net_melee` sem validação): adicionar sequência (`seq`),
  distância máxima (~alcance + raio + 0,7 m de tolerância de rede), ângulo,
  cadência (1 golpe/200 ms, 8/2 s) e timestamp monotônico.
- **B4** (hitstop global deformando a hitbox de todos): apagar o
  `SceneTreeTimer(atraso)` do servidor — o startup passa a ser contado pelo
  **cliente**, imune ao `time_scale` do servidor; o servidor só faz geometria
  instantânea contra um histórico curto de posições (rewind, ~200-300 ms,
  clampado).
- **B5** (hitbox não varre): dar hitbox de melee uma varredura mesmo com
  `vel = ZERO` — ou aceitar a caixa grande de §3.3 como mitigação suficiente
  (é o argumento da própria wiki do JJS: hitbox generosa compensa latência).
- **B6** (`trigger_hitstop` ocioso): ligar no `hit_landed` de `Melee.golpear`
  — ganho de graça, não custa orçamento de tempo de jogo porque zera `delta`
  em vez de alongar o clipe.

### 5.3 Sequência de RPCs recomendada

```
atacante: atacar_req(seq, passo, t_cliente, yaw)   [~16 B]
  → todos exceto atacante: net_tocar_golpe(seq, passo)   [call_remote — animação]
  → atacante: toca a própria animação IMEDIATAMENTE, localmente, no clique

servidor, no frame de startup: valida distância/ângulo/cadência,
  calcula hit por geometria instantânea (rewind curto do alvo)

atacante: acerto_req(seq, alvo_id, t_cliente)   [~12 B]
  → servidor confirma/rejeita
  → net_acerto_confirmado(seq)   [ao atacante: libera hit_confirmed]
  → net_stun(ate_ms, kb, tipo)   [ao alvo: hitstun/knockback, nunca posição direta]
```

Custo estimado: ~250 B/s por jogador — ~6 % do que a replicação de movimento
já consome hoje.

### 5.4 Ragdoll em rede

Simulado pelo **cliente dono** (servidor simula só para dummies sem dono).
Trafega um evento (`net_ragdoll(ligar, impulso, ate_ms, semente)`, ~28 B) +
a raiz do corpo pelo `MultiplayerSynchronizer` já existente, com
interpolação. Ossos individuais **não** trafegam — custaria ~16 KB/s contra
28 B do evento único.

---

## 6. Refazer as animações

**Por que refazer, não acelerar**: a causa raiz do bug de 2026-08-11 ("os
dois socos liam igual") não foi a velocidade em si — foi que os dois clipes
partiam de **poses de guarda idênticas ao grau**, e cortar cedo deixava em
tela só o que era comum aos dois. Acelerar clipe do Mixamo é exatamente o que
já falhou; animação autoral, desenhada nativamente para 0,40 s, evita o
problema por construção porque cada golpe pode ter guarda de ENTRADA
geometricamente distinta desde o quadro zero.

### 6.1 Ferramenta (sem Blender — não está instalado nesta máquina)

`tools/anim_editor/` — editor de keyframes próprio do projeto, Python puro
(tkinter), grava direto em `assets/animations/<nome>.tres`. Fluxo:
`python3 tools/anim_editor/main.py` → abrir/criar clipe → editar por
papel/quadro → Exportar. Pré-requisito (rodar 1x ou após mudar personagem):

```bash
godot --headless --path . -s tools/export_rig.gd
godot --headless --path . -s tools/export_anims.gd
godot --headless --path . -s tools/export_mesh.gd
```

### 6.2 Decisão de método por peça

| Peça | Método | Por quê |
|---|---|---|
| Jab, Soco 2, Chute, Finalizador | **(a) clipe autoral novo**, desenhado nativamente em 0,40 s (não acelerado) | evita reamostragem/borrão por construção; guarda de entrada distinta por golpe resolve o bug de 2026-08-11 na raiz |
| Guarda/bloqueio | **(b) pose procedural aditiva** (padrão de `RecepcaoDeDano.gd`) | precisa conviver com locomoção (andar/recuar bloqueando); clipe assado mata a locomoção inteira (`_apply_baked` faz `return`) |
| Quebra de guarda | **(b) pose procedural aditiva**, variante nova do mesmo padrão | reação a evento, entra/sai suave por cima do que o corpo já faz |
| Ragdoll/queda/levantar | **(c) híbrido** — física (`Knockback.gd`/FSM nova) governa a POSIÇÃO; clipe/pose só desenha a rotação dos membros | o formato `.tres`/`.res` só grava `<Papel>:rotation`, **sem posição** — queda "de verdade" tem que vir de física, senão o corpo desliza/flutua |

Note que o chute (3) só precisa animar Torso + perna ativa — o overlay de
braços/pernas em guarda (`MeleePoses.gd`, já em produção, §0.5) cobre o
resto. Isso reduz a autoria de 13 papéis para 4-6 por golpe na maioria dos
casos.

### 6.3 Legibilidade em 0,40 s (o problema central)

1. **Guardas de entrada geometricamente distintas por golpe** — não só
   espelhadas. É a correção direta da causa raiz de 2026-08-11.
2. **Eixo de trajetória diferente por golpe**: jab reto, soco 2 em arco,
   chute lateral, finalizador vertical. Quatro eixos diferentes compensam o
   tempo igual entre os quatro golpes.
3. **Congelar o quadro de contato** (não chavear pose nova durante o
   "ativo") — é o quadro que o hitstop (§5.2, B6) estica no relógio real sem
   gastar orçamento do clipe.
4. **Ligar `trigger_hitstop()`** no impacto — ~0,05-0,08 s nos 3 primeiros
   golpes, ~0,10 s no finalizador (mais longo, mas grátis em frame-data
   porque zera `delta` em vez de alongar o clipe).

### 6.4 Fases e portões de medição

| Fase | O que | Portão (ferramenta já existente ou nova) |
|---|---|---|
| 0 — linha de base | congelar estado atual dos 29 clipes | `medir_amplitude_res.gd`, `medir_pose_res.gd`, `medir_tempos_melee.gd` rodados e salvos como referência |
| A — Jab | autorar, apontar `COMBO[0]` | `medir_impacto_res.gd` (pico bate com `atraso`), `medir_tempos_melee.gd` (ciclo ≈0,40 s) |
| B — Soco 2 | idem + prova de distinção | **sonda nova**: `medir_distancia_guarda.gd` — distância geodésica entre a pose em t=0 dos dois socos; exigir ≥40° nos papéis de braço+torso. É o teste objetivo que faltava para o bug de 2026-08-11 (era só relato humano) |
| C — Chute | idem | + asserção já existente em `test_arena.gd` (perna ativa mais forte que braço isolado) |
| D — Finalizador | idem | soma dos 4 `recuo()` ≈ 1,6-1,9 s; `test_arena.gd` completo |
| E — Guarda | pose procedural | **sonda nova**: `medir_bloqueio_locomocao.gd` — metros percorridos segurando F+W contra controle; alvo 30-60 % da velocidade normal |
| F — Quebra de guarda | pose procedural | **sonda nova**: `medir_pose_reacao.gd` — tempo de subida/descida do peso da pose contra a duração declarada |
| G — Ragdoll/levantar | híbrido física+pose | portão manual (janela aberta): ciclo completo cair→chão→levantar sem flutuação/deslize |
| H — Integração | tudo junto | `test_arena.gd` + `medir_tempos_melee.gd` + passe manual do combo de 4 golpes, bloqueio e um knockdown completo |

### 6.5 Acervo atual (29 clipes)

Nenhum precisa ser apagado. Órfãos **já existentes hoje** (não criados por
este trabalho): `kicking` (substituído por `roundhouse_kick` em
2026-08-18), `right_upper_hook_from_guard`. Após o refazer, `boxing_1`,
`left_uppercut_from_guard`, `roundhouse_kick` e `meia_lua_de_compasso` saem
de uso mecânico mas viram referência (o finalizador giratório antigo é
candidato natural a golpe especial de skill/fruta no futuro — a coreografia
é legítima, só não cabe em 0,40 s). `dying` e `bouncing_fight_idle` ganham
uso real pela primeira vez, como base de ragdoll e de guarda, respectivamente.

---

## 7. Divisão do trabalho (fases de implementação)

Seguindo a regra de território fechado do [`AGENTES.md`](AGENTES.md):

| Ordem | Frente | Território | Depende de |
|---|---|---|---|
| 1 | **Frame data + FSM** | `src/player/hsm/*.gd` (novos estados), `Melee.gd` (tabela nova) | nada — pode começar já |
| 1 | **Rede — correções B1-B6** | `Player.gd` (RPCs), `DamageZone.gd`, `GameFlow.gd` (hitstop) | nada — independe da animação |
| 2 | **Animação — Fases A-D (os 4 M1)** | `assets/animations/*.tres`, `tools/anim_editor` | frame data (1) define a duração-alvo |
| 2 | **Bloqueio/guarda** | `src/anim/` (pose nova), `src/player/hsm/CombatStateBlocking.gd` | FSM (1) |
| 3 | **Ragdoll/levantar** | física + `src/player/hsm/CombatStateRagdoll.gd` + animação | FSM (1) + frame data do finalizador |
| 3 | **Sondas de medição novas** | `tools/dev_tests/medir_distancia_guarda.gd`, `medir_bloqueio_locomocao.gd`, `medir_pose_reacao.gd` | acompanha cada fase de animação |
| 4 | **Integração e validação** | `test_arena.gd`, `validar.sh` | tudo anterior |

`Player.gd` é ponto de contato entre quase todas as frentes — como no padrão
de `PLANO_FRUTAS.md`, mudanças ali devem ser reportadas como patch e
aplicadas por quem orquestra, não editadas por dois agentes ao mesmo tempo.

---

## 8. Riscos consolidados

| # | Risco | Sintoma se der errado |
|---|---|---|
| 1 | Nivelar os 4 golpes no mesmo tempo (0,40 s) pode enfraquecer a sensação do finalizador | mitigado por eixo vertical + hitstop mais longo (grátis em frame-data), mas só se confirma jogando |
| 2 | Ausência de root-motion no formato de clipe | queda/levantar animados sem combinar com física fazem o corpo deslizar ou flutuar — prototipar cedo com `dying` puro |
| 3 | Rig de 13 papéis não cobre mão/pulso/ombro | compensar com torso + eixo de trajetória, não dá pra contar com "snap de pulso" |
| 4 | Bloqueio/quebra de guarda são estados NOVOS sem réplica de rede pronta | se não forem sincronizados por RPC como o combo já é, cliente e servidor divergem sobre quem está bloqueando |
| 5 | `anim_editor` não tem undo | exportar/salvar a cada poucas chaves durante a autoria |
| 6 | Sondas novas (`medir_bloqueio_locomocao.gd`, `test_melee_trava.gd`) exigem janela (`DISPLAY`), não rodam headless | planejar acesso a máquina com tela antes de cada fase que dependa delas |
| 7 | `_request_combo_breaker` (G, cooldown 45 s) é placeholder não calibrado | não herdar o valor de 45 s sem revisão — decidir se essa mecânica entra no escopo deste plano ou fica para depois |

---

## 9. Fontes (pesquisa externa)

Wikis (dados **[W]**, texto integral obtido via `api.php?action=parse` do
Fandom quando o Cloudflare bloqueava fetch direto):

- The Strongest Battlegrounds — Basic Combat, Techniques, Combos (`the-strongest-battlegrounds-rblx.fandom.com`)
- Jujutsu Shenanigans — Controls & Mechanics, Template:CombatTabs/MovementTabs/MechanicsTabs, Tips & Techs (`jujutsu-shenanigans.fandom.com`)
- Untitled Boxing Game — Game Mechanics (Fandom) e Mechanics (`ubg.miraheze.org`)
- Alternate Battlegrounds — AB Mechanics, Tactics (`alternate-battlegrounds.fandom.com`)
- Heroes Battlegrounds — Techniques, Playstyles, Combos (`heroes-battlegrounds.fandom.com`)
- Blox Fruits (contraste) — Game Mechanics, PvP Combat Guide

Engenharia/DevForum **[E]**: client vs. server hit detection, lag compensation
em melee preciso, SecureCast (server-authoritative com lag compensation),
server authority model (docs oficiais Roblox), guias de "How to Make a
Roblox Fighting Game/Combat System" (kitsblox.com).

Lista completa de URLs (26 fontes) preservada no relatório original da
pesquisa — pedir se for preciso auditar uma fonte específica.

---

## Resumo executivo

1. O problema de hoje é matemático, não estético: trava = animação inteira +
   hitstun fixo de 0,30 s dá vantagem **negativa** em todo M1 — acertar é
   pior que errar.
2. O alvo é 4 golpes de ~0,40 s cada (1,6-1,9 s o combo), com vantagem
   **positiva** e hitstun de 0,75 s — matemática que garante combo de verdade.
3. A rede do projeto **já está desenhada certo** (híbrida, como o TSB) — falta
   só prever a animação localmente e corrigir 6 bugs já catalogados (B1-B6),
   não trocar de arquitetura.
4. As animações precisam ser **refeitas, não aceleradas** — a causa do bug de
   2026-08-11 foi guarda de entrada compartilhada, que só autoria nova resolve.
5. Parte da infraestrutura já existe no working tree local (auto-mira, lunge,
   overlay de guarda por membro, threading de hitstun) — o plano estende isso,
   não compete com isso.
6. Uma decisão pendente do dono: estender a exceção de cancelamento (hoje só
   dash-on-hit-confirmed) para também cobrir bloqueio durante a recuperação.
