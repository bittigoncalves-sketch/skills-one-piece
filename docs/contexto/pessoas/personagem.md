# Personagem, rig e animação — para quem chega

> Versão para agentes: [`../agentes/personagem.md`](../agentes/personagem.md) · arquivos: [`../INDICE.md#personagem`](../INDICE.md#personagem)

## O que é

Como o personagem é montado (o modelo 3D), vestido (customização: corpo, raça, acessórios,
cores) e animado. O personagem padrão hoje é o **base V2**, modelado no Blender.

"Rig" é o esqueleto que move o boneco. Aqui todo personagem usa o mesmo esqueleto lógico de
**13 partes**: tronco, pescoço, cabeça, braços e antebraços, coxas, canelas e pés. Isso deixa uma
animação servir para qualquer personagem.

## Como funciona, em poucas linhas

- A maior parte da animação é **procedural**: calculada por código a cada quadro
  (`src/anim/ProceduralAnimator.gd`), em vez de clipes prontos.
- Golpes de algumas frutas têm **poses autorais** (arquivos `*Poses.gd`).
- A customização passa por uma única função que transforma as escolhas do jogador em modelo
  (`src/customizacao/Visual.gd`).
- A arte-fonte (arquivos `.blend`) fica em `art_src/`, fora do projeto Godot.

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| mudar a animação de andar, correr, pular | `src/anim/ProceduralAnimator.gd` |
| mudar as poses de golpe de uma fruta | `src/anim/<Fruta>Poses.gd` |
| mudar as opções de customização | `src/customizacao/` |
| mudar como o personagem é montado | `CharacterBuilder.gd` |
| trocar o modelo base | `art_src/blender/` + `assets/models/base_v2/` |

## Cuidado com

- **A frente do personagem é o eixo −Z.** O esqueleto já ficou espelhado por meses por causa disso.
- **Meça a pose em relação ao próprio personagem**, não ao mundo: o mundo tem escalas diferentes
  por eixo e engana.
- **Animação ruim não se copia.** Reaproveite o mecanismo, não a curva de um golpe que ficou feio.
- Qualidade de referência: o padrão de acabamento da Ope Ope no Mi, com estética própria em cada
  criação (não há obrigação de estilo "blocado").

## Para saber mais

- [`../../ESQUELETO.md`](../../ESQUELETO.md) — as 13 partes, medidas e problemas dos clipes
- [`../../PERSONAGEM_BASE_V2.md`](../../PERSONAGEM_BASE_V2.md) — o modelo atual
- [`../../ANIMACOES_MIXAMO.md`](../../ANIMACOES_MIXAMO.md) — como trazer animações do Mixamo
- [`../../CUSTOMIZACAO.md`](../../CUSTOMIZACAO.md) — o sistema de customização
