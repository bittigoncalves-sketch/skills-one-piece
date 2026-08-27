# Gear 2 — a primeira transformação do jogo

Decisão do dono (2026-08-27): o slot **V** da Gomu Gomu deixa de ser um golpe e
vira **transformação**, com **30 segundos** de duração.

Código: [`src/player/gear2_controller.gd`](../src/player/gear2_controller.gd).
Sonda: `tools/dev_tests/medir_gear2.gd` (15 conferências).

---

## Por que é um ESTADO, e não um golpe

Um golpe nasce, resolve e morre no mesmo instante. Uma transformação tem
**entrada, duração e saída** — e a saída chega por quatro caminhos diferentes:

| saída | o que acontece se esquecer |
|---|---|
| o relógio (30 s) | — |
| **morrer** | o corpo renasce com a pele e o chapéu, sem o estado: transformação permanente pela porta dos fundos |
| **trocar de fruta** | pele e chapéu num personagem que já é de outra fruta |
| **trocar de personagem** | `_rig.montar` faz um modelo novo — sobra um chapéu órfão em cena |

Os quatro estão cobertos e cada um tem conferência própria na sonda.

---

## O que a transformação faz

**Pele.** O corpo inteiro vira `(0.93, 0.51, 0.40)` — avermelhado, não o tom de
pele normal: se fosse o normal, a transformação não leria na tela, que é o ponto
dela. O material anterior de CADA malha é guardado e devolvido na saída, então o
corpo volta exatamente ao que era — inclusive quando não havia tinta de time.

**Vapor.** Partículas subindo do corpo inteiro (caixa de emissão 0,26 × 0,60 ×
0,20), não de um ponto. Grão de 0,085 e escala até 0,9: a primeira versão usava
0,16 com escala 1,3 e os quadrados de 21 cm liam como **caixas flutuando**. O
jogo é anguloso, mas fumaça é a única coisa aqui que não pode ser.

**Chapéu de palha.** Invocado na cabeça, some na saída.

---

## O chapéu

Modelado em [`tools/blender/chapeu_palha.py`](../tools/blender/chapeu_palha.py),
exportado para `assets/models/acessorios/chapeu_palha.glb`. **24 vértices, 18
faces** — só caixas.

⚠️ **É acessório, não personagem novo.** O pedido foi explícito, e é o que faz o
chapéu servir a QUALQUER personagem do elenco sem duplicar modelo.

### As medidas saem da cabeça, não do olho

A AABB do nó `Head` do `base.scn`, em unidades locais (as mesmas do chapéu, que
entra como filho dela):

```
posição (-0,250,  0,000, -0,370)
tamanho ( 0,500,  0,500,  0,740)
```

A cabeça é **quase 1,5× mais funda que larga** — um chapéu dimensionado só pela
largura flutuaria na frente e atrás. A copa é `0,500 + 0,06` por `0,740 + 0,06`:
folga de 3 cm em cada lado, que evita z-fighting entre copa e cabeça.

### O encaixe: 1/3, medido

O chapéu **veste** o terço de cima da cabeça em vez de pousar no topo (a primeira
versão pousava, e lia como prato). A origem do modelo é a **linha de 2/3**, e o
controlador a coloca em `aabb.end.y − aabb.size.y / 3`.

Medido em jogo:

```
cabeça local: y de 0,000 a 0,500 (altura 0,500)
chapéu apoia em y=0,333 | linha de 2/3 = 0,333 | engole 33,3% da cabeça
```

Tirar os dois números da MESMA fonte (a AABB) é o que mantém o encaixe se o
modelo mudar de proporção — em vez de repetir no código um número que mora no
`.scn`.

---

## O que ainda NÃO existe

**Os golpes do Gear 2.** A decisão diz que Z/X/C são remapeados durante a
transformação, mas isso depende da pesquisa dos golpes do Luffy, aberta na
[`FILA_DE_TAREFAS.md`](FILA_DE_TAREFAS.md). Sem ela não há o que remapear. O
estado e o visual estão prontos; o conteúdo entra por `ativar` / `desativar`.

**O Red Hawk não foi apagado.** Era o V antigo e segue vivo em
`GomuFX._red_hawk` (variante 3), agora sem tecla. É o candidato natural ao
conjunto transformado — apagá-lo por causa de uma tecla seria jogar fora trabalho
pronto.

---

## Quando isto virar um motor

É deliberadamente **a Gear 2**, não um "motor de transformações". Com uma
transformação só, generalizar seria adivinhar.

**Gatilho para extrair o motor:** quando a segunda transformação entrar (Gear 3,
ou outra fruta). Aí o que for comum — relógio, salvar/restaurar visual, os quatro
caminhos de saída — sobe para uma base e a Gear 2 vira só a configuração dela.
