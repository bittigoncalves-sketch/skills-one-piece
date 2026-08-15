# Gomu Gomu no Mi — borracha

**Id:** `gomu_gomu` · **Tipo:** Paramecia · **Passiva:** Corpo Elástico —
`speed_mod 1,10`, `jump_mod 1,20`, e a descrição promete **−40% de knockback
recebido** (⚠️ apenas os dois multiplicadores são aplicados hoje pelo
`equip_fruit`; a redução de knockback não tem implementação).

**A regra visual da fruta:** os golpes **esticam os membros do próprio modelo
3D** do jogador. Não há projétil de borracha — há um braço que cresce a partir
do ombro real e volta. É a fruta com o padrão de qualidade mais alto do projeto,
e o `GomuArm` é o molde que os golpes novos deveriam seguir.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/GomuFX.gd` | o despachante dos 4 slots e a montagem do membro |
| `src/effects/GomuArm.gd` | **o braço elástico**: cresce do ombro, acerta, volta, chama a recepção |
| `src/effects/GomuGatling.gd` | a rajada de socos do C (usa vários `GomuArm`) |
| `src/effects/GomuRedHawk.gd` | o V: piscada + mergulho + explosão + queimadura |
| `src/effects/BurnStatus.gd` | o dano contínuo da queimadura do V |

`GomuFX._find_rig_node` acha `UpperArm_R` (ou `UpperArm_L`) **pelo nome**, no
rig de 13 papéis. Personagem sem esses nós cai no `_create_rubber_limb`, um
braço de caixa desenhado do zero — é rede de segurança, não o caminho normal.

---

## O que cada tecla faz, hoje

⚠️ **Cada golpe tem DOIS caminhos**, e é fácil documentar o errado: com rig
(o normal) o dano sai do `GomuArm`; **sem** rig cai num fallback com números
próprios, escritos direto no `GomuFX`. A tabela abaixo é o **caminho com rig**.

| tecla | golpe | o que acontece |
|---|---|---|
| **Z** | Gomu Gomu no Pistol | um `GomuArm` do ombro direito: alcance **12 m**, raio 0,28 do feixe (`0,22`), extensão 0,09 s → segura 0,06 s → retrai 0,15 s, e chama a animação de recepção na volta |
| **X** | Gomu Gomu no Bazooka | **dois** `GomuArm` simultâneos, alcance **16 m**, raio 0,28, com `knockback_mult 2,2` e `shake_mult 1,8` · sopro de ar comprimido agendado para o frame de impacto (0,09 s) |
| **C** | Gomu Gomu no Gatling | `GomuGatling`: **16 socos** alternando os braços em 1,8 s, intervalo caindo de 0,12 s até 0,05 s, alcance sorteado 11–15 m e dispersão aleatória |
| **V** | Gear 2 / Red Hawk | pisca até o alvo (`_blink`), mergulha (`_plunge`) e explode no impacto |

**A hitbox de cada soco** nasce em `GomuArm._do_hit`:
`dano` · `kb = 35 × knockback_mult` · velocidade `mira × 28 × knockback_mult` ·
vida 0,35 s · raio `1,3 × shake_mult`.

**O ritmo do Gatling é desenhado, não uniforme** (`GomuGatling._fire_punch`): os
15 primeiros socos valem `dano × 0,4` com `knockback 0,15` — eles **prendem** o
alvo no lugar; o **último** vale `dano × 1,8` com `knockback 2,5` e vai reto no
centro, sem dispersão. Ou seja, o C é uma metralhadora que termina em canhão: a
barragem segura, o último arremessa. Quem mexer nos números precisa preservar
essa forma, senão o golpe vira 16 empurrões que espalham o alvo no primeiro.

**O V** é o único golpe do jogo que **move o conjurador até o alvo** antes de
bater e o único que deixa **status** no alvo: impacto de `dano × 2,5`, kb 30,
**raio 8,0**, vida 0,2 s, mais queimadura de `dano × 0,1` por 3 s
(`BurnStatus`).

---

## Decisões que valem lembrar

**O braço cresce, não escala.** `GomuArm` não mexe em `scale.z` do nó do braço:
o membro é reconstruído a cada quadro a partir do ombro fixo. Escalar o osso
deformaria a mão e o antebraço junto — o efeito lê como "braço inflado", não
"braço esticado".

**`add_child` ANTES de posicionar.** O comentário em `GomuFX.gd:112-115` guarda
uma armadilha que já custou caro aqui: `global_position` num nó **fora** da
árvore não tem espaço global para resolver, e o sopro do Bazooka nascia em
(0,0,0) — no centro do mapa, não na ponta do braço. O mesmo padrão foi corrigido
no `GomuRedHawk`. É a mesma família do **item 31** da lista de correções, que
segue aberto na Gura Gura.

**O `GomuArm` centraliza dano, knockback, partículas, som e speed-lines.** Quem
for criar um golpe corpo-a-corpo novo em qualquer fruta deve olhar para ele
primeiro: os quatro slots da Gomu, incluindo o V, são composições dele.

---

## Pendências

- **A passiva mente em parte:** "reduz repulsão recebida em 40%" está na
  descrição da `FruitPassiveSystem` e **não existe no código** — só
  `speed_mod`/`jump_mod` são lidos por `equip_fruit`.
- Histórico: o V já vazou uma `OmniLight3D` acesa para sempre a cada uso
  (achado na auditoria de 2026-08-10, corrigido). Os testes
  `tools/dev_tests/test_gomu_leak.gd` e `test_gomu_burn_leak.gd` existem por
  causa disso — use-os depois de mexer no V.
