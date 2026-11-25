# Grama personalizada

Textura nova de folhas curtas pintadas em estilo anime, criada com a ferramenta integrada `imagegen`. O prompt integral está em `prompt.txt`. Fonte raster original: `assets/textures/terreno/grama_anime.png` (1254×1254 RGB); importação em até 1024×1024, sem compressão destrutiva e com mipmaps.

## Aplicação

- `TexturasDeBloco`: o topo da grama recebe a imagem nova; uma redução para 16×16 atende aos ícones e mantém o tamanho do array de blocos. A franja lateral recebe verde compatível; a terra continua com a textura existente.
- `GradeVoxel`: fornece ao material o sampler da grama e o índice da camada do topo.
- `bloco_minecraft.gdshader`: amostra a grama com filtro linear, mipmaps e anisotropia, uma repetição a cada quatro blocos (3,52 m). Os demais blocos continuam no atlas original com seu filtro anterior. Lajes, escadas e octantes de grama herdam o material.

Nenhuma alteração de geometria, colisão, saves ou regras de escavação. A malha simplificada distante das ilhas continua usando o material que já tinha; a alteração se aplica à grama das seções de blocos carregadas.

## Evidências

- `antes/` e `depois/`: mesma cena de `tools/dev_tests/captura_blocos_texturizados.gd`, mesmas câmeras e iluminação.
- `historia/`: captura da ilha real pelo fluxo de `GameFlow.start_story()`, com save XDG temporário e renderizador Forward+.
- `test_visual_minecraft.gd`: 145 verificações aprovadas, zero falhas.

A captura em compatibilidade expôs uma limitação do contorno preexistente (`hint_normal_roughness_texture` exige Forward+); a checagem da ilha foi repetida no renderizador do projeto. Logs preservados junto às evidências. A validação é focada na textura e em sua integração, não uma regressão completa da campanha.

Na execução Forward+ houve dois erros de reparenting de `VBoxContainer`/`HBoxContainer` durante a carga e avisos de recursos no encerramento, fora dos arquivos alterados. As quatro capturas foram concluídas e o processo saiu com código 0. Não houve erro de compilação da textura/shader novo. Essa execução não é evidência de campanha inteira sem erros.
