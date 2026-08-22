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
(o normal) o dano sai do `GomuArm`; **sem** rig cai num fallback com **forma**
própria, escrito direto no `GomuFX` (o *número* é o mesmo — vem da tabela —, mas
o desenho do golpe não). A tabela abaixo é o **caminho com rig**.

| tecla | golpe | o que acontece | dano |
|---|---|---|---|
| **Z** | Gomu Gomu no Pistol | um `GomuArm` do ombro direito: alcance **12 m**, raio 0,22 do feixe, extensão 0,09 s → segura 0,06 s → retrai 0,15 s, e chama a animação de recepção na volta | **88**, acerto único |
| **X** | Gomu Gomu no Bazooka | **dois** `GomuArm` simultâneos, alcance **16 m**, raio 0,28, com `knockback_mult 2,2` e `shake_mult 1,8` · sopro de ar comprimido agendado para o frame de impacto (0,09 s) | **176**, acerto único |
| **C** | Gomu Gomu no Gatling | `GomuGatling`: **16 socos** alternando os braços, intervalo caindo de 0,12 s até 0,05 s (a barragem inteira sai em ~0,85 s; o movimento fica travado 1,8 s), alcance sorteado 11–15 m e dispersão aleatória | **15 × 80 + 160** no último · teto **384** |
| **V** | Gear 2 / Red Hawk | pisca até o alvo (`_blink`), mergulha (`_plunge`) e explode no impacto | **704** |

Os números saem de `src/combat/Balance.gd` e são **finais** — é o que a barra de
vida perde. Ver a seção "Dano" do [README da pasta](README.md).

**A hitbox de cada soco** nasce em `GomuArm._do_hit`:
`dano` · `kb = 35 × knockback_mult` · velocidade `mira × 28 × knockback_mult` ·
vida 0,35 s · raio `1,3 × shake_mult`. O `GomuArm` recebe a `DamageSpec` do golpe
e carimba a zona com `spec.marcar()` — é assim que braços irmãos acabam no mesmo
orçamento.

**O Bazooka estica dois braços e cria UMA hitbox.** O `GomuArm` da esquerda nasce
com `is_main_arm = false` (`GomuFX.gd:103`), e só o braço principal abre
`DamageZone`, speed-lines e som de impacto. O X vale 176 uma vez, não 2 × 176 —
o segundo braço é leitura visual do golpe. (Mesmo que abrisse, os dois carregam a
mesma spec: o teto do slot X, 256, cortaria o excedente.)

**O ritmo do Gatling é desenhado, não uniforme** (`GomuGatling._fire_punch`): os
15 primeiros socos valem **80** com `knockback 0,15` — eles **prendem** o alvo no
lugar; o **último** vale **160** (`partes.final`) com `knockback 2,5` e vai reto
no centro, sem dispersão. Ou seja, o C é uma metralhadora que termina em canhão:
a barragem segura, o último arremessa. Quem mexer nos números precisa preservar
essa forma, senão o golpe vira 16 empurrões que espalham o alvo no primeiro.

**Os 16 socos são UMA conjuração.** Todos recebem a mesma `DamageSpec`, logo o
mesmo `cast_id` e o mesmo teto: quem toma a barragem inteira leva **384** (o teto
do slot C), não os 1360 que a soma crua daria. O corte é no dano — cada soco
continua prendendo, o último continua arremessando.

⚠️ **Consequência que vale saber antes de mexer nos números:** 384 ÷ 80 = 4,8, ou
seja o orçamento fecha no **5º** soco. Quem tomar a barragem inteira já estará no
teto quando o soco final chegar, e os 160 do `partes.final` **saem como 0** —
mas ele ainda arremessa, que é a função dele. O `partes.final` só entrega dano
para quem **não** tomou a barragem toda: alvo que entra no meio da rajada, ou que
é pego pela dispersão em alguns socos e não em outros. É a diferença entre "o
último soco é o mais forte" (verdade sobre o valor) e "o último soco é o que mais
tira" (nem sempre, e de propósito — ver a nota do `Balance.gd` sobre por que o
teto não vira "baixar o dano até caber").

**O V** é o único golpe do jogo que **move o conjurador até o alvo** antes de
bater e o único que deixa **status** no alvo: impacto de **704**, kb 30,
**raio 8,0**, vida 0,2 s, mais queimadura de **32/s por 3 s** (`BurnStatus`
tica 16 a cada 0,5 s, com o `partes.queimadura` da tabela).

> ⚠️ **A queimadura não alcança ninguém hoje.** `GomuRedHawk._apply_burn_aoe`
> varre o grupo `"enemies"`, **vazio** desde que os inimigos foram desativados
> (10 ago) — em partida PvP ela nunca acende. O valor fica declarado em
> `partes.queimadura` para o dia em que voltarem. E, se voltarem, ela divide o
> orçamento do V: 704 do impacto contra um teto de 768 deixam **64** para o
> fogo, ou seja 4 dos 6 tiques.

---

## Decisões que valem lembrar

**O braço cresce, não escala.** `GomuArm` não mexe em `scale.z` do nó do braço:
o membro é reconstruído a cada quadro a partir do ombro fixo. Escalar o osso
deformaria a mão e o antebraço junto — o efeito lê como "braço inflado", não
"braço esticado".

**`add_child` ANTES de posicionar.** O comentário em `GomuFX.gd:119-122` guarda
uma armadilha que já custou caro aqui: `global_position` num nó **fora** da
árvore não tem espaço global para resolver, e o sopro do Bazooka nascia em
(0,0,0) — no centro do mapa, não na ponta do braço. O mesmo padrão foi corrigido
no `GomuRedHawk`. É a mesma família do **item 31** da lista de correções, que
segue aberto na Gura Gura.

**O `GomuArm` centraliza dano, knockback, partículas, som e speed-lines.** Quem
for criar um golpe corpo-a-corpo novo em qualquer fruta deve olhar para ele
primeiro: os quatro slots da Gomu, incluindo o V, são composições dele.

**Os multiplicadores saíram dos arquivos de efeito em 2026-08-21.** Esta fruta
tinha três deles: `_damage * (1.8 if is_last else 0.4)` no Gatling e
`_damage * 2.5` no Red Hawk. O problema não era a conta, era o que `_damage`
significava: no Gatling ele era o **orçamento do golpe inteiro** a ser fatiado em
16, no Red Hawk era uma **base** a multiplicar, e no Pistol era o dano do soco —
três contratos para o mesmo campo, e nenhum jeito de saber qual valia sem abrir o
arquivo de partículas. Hoje `spec.dano` é sempre "quanto vale UM acerto" e o que
foge disso tem nome próprio na tabela (`partes.final`, `partes.queimadura`). Os
comentários no ponto exato onde cada multiplicador morava ficaram no código, de
propósito.

**O Gatling sem rig não é o mesmo golpe.** O fallback do `GomuFX._gatling` cria
**uma** `DamageZone` de 1,5 s com `spec.dano` — 80, o valor de UM soco. É rede de
segurança para personagem sem `UpperArm_R`/`UpperArm_L`, não uma versão
equivalente: quem cair nesse caminho leva 80 no lugar de 384. Z e X também têm
fallback, mas neles a conta não muda (um acerto de 88 e um de 176); o V não tem —
o `GomuRedHawk` roda com ou sem ombro, só perde o braço de fogo.

---

## Pendências

- **A passiva mente em parte:** "reduz repulsão recebida em 40%" está na
  descrição da `FruitPassiveSystem` e **não existe no código** — só
  `speed_mod`/`jump_mod` são lidos por `equip_fruit`.
- **A queimadura do V é código morto em PvP** — `_apply_burn_aoe` só olha para o
  grupo `"enemies"`, que ninguém povoa hoje. Trocar o grupo é decisão de desenho
  (a ultimate ganharia dano por tempo contra jogadores), não conserto de bug, e
  por isso está registrada aqui em vez de feita.
- Histórico: o V já vazou uma `OmniLight3D` acesa para sempre a cada uso
  (achado na auditoria de 2026-08-10, corrigido). Os testes
  `tools/dev_tests/test_gomu_leak.gd` e `test_gomu_burn_leak.gd` existem por
  causa disso — use-os depois de mexer no V.
