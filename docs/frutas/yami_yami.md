# Yami Yami no Mi — trevas

**Id:** `yami_yami` · **Tipo:** Logia · **Passiva declarada:** Supressão Abissal
(aura de 8 m que desliga os poderes de quem estiver perto).

⚠️ **A aura não existe.** `SkillSystem.apply_yami_suppression()` está escrita e
**não tem nenhum chamador** — conferido por grep. O silenciamento que acontece
de fato vem **dos golpes**: X silencia 4 s e o V, 10 s. Quem contar com a
passiva num balanceamento vai contar com nada.

**A identidade da fruta é NEGAÇÃO:** puxa, prende, silencia. É a única que mexe
no que o adversário *pode fazer*, não só em onde ele está.

---

## Onde mora cada parte

| arquivo | papel |
|---|---|
| `src/effects/YamiFX.gd` | os 4 golpes, os blocos de concreto e o vórtice |
| `src/player/disparo_sustentado.gd` | a **pistola** (o Z é um toggle, não um golpe) |
| `src/player/cast_controller.gd:145-158` | o portão do C (exige chão) e o estado `yami_black_hole_active` |
| `src/effects/StatusFX` (`src/combat/StatusFX.gd`) | o ícone de `SILENCIADO` na tela |

Constantes calibradas (topo do `YamiFX.gd`), com raio e vida **casados com o que
aparece na tela**: `KUROUZU_DURATION 3,2` · `KUROUZU_RADIUS 1,9` ·
`LIBERATION_RADIUS 25,0` · `DEBRIS_LIFETIME 6,0` · `MAX_ABSORBED_BLOCKS 30` ·
`MAX_SPAWN_PER_CAST 25` · `MAX_SCENE_BLOCKS 35`.

---

## O que cada tecla faz, hoje

### Z — a pistola é um TOGGLE

Apertar Z **empunha ou guarda** a pistola de trevas; ela não lança golpe. Com a
pistola na mão: **botão direito** mira, **botão esquerdo** atira, cadência
`YAMI_CADENCIA = 0,35 s`. Qualquer outra skill guarda a pistola sozinha.

Bala (`YamiFX.bullet`): dano 25 · kb 12 · **`fwd × 105` m/s** · vida 0,5 s ·
raio 0,3. ⚠️ 105 m/s está **acima do teto de ~79 m/s** onde a `DamageZone`
começa a atravessar o alvo entre dois quadros; hoje isso é mitigado pela
varredura de caminho (item 24), não pela velocidade.

### X — Kurouzu (espiral negra)

Trava o conjurador por `KUROUZU_DURATION = 3,2 s` — **a trava dura exatamente o
que a hitbox dura**, de propósito. Puxa o alvo para o centro e **silencia por
4 s**. Zona: dano 35 · kb 6 · estática · raio 1,9.

### C — Black Hole: controle puro, e isso é decisão declarada

Exige **contato com o solo** (`CastController` recusa no ar) e é **segurado**: o
poço fica aberto enquanto `yami_black_hole_active` for verdadeiro.

O poço abre **nos pés** — o raycast que procura o chão passou a excluir o próprio
caster em 2026-08-12. Antes ele acertava o colisor do jogador e o vórtice abria
~1,78 m acima dos pés, na altura do rosto.

**Uma mordida só, na entrada:** dano na abertura, `knockback 0` (o golpe **suga**;
empurrar mataria a mecânica), raio = `RADIUS`, vida = `MAX_DURATION`.

**O prisioneiro é imune ao resto** — e isso está declarado nas *entidades*, não
no efeito: `TrainingDummy.take_damage` e `Enemy.take_damage` recusam dano
enquanto `in_black_hole` for verdadeiro. O projeto já diz que o poço é controle,
não moedor. Medido: um tique de esmagamento por segundo não tirava nada do
dummy; a mordida de entrada tira 6,0.

⚠️ **Item 2 da lista (resolvido em 2026-08-11):** o `Player` **não tinha** essa
guarda e o jogador preso tomava dano onde o dummy não tomava. A guarda foi
acrescentada — o Black Hole é controle puro para todo mundo.

### V — Liberation

Repelão de **25 m** de raio (`LIBERATION_RADIUS`) com `dano × 1,5`, kb 38, vida
0,45 s, mais até 25 blocos de concreto arremessados por conjuração (teto de 35
simultâneos na cena, para não derrubar o FPS). Silencia **10 s**.

---

## Pendências

- **Item 3:** os `YamiBlock` que voam varrem só o grupo `"enemy"` no
  `_physics_process` deles. Numa arena PvP, **os escombros atravessam outros
  jogadores**. A onda de repelão já foi corrigida; os blocos, não.
- **A passiva de 8 m não é chamada por ninguém** (ver o topo). Decidir: ligar a
  aura, ou apagar a função e assumir que o silenciamento é dos golpes?
- Histórico: esta era a fruta **mais quebrada** da auditoria de 2026-08-10 —
  3 dos 4 golpes não machucavam (X, C e V eram só visual) e o V deixava 40 nós
  no mapa. Hoje é 4/4. O detalhe do que era cada defeito está em
  [`../erros.md`](../erros.md) e o placar em
  [`../AUDITORIA_FRUTAS.md`](../AUDITORIA_FRUTAS.md).
- O entulho do V teve a vida cortada de 20 s para 6 s (`DEBRIS_LIFETIME`) — é a
  **única** duração encurtada por causa do teste, e está marcada como mudança de
  sensação reversível numa constante.
