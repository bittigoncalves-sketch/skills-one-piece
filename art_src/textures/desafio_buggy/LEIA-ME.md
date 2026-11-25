# Atlas e expressões do Buggy — levantamento

Estado em 21/11/2026: **a primeira versão foi gerada e integrada pelo Claude** em `assets/textures/desafio_buggy/`, com cinco atlas e seis expressões. As capturas estão em `art_src/validation/desafio_buggy/`. A v2 das grades faciais em `projeto.json` foi reaplicada e capturada em close e à distância de jogo; a avaliação artística permanece pendente. O briefing musical está em `art_src/audio/buggy_cutscene/BRIEFING.md`.

O primeiro ensaio de edição por geração de imagem não preservou o contrato: gerou imagem de 1254×1254 com alfa de 256 níveis a partir de um atlas 64×64 com alfa binário; o desenho e a posição das ilhas também mudaram. A imagem foi rejeitada para uso em jogo. Redimensionar simplesmente não corrigiria esse deslocamento nem restauraria os pixels do alfa. Os PNGs originais em `mapas/modelos/` não foram modificados.

## UV confirmado no arquivo existente

No `mapas/modelos/mp_buggy.glb`, o mesh `armorHead` tem a face de normal local −Z com coordenadas UV em pixels `[8, 16] × [8, 16]` no atlas 64×64. A região correspondente de texels é **x=8–15, y=8–15**, inclusivos, com origem no canto superior esquerdo. Uma inspeção das caixas UV dos triângulos detectou apenas dois triângulos de `armorHead` intersectando o interior desse retângulo; isso não substitui renderizar as variantes no jogo. O nariz tem geometria e amostragem UV separadas, pelo que alterar somente a frente da face não altera o nariz 3D.

## Contrato dos PNGs

- Cinco atlas novos, nomes `mp_buggy_corpo.png`, `mp_cabaji_corpo.png`, `mp_richie_corpo.png`, `mp_pirate_pirate4_corpo.png`, `mp_pirate_pirate5_corpo.png`: RGBA 64×64, layout e alfa pixel a pixel iguais aos respectivos originais.
- Seis atlas completos `buggy_rosto_neutro.png`, `buggy_rosto_riso.png`, `buggy_rosto_raiva.png`, `buggy_rosto_surpresa.png`, `buggy_rosto_malicioso.png`, `buggy_rosto_derrotado.png`: RGB idêntico ao novo atlas Buggy fora de x=8–15/y=8–15, e alfa idêntico em todo o atlas; ter expressões claramente distintas sem tocar em nariz, cabelo ou outros elementos compartilhados.
- A primeira versão foi capturada no jogo; dimensões e alfa dos 11 PNGs, e a restrição de diferenças à área facial nas seis variantes, foram verificados. A v2 também foi aplicada e capturada; aprovação artística permanece pendente.

## Projeto em dados para o Claude

`projeto.json` contém paletas nomeadas, regras regionais de recoloração para os cinco atlas e grades 8×8 de seis expressões. Não é uma textura e não aplica alterações sozinho. A proposta usa as cores efetivamente encontradas nos PNGs originais. A legenda da grade facial é: `E` sobrancelha, `D` detalhe escuro dos olhos, `W` branco dos olhos, `S` pele, `B` bochecha, `M` boca, `T` dentes e `.` preserva o pixel base. As duas primeiras linhas mantêm o cabelo; o nariz continua na malha separada.

Aplicar cada regra comparando a cor com o PNG original, sem encadear substituições; preservar o alfa original e coordenadas de UV. Depois copiar a base recolorida em cada variante e aplicar a grade apenas em x=8–15/y=8–15. As versões v1 e v2 foram renderizadas; conferir a leitura das expressões nas capturas de close e de distância de jogo, incluindo a oclusão pelo nariz. Os retângulos de recolor são seletores de cor, não garantia de que todos os personagens usem um layout humano padrão.

## Revisão de expressões v2

Após examinar as capturas de `art_src/validation/desafio_buggy/rosto_*.png` e `cena4_close_no_rosto.png`, as grades em `projeto.json` foram reforçadas: sobrancelhas, olhos e bocas com maior contraste e elementos laterais para contornar a oclusão do nariz. As duas primeiras linhas seguem preservadas. A v2 foi reaplicada e capturada em `rostos_close_v2.png` e `rostos_jogo_v2.png`. Os padrões das seis variantes se distinguem no close, mas algumas emoções não são imediatamente identificáveis sem legenda; na distância de jogo as diferenças ficam pequenas. A aprovação artística permanece pendente.
