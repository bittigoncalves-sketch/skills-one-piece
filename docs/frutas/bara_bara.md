# Bara Bara no Mi — desmembramento

**Id:** `bara_bara` · **Tipo:** Paramecia · **Passiva declarada:** Esquiva
Desmembrada (35% de chance de esquivar dano cortante/frontal).

⚠️ **A esquiva não existe no código.** Só `speed_mod 1,05` é aplicado; nada lê
uma chance de desvio. Ver o README da pasta.

Os dois primeiros golpes são o piso da simplicidade do projeto: projétil, uma
hitbox, sem estado. Os dois últimos **não são** — cada um tem nó gerenciador
próprio, estado no `caster` e caso especial no `CastController`, e é neles que
mora tudo o que esta página tem de interessante.

---

## Onde mora cada parte

`src/effects/BaraFX.gd` — arquivo único, com os 4 golpes e mais duas classes
internas: `BaraCleaveController` (o C, que vive pendurado no conjurador) e
`BaraDomainController` (o V, que vive no mundo). O `CastController` conhece as
duas: o C é **hold** (`bara_cleave_active`), e o V se recusa a ser lançado duas
vezes e só entra em recarga quando o domínio acaba (`bara_v_active`).

---

## O que cada tecla faz, hoje

| tecla | golpe | o que acontece | hitbox |
|---|---|---|---|
| **Z** | Corte Único (Dismantle) | lâmina de distorção à frente, com flash branco na ponta | dano 92 · kb 18 · `fwd × 45` · vida 0,6 s · raio 1,2 · derruba 1,2 s |
| **X** | Buggy Ball | flecha de fogo lenta que explode ao encostar em qualquer coisa | dano 168 · kb 18 · `fwd × 25` · vida 0,72 s · raio 0,6 · derruba 1,5 s |
| **C** | Área Cortante (Cleave) | **segurar**: cortes invisíveis num raio de 12 m em volta do conjurador, por até 7 s | 5 cortes de 80 (um a cada 1,4 s) · sem knockback · `lock_movement` 0,5 s · teto 384 |
| **V** | Expansão de Domínio (Shrine) | santuário de ossos e sangue; o mundo escurece e todo alvo num raio de 40 m é retalhado por 30 s | ~8 cortes de 96 (um a cada 3,5 s) · sem knockback · hitstun 0,8 s · teto 768 |

Os números saem de `src/combat/Balance.gd` e são **finais** — é o que a barra de
vida perde. Ver a seção "Dano" do [README da pasta](README.md).

Z e X são projéteis com `DamageZone`. C e V não criam hitbox nenhuma: varrem
alvos por consulta de física (C) ou por grupo (V) e chamam
`CombatResolver.aplicar()` — que é o mesmo funil da hitbox, e por isso obedecem
ao mesmo teto de conjuração.

⚠️ A explosão do X é **só efeito**: ela é espetacular e não cria zona de dano
nenhuma. Quem leva o golpe é quem a flecha encostou.

---

## Os dois redesenhos de cadência (2026-08-21)

O rebalanceamento do dia 21 não só reescalou o C e o V — **mudou o ritmo dos
dois**, porque reescalar sozinho produziria golpes que não leem como o que o
nome promete.

**C — Área Cortante.** Era um tique a cada 0,25 s por 7 s: 28 acertos de dano
CRU (`take_damage(damage * 0.25)` direto, fora do funil), 175 de dano total.
Só trocar o número daria 28 tiques de 14 cada — uma névoa que tira lascas e
ocupa a arena o tempo todo. Hoje o intervalo é
`BaraFX.BaraCleaveController.INTERVALO_CLEAVE = 1,4 s`: **5 cortes pesados de
80** nos mesmos 7 s e no mesmo raio de 12 m. Os cinco somam 400, então o teto do
slot C corta o último em 64 — a rede de segurança por cima do redesenho, não no
lugar dele.

**V — Expansão de Domínio.** Mesmo motivo, em escala maior: eram 3 cortes por
segundo durante 30 s — 90 acertos de dano cru, 810 no total, num raio de 40 m
sem linha de visão e sem esquiva. Era a segunda skill mais forte do jogo por
acidente. Hoje são `INTERVALO_DOMINIO = 3,5 s` e `CORTES_POR_TIQUE = 1`: **~8
cortes de 96** nos mesmos 30 s, somando exatamente o teto de 768. O domínio
continua durando o que durava e continua sendo **controle de área** — cada corte
prende com 0,8 s de hitstun. O que ele deixou de ser é um moedor que tirava 40%
da vida de quem estivesse na metade da arena.

Os dois chamavam `take_damage()` direto, o que os deixava fora do
`DamageZone.DAMAGE_SCALE = 0,12` de então e 8,3× acima de qualquer golpe
equivalente com hitbox. A constante foi removida do jogo; os dois passam pelo
`CombatResolver`.

---

## Pendências

- A passiva de esquiva é texto sem implementação.
- Nenhum golpe usa o rig do personagem (ao contrário da Gomu, que estica os
  membros reais). Se a Bara for aprimorada, o caminho natural é **desmembrar o
  modelo do jogador** em vez de desenhar caixas soltas — o `GomuArm` já mostra
  como pegar nós do rig por nome.
- Personagem associado: `buggy` — fora do `ELENCO_LIBERADO` hoje.
- Nunca teve golpe mudo nem vazamento: passou **4/4** já na primeira auditoria.
