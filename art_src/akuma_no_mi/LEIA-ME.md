# Akuma no Mi em voxel — Claude constrói (Blender), Codex dá as imagens (25/11/2026)

44 frutas canônicas listadas (variantes `*_mine_piece`, `_gear2` e `hito_hito_nika` são `aliases` da base e usam o mesmo modelo) em `manifesto.json` (id, nome, cor atual do pickup). Modelo = voxel 24³ gerado por
`tools/akuma_no_mi/gerar_frutas.py` (Blender headless) → `assets/models/akuma_no_mi/<id>.glb`. A silhueta de cada fruta
vem de `formas.json` e hoje é um CHUTE PROVISÓRIO (família esfera/pera/gomos/gota/cacho + caule + folhas).

## O que o Codex faz, por fruta
1. **Referências da internet**: buscar imagens da Akuma no Mi (anime/wiki), salvar 1–3 em `referencias_web/<id>_1.png…`
   (reduzidas, ok até 512 px) e anotar em `referencias_web/notas.json`: `{ "<id>": {"fonte": "url", "forma": "esfera|pera|gomos|gota|cacho + observação", "caule": "...", "cores": ["#hex"…], "padrao": "espiral/…"} }`.
   Se a silhueta do anime diferir muito do chute, diga em `forma` — o Claude ajusta `formas.json` e regera.
2. **Textura**: pintar o atlas `texturas/<id>.png` com **72×48 px** (3 colunas × 2 linhas de vistas 24×24):
   `frente | tras | direita` na linha de cima e `esquerda | topo | base` na de baixo.
   Cada vista é o que se vê de FORA olhando aquela face (cima = +Y; topo/base: cima = frente). Pinte só dentro da
   silhueta: `guias/<id>_guia.png` (cinza = onde existe voxel). `guias/<id>_reserva.png` é a cor lisa atual
   (caule marrom, folha verde). Pixel-art nítido, SEM suavização, as espirais/padrões da fruta contínuos entre as vistas
   vizinhas (o padrão em volta da fruta deve fechar entre frente/direita/tras/esquerda).
3. Avisar por mensagem; o Claude roda `blender -b -P tools/akuma_no_mi/gerar_frutas.py` e valida.

## Regras
- Pintar do zero a partir da leitura das imagens (nada de colar print/arte do mod). Fundo transparente fora da silhueta.
- Frutas `*_mine_piece` e a variante sem sufixo (ex. `hie_hie` / `hie_hie_no_mi_mine_piece`) são a MESMA fruta: pintar igual.
- Divisão: Claude = tools/, assets/models/akuma_no_mi/, formas.json; Codex = texturas/, referencias_web/.
- `folha_reserva.png`: como as 45 estão com a cor lisa hoje.

## Estado (25/11/2026, 08:10)
44/44 atlas do Codex aplicados; `gerar_frutas.py` sem AVISO de texels vazios; `test_akuma_no_mi_modelos` 166/166; `folha_final.png` = as 44 renderizadas no Blender.
Pendente: aprovação visual do dono dentro do Godot; decidir se o modelo novo substitui os 5 pickups autorais (gomu, goro, ope, bara, buda — hoje o autoral vence); notas de fonte do lote 4 (Codex fecha `referencias_web/notas.json`).
Regerar tudo: `blender -b -P tools/akuma_no_mi/gerar_frutas.py` e `"$(./find_godot.sh)" --headless --path . --import`.
