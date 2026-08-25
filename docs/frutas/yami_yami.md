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
| `src/combat/Balance.gd` | **todo o dano** dos quatro slots (a tabela única, desde 2026-08-21) |

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

Bala (`YamiFX.bullet`): dano **24** · kb 12 · **`fwd × 105` m/s** · vida 0,5 s ·
raio 0,3. ⚠️ 105 m/s está **acima do teto de ~79 m/s** onde a `DamageZone`
começa a atravessar o alvo entre dois quadros; hoje isso é mitigado pela
varredura de caminho (item 24), não pela velocidade.

**O Z é a única linha da tabela sem teto** (`"teto": 0.0` em `Balance.FRUTAS`), e
isso é consequência de ele ser toggle e não conjuração: cada tiro abre um
orçamento próprio, e um teto aqui zeraria a arma depois de N balas — ela nunca
mais machucaria ninguém. O freio é a cadência (0,35 s) e o custo de energia por
bala. Oito tiros seguidos somam 192, dentro dos 200 que o slot Z permite.

### X — Kurouzu (espiral negra)

Trava o conjurador por `KUROUZU_DURATION = 3,2 s` — **a trava dura exatamente o
que a hitbox dura**, de propósito. Puxa o alvo para o centro e **silencia por
4 s**. Zona do vórtice: dano **64** · kb 6 · estática · raio 1,9 — knockback
baixo porque este golpe **puxa**; quem arremessa é a soltura.

O **arremesso** do release vale **192** (`partes.arremesso`), com
`mira × 45 + 10` para cima. 64 + 192 = **256**, que é exatamente o teto do slot
X: o golpe inteiro cabe no orçamento, e o clímax continua valendo o triplo do
vórtice.

⚠️ **Dois consertos em 2026-08-23 — o golpe estava efetivamente quebrado em uso
normal.** `pedir_cancelar_hold` era chamado com UM argumento onde a assinatura pede
DOIS; o erro abortava `_physics_process` **antes** do `queue_free()`, e o
controlador virava zumbi: o orbe ficava colado na mão para sempre, e a linha
`yami_kurouzu_active = false` (que vem antes da que falha) seguia rodando e
desligava o X SEGUINTE no primeiro quadro. Os dois sintomas relatados pelo dono —
"não atrai" e "não some" — eram esta causa só. Junto, `_find_closest_entity` usava
`world.get_tree()`, que é null no primeiro golpe de cada vida, e por isso a
conjuração nunca marcava alvo (sem `in_kurouzu`, sem `SUGADO`, sem os 4 s de
silêncio). Medição em [`../erros.md`](../erros.md).

⚠️ **Corrigido em 2026-08-21 — este era o segundo desvio da fruta.** O arremesso
era `take_damage(damage × 1,5)` **direto**, fora do funil e portanto sem o
`DAMAGE_SCALE` de 0,12 que a hitbox do vórtice levava: o arremesso valia 56,7
enquanto o vórtice sozinho valia 4,2. Hoje as duas partes passam pelo
`CombatResolver` e dividem o mesmo teto.

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
dummy; **a mordida de entrada tira 256**, o valor cheio do slot C. (Os 6,0
medidos na auditoria antiga eram os mesmos 50 da tabela velha depois do
`DAMAGE_SCALE` de 0,12 — o golpe não mudou de desenho, só de escala.)

⚠️ **O prisioneiro-IA não era prisioneiro (resolvido em 2026-08-23).** A guarda
`in_black_hole` estava no `TrainingDummy` e no `Player`, mas o **`AutoDummy`** não
a repetia — `super._physics_process()` não interrompe o corpo do filho. Medido com
o poço aberto: o boneco automático acelerava para 3,10 m/s (a perseguição cheia) e
escapava, enquanto o TrainingDummy ao lado ficava nos 0,4 m/s da sucção. O jogador
humano **já estava travado** nos dois sentidos da rede (dois processos, W segurado:
`velocity = (0,0,0)`), então a falha era só da IA.

⚠️ **Item 2 da lista (resolvido em 2026-08-11):** o `Player` **não tinha** essa
guarda e o jogador preso tomava dano onde o dummy não tomava. A guarda foi
acrescentada — o Black Hole é controle puro para todo mundo.

### V — Liberation

Repelão de **25 m** de raio (`LIBERATION_RADIUS`) valendo **128**
(`partes.onda`), kb 38, vida 0,45 s, mais de 12 a 25 blocos de concreto
arremessados por conjuração (teto de 35 simultâneos na cena, para não derrubar o
FPS). Silencia **10 s**. A onda e os escombros dividem **um orçamento de 768** —
o teto do slot V, e o maior do jogo.

⚠️ **Aqui estava o pior desequilíbrio do jogo. Corrigido em 2026-08-21.** Cada
escombro chamava `take_damage()` **direto**, com `damage × 1,2`, fora do funil e
portanto sem o corte de 0,12 que o resto do jogo levava; cada bloco tinha a sua
**própria** lista `hit_targets`, então nada impedia o mesmo alvo de ser atingido
por todos. Com 25 blocos: **1800 de dano contra uma vida de 2048** — 88% da vida
de alguém num golpe, enquanto a ultimate da Gura, na mesma medição, tirava 1%.

Junto saiu o `damage_mult`, que **aumentava** o dano por bloco quando o número de
blocos passava do limite de spawn ("para não perder poder de fogo"): ele empurrava
exatamente na direção contrária à do teto. Hoje o golpe continua ejetando de 12 a
25 blocos e continua parecendo o fim do mundo; os que chegam depois do orçamento
esgotado **empurram e não ferem**, que é o espetáculo sem a execução.

---

## Pendências

- **Item 3 — resolvido em 2026-08-21:** os `YamiBlock` varriam só o grupo
  `"enemy"` no `_physics_process` deles, e numa arena PvP os escombros
  atravessavam os outros jogadores. Hoje a varredura é
  `"enemy" + "player"` (`YamiFX.gd`, `YamiBlock._ready`), como a da onda.
- ⚠️ **O escombro não vale o que a tabela diz.** `Balance` declara `dano: 96` por
  escombro (8 acertos = os 768 do teto), e `_liberation` passa `spec.dano` para o
  bloco — mas `YamiBlock._init` ainda faz `damage = maxf(d * 0,25, 12.0)`, sobra
  da escala antiga. Cada bloco entrega **24**, não 96, e nem os 25 juntos (600 +
  128 da onda = 728) alcançam o teto. O comentário do próprio `_liberation` diz
  "os escombros valem o dano MULTI da tabela (96)", então **código e comentário
  discordam**. `test_balance.gd` não pega isto: ele valida a tabela, não os
  arquivos de efeito. Decidir: apagar o `× 0,25` (e o golpe passa a bater no
  teto com 8 blocos, como projetado) ou baixar o `dano` da tabela.
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
