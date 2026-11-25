# Árvores, frutas e doma — checkpoint (01/10/2026)

Pedido do dono: árvores novas (pacote `free_download_low_poly_nature_pack.glb` + pasta
`Free Forest Nature Pack Updated`, em `~/Downloads/Assets/baixados de sites/`) e frutas
**grudadas nas árvores**, que **caem a cada 5 minutos** e viram **itens no chão**
coletáveis; aba **Frutas** no inventário. Depois: frutas **domam herbívoros**, que viram
pets.

## Decisões do dono

| tema | decisão |
|---|---|
| Onde entram as árvores | **loja + plantar no mapa** (pomares perto da vila/fazendas; Free Forest enriquecendo a floresta oeste), somando ao mapa vivo |
| Queda | a cada **5 min**, cai uma fruta de **UMA árvore sorteada da ilha** |
| Rebrotar | a fruta volta ao galho **5 min** depois; no chão fica até ser pega, **no máximo 30** na ilha (passou, some a mais antiga) |
| Coleta | **passar por cima** (aviso "+1 Maçã") |
| Fruta por árvore | **uma espécie por árvore**: verde comum = maçã, laranja ou pêssego (sorteado por árvore); cerejeira = cereja; pinheiro = pinha; árvore gigante = bolota; palmeira sem fruta (o pacote não tem coco) |
| Doma | tirar a fruta do inventário **para a mão**; tecla **Y** tenta domar (o F continua sendo o voo da fruta) |
| Chance | **sorte fixa 35 %** por fruta; cada tentativa gasta 1 fruta |
| Domáveis | **pasto grande** (vaca, cavalo, búfalo, bisão), **caça** (coelho, cervo, alce), **ovelhas** (ovelha, carneiro), **macaco e aves de fazenda** (galinha, pintinho, pato). Chefes nunca |
| Fruta certa | **qualquer fruta** doma qualquer herbívoro |
| Pets | **quantos quiser**, no máximo **6 convocados** ao mesmo tempo; **pet que morre é apagado para sempre** — vale para **todos**, gaivota e caranguejo também; inimigos e bichos bravos revidam contra o pet que os ataca |

## Padrões meus (declarados — o dono pode trocar)

- Com fruta na mão, herbívoro domável **não foge nem ataca** o jogador (curioso): sem
  isso não dá para chegar a 3 m de um coelho (alerta 8 m). Bicho que apanhou continua
  bravo/fugindo.
- Alcance da doma: **3 m** em volta do jogador (o herbívoro mais perto).
- Bicho domado sai da natureza; a área dele repõe um selvagem em 30 s.
- Domado manso (coelho, ovelha…) em guarda/agressivo só acompanha; quem tem dano na ficha
  (búfalo, bisão, macaco) luta.
- Tamanhos: frutas **0,45 m** (estilizadas: com 0,3 m sumiam na copa); árvores adultas 6,5–12 m.
- Folhagem não colide: árvore colide só pelo **tronco**; grama, flores, cogumelos e
  arbustos atravessáveis.

## Como funciona (arquivos)

| parte | arquivo |
|---|---|
| separar o pacote, colisão de tronco, pontos de fruta na copa | `tools/blender/preparar_natureza.py` → `art_src/natureza/` |
| registrar na loja (categorias Árvores/Frutas/Floresta, tamanhos, atravessável, frutífera) | `tools/mapa_ilha/importar_natureza_na_loja.gd` |
| plantar no mapa vivo (soma, idempotente, cópia antes) | `tools/mapa_ilha/plantar_natureza.gd` + `natureza_plantio.json` |
| campo `frutifera` e `atravessavel` da loja | `src/world/biblioteca_modelos.gd` |
| frutas penduradas, queda a cada 5 min, rebrotar, teto de 30 | `src/historia/pomar/pomar_da_ilha.gd` |
| fruta no chão (cai, quica, gira, coleta ao encostar) | `src/historia/pomar/fruta_no_chao.gd` |
| fruta na mão (Hand_R) e tecla Y | `src/historia/pomar/fruta_na_mao.gd`, `src/ui/HistoriaHud.gd` |
| aba FRUTAS e PETS individuais | `src/ui/InventarioDaHistoria.gd` |
| doma (35 %), herbívoro mais perto | `src/historia/ModoHistoria.gd` (`_tentar_domar`) |
| herbívoro calmo, revide contra pet | `src/historia/animais/animal_da_ilha.gd` |
| pet domado (4 modos), vida e morte permanente | `src/historia/animais/pet_domado.gd`, `src/historia/pets/companhia.gd`, `gaivota.gd`, `caranguejo.gd` |
| frutas e pets no progresso | `src/historia/progressao.gd` (`frutas_do_pomar`, `pets` por id) |

## Números medidos

- Loja: **88 modelos** (51 em Árvores, 6 em Frutas, 31 em Floresta). Árvore colide só
  pelo tronco (cilindro de 28 faces); 24 modelos atravessáveis.
- Mapa vivo: **514 → 682 peças**, as 514 do dono idênticas (cópia em
  `art_src/backups/mapa_historia/baseplate_antes_natureza_30fafb840724.json`); 168 novas:
  23 frutíferas adultas (115 frutas penduradas), mudas, 136 do Free Forest. Pediu 2
  árvores gigantes e coube 1 (a floresta oeste está cheia; espaço mínimo 14 m).
- Montagem do mapa: 1,53 s cache frio / 0,29 s quente (antes 1,5 / 0,28).
- Quadro com GPU (RTX 3050, 1280×800): **6,7–7,0 ms** em todas as vistas (antes 7,2 ms).
- Frutas de 0,3 m sumiam na copa vista do chão (captura): passaram a **0,45 m**, presas na
  faixa média-baixa da copa.

## Validação

- `tools/dev_tests/test_pomar_e_doma.gd` — 34 checagens, 0 falhas (loja, progresso, e no
  Modo História: frutas grudadas, queda, coleta, rebrotar, teto, mão, calma, doma com
  sorte, pet que segue, máximo de 6, revide, morte permanente).
- `test_ilha_inicial`, `test_animais`, `test_pets_comportamento`, `test_pet_caranguejo`,
  `test_progressao`, `test_editor_mapa`, `test_loja_modelos`, `test_terreno_mapa`: passam.
- Fotos com GPU: `art_src/validation/pomar/` (`tools/mapa_ilha/capturar_pomar.gd`).

## Limitações conhecidas

- O boneco de duelo (inimigo que luta) não revida contra pets — só os bichos bravos.
- Fruta no chão e frutas nos galhos não são salvas: ao reabrir o jogo as árvores voltam
  cheias e o chão vazio (o que o jogador COLETOU é salvo).
- Frutas são 115 nós separados (~120–400 triângulos cada). Gatilho: mais de 300
  frutíferas no mapa ou quadro > 16 ms → MultiMesh por espécie de fruta.
- O F continua sendo o voo da fruta (Akuma no Mi); a doma é no Y.

## Fases

| # | fase | estado |
|---|---|---|
| 1 | Loja: separar o pacote (Blender), importar Free Forest, tamanhos, colisão de tronco, pontos de fruta na copa | ✅ |
| 2 | Frutas nas árvores, queda a cada 5 min, item no chão, coleta, rebrotar | ✅ |
| 3 | Inventário: aba FRUTAS, salvar no progresso, fruta na mão | ✅ |
| 4 | Doma (Y, 35 %), herbívoros calmos com fruta na mão | ✅ |
| 5 | Pets individuais (vários por espécie, máx. 6 fora), vida e morte permanente, revide | ✅ |
| 6 | Plantar no mapa vivo (pomares + floresta), testes, fotos, custo | ✅ |
