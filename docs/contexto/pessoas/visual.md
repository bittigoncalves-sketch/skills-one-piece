# Visual, VFX e áudio — para quem chega

> Versão para agentes: [`../agentes/visual.md`](../agentes/visual.md) · arquivos: [`../INDICE.md#visual`](../INDICE.md#visual)

## O que é

O jeito como o jogo é desenhado e soa. O estilo escolhido pelo dono é **cel-shading de anime,
inspirado em One Piece**: sombras em faixas, contorno escuro nos personagens, cores vivas. Esse
estilo foi feito em seis fases, todas concluídas.

Aqui também moram os efeitos de tela (vinheta, clarão, a tela "quebrando" nos golpes da Gura Gura),
o rastro das armas, o fôlego do personagem ao correr e os sons de personagem (passos, eventos).

> Os efeitos de cada fruta ficam com as frutas ([frutas.md](frutas.md)).

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| criar ou mudar material | `src/fx/Materiais.gd` (todo material sai daqui) |
| mudar o contorno | `src/fx/Contorno.gd` |
| mudar efeitos de tela | `src/fx/ScreenFX.gd`, `src/fx/ScreenShatterFX.gd` |
| mudar luz e céu | `src/world/WorldEnv.gd` |
| mudar sons de personagem | `src/audio/` |

## Referência de qualidade

O padrão de acabamento é o da **Ope Ope no Mi**: cada criação com estética própria, bem integrada
ao jogo. Não existe obrigação de estilo "blocado" (low poly ou voxel) — a forma se adapta ao
resultado.

## Cuidado com

- **Todo efeito que aparece tem que sumir** (senão o jogo vai ficando pesado).
- Duas pegadinhas da engine: material "sem sombreamento" perde o brilho próprio, e os níveis de
  brilho (glow) começam a contar do zero.
- **Visual se aprova olhando no jogo**, com captura na câmera real. Sem captura, diga que não foi
  conferido visualmente.

## Para saber mais

- [`../../PLANO_VISUAL.md`](../../PLANO_VISUAL.md) — o plano do estilo, fase a fase
- [`../../guia/ASSETS_VISUAIS.md`](../../guia/ASSETS_VISUAIS.md) — regras para efeitos, malhas e partículas
