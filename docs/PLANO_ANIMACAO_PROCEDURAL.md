# Plano — Animação Procedural em Tempo Real (analisa o corpo do jogador)

> Status: **PLANO / DESIGN** (nada implementado ainda). Objetivo deste documento
> é definir o algoritmo, a arquitetura e as fases antes de escrever código.

## 1. Objetivo
Gerar as animações do personagem **por código, em tempo real**, sem keyframes
pré-gravados. O sistema **mede o corpo** do personagem (o rig articulado) e usa
essas medidas para produzir movimentos (idle, andar, correr, pular, escalar, cair)
que ficam corretos **para qualquer personagem** — o boneco Base, o Buggy, ou
qualquer humanoide futuro — sem precisar reanimar à mão.

Rig atual (nós articulados, ver `articulate_buggy.py`/`build_base.py`):
```
Torso ─┬─ Neck ─ Head
       ├─ UpperArm_L ─ ForeArm_L        (ombro → cotovelo)
       ├─ UpperArm_R ─ ForeArm_R
       ├─ Thigh_L ─ Shin_L ─ Foot_L     (quadril → joelho → tornozelo)
       └─ Thigh_R ─ Shin_R ─ Foot_R
```

## 2. Por que "analisar o corpo"
Uma animação por keyframes é feita para UM esqueleto de proporções fixas. Se o
personagem muda (Base é magro, Buggy é mais largo, um gigante seria enorme), a
animação quebra. Medindo o corpo em runtime — comprimento de coxa/canela, altura
do quadril, largura dos ombros, tamanho do passo — o MESMO algoritmo escala a
passada, o balanço dos braços e o IK dos pés para as proporções reais. Um
algoritmo, N personagens.

## 3. Visão geral do algoritmo (pipeline por frame)
```
[1] BodyScanner  → Perfil do Esqueleto (uma vez, ao trocar de personagem)
        │
[2] Sinais de estado (a cada frame, vindos do Player/física):
        velocidade planar, direção, no_chão, vel. vertical, escalando, castando
        │
[3] Geradores de pose procedurais (por estado): idle / walk / run / jump / climb
        → cada um devolve rotações-alvo por junta
        │
[4] Blend de estados (pesos com crossfade suave)
        │
[5] Camadas aditivas: IK de pé (grounding), look-at (cabeça mira a seta), reações
        │
[6] Aplicação: lerp de cada nó do rig para a rotação-alvo do frame
```

## 4. Componentes

### A. BodyScanner → Perfil do Esqueleto
Ao carregar/trocar o personagem, varre a hierarquia do modelo e monta um
`SkeletonProfile`:
- Mapeia **papéis semânticos → nós** por nome (`Torso`, `Head`, `UpperArm_L`, …).
  Robustez: se um nó faltar, o gerador que depende dele é pulado.
- Mede, via AABB de cada parte e posições dos pivôs:
  - comprimento de `Thigh`, `Shin` (para IK e passada),
  - altura do quadril (Torso) e do ombro,
  - largura dos ombros / dos quadris,
  - comprimento do braço (Upper+Fore).
- Guarda a **pose de descanso** (rotação inicial de cada nó) como base.
- Saída: `Dictionary`/recurso com `{papel: {node, comprimento, pivot, rest_rot}}`.

> Isso é o "analisa o corpo". Tudo abaixo usa essas medidas em vez de números
> fixos.

### B. Sinais de estado (entrada)
Já existem no `Player.gd` — só expor/ler:
- `velocity` → **rapidez planar** `speed` e **direção** relativa ao facing.
- `is_on_floor()`, `velocity.y` (subindo/caindo), `_is_climbing`, `is_casting`.
- Facing atual (`_char_model.rotation.y`, que segue a mira `_yaw`).
Deriva:
- `gait_speed01` = speed / SPEED (0..1) → controla amplitude e frequência.
- `phase φ` = acumulador que avança com `passada`, onde a frequência do passo
  escala por `speed / comprimento_da_perna` (passo curto p/ perna curta).

### C. Geradores de pose (procedurais, por estado)
Cada gerador devolve **rotações locais alvo** por junta (Vector3 em rad).

- **IDLE**: respiração (bob leve do Torso em `sin`), troca de peso lenta,
  micro-balanço dos braços e cabeça. Ruído suave (FastNoiseLite) evita robótico.
- **WALK/RUN** (oscilador de marcha por `φ`):
  - Pernas: `Thigh` balança `±A·sin(φ)` (L e R em oposição `φ` e `φ+π`);
    `Shin` dobra o joelho na volta (`max(0, sin(φ+δ))`).
  - Braços: balançam opostos às pernas (`UpperArm` ~ `-Thigh` do mesmo lado).
  - Torso: bob vertical em `2φ` + leve contra-rotação (twist) e inclinação p/ frente
    proporcional à velocidade.
  - Amplitudes e passada escalam por `gait_speed01` e pelos comprimentos medidos.
  - Corrida = mesmo gerador com amplitude/frequência/inclinação maiores.
- **JUMP/FALL**: por `velocity.y` — subindo: pernas recolhidas, braços p/ cima;
  caindo: pernas estendidas antecipando o pouso, leve "windmill" dos braços.
- **CLIMB**: mãos alternadas sobem, pernas empurram; fase própria por `φ`.

### D. Blend de estados
Mantém um **peso por estado** e faz crossfade (aproximação exponencial) quando o
estado muda, então idle↔walk↔run↔jump são suaves. A pose final = soma ponderada
das poses dos geradores ativos, sobre a pose de descanso.

### E. Camadas aditivas (fase 2+)
- **IK de pé (grounding)**: raycast p/ baixo de cada pé; planta o pé no chão e
  resolve o joelho com **IK de 2 ossos** usando `Thigh`/`Shin` medidos → pés não
  flutuam nem afundam em terreno irregular (blocos do mapa).
- **Look-at**: `Head` (e um pouco do Torso) miram a direção da seta/alvo.
- **Reações**: flinch ao tomar dano, wind-up ao segurar skill (hold-to-cast),
  como camada por cima da locomoção.

### F. Aplicação (por frame)
Como o rig é **baseado em nós** (não skinado), aplicamos rotação direto nos nós:
```gdscript
for papel in perfil:
    var alvo = pose_final[papel]            # rotação local desejada
    var no = perfil[papel].node
    no.rotation = no.rotation.lerp(alvo, 1.0 - exp(-STIFFNESS * delta))
```
Suavização exponencial dá resposta natural sem "snap".

## 5. Arquitetura / integração (arquivos)
Novo módulo em `src/anim/` (mantém o padrão de arquivos pequenos):
| Arquivo | Papel |
|---|---|
| `src/anim/BodyScanner.gd` | Varre o modelo → `SkeletonProfile` (medidas + nós) |
| `src/anim/ProceduralAnimator.gd` | Nó que roda o pipeline por frame; lê estado do Player + perfil e dirige o rig |
| `src/anim/gaits/*.gd` | Geradores (idle, walk_run, air, climb) — um por assunto |
| `src/anim/FootIK.gd` | IK de 2 ossos + raycast de pé (fase 3) |

Integração: o `ProceduralAnimator` **substitui/coexiste** com o `CharacterAnimator`
(hoje baseado em `AnimationPlayer`, que mira nomes antigos e quase não pega no rig
novo). O `Player._setup_character_model` instancia o `BodyScanner` no modelo e cria
o `ProceduralAnimator` alimentado pelos sinais que o Player já calcula.

## 6. Fases de implementação
- **Fase 0** — `BodyScanner`: mapear papéis + medir. Validar imprimindo o perfil.
- **Fase 1** — Locomoção (idle + walk/run) dirigindo pernas/braços/torso pelo `φ`.
  Critério: andar/correr parecem naturais em Base e Buggy, escalando por porte.
- **Fase 2** — Ar (jump/fall) + escalada + blend de estados suave.
- **Fase 3** — IK de pé (grounding em terreno) + look-at da cabeça na seta.
- **Fase 4** — Reações (dano, wind-up de skill) + polish (ruído, secundário no casaco).

## 7. Riscos e decisões
- ⚠️ **Escala não-uniforme no root** (hoje `Vector3(ky, ky, ky*1.9)` p/ engrossar a
  profundidade) **cisalha** membros rotacionados. **Decisão:** antes da Fase 1,
  embutir a profundidade **no modelo (geo)** e voltar o `_fit_model_to_body` para
  escala **uniforme** — senão as animações distorcem as juntas.
- Rig é node-based (rotações nas juntas) — barato e direto; sem skinning.
- Determinístico e leve: só `sin/noise/lerp` por junta (13 nós) — custo desprezível.

## 8. Critérios de aceite
- Um único algoritmo anima Base, Buggy e um humanoide de porte diferente sem ajuste
  manual (a passada/braço/IK escalam pelas medidas).
- Transição idle→andar→correr→pular→pousar sem "snap".
- Pés assentam no chão (blocos/terreno) sem flutuar/afundar (Fase 3).
- 0 keyframes gravados; tudo gerado em runtime.
