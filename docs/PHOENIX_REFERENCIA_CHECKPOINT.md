# Fênix — nova referência 14/10/2026

## Entrega

Reconstruída a forma completa da Tori Tori pela imagem enviada: volumes azuis
em camadas, pontas das asas em gancho, crista/faixas douradas, cabeça afilada,
marca escura no peito e cinco caudas contínuas. A referência é orientação
artística; não se declara reprodução exata nem aprovação artística do usuário.

Modelo exportado e capturado no mapa real da história, por Z e F. Preservados:
controlador, ações Z/X/C/V/F/H, dano, duração, colisão e identidade dos pivôs.
O recurso é compartilhado pela história e arena.

## Fonte e reprodução

- `src/effects/phoenix/forma_phoenix.gd`: construção, materiais e poses.
- `src/effects/phoenix/labaredas_phoenix.gd`: volumes fechados em Bézier.
- `src/effects/phoenix/plasma_phoenix.gdshader`: bandas e onda ancorada na raiz.
- `assets/models/phoenix/fenix_anime.scn`: recurso exportado carregado pelo jogo.
- `tools/exportar_fenix_anime.gd`: exportação com Godot 4.6.3 headless.
- `tools/dev_tests/capturar_phoenix_anime.gd`: estúdio, poses e fases da batida;
  definir PHOENIX_CAPTURA_DIR=res://art_src/validation/phoenix_referencia_2026-10-14/.
- `tools/dev_tests/capturar_phoenix_referencia_historia.gd`: mapa real, progresso
  descartável, mouse liberado. A imagem 06 usa o scroll existente para 11 m;
  a imagem 05 mostra a distância padrão de 4 m. Não foi mudada a câmera do jogo.
- `tools/dev_tests/test_phoenix_rig.gd`: acrescentada medição dos vértices das
  asas contra o chão nas poses terrestres ao fim de cada fase.

Referência: `art_src/references/phoenix/referencia_usuario.png`, fornecida pelo
usuário; não houve importação de modelo externo nem licença externa presumida.
Backup anterior: `art_src/validation/phoenix_referencia_2026-10-14/antes/`.

## Validação

Godot 4.6.3, capturas Forward+ / NVIDIA RTX 3050 6 GB.
Logs e imagens em `art_src/validation/phoenix_referencia_2026-10-14/`.

- Exportação: erro 0; recurso carregado em estúdio e no mapa da história.
- Kit: 34 verificações passaram, 0 falhas; inclui cinco transformações sem
  acúmulo de nós e limpeza dos efeitos.
- Locomoção na história: 23 passaram, 0 falhas.
- Rig: 220.152 verificações, 0 falhas a 30/60 FPS; comprimentos, contato dos
  pés, transições, escala unitária e asas acima do chão nas poses medidas.
- Geometria carregada: 79 superfícies, 222.176 vértices, 442.270 triângulos.
  São contagens, não um benchmark de FPS ou custo de GPU.
- Índice documental regenerado pelo verificador; foi apontado um caminho
  antigo ausente em docs/contexto/agentes/historia.md
  (`historia/equipamentos/bicicleta_de_gelo.gd`). Log em indice.log.
- Compilação global: 6 scripts de tools/anim_editor/studio reprovados, os
  mesmos caminhos registrados antes desta tarefa. Nenhum arquivo dessa frente
  foi alterado.
- Regressão geral parcial: 41 passaram / 12 reprovaram. Foi interrompida após
  reproduzir falhas já apontadas na lista de correções (arena sem dummy, água,
  Pika Z, bestas e editor de animação). Não é uma bateria completa nem verde.
  Resultado preservado em regressao_rapida.log e regressao_status.txt.

## Decisões e limites

A pergunta inicial sobre chama integral versus penas sólidas não recebeu
resposta; adotou-se chama integral pela referência explícita, após oportunidade
de resposta. Fonte procedural e exportação reproduzível mantidas.

A câmera próxima do humano pode ser encoberta pelas asas. O projeto registra
preferência por não forçar a câmera; perguntou-se sobre afastamento automático
exclusivo da fênix. Sem resposta, manteve-se o zoom manual existente. A captura
com scroll comprova o enquadramento afastado, não a existência de autozoom.

A comparação visual cobre frente, três quartos, dorso, cabeça, chão, sentado,
andando, voo e pouso. Não houve benchmark comparativo de desempenho nem teste
multiplayer novo (controlador/rede não alterados). Acabamento sujeito à avaliação
do usuário pelas capturas reais. Nenhum commit criado.
