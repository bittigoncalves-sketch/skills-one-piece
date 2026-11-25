# Transformação do Buda — 11/11/2026

Objetivo: reconstruir o modelo da transformação `hito_hito_daibutsu`, usando os detalhes e a paleta da textura do Mine Piece como referência para volume 3D. Manter criação por código nativo, sem plugins externos.

Concluído: referência renderizada confirmou rosto vazado; novo corpo voxel sólido usa a paleta da textura e converte desenhos de musculatura/barriga em volumes. 12 peças articuladas, 15.980 triângulos, um material.

Arquivos: `tools/gerar_buda_transformacao.gd`, `assets/models/buda/buda_transformacao.tscn`, `src/minecraft/forma_zoan.gd`, `tools/dev_tests/captura_buda_transformacao.gd`, `tools/dev_tests/test_buda_transformacao.gd`, adaptação do teste de material em `test_forma_zoan.gd`. Preservada a correção concorrente de camadas das demais Zoans.

Validação: 30 verificações focadas e 185 da bateria Zoan passaram. Capturas no Modo História com Forward+ conferidas: parado, andando e articulações. Correção adicional de remoção segura na troca de fruta.

Limites: sem validação multiplayer, bateria completa de golpes ou morte/respawn. Logs preservam erros externos da tela de carregamento e recursos vivos no encerramento. Detalhes em `assets/models/buda/TRANSFORMACAO.md`.
Próximo passo opcional: revisão visual do usuário e ajustes artísticos solicitados.
