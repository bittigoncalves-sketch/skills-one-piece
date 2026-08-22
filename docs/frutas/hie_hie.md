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
| **Z** | Disparo de Gelo | **rajada** (16 flechas, 0,09 s de intervalo) pelo `DisparoSustentado`; a flecha é `IceFX.bullet` | dano 12 · kb 9 · `fwd × 55` · vida 0,7 s · raio 0,32 |
| **X** | Iceberg | ergue a mão e lança um bloco gigante | dano 168 · kb 25 · `fwd × 22` · vida 1,8 s · raio 2,5 |
| **C** | Investida de Gelo | **dash congelante**: o conjurador é impulsionado a `fwd × 28 + UP × 4` e a zona viaja junto | dano 192 · **kb 0** · `fwd × 26,7` · vida 0,45 s · raio 2,2 · quem encosta congela **5 s** (+2 s de imunidade) |
| **V** | Ice Age | erupção inicial + campo que cresce e **dura 50 s** | erupção: dano 256 · kb 8 · raio 5 · vida 1 s · campo: **32 por tique** a cada 0,2 s, congela e recongela · teto 768 |

Os números saem de `src/combat/Balance.gd` e são **finais** — é o que a barra de
vida perde. Ver a seção "Dano" do [README da pasta](README.md).

**A rajada Z inteira é UMA conjuração**, não dezesseis: as 16 flechas dividem o
`cast_id` aberto por `Player._spec_do_disparo`, e o pente cheio vale
12 × 16 = 192, logo abaixo do teto de 200 do slot Z. Quem acerta tudo entrega o
pente; quem acerta metade entrega metade — era esse o ponto de ter teto em vez
de baixar o dano por flecha.

**Por que o C tem knockback zero:** a investida **prende** o alvo num bloco de
gelo. Empurrar mandaria o bloco para longe e desmancharia o controle, que é o
ponto do golpe. Está escrito no código, e vale como precedente para qualquer
golpe de captura novo.

**Por que o campo do V dura 50 s:** é área negada, antes de ser dano. O ciclo é
5 s congelado → 2 s de imunidade → recongela. Os 34 nós que a auditoria marcou
como "vazamento" eram esse campo vivo — o teste esperava 8,9 s e o efeito dura
55. Nenhuma duração foi encurtada para agradar o cronômetro.

**E por que ele não executa ninguém, apesar dos 250 tiques.** A constante local
`AGE_DPS := 30.0` **foi removida em 2026-08-21** — era mais um número de
balanceamento morando longe dos outros, e o tique aplicava
`AGE_DPS * DamageZone.DAMAGE_SCALE * 0.2` direto em `take_damage`, ou seja um
remendo à mão para compensar estar fora do funil (o mesmo caso do tornado da
Suna Suna). Hoje o valor vem da tabela: **32 por tique**, e o tique passa pelo
`CombatResolver`.

O freio agora não é só o valor ser baixo — é o **teto**, que o campo divide com
a erupção de abertura, porque as duas partes nascem do mesmo aperto de tecla e
carregam o mesmo `cast_id`. Quem toma a erupção (256) chega aos 768 do slot V em
mais ~16 tiques, cerca de 3 s dentro do gelo; **a partir daí o campo é só
controle** — continua congelando e recongelando pelos 50 s, sem tirar mais vida.
Dano alto em alvo que não pode se mexer seria execução, não pressão.

---

## Pendências

- **Item 11 da lista:** `IceFX.gd:166` usa `caster.has_node("_char_model")`, mas
  `_char_model` é **campo**, não nó filho — a condição é **sempre falsa** e o
  tween que levanta o braço direito **nunca roda**. O jeito certo, já usado pelo
  `BukiFX.gd:140`, é `caster.get("_char_model")`. Não corrigido porque ligar isso
  **adiciona** uma animação que o golpe hoje não tem: é decisão de design.
- **Item 7:** o campo da Ice Age passou a causar dano em 2026-08-11 e foi
  reescalado em 2026-08-21 (32 por tique, vindos da tabela, com teto). O que
  segue em aberto é se **recongelar em ciclo** é desejável numa rodada de
  10 minutos — o teto tirou o dano de cena depois de ~3 s, mas o controle
  continua valendo os 50 s inteiros.
- A auditoria de 2026-08-10 pegou a Hie Hie em **2/4** golpes com hitbox (C e V
  eram só visual). Os dois foram corrigidos; o histórico do que era cada defeito
  está em [`../erros.md`](../erros.md).
