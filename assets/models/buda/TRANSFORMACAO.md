# Transformação do Buda — Mine Piece

`buda_transformacao.tscn` substitui o visual de `hito_hito_daibutsu` na tecla J.
Fonte editável: `tools/gerar_buda_transformacao.gd`, usando somente Godot.

Referência: `assets/mine_piece/visual/entidades/transform_hito_hito_daibutsu_humanbeast.png`.
A paleta é extraída dos pixels opacos originais. A interpretação dos desenhos constrói
peitorais, barriga oval, deltoides, braços, coxas e canelas com profundidade real.
Os pontos dourados da cabeça viram cachos; o rosto vazado da referência foi reconstruído
com geometria sólida, nariz, olhos, boca e orelhas alongadas. A malha final não depende
da transparência nem do carregamento da textura original em execução.

12 peças, 15.980 triângulos, um material compartilhado com cores por vértice.
Cotovelos, joelhos e pés acompanham as respectivas juntas do personagem; a rotação
herdada do pai é descontada para não aplicar duas vezes o movimento.
Mantidos os identificadores, poderes, tecla J e escala 3,5 do mod.

## Reprodução

Gerar: `godot --headless --path . --script tools/gerar_buda_transformacao.gd`.
Prévia: `godot --path . --script tools/dev_tests/captura_buda_transformacao.gd`.
Referência anterior: acrescentar `-- referencia` à prévia.
Integração: `godot --path . --fixed-fps 60 --script tools/dev_tests/test_buda_transformacao.gd`.
O último comando também funciona com `--headless`, sem capturas.
Para testes isolados, definir XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME em `/tmp`.

## Evidência em 11/11/2026

- 30 verificações focadas passaram no Modo História com Forward+: transformação,
  caminhada pelo controle real, perspectiva, articulações, retorno e troca de fruta.
- 185 verificações das 14 formas Zoan passaram após a integração.
- Capturas antes/depois, parado, andando e pose articulada em
  `art_src/validation/buda_transformacao/`.
- Corrigida a remoção da forma durante `_exit_tree`: libera nome e visibilidade
  imediatamente, e retira o nó com `queue_free` sem modificar um pai ocupado.

Limitações: a replicação multiplayer continua limitada pelo sistema Zoan existente.
Não foi testada a bateria completa de golpes nem morte/respawn. Os logs também
registram erros da tela de carregamento (`tela_de_carregamento.gd:87/89`) e avisos
de recursos vivos ao encerrar; não são uma validação global sem erros do projeto.
