# Miniaturas anime — reconstrução

A primeira tentativa foi rejeitada pelo usuário. Os modelos, STLs, prévias e três scripts dessa tentativa foram excluídos em 23/10/2026. As nove referências foram preservadas.

## Ferramentas e fonte

Nesta reconstrução foram usadas somente ferramentas nativas do Codex: terminal, edição de arquivos e visualização de imagens. O terminal executa código autoral no Blender já instalado localmente. Não foram carregadas skills externas, consultados repositórios externos, usados MCPs de modelagem ou enviados arquivos a geradores 3D remotos.

- `reconstruir_anime.py`: fonte da nova modelagem, criada do zero.
- `fabricar_anime.py`: união volumétrica, validação e exportação.
- `referencias/`: nove imagens fornecidas pelo usuário e manifesto de origem.

## Nova modelagem

As formas foram refeitas com anatomia contínua, musculatura e dobras pertencentes à superfície, olhos angulares, íris apoiadas na superfície facial, mechas curvas e roupa aberta. A mão azul da Rebecca inclui falanges, juntas, carcaça e ranhuras. A fonte mantém as partes separadas e materiais; a versão de impressão consolida os volumes.

| Personagem | Fonte editável | Corpo | Rosto |
| --- | --- | --- | --- |
| David | [david_anime.blend](david_anime/david_anime.blend) | [Render](david_anime/corpo.png) | [Close](david_anime/rosto.png) |
| Rebecca | [rebecca_anime.blend](rebecca_anime/rebecca_anime.blend) | [Render](rebecca_anime/corpo.png) | [Close](rebecca_anime/rosto.png) |

A referência do David é a versão musculosa de jaqueta e implantes. O arquivo da Rebecca corta a parte inferior do corpo; pernas e botas são interpretação. Costas e superfícies ocultas também são interpretações. Não há alegação de reprodução exata de detalhes que não são visíveis nas imagens.

## Impressão

A escala de exportação permanece provisoriamente em **120 mm incluindo a base**. A fonte usa medidas de construção diferentes, e o exportador aplica a escala explicitamente. STL deve ser importado em milímetros.

Cada personagem tem um relatório `validacao_anime.json`. A exportação é bloqueada se houver componentes separados, arestas não manifold, faces degeneradas ou volume inválido. O STL exportado é reaberto para conferir dimensões e integridade binária.

Malha fechada não garante impressão bem-sucedida: não houve teste físico, verificação abrangente de espessuras, geração de suportes ou fatiamento para uma máquina específica. Os arquivos não contêm perfil de impressora nem G-code.

## Reprodução

Executar a partir da raiz do workspace:

```bash
blender --background --factory-startup --python-exit-code 1 --python miniaturas_3d/reconstruir_anime.py -- --personagem david --render --close
blender --background --factory-startup miniaturas_3d/david_anime/david_anime.blend --python-exit-code 1 --python miniaturas_3d/fabricar_anime.py -- --nome david --altura 120 --render
```

Trocar `david` por `rebecca` para o segundo personagem. Alterações manuais no `.blend` não voltam automaticamente ao gerador. Alterar altura exige nova avaliação dos detalhes finos.

## Checkpoint

Modelos rejeitados removidos. Reconstrução de David e Rebecca em revisão visual e validação digital. A aprovação de fidelidade pelo usuário ainda não foi obtida. Não chamar a coleção inteira de concluída: os demais personagens não foram modelados. Material/processo de impressão e tamanho definitivo continuam sem confirmação.
