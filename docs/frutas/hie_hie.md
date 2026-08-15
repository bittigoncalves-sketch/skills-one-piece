# Hie Hie no Mi — gelo

**Id:** `hie_hie` · **Tipo:** Logia · **Passiva declarada:** Trilha Congelante —
só `speed_mod 1,15` está implementado (o rastro de gelo ao correr não existe no
código).

**A identidade da fruta é CONTROLE:** dois dos quatro golpes trocam knockback
por congelamento. Onde as outras frutas arremessam, a Hie Hie prende.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/IceFX.gd` | os 4 golpes, a flecha de gelo (`bullet`) e `_congelar_alvo` |
| `src/player/disparo_sustentado.gd` | a **rajada** do Z (mesma da Mera Mera) |
| `src/combat/StatusFX.gd` | o ícone e o estado `CONGELADO` na tela |

---

## O que cada tecla faz, hoje

| tecla | golpe | o que acontece | hitbox |
|---|---|---|---|
| **Z** | Disparo de Gelo | **rajada** (16 flechas, 0,09 s de intervalo) pelo `DisparoSustentado`; a flecha é `IceFX.bullet` | dano 8 · kb 9 · `fwd × 55` · vida 0,7 s · raio 0,32 |
| **X** | Iceberg | ergue a mão e lança um bloco gigante | dano 45 · kb 25 · `fwd × 22` · vida 1,8 s · raio 2,5 |
| **C** | Investida de Gelo | **dash congelante**: o conjurador é impulsionado a `fwd × 28 + UP × 4` e a zona viaja junto | dano 40 · **kb 0** · `fwd × 26,7` · vida 0,45 s · raio 2,2 · quem encosta congela **5 s** (+2 s de imunidade) |
| **V** | Ice Age | erupção inicial + campo que cresce e **dura 50 s** | erupção: dano 85 · kb 8 · raio 5 · vida 1 s · campo: `AGE_DPS = 30`/s, congela e recongela |

**Por que o C tem knockback zero:** a investida **prende** o alvo num bloco de
gelo. Empurrar mandaria o bloco para longe e desmancharia o controle, que é o
ponto do golpe. Está escrito no código, e vale como precedente para qualquer
golpe de captura novo.

**Por que o campo do V dura 50 s:** é área negada, não dano. O ciclo é
5 s congelado → 2 s de imunidade → recongela. Os 34 nós que a auditoria marcou
como "vazamento" eram esse campo vivo — o teste esperava 8,9 s e o efeito dura
55. Nenhuma duração foi encurtada para agradar o cronômetro.

---

## Pendências

- **Item 11 da lista:** `IceFX.gd:166` usa `caster.has_node("_char_model")`, mas
  `_char_model` é **campo**, não nó filho — a condição é **sempre falsa** e o
  tween que levanta o braço direito **nunca roda**. O jeito certo, já usado pelo
  `BukiFX.gd:140`, é `caster.get("_char_model")`. Não corrigido porque ligar isso
  **adiciona** uma animação que o golpe hoje não tem: é decisão de design.
- **Item 7:** o campo da Ice Age passou a causar dano (30/s) em 2026-08-11. O
  que segue em aberto é se **recongelar em ciclo** é desejável numa rodada de
  10 minutos.
- A auditoria de 2026-08-10 pegou a Hie Hie em **2/4** golpes com hitbox (C e V
  eram só visual). Os dois foram corrigidos; o histórico do que era cada defeito
  está em [`../erros.md`](../erros.md).
