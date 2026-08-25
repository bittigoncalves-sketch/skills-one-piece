# O esqueleto do personagem — análise

Medido em 2026-08-25, no `base` (o único personagem destrancado). As fontes são
`src/anim/BodyScanner.gd`, `src/anim/SkeletonDriver.gd` e o JSON produzido por
`tools/export_rig.gd` — nenhum número aqui foi escrito à mão.

---

## 1. A forma: 13 papéis, uma hierarquia rasa

```
Torso ─┬─ Neck ── Head
       ├─ UpperArm_L ── ForeArm_L
       ├─ UpperArm_R ── ForeArm_R
       ├─ Thigh_L ── Shin_L ── Foot_L
       └─ Thigh_R ── Shin_R ── Foot_R
```

O `Torso` é a RAIZ do corpo — não há pélvis separada. Duas consequências que
aparecem o tempo todo:

- **girar o tronco gira o corpo inteiro**, pernas incluídas. Quem quiser ombros
  girando sem o quadril acompanhar não tem onde escrever isso;
- **não existe root motion**. O rig só grava rotação (`<Papel>:rotation`), nunca
  posição. Qualquer deslocamento do corpo vem da física, não do clipe — é por
  isso que o §6.2 do plano de combate manda o ragdoll ser híbrido.

### O que o rig NÃO tem

| ausente | consequência prática |
|---|---|
| **mão / pulso** | não dá para fechar o punho nem virar a palma. O "snap de pulso" que dá estalo a um soco tem de ser compensado com tronco + trajetória (é o risco 3 do §8 do plano de combate) |
| **ombro (clavícula)** | o braço nasce no tronco; não há como "jogar o ombro" no soco |
| **coluna intermediária** | um só `Torso`: não há curvatura, só inclinação em bloco |
| **dedos** | já foram removidos de propósito numa sessão anterior |

Os 13 papéis são o contrato: `BodyScanner.ROLES`, `SkeletonDriver.RIG_PARENT` e
o `MAP` do `tools/bake_mixamo.gd` repetem a mesma lista. Papel novo exige mexer
nos três.

---

## 2. As medidas (personagem `base`, unidades do modelo)

| segmento | comprimento |
|---|---|
| tronco (altura da caixa) | 0,750 |
| ombro → cotovelo | 0,3125 |
| cotovelo → punho (caixa do antebraço) | 0,375 |
| quadril → joelho (**coxa**) | **0,250** |
| joelho → tornozelo (**canela**) | **0,375** |
| largura de ombros | 0,750 (±0,375) |
| altura total, em repouso | **2,000 m** (medido no Blender, pés em Z=0) |

### ⚠️ A canela é 50% mais longa que a coxa

`thigh_len = 0,45` contra `shin_len = 0,675` nas métricas do `BodyScanner` —
e, nas posições dos nós, 0,250 contra 0,375.

Num corpo humano a proporção é a inversa (a coxa é a maior). O efeito é que o
**joelho fica alto demais**, e isso encarece toda animação de perna: um chute
que pareça natural precisa dobrar mais o joelho do que o mesmo movimento
pediria num rig proporcionado, e a passada da locomoção procedural já compensa
isso com números próprios.

**Não é bug**, é escolha de estilo voxel — mas quem for autorar perna precisa
saber, porque a intuição de referência humana erra aqui.

---

## 3. Dois corpos, um contrato

O `SkeletonDriver` é a peça que faz um personagem **skinnado** (Meshy AI, com
`Skeleton3D`) responder às mesmas animações que um **voxel** (nós com nome de
papel):

- no voxel, o animador gira os nós direto;
- no skinnado, ele gira 13 **proxies** e o driver copia para os ossos.

O `ProceduralAnimator` não sabe a diferença. É por isso que as 29 animações do
Mixamo e a locomoção procedural inteira valem nos dois.

**A armadilha documentada:** os modelos Meshy vêm **Z-up** (altura no Z, com a
Armature girada −90° em X). O driver converte por conjugação
`d_skel = A⁻¹ · W · A`. Errar essa conversão **colapsa os membros para dentro do
corpo** — e é o mesmo tipo de erro que derrubou a primeira tentativa de montar
o `.blend` (ver §5).

---

## 4. ⚠️ Onze dos 29 clipes têm o tronco tombado

Medido no primeiro quadro de cada clipe (`Torso.z`, o eixo de ROLAGEM):

| clipe | Z em t=0 | faixa no clipe |
|---|---|---|
| `roundhouse_kick` | **−81,4°** | −85,7° … −51,8° |
| `roundhouse_kick_2` | **−81,4°** | −85,7° … −51,8° |
| `kicking` | −60,6° | −84,5° … +3,8° |
| `gunplay` | −53,8° | −53,8° … −51,7° |
| `bouncing_fight_idle` | −50,7° | −55,2° … −48,0° |
| `stabbing` | −48,6° | −85,1° … +57,1° |
| `boxing_2` | −38,3° | −55,0° … +37,2° |
| `boxing_3` | −37,7° | −38,1° … −21,6° |
| `boxing` / `boxing_1` | −32,8° | −56,1° … +32,6° |
| `quad_punch` | −28,0° | −49,1° … +13,8° |

**Confirmado no jogo, não só no dado.** Tocando `bouncing_fight_idle` pelo
`play_baked`, o vetor "para cima" do torso fica a **51,4° da vertical**. O
personagem literalmente joga o corpo de lado.

O `roundhouse_kick` é o pior caso: ele **nunca fica de pé** — o tronco passa o
clipe inteiro entre −52° e −86°.

Dois desses eram do combo (`boxing_1` no jab, `roundhouse_kick` no chute), e é
por isso que refazer os quatro M1 (§6 do plano de combate) não era só questão
de caber em 0,40 s. Os clipes autorais novos mantêm `Torso.z` dentro de ±20°,
com portão medido em `tools/autorar_combo_m1.py`.

Os 18 clipes restantes estão de pé no primeiro quadro. **Nenhum foi corrigido
nesta passada** — a lista acima é o mapa de quem precisa de autoria nova, em
ordem de gravidade.

---

## 5. A ponte para o Blender

`tools/blender/montar_personagem.py` monta `art_src/blender/personagem_base.blend`
com **uma armature de 13 ossos + a malha voxel pesada nos ossos + 33 actions**
(as 29 do Mixamo e os 4 M1 novos).

O caminho é `Godot → JSON → Blender`, reusando o que já existia:

```bash
godot --headless --path . -s tools/export_rig.gd     # rig   -> JSON
godot --headless --path . -s tools/export_anims.gd   # clipes -> JSON
blender --background --python tools/blender/montar_personagem.py
```

### As duas conversões, e o erro que quase passou

| | |
|---|---|
| **eixos** | Godot é Y-up com frente em −Z; Blender é Z-up com frente em −Y. `(x, y, z) → (x, −z, y)` |
| **ordem de Euler** | o Godot reporta `rotation_order = 2`, que ele CHAMA de **YXZ**. A string equivalente no mathutils é **`ZXY`** — as duas bibliotecas nomeiam a ordem em sentidos opostos |

A segunda quase passou batido, e o motivo interessa: com `'YXZ'` a pose de
REPOUSO saía perfeita (todos os ângulos são zero, então qualquer ordem acerta)
e **toda pose animada saía embaralhada**. Pior, a conferência de cinemática
direta dava verde — porque os dois lados dela liam o Euler pela mesma função.
**Teste que compara um erro consigo mesmo sempre passa.**

A correção foi uma **âncora externa**: uma base medida dentro do Godot,
colada no script como número, conferida antes de qualquer montagem. Hoje o
script recusa exportar em três casos:

1. a conversão de Euler não bate com a âncora do Godot (`erro > 1e-5`);
2. a pose avaliada pelo Blender diverge da cinemática direta (`> 1 mm`);
3. o **controle sabotado** (mesma conta com os eixos errados de propósito) NÃO
   explode — ou seja, a conferência perdeu o poder de reprovar.

Medido na última execução: âncora 3×10⁻⁷, pior erro **0,099 mm**, controle
**2,243 m**.
