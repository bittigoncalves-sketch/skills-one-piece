# Grama personalizada — 2026-11-12

Objetivo: criar uma nova textura de grama e integrar ao terreno do jogo.
Direção assumida: anime, verde vivo moderado, folhas curtas, sem pedras/flores, repetição sem ponto focal.
Asset gerado pela ferramenta integrada imagegen: `assets/textures/terreno/grama_anime.png`.
Integração: topo dos blocos GRAMA e formas derivadas (lajes/escadas/octantes), mipmaps e sampler dedicado para preservar a resolução sem aumentar todas as camadas do atlas vanilla.
Concluído: integração em `src/voxel/texturas_de_bloco.gd`, `grade_voxel.gd` e `bloco_minecraft.gdshader`; importação com mipmaps e limite de 1024 px.
Validação: `test_visual_minecraft.gd` — 145 verificações aprovadas, zero falhas. Capturas comparáveis em `antes/` e `depois/`; ilha real em `historia/`, via `GameFlow.start_story()`, Forward+, XDG temporário. Revisadas visualmente as vistas próximas e aéreas; nenhuma mudança de geometria/colisão.
Limitações: a malha distante simplificada permanece como antes. O teste completo da ilha emitiu erros de reparenting da interface e avisos de recursos no encerramento (log preservado), apesar de concluir as quatro capturas e sair com código 0. Não declarar regressão global verde. O contorno existente exige Forward+, por isso a tentativa inicial em compatibilidade foi substituída.
Próximo passo: avaliação artística do usuário; implementação pronta para o próximo início do jogo.
