# Fruta do Buda voxel

Modelo autoral gerado por código, somente com a API nativa do Godot 4.6.3.
Sem Blender, plugins de modelagem, bibliotecas adicionais ou geração externa.

- Cena editável: `buda_voxel.tscn`.
- Fonte da geometria: `tools/gerar_buda_voxel.gd`.
- Ícone com transparência: `buda_loja.png` (256 × 256).
- Integração: `TreeAndFruitGenerator.PICKUPS_AUTORAIS`, ID `hito_hito_daibutsu`.
- Loja: `PerfilDeFrutas.imagem_na_loja` usa a renderização deste modelo.
- Malha: 7.644 triângulos, uma superfície/material, faces internas removidas.

Para regenerar, executar Godot com `--headless --path . --script tools/gerar_buda_voxel.gd`.
Para renderizar frente, costas e ícone, executar com `--path . --rendering-method gl_compatibility --script tools/dev_tests/captura_buda_voxel.gd`.
O mesmo script em modo `--headless` verifica a integração e o carregamento do ícone já importado.

Validação em 11/11/2026: renderizações inspecionadas e verificações focadas de criação,
colisão, escala, catálogo, preço e textura. Capturas em `art_src/validation/buda_voxel/`.
Não houve playtest completo no Modo História nem alteração das habilidades da fruta.
