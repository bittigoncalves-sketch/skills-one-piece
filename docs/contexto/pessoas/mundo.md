# Mundo e editor de mapa — para quem chega

> Versão para agentes: [`../agentes/mundo.md`](../agentes/mundo.md) · arquivos: [`../INDICE.md#mundo`](../INDICE.md#mundo)

## O que é

Os lugares onde se joga, e a ferramenta de construí-los.

- **A arena** é montada por código: uma grade de lajes de 10 m com 16 buracos, blocos, árvores e
  as frutas para pegar. Luz e atmosfera também são código.
- **Os mapas do Modo História** são **arquivos** (`mapas/historia/*.json`). Nada do chão é escrito
  no código: tudo sai do arquivo.
- **O editor de mapa** (menu JOGAR → EDITOR) edita esses arquivos, no estilo do Roblox Studio:
  mover, escalar e girar peças, desfazer, lista de peças (Explorer), seleção múltipla, agrupar
  (Ctrl+G), uma loja de modelos `.glb` com categorias e um botão **Testar** que coloca o jogador
  de verdade no mapa.

## Onde mexer para…

| tarefa | arquivo |
|---|---|
| mudar a arena | `src/world/MapBuilder.gd` |
| mudar luz e céu | `src/world/WorldEnv.gd` |
| mudar o formato do arquivo de mapa | `src/world/mapa_arquivo.gd` (e só ele) |
| mudar como o mapa vira cena | `src/world/mapa_montador.gd` |
| mudar o editor | `src/editor_mapa/` (o orquestrador é `EditorDeMapa.gd`) |
| importar modelos para a loja | `src/editor_mapa/importador_glb.gd`, `src/world/biblioteca_modelos.gd` |

## A hitbox de uma peça (23/09/2026)

O que o jogador esbarra pode ser diferente do que ele vê. Selecione a peça e, em
Propriedades, marque **Hitbox: própria** — aí dá para escolher a forma (inclusive cápsula,
boa para tronco e poste), deslocar, medir e girar o volume.

- **H** mostra o volume de todas as peças do mapa; a da peça selecionada aparece sempre.
- **Ctrl+H** faz as alças do gizmo mexerem no volume em vez da peça (o botão da barra vira
  `Hitbox ✎` enquanto isso). Clicar noutra peça devolve as alças à peça.
- **Aplicar nas iguais** copia a hitbox para todas as cópias do mesmo modelo de uma vez, e
  um Ctrl+Z desfaz tudo junto.
- Deixe em **automática** quando estiver bom: é o comportamento de sempre, e o arquivo nem
  ganha o campo.

## Cuidado com

- **Um modelo vira inimigo quando está na categoria "inimigos" da loja.** Não existe um tipo de
  peça "inimigo" no arquivo.
- **Peça com colisão desligada não toma golpe** — e também não desenha hitbox nenhuma.
- **Coloque o objeto na cena antes de posicioná-lo.** É o erro mais repetido do projeto.
- **O mapa de verdade é do dono.** Testes usam mapas de teste em `tools/dev_tests/fixtures/`.

## Para saber mais

- [`../../MODO_HISTORIA.md`](../../MODO_HISTORIA.md) §3–4 — o formato do mapa e o editor
- [`../../PLANO_VISUAL.md`](../../PLANO_VISUAL.md) — luz e atmosfera
