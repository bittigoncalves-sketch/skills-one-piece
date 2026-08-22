# Suna Suna no Mi — areia

**Id:** `suna_suna` · **Tipo:** Logia · **Passiva declarada:** Drenagem
Desértica — só `speed_mod 1,05` está implementado (o roubo de estamina e a cura
de 12% do dano **não existem** no código).

Toda a areia é procedural: cor e curvas geradas em código, **sem textura
nenhuma**. Cada golpe é `DamageZone` (móvel ou estática) + grãos + poeira +
malha de areia.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/SandFX.gd` | os 4 golpes, o gerador de grãos (`_proc`) e o terreno de dunas |
| `src/effects/SandTornado.gd` | o tornado do X — nó próprio, com sucção e elevação |
| `src/effects/Tumbleweed.gd` | os arbustos que rolam no deserto do V |

---

## O que cada tecla faz, hoje

| tecla | golpe | o que acontece | hitbox |
|---|---|---|---|
| **Z** | Desert Spada | lâmina de areia à frente | dano 92 · kb 30 · `dir × 22` · vida 1,45 s · raio 3,0 |
| **X** | Sables | tornado a 4 m à frente que **puxa e levanta** | `SandTornado`: raio 3,4 · puxão 11 · lift 7,5 · **64 por tique** (0,4 s) · vida 3,2 s · teto 256 |
| **C** | Desert Girasole | areia movediça (várias poças) | dano 240 · kb 5 · estática · **vida 8,5 s** · raio 3,5 |
| **V** | Suna no Sabaku | deserto vivo a 11 m à frente: terreno de dunas + tempestade | tempestade: dano 640 · kb 40 · estática · vida 6,0 s · **raio 20** · o terreno some sozinho em 20 s |

Os números saem de `src/combat/Balance.gd` e são **finais** — é o que a barra de
vida perde. Ver a seção "Dano" do [README da pasta](README.md).

**O X é a única multi-hit da fruta.** A tabela declara `MULTI 64 × 9`: um acerto
de entrada na `DamageZone` do tornado mais 8 tiques (0,4 s cada em 3,2 s de
vida). Os nove acertos dividem o teto do slot X, 256 — quem for sugado e ficar
até o fim chega ao teto no 4º acerto, e o resto do tornado vira só puxão e
levantada. É de propósito: **o teto corta o dano, não o acerto.**

**O C nasce em cinco poças** (a do alvo e quatro sorteadas em volta), e todas
carregam o mesmo `cast_id`. Elas são espaçadas em 7,5 m para não se encostarem
— o raio é 3,5 —, então ninguém está em duas ao mesmo tempo; quem cair numa
segunda depois de sair da primeira leva 144, o que sobra do teto de 384.

**O alvo do V ignora o pitch de propósito** (`_ground_target` achata a direção):
olhar para cima ou para baixo nunca pode fazer o deserto nascer no céu ou
enterrado sob o mapa.

---

## A armadilha que esta fruta ensinou ao projeto

**Item 1 da lista (resolvido em 2026-08-11):** o tornado chamava
`take_damage(_dps * _tick)` **direto**, pulando o `DamageZone.DAMAGE_SCALE = 0,12`
que todas as outras fontes respeitavam. Eram 50 × 0,4 = 20 por tique, 8 tiques em
3,2 s: **142,4 de dano contra 3–10 de todo o resto — 14× fora da escala.**

Ninguém percebeu por meses porque o tornado só alcançava o grupo `"enemy"`
(o boneco de treino). Quando ele passou a alcançar jogadores, o desequilíbrio
apareceu. O primeiro conserto foi colar um `* DamageZone.DAMAGE_SCALE` à mão
dentro do tornado: funcionava, e era a prova de que a constante estava no lugar
errado — um golpe precisava lembrar de se autopunir para caber na escala.

**Corrigido de vez em 2026-08-21.** O `DAMAGE_SCALE` foi removido do jogo e o
remendo saiu junto: o tornado passa pelo `CombatResolver` como qualquer outra
fonte, e por isso divide o orçamento do golpe com a hitbox de entrada. O 4º
argumento de `SandTornado.setup()` deixou de ser "dps" e passou a ser o dano
**por tique** — é o que a tabela declara, e evita o mesmo erro de unidade que
gerou o 142,4.

**A lição continua valendo para qualquer golpe novo,** só mudou a regra: dano
fora do `CombatResolver` é dano fora do orçamento, e o erro fica invisível
enquanto o golpe só acertar bonecos.

---

## Pendências

- A passiva de drenagem/cura não existe.
- O V já foi medido deixando 14 nós depois de 8,9 s — era o terreno com
  `autofree(desert_mmi, 20.0)`, ou seja **duração de propósito**, não vazamento.
  Ver as ressalvas em [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md).
- Personagem associado: `crocodile` — fora do `ELENCO_LIBERADO` hoje, então a
  troca de aparência não acontece.
