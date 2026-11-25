# Ilha Inicial com relevo — checkpoint (30/09/2026)

Pedido do dono: refazer o mapa do Modo História com os assets da loja — relevo acima
da baseplate, tirar tudo o que está em cima e recolocar no relevo, sempre corrigindo o
tamanho das construções (a maioria vem pequena). Um **rio em S corta a ilha ao meio**;
há **floresta**, **vila** e **porto**. Os **navios** ficam numa classificação própria,
onde moram as propriedades dos barcos.

## Decisões do dono

- Relevo = **terreno por alturas** (peça nova `terreno`), **dividido em blocos** por cima
  da baseplate para editar por partes.
- Escala das construções **por tipo, medida contra o jogador**; vale também ao **arrastar
  da loja** (tamanho padrão por modelo no catálogo — uma tabela só).
- Além de rio, floresta, vila e porto: só o **coliseu** — futuro local das **invocações
  (pets) e lutas com chefes** (não implementado agora).
- Navios: categoria **`navios`** + **ficha inicial de propriedades**. Entram `boat`,
  `small_ship`, `ship` e os três barcos-casa (`house-g7esjlfi4v`, `house-2kytqgs4rh`,
  `house`), conferidos pelas miniaturas (`art_src/validation/mapa_ilha/navios_e_duvidas.png`).
- Planta **aprovada** como no esboço (`art_src/validation/mapa_ilha/esboco_planta.png`):
  floresta + morros + coliseu a oeste do rio; vila, fazendas e porto a leste; rio de
  costa a costa; nascimento na praça da vila.
- Pontes: **modelo novo low poly** (Blender), uma em cada cruzamento estrada × rio.
- Consequência aceita: boneco de duelo e inimigos **não** são recolocados; castelo e mina
  ficam fora.

## Decisões minhas (declaradas)

- Blocos de **64 m** (8×8 = 64 peças), células de 2 m (2.048 triângulos por bloco).
- Alturas em **1/10000 do tamanho Y** da peça: esticar o bloco no gizmo estica o relevo,
  como qualquer peça. Todos os blocos com o **mesmo tamanho Y** — senão o arredondamento
  abre fendas nas emendas (a mesma armadilha dos pontinhos pretos da areia).
- Colisão e clique do editor do bloco = **a própria malha** (trimesh). Com a caixa, o bloco
  engoliria o clique das casas em cima dele.
- Água do rio = camada opcional do bloco (nível por vértice), shader próprio.
- Fonte do desenho = `tools/mapa_ilha/planta.json`; o gerador grava o mapa pelo
  `MapaArquivo.salvar` (validado e atômico). Depois de gerado, **o mapa é a fonte** — o
  dono edita no editor; o gerador só é rodado de novo se ele pedir.
- Cópia do mapa e do catálogo de antes: `art_src/backups/mapa_historia/`.

## Etapas

| # | etapa | estado |
|---|---|---|
| 1 | Peça `terreno` (formato, montador, editor: clique, inserção, propriedades) + testes | ✅ `test_terreno_mapa` 38/38; editor/loja/história/praia/inimigos 7/7 |
| 2 | Água do rio (shader) | ✅ conferida nas capturas (cor pela profundidade, sem purpurina) |
| 3 | Catálogo: `tamanho_padrao`, categoria `navios`, ficha de navio, loja usando o tamanho padrão | ✅ 158 modelos com padrão, 6 navios com ficha (`tools/mapa_ilha/aplicar_tamanhos_padrao.gd`) |
| 4 | Ponte low poly (Blender → loja) — agente de modelagem em paralelo | ✅ 4.972 tris + malha `Colisao` (396); jogador atravessa as duas |
| 5 | Gerador da ilha (relevo, rio, estradas, praia, vila, floresta, porto, coliseu, pontes, grupos) | ✅ mapa vivo gravado (483 peças) |
| 6 | Validação: testes, capturas GPU, montagem/FPS medidos, editor abrindo o mapa | ✅ ver abaixo |

## Gatilhos já conhecidos

- `MapaMontador`: >1.500 peças ou montagem >100 ms → agrupar estáticas em MultiMesh.
  Medir com o mapa novo antes de declarar pronto.

## Estado — CONCLUÍDO (01/10/2026)

Doc de uso: `docs/MAPA_ILHA.md`. Mapa vivo regravado pelo gerador (cópia de antes em
`art_src/backups/mapa_historia/`).

Validação:
- `test_ilha_inicial` 20/20 no mapa vivo: grupos, emendas exatas (5.697 pontos, 0,000 mm),
  nada no rio, nada flutuando/enterrado, nascimento livre, e o **Player real atravessa as
  duas pontes** (48,3 e 46,0 m andados).
- `test_terreno_mapa` (formato, malha, colisão, emendas, editor, loja no tamanho padrão,
  catálogo real, malha `Colisao`): sem falhas.
- Conjunto da frente 11/11 (`ilha_inicial terreno_mapa loja_modelos editor_mapa
  grupos_editor modo_historia praia_oceano inimigos_historia inimigo_lutador
  pets_comportamento pet_caranguejo`).
- Bateria completa (`./validar.sh rapido`): 107 ✅ / 9 ❌ / 1 pulado; as 9 = as 8
  conhecidas + `test_ilha_inicial`, que rodou contra o mapa antigo e passou depois de
  gravado o novo → equivalente a 108/8/1. `test_compila`: os mesmos 6 scripts do estúdio.
- Capturas GPU: `art_src/validation/mapa_ilha/01..10`. Montagem e quadro: ver doc.
- Editor abre a ilha (483 peças, 100 blocos, 11 grupos) em 2,7 s; clicar na praça pega o
  chafariz.

Erros achados e registrados (`docs/erros.md`): pontinhos da areia (compressão), praia
dupla (material), degrau de 0,56 m na foz (escalas diferentes), jogador travando na
ponte (caixa × degrau e caixa × arestas da malha visual).

Limites: a água do rio é visual (anda-se no leito); sem inimigos no mapa (decisão);
esticar UM bloco no Y desalinha a emenda; o `house` (barco-casa) parece estar de pé no
arquivo e ficou fora do porto; navios ainda não navegam; sem benchmark em celular.
