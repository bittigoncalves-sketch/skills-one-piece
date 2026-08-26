# art_src — arte FONTE, fora do jogo

Aqui ficam os arquivos de trabalho: `.blend`, referências, saídas cruas de
geradores. **Nada aqui é carregado pelo jogo.**

## ⚠️ O `.gdignore` ao lado NÃO É OPCIONAL

O Godot varre o projeto inteiro procurando o que importar, e ele tem um
importador para `.blend` que **exige o Blender configurado no editor**. Com o
`personagem_base.blend` aqui e sem o `.gdignore`, qualquer importação morre com:

```
ERROR: Blender path is invalid or not set, check your Editor Settings.
        Cannot configure blender path in headless mode.
```

E morre para TODO o resto junto — foi assim que a `arvore_voxel.glb` não
importou. Um arquivo de arte que ninguém abre derruba a importação do projeto
inteiro, em headless, sem dizer que a causa está noutra pasta.

`.gdignore` (arquivo vazio) faz o Godot pular a pasta e tudo abaixo dela.

## O que mora aqui

| arquivo | de onde vem | vai para o jogo como |
|---|---|---|
| `blender/personagem_base.blend` | `tools/blender/montar_personagem.py` | nada — é para animar |
| (referências e saídas cruas) | Meshy AI, geradores | passam por `tools/blender/preparar_*.py` |

O caminho de um asset é sempre: **fonte aqui → script de preparo em `tools/` →
`assets/` no formato do jogo**. Arte crua não entra em `assets/` direto.
